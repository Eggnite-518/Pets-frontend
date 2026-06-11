import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/utils/image_url_helper.dart';
import 'package:pets/features/caretaker/data/models/fulfillment_record_model.dart';
import 'package:pets/features/caretaker/domain/entities/fulfillment_record.dart';
import 'package:pets/features/owner/data/datasources/order_remote_data_source.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerFulfillmentRecordsScreen extends StatefulWidget {
  const OwnerFulfillmentRecordsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OwnerFulfillmentRecordsScreen> createState() =>
      _OwnerFulfillmentRecordsScreenState();
}

class _OwnerFulfillmentRecordsScreenState
    extends State<OwnerFulfillmentRecordsScreen> {
  static const _nodeTitles = {
    1: '抵达签到',
    2: '入户确认',
    3: '喂食换水',
    4: '铲屎清洁',
    5: '遛宠中',
    6: '锁门离场',
  };

  static const _nodeIcons = {
    1: Icons.location_on_outlined,
    2: Icons.photo_camera_outlined,
    3: Icons.water_drop_outlined,
    4: Icons.cleaning_services_outlined,
    5: Icons.directions_walk_outlined,
    6: Icons.lock_outlined,
  };

  final ApiClient _apiClient = ApiClient();
  late final OrderRemoteDataSource _dataSource;

  bool _isLoading = true;
  String? _error;
  List<int> _checklistNodeTypes = const [];
  final Map<int, FulfillmentRecord> _recordsByNode = {};

  @override
  void initState() {
    super.initState();
    _dataSource = OrderRemoteDataSource(_apiClient);
    _load();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _dataSource.getFulfillmentRecords(widget.orderId);
      if (!mounted) return;
      if (!response.isSuccess || response.data == null) {
        setState(() {
          _isLoading = false;
          _error = response.message.isEmpty ? '加载失败' : response.message;
        });
        return;
      }

      final map = response.data!;
      final checklistRaw = map['checklistNodeTypes'];
      final recordsRaw = map['records'];
      final checklist = checklistRaw is List
          ? checklistRaw.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toList()
          : <int>[];
      final recordsByNode = recordsRaw is List
          ? _parseRecords(recordsRaw)
          : <int, FulfillmentRecord>{};

      setState(() {
        _checklistNodeTypes = checklist;
        _recordsByNode
          ..clear()
          ..addAll(recordsByNode);
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '加载失败，请稍后重试';
      });
    }
  }

  Map<int, FulfillmentRecord> _parseRecords(List<dynamic> recordsRaw) {
    final map = <int, FulfillmentRecord>{};
    for (final item in recordsRaw) {
      final record = FulfillmentRecordModel.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
      map[record.nodeType] = record;
    }
    return map;
  }

  FulfillmentRecord? _recordForNode(int nodeType) => _recordsByNode[nodeType];

  void _openImagePreview(String url) {
    final normalized = ensureHttpsMediaUrl(url);
    if (normalized.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.network(
                  normalized,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      '图片加载失败',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openVideo(String? url) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('视频暂不可用')),
      );
      return;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开视频')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '服务打卡记录 · ${widget.orderId}',
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final nodes = _checklistNodeTypes.isNotEmpty
        ? _checklistNodeTypes
        : const [1, 2, 3, 4, 6];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2EF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF9BC7B4)),
            ),
            child: const Text(
              '以下为宠托师履约打卡节点。确认完成前请核对各节点照片与视频是否齐全。',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF4A6358),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(nodes.length, (index) {
            final nodeType = nodes[index];
            final record = _recordForNode(nodeType);
            final isCompleted = record != null && !record.isFailed;
            return _OwnerTimelineNode(
              index: index,
              isLast: index == nodes.length - 1,
              nodeType: nodeType,
              title: _nodeTitles[nodeType] ?? '节点 $nodeType',
              icon: _nodeIcons[nodeType] ?? Icons.check_circle_outline,
              record: record,
              isCompleted: isCompleted,
              onPreviewImage: _openImagePreview,
              onOpenVideo: _openVideo,
            );
          }),
        ],
      ),
    );
  }
}

class _OwnerTimelineNode extends StatelessWidget {
  final int index;
  final bool isLast;
  final int nodeType;
  final String title;
  final IconData icon;
  final FulfillmentRecord? record;
  final bool isCompleted;
  final void Function(String url) onPreviewImage;
  final Future<void> Function(String? url) onOpenVideo;

  const _OwnerTimelineNode({
    required this.index,
    required this.isLast,
    required this.nodeType,
    required this.title,
    required this.icon,
    required this.record,
    required this.isCompleted,
    required this.onPreviewImage,
    required this.onOpenVideo,
  });

  String get _statusText {
    if (record == null) return '宠托师尚未打卡';
    if (record!.isFailed) {
      return record!.processingError?.isNotEmpty == true
          ? record!.processingError!
          : '处理失败，宠托师需重新上传';
    }
    if (record!.isProcessing) return '媒体处理中，请稍后刷新';
    if (record!.isVideo) return '离场视频已提交';
    if (nodeType == 1) return '已于 ${record!.createdAt} 完成签到';
    return '已于 ${record!.createdAt} 提交留证';
  }

  bool get _showImage {
    if (record == null || record!.isVideo || record!.isFailed) return false;
    final url = record!.imageUrl?.trim() ?? '';
    return url.isNotEmpty && record!.isMediaReady;
  }

  bool get _showVideo {
    if (record == null || !record!.isVideo || record!.isFailed) return false;
    return record!.isMediaReady || record!.isProcessing;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = isCompleted
        ? const Color(0xFF004D36)
        : record?.isFailed == true
        ? const Color(0xFFD14B4B)
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
                        : const Color(0xFFF0F3F1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: isCompleted ? 0 : 1.5,
                    ),
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
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFFD7E8E0)
                      : const Color(0xFFE8EDEA),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isCompleted
                                ? const Color(0xFF1A2621)
                                : const Color(0xFF6A7D74),
                          ),
                        ),
                      ),
                      if (isCompleted)
                        const Icon(
                          Icons.verified_outlined,
                          color: Color(0xFF004D36),
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: record?.isFailed == true
                          ? const Color(0xFFD14B4B)
                          : const Color(0xFF6A7D74),
                    ),
                  ),
                  if (_showImage) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => onPreviewImage(record!.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Image.network(
                            ensureHttpsMediaUrl(record!.imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF0F3F1),
                              alignment: Alignment.center,
                              child: const Text('图片加载失败'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_showVideo) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: record!.isProcessing
                          ? null
                          : () => onOpenVideo(ensureHttpsMediaUrl(record!.imageUrl)),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: Text(
                        record!.isProcessing ? '视频处理中…' : '查看离场视频',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF004D36),
                        side: const BorderSide(color: Color(0xFF9BC7B4)),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                  if (record?.watermarkText?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      '水印：${record!.watermarkText}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8FA198),
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
}
