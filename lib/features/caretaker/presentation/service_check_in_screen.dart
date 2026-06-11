import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/utils/image_url_helper.dart';

import '../data/datasources/caretaker_dashboard_remote_data_source.dart';
import '../data/datasources/fulfillment_remote_data_source.dart';
import '../data/repositories/caretaker_dashboard_repository_impl.dart';
import '../data/repositories/fulfillment_repository_impl.dart';
import '../domain/entities/fulfillment_record.dart';
import '../domain/usecases/add_fulfillment_record_use_case.dart';
import '../domain/usecases/get_caretaker_order_detail_use_case.dart';
import '../domain/usecases/get_fulfillment_records_use_case.dart';
import '../domain/usecases/self_report_exception_use_case.dart';

/// 打卡节点定义（nodeType → label / icon / subtitle）
const _allNodes = [
  _NodeMeta(
    1,
    '抵达签到',
    '需在服务地址500米内签到，将获取当前位置',
    Icons.location_on_outlined,
    false,
    false,
    true,
  ),
  _NodeMeta(
    2,
    '入户确认',
    '拍摄进门凭证照片，需在服务地址附近（必填）',
    Icons.photo_camera_outlined,
    true,
    false,
    true,
  ),
  _NodeMeta(
    3,
    '喂食换水',
    '完成喂食换水后拍照留证，需在服务地址附近（必填）',
    Icons.water_drop_outlined,
    true,
    false,
    true,
  ),
  _NodeMeta(
    4,
    '铲屎清洁',
    '清理完成后拍照留证，需在服务地址附近（必填）',
    Icons.cleaning_services_outlined,
    true,
    false,
    true,
  ),
  _NodeMeta(
    5,
    '遛宠中',
    '遛宠过程或结果拍照留证（必填）',
    Icons.directions_walk_outlined,
    true,
    false,
    false,
  ),
  _NodeMeta(
    6,
    '锁门离场',
    '拍摄视频确认门窗已锁好，需在服务地址附近（必填）',
    Icons.lock_outlined,
    false,
    true,
    true,
  ),
];

class _NodeMeta {
  final int type;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool requiresPhoto;
  final bool requiresVideo;
  final bool requiresLocation;
  const _NodeMeta(
    this.type,
    this.title,
    this.subtitle,
    this.icon,
    this.requiresPhoto,
    this.requiresVideo,
    this.requiresLocation,
  );
}

class _SubmitLocation {
  final double? lat;
  final double? lng;
  final _LocationError? error;

  const _SubmitLocation({this.lat, this.lng, this.error});
}

enum _LocationError {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class ServiceCheckInScreen extends StatefulWidget {
  const ServiceCheckInScreen({
    super.key,
    required this.serviceId,
    this.checklistNodeTypes = const [],
  });

  final String serviceId;
  final List<int> checklistNodeTypes;

  @override
  State<ServiceCheckInScreen> createState() => _ServiceCheckInScreenState();
}

class _ServiceCheckInScreenState extends State<ServiceCheckInScreen> {
  final Set<int> _completedNodes = {};

  /// 节点 → 后端返回的履约记录，用于展示处理状态
  final Map<int, FulfillmentRecord> _records = {};

  /// 本地上传文件路径，用于即时预览
  final Map<int, String> _localMediaPaths = {};

  bool _isLoadingRecords = true;

  /// 拍照/视频节点 nodeType，正在上传时非 null
  int? _uploadingMediaNode;

  /// 非媒体节点正在提交的 nodeType
  int? _submittingNode;

  List<int> _checklistNodeTypes = const [];

  late final AddFulfillmentRecordUseCase _addFulfillmentRecordUseCase;
  late final GetCaretakerOrderDetailUseCase _getOrderDetailUseCase;
  late final GetFulfillmentRecordsUseCase _getFulfillmentRecordsUseCase;
  late final SelfReportExceptionUseCase _selfReportExceptionUseCase;

  final ImagePicker _imagePicker = ImagePicker();
  bool _isReportingEmergency = false;
  bool _emergencyExpanded = false;
  bool _fulfillmentChanged = false;

  /// 5=待宠主确认，6=已完成；null 表示尚未拉取
  int? _orderStatus;
  String _accessNote = '';

  _SubmitLocation? _cachedLocation;
  DateTime? _cachedLocationAt;
  bool _isPrefetchingLocation = false;
  Timer? _processingPollTimer;
  Timer? _orderStatusPollTimer;

  List<_NodeMeta> get _visibleNodes {
    final typeOrder = _checklistNodeTypes.isNotEmpty
        ? _checklistNodeTypes
        : _allNodes.map((node) => node.type).toList();
    return typeOrder
        .map((type) => _allNodes.where((node) => node.type == type).firstOrNull)
        .whereType<_NodeMeta>()
        .toList();
  }

  @override
  void dispose() {
    _processingPollTimer?.cancel();
    _orderStatusPollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _checklistNodeTypes = List<int>.from(widget.checklistNodeTypes);
    final client = ApiClient();
    final httpClient = http.Client();
    final dashboardRepo = CaretakerDashboardRepositoryImpl(
      CaretakerDashboardRemoteDataSource(client),
    );
    final fulfillmentDataSource = FulfillmentRemoteDataSource(
      client,
      httpClient,
    );
    final fulfillmentRepo = FulfillmentRepositoryImpl(fulfillmentDataSource);
    _addFulfillmentRecordUseCase = AddFulfillmentRecordUseCase(fulfillmentRepo);
    _getOrderDetailUseCase = GetCaretakerOrderDetailUseCase(dashboardRepo);
    _getFulfillmentRecordsUseCase = GetFulfillmentRecordsUseCase(
      fulfillmentRepo,
    );
    _selfReportExceptionUseCase = SelfReportExceptionUseCase(fulfillmentRepo);
    _loadInitialData();
    _prefetchLocation();
  }

  Future<void> _prefetchLocation() async {
    if (_isPrefetchingLocation) return;
    _isPrefetchingLocation = true;
    await _resolveCurrentLocation(forceRefresh: true);
    _isPrefetchingLocation = false;
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingRecords = true);
    await _restoreChecklistNodes();
    if (!mounted) return;
    await _restoreCompletedNodes();
  }

  Future<void> _restoreChecklistNodes() async {
    final result = await _getOrderDetailUseCase(widget.serviceId);
    if (!mounted) return;
    result.when(
      success: (detail) {
        setState(() {
          _orderStatus = detail.orderStatus;
          _accessNote = detail.requirementTags.accessNote.trim();
          if (_checklistNodeTypes.isEmpty && detail.checklistNodeTypes.isNotEmpty) {
            _checklistNodeTypes = List<int>.from(detail.checklistNodeTypes);
          }
        });
        _syncOrderStatusPolling();
      },
      failure: (_) {},
    );
  }

  Future<void> _refreshOrderStatus() async {
    final result = await _getOrderDetailUseCase(widget.serviceId);
    if (!mounted) return;
    result.when(
      success: (detail) {
        final previous = _orderStatus;
        setState(() {
          _orderStatus = detail.orderStatus;
          _accessNote = detail.requirementTags.accessNote.trim();
        });
        if (previous == 5 && detail.orderStatus == 6) {
          _showSnackBar('宠主已确认完成，订单已结算');
        }
        _syncOrderStatusPolling();
      },
      failure: (_) {},
    );
  }

  void _syncOrderStatusPolling() {
    _orderStatusPollTimer?.cancel();
    _orderStatusPollTimer = null;
    if (_orderStatus != 5 || !_allNodesCompleted) return;
    _orderStatusPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshOrderStatus(),
    );
  }

  Future<void> _restoreCompletedNodes() async {
    final result = await _getFulfillmentRecordsUseCase(widget.serviceId);
    if (!mounted) return;
    result.when(
      success: (records) {
        setState(() {
          _completedNodes.clear();
          _records.clear();
          for (final r in records) {
            _records[r.nodeType] = r;
          }
          for (final entry in _records.entries) {
            if (!entry.value.isFailed) {
              _completedNodes.add(entry.key);
            }
          }
          _isLoadingRecords = false;
        });
        _scheduleProcessingPoll();
        _syncOrderStatusPolling();
      },
      failure: (_) => setState(() => _isLoadingRecords = false),
    );
  }

  Future<void> _refreshProcessingRecords() async {
    final result = await _getFulfillmentRecordsUseCase(widget.serviceId);
    if (!mounted) return;
    result.when(
      success: (records) {
        final hadProcessing = _records.values.any((record) => record.isProcessing);
        setState(() {
          _completedNodes.clear();
          _records.clear();
          for (final r in records) {
            _records[r.nodeType] = r;
          }
          for (final entry in _records.entries) {
            if (!entry.value.isFailed) {
              _completedNodes.add(entry.key);
            }
          }
        });
        final hasProcessing = _records.values.any((record) => record.isProcessing);
        final hasFailed = _records.values.any((record) => record.isFailed);
        if (hadProcessing && !hasProcessing) {
          if (hasFailed) {
            _showSnackBar('视频处理失败，请查看节点提示后重新上传', isError: true);
          } else {
            _showSnackBar('视频处理完成');
          }
        }
        _scheduleProcessingPoll();
      },
      failure: (_) {},
    );
  }

  void _scheduleProcessingPoll() {
    _processingPollTimer?.cancel();
    final hasProcessing = _records.values.any((record) => record.isProcessing);
    if (!hasProcessing) return;
    _processingPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshProcessingRecords(),
    );
  }

  bool _isNodeCompleted(int nodeType) {
    final record = _records[nodeType];
    if (record?.isFailed == true) return false;
    return _completedNodes.contains(nodeType);
  }

  bool _isNodeEnabled(int nodeType) {
    if (_isNodeCompleted(nodeType)) return false;
    final currentIndex = _visibleNodes.indexWhere(
      (node) => node.type == nodeType,
    );
    if (currentIndex == -1) return false;
    if (currentIndex == 0) return true;
    final previousNodeType = _visibleNodes[currentIndex - 1].type;
    return _isNodeCompleted(previousNodeType);
  }

  int get _completedCount =>
      _visibleNodes.where((node) => _isNodeCompleted(node.type)).length;

  bool get _allNodesCompleted =>
      _visibleNodes.isNotEmpty && _completedCount == _visibleNodes.length;

  void _markFulfillmentChanged() => _fulfillmentChanged = true;

  void _exitCheckIn() {
    Navigator.of(context).pop(_fulfillmentChanged);
  }

  void _openImagePreview({String? localPath, String? remoteUrl}) {
    final url = remoteUrl == null ? null : ensureHttpsMediaUrl(remoteUrl);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: localPath != null
                    ? Image.file(File(localPath), fit: BoxFit.contain)
                    : Image.network(url!, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFD14B4B) : null,
        ),
      );
  }

  Future<_SubmitLocation> _resolveCurrentLocation({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedLocation?.lat != null &&
        _cachedLocationAt != null &&
        DateTime.now().difference(_cachedLocationAt!) <
            const Duration(minutes: 2)) {
      return _cachedLocation!;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final failed =
            const _SubmitLocation(error: _LocationError.serviceDisabled);
        _cachedLocation = failed;
        return failed;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        final failed =
            const _SubmitLocation(error: _LocationError.permissionDenied);
        _cachedLocation = failed;
        return failed;
      }
      if (permission == LocationPermission.deniedForever) {
        final failed = const _SubmitLocation(
          error: _LocationError.permissionDeniedForever,
        );
        _cachedLocation = failed;
        return failed;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (_) {
          position = await Geolocator.getLastKnownPosition();
        }
      }

      if (position == null) {
        final failed = const _SubmitLocation(error: _LocationError.unavailable);
        _cachedLocation = failed;
        return failed;
      }

      final location = _SubmitLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
      _cachedLocation = location;
      _cachedLocationAt = DateTime.now();
      return location;
    } catch (_) {
      final failed = const _SubmitLocation(error: _LocationError.unavailable);
      _cachedLocation = failed;
      return failed;
    }
  }

  Future<_SubmitLocation?> _requireCurrentLocation() async {
    var location = await _resolveCurrentLocation();
    if (location.lat != null && location.lng != null) {
      return location;
    }
    location = await _resolveCurrentLocation(forceRefresh: true);
    if (location.lat != null && location.lng != null) {
      return location;
    }
    return null;
  }

  String _locationErrorMessage(_LocationError? error) {
    return switch (error) {
      _LocationError.serviceDisabled => '请先在系统设置中开启定位服务',
      _LocationError.permissionDenied ||
      _LocationError.permissionDeniedForever =>
        '请先在系统设置中允许本 App 使用定位权限',
      _LocationError.unavailable ||
      null =>
        '暂时无法获取当前位置，请到窗边或室外重试',
    };
  }

  Future<_SubmitLocation?> _resolveLocationForNode(int nodeType) async {
    final meta = _allNodes.where((node) => node.type == nodeType).firstOrNull;
    if (meta?.requiresLocation == true) {
      return _requireCurrentLocation();
    }
    return _resolveCurrentLocation();
  }

  Future<void> _submitSimpleNode(int nodeType) async {
    if (!_isNodeEnabled(nodeType)) return;
    setState(() => _submittingNode = nodeType);
    final location = await _resolveLocationForNode(nodeType);
    if (location == null) {
      _showSnackBar(
        _locationErrorMessage(_cachedLocation?.error),
        isError: true,
      );
      if (mounted) setState(() => _submittingNode = null);
      return;
    }
    final result = await _addFulfillmentRecordUseCase(
      orderId: widget.serviceId,
      nodeType: nodeType,
      lat: location.lat,
      lng: location.lng,
    );
    if (!mounted) return;
    result.when(
      success: (record) => setState(() {
        _markFulfillmentChanged();
        _completedNodes.add(nodeType);
        _records[nodeType] = record;
      }),
      failure: (error) => _showSnackBar(error.message, isError: true),
    );
    if (mounted) setState(() => _submittingNode = null);
  }

  Future<void> _submitMediaNode(int nodeType, {bool isVideo = false}) async {
    if (!_isNodeEnabled(nodeType)) return;
    setState(() => _uploadingMediaNode = nodeType);

    try {
      final location = await _resolveLocationForNode(nodeType);
      if (location == null) {
        _showSnackBar(
          _locationErrorMessage(_cachedLocation?.error),
          isError: true,
        );
        if (mounted) setState(() => _uploadingMediaNode = null);
        return;
      }

      final XFile? picked = isVideo
          ? await _showVideoSourceAndPick()
          : await _showImageSourceAndPick();

      if (picked == null) {
        if (mounted) setState(() => _uploadingMediaNode = null);
        return;
      }

      final mediaFile = File(picked.path);
      final result = await _addFulfillmentRecordUseCase(
        orderId: widget.serviceId,
        nodeType: nodeType,
        file: mediaFile,
        lat: location.lat,
        lng: location.lng,
      );
      if (!mounted) return;
      result.when(
        success: (record) {
          setState(() {
            _markFulfillmentChanged();
            _completedNodes.add(nodeType);
            _records[nodeType] = record;
            _localMediaPaths[nodeType] = mediaFile.path;
          });
          _scheduleProcessingPoll();
          if (nodeType == 6) {
            _syncOrderStatusPolling();
            _showSnackBar(
              record.isProcessing
                  ? '离场视频已上传，后台处理中。全部打卡已完成，等待宠主确认。'
                  : '全部打卡已完成，等待宠主确认订单',
            );
            return;
          }
          if (record.isProcessing) {
            _showSnackBar('视频上传成功，后台处理中…');
          } else {
            _showSnackBar('${isVideo ? '视频' : '照片'}上传成功');
          }
        },
        failure: (error) => _showSnackBar(error.message, isError: true),
      );
    } catch (e) {
      _showSnackBar('上传失败，请检查网络后重试', isError: true);
    }

    if (mounted) setState(() => _uploadingMediaNode = null);
  }

  Future<XFile?> _showVideoSourceAndPick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE5E2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '上传离场视频',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: Color(0xFF004D36)),
              title: const Text('录制视频'),
              subtitle: const Text('建议 15–60 秒，确认门窗已锁好'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined, color: Color(0xFF004D36)),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return _imagePicker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
  }

  Future<XFile?> _showImageSourceAndPick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE5E2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: Color(0xFF004D36),
              ),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF004D36),
              ),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
  }

  Future<void> _openEmergencyReportSheet() async {
    if (_isReportingEmergency) return;
    final draft = await showModalBottomSheet<_EmergencyReportDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EmergencyReportSheet(),
    );
    if (draft == null || !mounted) return;

    setState(() => _isReportingEmergency = true);
    final result = await _selfReportExceptionUseCase(
      orderId: widget.serviceId,
      exceptionType: draft.exceptionType,
      description: draft.description,
    );
    if (!mounted) return;
    setState(() => _isReportingEmergency = false);

    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _visibleNodes.length;
    final completed = _completedCount;
    final progress = total == 0 ? 0.0 : completed / total;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitCheckIn();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F6F4),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF3F6F4),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: BackButton(onPressed: _exitCheckIn),
          title: const Text(
            '履约打卡',
            style: TextStyle(
              color: Color(0xFF1A2621),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        ),
        body: _isLoadingRecords
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF004D36)),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _ProgressHeader(
                      orderId: widget.serviceId,
                      completed: completed,
                      total: total,
                      progress: progress,
                      allCompleted: _allNodesCompleted,
                    ),
                  ),
                  if (_accessNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _AccessNoteBanner(accessNote: _accessNote),
                    ),
                  if (_allNodesCompleted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _CompletionBanner(
                        orderStatus: _orderStatus ?? 5,
                        onBackToOrder: _exitCheckIn,
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _visibleNodes.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        if (index == _visibleNodes.length) {
                          return _EmergencyCollapsedSection(
                            expanded: _emergencyExpanded,
                            isSubmitting: _isReportingEmergency,
                            onToggle: () => setState(
                              () => _emergencyExpanded = !_emergencyExpanded,
                            ),
                            onTap: _openEmergencyReportSheet,
                          );
                        }

                        final node = _visibleNodes[index];
                        final isCompleted = _isNodeCompleted(node.type);
                        final isEnabled = _isNodeEnabled(node.type);
                        final isCurrent =
                            isEnabled && !isCompleted && !_isLoadingRecords;
                        final record = _records[node.type];
                        final localPath = _localMediaPaths[node.type];
                        final isLast = index == _visibleNodes.length - 1;

                        return _TimelineNodeCard(
                          meta: node,
                          index: index,
                          isLast: isLast,
                          isCompleted: isCompleted,
                          isEnabled: isEnabled,
                          isCurrent: isCurrent,
                          isLoading: _uploadingMediaNode == node.type ||
                              _submittingNode == node.type,
                          record: record,
                          localMediaPath: localPath,
                          onSimpleSubmit: () => _submitSimpleNode(node.type),
                          onMediaSubmit: () => _submitMediaNode(
                            node.type,
                            isVideo: node.requiresVideo,
                          ),
                          onPreviewImage: () => _openImagePreview(
                            localPath: localPath,
                            remoteUrl: record?.imageUrl,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EmergencyReportDraft {
  final int exceptionType;
  final String description;

  const _EmergencyReportDraft({
    required this.exceptionType,
    required this.description,
  });
}

class _EmergencyCollapsedSection extends StatelessWidget {
  final bool expanded;
  final bool isSubmitting;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _EmergencyCollapsedSection({
    required this.expanded,
    required this.isSubmitting,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(
                    Icons.support_agent_outlined,
                    size: 18,
                    color: expanded
                        ? const Color(0xFF6A7D74)
                        : const Color(0xFF8BA49A),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '遇到紧急情况需要帮助？',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6A7D74),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF8BA49A),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFE1E8E4)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '仅在宠物健康危急或存在人身威胁时使用。提交后订单将转为平台介入，并通知宠主。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6A7D74),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isSubmitting ? null : onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB02A37),
                      side: const BorderSide(color: Color(0xFFE8B4B0)),
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sos_outlined, size: 16),
                    label: Text(
                      isSubmitting ? '上报中…' : '发起紧急求助',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmergencyReportSheet extends StatefulWidget {
  const _EmergencyReportSheet();

  @override
  State<_EmergencyReportSheet> createState() => _EmergencyReportSheetState();
}

class _EmergencyReportSheetState extends State<_EmergencyReportSheet> {
  static const _options = [
    _EmergencyOption(2, '宠物异常', '宠物奄奄一息、抽搐、剧烈应激等，需要平台尽快介入'),
    _EmergencyOption(6, '人身威胁', '宠物强攻击性、咬人风险高，已无法安全靠近'),
  ];

  final TextEditingController _descriptionController = TextEditingController();
  int _selectedType = _options.first.code;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请补充现场情况说明')));
      return;
    }
    Navigator.of(context).pop(
      _EmergencyReportDraft(
        exceptionType: _selectedType,
        description: description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE5E2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '紧急求助',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2621),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '请选择紧急类型并简要描述现场情况。提交后订单会立即转为“紧急终止 / 平台介入”。',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5A6B62),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              RadioGroup<int>(
                groupValue: _selectedType,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedType = value);
                },
                child: Column(
                  children: _options
                      .map(
                        (option) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RadioListTile<int>(
                            value: option.code,
                            activeColor: const Color(0xFFB02A37),
                            title: Text(
                              option.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              option.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6A7D74),
                                height: 1.4,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            tileColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: '例如：猫咪持续抽搐且呼吸急促，已无法继续正常服务',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFDDE5E2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFDDE5E2)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB02A37),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('提交紧急求助'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyOption {
  final int code;
  final String title;
  final String subtitle;

  const _EmergencyOption(this.code, this.title, this.subtitle);
}

// ─── 门禁说明 ───────────────────────────────────────────────────────────────

class _AccessNoteBanner extends StatelessWidget {
  final String accessNote;

  const _AccessNoteBanner({required this.accessNote});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9BC7B4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.key_outlined, size: 18, color: Color(0xFF004D36)),
              SizedBox(width: 6),
              Text(
                '门禁说明',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF004D36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            accessNote,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A2621),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 进度头部 ───────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final String orderId;
  final int completed;
  final int total;
  final double progress;
  final bool allCompleted;

  const _ProgressHeader({
    required this.orderId,
    required this.completed,
    required this.total,
    required this.progress,
    this.allCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C5C43), Color(0xFF004D36)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF004D36).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '订单 #$orderId',
            style: const TextStyle(color: Color(0xFFD7E8E0), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completed',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                allCompleted ? ' 项全部完成' : ' / $total 项已完成',
                style: const TextStyle(
                  color: Color(0xFFD7E8E0),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (allCompleted) ...[
            const SizedBox(height: 8),
            const Text(
              '打卡记录已保存，可继续查看各节点详情',
              style: TextStyle(color: Color(0xFFD7E8E0), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: const Color(0xFF9FE0C3),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  final int orderStatus;
  final VoidCallback onBackToOrder;

  const _CompletionBanner({
    required this.orderStatus,
    required this.onBackToOrder,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = orderStatus == 6;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFE8F2EF) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF9BC7B4)
              : const Color(0xFFFFE0A3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.hourglass_top_rounded,
                color: isCompleted
                    ? const Color(0xFF004D36)
                    : const Color(0xFF9C5A00),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isCompleted ? '宠主已确认完成' : '全部打卡已完成',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isCompleted
                      ? const Color(0xFF004D36)
                      : const Color(0xFF9C5A00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isCompleted
                ? '本单已完成结算，收入将计入你的钱包。你可以继续浏览下方各节点记录。'
                : '订单已进入「待宠主确认」，宠主确认后平台会立即结算。',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4A6358),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onBackToOrder,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF004D36),
              side: const BorderSide(color: Color(0xFF9BC7B4)),
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('返回订单详情'),
          ),
        ],
      ),
    );
  }
}

// ─── 时间线节点卡片 ───────────────────────────────────────────────────────────

class _TimelineNodeCard extends StatelessWidget {
  final _NodeMeta meta;
  final int index;
  final bool isLast;
  final bool isCompleted;
  final bool isEnabled;
  final bool isCurrent;
  final bool isLoading;
  final FulfillmentRecord? record;
  final String? localMediaPath;
  final VoidCallback onSimpleSubmit;
  final VoidCallback onMediaSubmit;
  final VoidCallback onPreviewImage;

  const _TimelineNodeCard({
    required this.meta,
    required this.index,
    required this.isLast,
    required this.isCompleted,
    required this.isEnabled,
    required this.isCurrent,
    required this.isLoading,
    required this.record,
    required this.localMediaPath,
    required this.onSimpleSubmit,
    required this.onMediaSubmit,
    required this.onPreviewImage,
  });

  bool get _needsMedia => meta.requiresPhoto || meta.requiresVideo;

  @override
  Widget build(BuildContext context) {
    final active = isCompleted || isEnabled;
    final statusColor = isCompleted
        ? const Color(0xFF004D36)
        : isCurrent
        ? const Color(0xFF0C5C43)
        : const Color(0xFFC3D5CC);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF004D36)
                        : isCurrent
                        ? const Color(0xFFE8F2EF)
                        : const Color(0xFFF0F3F1),
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: isCompleted ? 0 : 1.5),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isCompleted
                          ? const Color(0xFF9BC7B4)
                          : const Color(0xFFE1E8E4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF9BC7B4)
                      : isCompleted
                      ? const Color(0xFFD7E8E0)
                      : const Color(0xFFE8EDEA),
                  width: isCurrent ? 1.5 : 1,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: const Color(0xFF004D36).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(meta.icon, size: 20, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          meta.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? const Color(0xFF1A2621)
                                : const Color(0xFFAAB8B1),
                          ),
                        ),
                      ),
                      if (isCompleted)
                        const Icon(Icons.verified_outlined, color: Color(0xFF004D36), size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitleText(),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: record?.isFailed == true
                          ? const Color(0xFFD14B4B)
                          : active
                          ? const Color(0xFF6A7D74)
                          : const Color(0xFFC3D5CC),
                    ),
                  ),
                  if (_showImagePreview) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onPreviewImage,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildPreviewImage(),
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_out_map, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        '查看大图',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_showVideoPreview) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F3F1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE1E8E4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF004D36).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.videocam_outlined,
                              color: Color(0xFF004D36),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              record?.isProcessing == true
                                  ? '离场视频已上传，后台处理中'
                                  : '离场视频已提交',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF4A6358),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isCompleted && record?.isProcessing == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF004D36),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('视频处理中，请稍候…', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  if (!isCompleted && (isEnabled || record?.isFailed == true)) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: isLoading
                            ? null
                            : (_needsMedia ? onMediaSubmit : onSimpleSubmit),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF004D36),
                          disabledBackgroundColor: const Color(0xFFD7E8E0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                meta.requiresVideo
                                    ? Icons.videocam_outlined
                                    : meta.requiresPhoto
                                    ? Icons.photo_camera_outlined
                                    : Icons.check_circle_outline,
                                size: 18,
                              ),
                        label: Text(
                          isLoading
                              ? '上传中…'
                              : meta.requiresVideo
                              ? '录制 / 上传视频'
                              : meta.requiresPhoto
                              ? '拍照 / 上传照片'
                              : '确认完成',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showImagePreview {
    if (!isCompleted || meta.requiresVideo) return false;
    if (localMediaPath != null) return true;
    return record?.isMediaReady == true &&
        record?.imageUrl != null &&
        record?.mediaType == 'IMAGE';
  }

  bool get _showVideoPreview {
    if (!isCompleted || !meta.requiresVideo) return false;
    return localMediaPath != null || record != null;
  }

  Widget _buildPreviewImage() {
    if (localMediaPath != null) {
      return Image.file(File(localMediaPath!), fit: BoxFit.cover);
    }
    final url = ensureHttpsMediaUrl(record!.imageUrl);
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFF0F3F1),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFF8BA49A), size: 40),
        ),
      ),
    );
  }

  String _subtitleText() {
    if (isLoading) return '上传中，请稍候…';
    if (isCompleted && record != null) {
      if (record!.isProcessing) return '视频已上传，后台处理中';
      if (record!.isFailed) {
        return '上传失败：${record!.processingError ?? '请重新上传'}';
      }
      if (meta.requiresVideo) return '视频已提交';
      if (meta.requiresPhoto) return '照片已上传，可点击查看大图';
      return '已完成';
    }
    if (isCurrent) return meta.subtitle;
    if (isEnabled) return meta.subtitle;
    return '请先完成上一项';
  }
}
