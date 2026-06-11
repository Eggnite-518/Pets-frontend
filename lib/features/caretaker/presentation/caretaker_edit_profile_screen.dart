import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/features/owner/presentation/address_location_picker_screen.dart';

import '../data/datasources/caretaker_profile_remote_data_source.dart';
import '../data/datasources/upload_remote_data_source.dart';
import '../data/repositories/caretaker_profile_repository_impl.dart';
import '../domain/entities/caretaker_profile.dart';
import '../domain/usecases/update_service_range_use_case.dart';
import '../domain/usecases/upload_image_use_case.dart';

/// 预设特色标签选项
const _kPresetLabels = [
  '1-3年经验',
  '3-5年经验',
  '5+年经验',
  '持证美容师',
  '宠物急救',
  '爱养猫咪',
  '爱养狗狗',
  '有自养宠物',
];

/// 业务属性标签（不计入特色标签 3 个上限）
const _kBusinessAttributeLabels = [
  '接受大型犬',
  '具备医疗/喂药经验',
];

/// 系统维护标签，用户不可自选（通过考核/履约等自动授予）
const _kSystemManagedLabels = {
  '实名认证',
  '平台认证',
  '10+次服务',
  '50+次服务',
};

bool _isUserSelectableLabel(String label) =>
    !_kSystemManagedLabels.contains(label);

class CaretakerEditProfileScreen extends StatefulWidget {
  final CaretakerProfile profile;

  const CaretakerEditProfileScreen({super.key, required this.profile});

  @override
  State<CaretakerEditProfileScreen> createState() =>
      _CaretakerEditProfileScreenState();
}

class _CaretakerEditProfileScreenState
    extends State<CaretakerEditProfileScreen> {
  late final TextEditingController _nicknameCtrl;
  late final UpdateProfileUseCase _updateProfileUseCase;
  late final UploadImageUseCase _uploadImageUseCase;

  late List<String> _featureLabels;
  late List<String> _businessAttributes;
  late int _serviceRangeKm;
  String _avatarUrl = '';
  File? _pendingAvatarFile;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  String? _residentAddress;
  double? _residentLatitude;
  double? _residentLongitude;

  static const _kRangeOptions = [
    (label: '1 km 内', value: 1),
    (label: '3 km 内', value: 3),
    (label: '5 km 内', value: 5),
    (label: '10 km 内', value: 10),
    (label: '不限距离', value: 0),
  ];

  @override
  void initState() {
    super.initState();
    _nicknameCtrl =
        TextEditingController(text: widget.profile.nickname);
    _avatarUrl = widget.profile.avatarUrl;
    final allLabels = widget.profile.certLabels
        .where(_isUserSelectableLabel)
        .toList();
    _businessAttributes = allLabels
        .where((l) => _kBusinessAttributeLabels.contains(l))
        .toList();
    _featureLabels = allLabels
        .where((l) => !_kBusinessAttributeLabels.contains(l))
        .toList();
    _serviceRangeKm = widget.profile.serviceRangeKm;
    _residentAddress = widget.profile.residentAddress;

    final client = ApiClient();
    final profileDataSource = CaretakerProfileRemoteDataSource(client);
    final profileRepo = CaretakerProfileRepositoryImpl(profileDataSource);
    _updateProfileUseCase = UpdateProfileUseCase(profileRepo);
    _uploadImageUseCase =
        UploadImageUseCase(UploadRemoteDataSource(http.Client()));

    // 档案昵称为空时（新用户），从本地读取注册时的昵称预填
    if (widget.profile.nickname.isEmpty) {
      _prefillNickname();
    }
  }

  Future<void> _prefillNickname() async {
    final stored = await AuthTokenStore.instance.readNickname();
    if (stored != null && stored.isNotEmpty && mounted) {
      _nicknameCtrl.text = stored;
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    setState(() {
      _pendingAvatarFile = file;
      _isUploadingAvatar = true;
    });

    final result = await _uploadImageUseCase(file);
    if (!mounted) return;
    result.when(
      success: (url) => setState(() {
        _avatarUrl = url;
        _isUploadingAvatar = false;
      }),
      failure: (error) {
        setState(() {
          _pendingAvatarFile = null;
          _isUploadingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('头像上传失败：${error.message}'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressLocationPickerScreen(
          initialLatitude: _residentLatitude,
          initialLongitude: _residentLongitude,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final gcjLat = (result['latitude'] as num).toDouble();
    final gcjLng = (result['longitude'] as num).toDouble();
    final (wgsLat, wgsLng) = _gcj02ToWgs84(gcjLat, gcjLng);

    final city = result['city']?.toString() ?? '';
    final district = result['district']?.toString() ?? '';
    final label = '$city$district'.isEmpty ? null : '$city$district';

    setState(() {
      _residentAddress = label;
      _residentLatitude = wgsLat;
      _residentLongitude = wgsLng;
    });
  }

  /// GCJ-02（高德坐标）→ WGS-84 近似转换，误差约 0–5 m。
  static (double lat, double lng) _gcj02ToWgs84(double gcjLat, double gcjLng) {
    const a = 6378245.0;
    const ee = 0.00669342162296594323;

    double transformLat(double x, double y) {
      var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y +
          0.1 * x * y + 0.2 * sqrt(x.abs());
      ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
      ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
      ret += (160.0 * sin(y / 12.0 * pi) + 320.0 * sin(y * pi / 30.0)) * 2.0 / 3.0;
      return ret;
    }

    double transformLng(double x, double y) {
      var ret = 300.0 + x + 2.0 * y + 0.1 * x * x +
          0.1 * x * y + 0.1 * sqrt(x.abs());
      ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
      ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
      ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
      return ret;
    }

    final dLat = transformLat(gcjLng - 105.0, gcjLat - 35.0);
    final dLng = transformLng(gcjLng - 105.0, gcjLat - 35.0);
    final radLat = gcjLat / 180.0 * pi;
    final magic = sin(radLat);
    final sqrtMagic = sqrt(1 - ee * magic * magic);
    final finalDLat =
        (dLat * 180.0) / ((a * (1 - ee)) / (sqrtMagic * sqrtMagic * sqrtMagic) * pi);
    final finalDLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
    return (gcjLat - finalDLat, gcjLng - finalDLng);
  }

  String _rangeLabel(int km) {
    if (km == 0) return '不限距离';
    return '$km km 内';
  }

  Future<void> _pickServiceRange() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '服务范围',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2621),
                ),
              ),
            ),
            ..._kRangeOptions.map((o) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(o.label),
                  trailing: _serviceRangeKm == o.value
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF004D36))
                      : null,
                  onTap: () => Navigator.pop(context, o.value),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _serviceRangeKm = selected);
    }
  }

  void _toggleFeatureLabel(String label) {
    if (_featureLabels.contains(label)) {
      setState(() => _featureLabels.remove(label));
    } else if (_featureLabels.length < 3) {
      setState(() => _featureLabels.add(label));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('最多选 3 个特色标签'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleBusinessAttribute(String label) {
    setState(() {
      if (_businessAttributes.contains(label)) {
        _businessAttributes.remove(label);
      } else {
        _businessAttributes.add(label);
      }
    });
  }

  List<String> get _mergedCertLabels => [
        ..._featureLabels,
        ..._businessAttributes,
      ].where(_isUserSelectableLabel).toList();

  Future<void> _save() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称不能为空')),
      );
      return;
    }
    if (nickname.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称不超过 20 字')),
      );
      return;
    }
    if (_isUploadingAvatar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像上传中，请稍候…')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final result = await _updateProfileUseCase(
      nickname: nickname,
      avatarUrl: _avatarUrl,
      certLabels: _mergedCertLabels,
      serviceRangeKm: _serviceRangeKm,
      residentAddress: _residentAddress,
      residentLatitude: _residentLatitude,
      residentLongitude: _residentLongitude,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('档案已更新'),
            backgroundColor: Color(0xFF004D36),
          ),
        );
        Navigator.pop(context, true);
      },
      failure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '编辑档案',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF5A6B62)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Color(0xFF004D36),
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      color: Color(0xFF004D36),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarPicker(
              avatarUrl: _avatarUrl,
              pendingFile: _pendingAvatarFile,
              isUploading: _isUploadingAvatar,
              onTap: _pickAvatar,
            ),
            const SizedBox(height: 24),
            _SectionCard(
              title: '基本信息',
              children: [
                _FieldRow(
                  label: '昵称',
                  child: TextField(
                    controller: _nicknameCtrl,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      hintText: '给自己起个昵称',
                      hintStyle: TextStyle(color: Color(0xFFB0C4BC)),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A2621),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F4F2)),
                _FieldRow(
                  label: '常驻地址',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickAddress,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            _residentAddress ?? '点击选择位置',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              color: _residentAddress != null
                                  ? const Color(0xFF1A2621)
                                  : const Color(0xFFB0C4BC),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: Color(0xFFB0C4BC)),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF0F4F2)),
                _FieldRow(
                  label: '服务范围',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickServiceRange,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _rangeLabel(_serviceRangeKm),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A2621),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            size: 18, color: Color(0xFFB0C4BC)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.profile.certLabels.contains('平台认证'))
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2EF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBDED6)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_outlined,
                          color: Color(0xFF004D36), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '平台认证：已通过平台考核后自动授予，不可手动选择',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF004D36),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _SectionCard(
              title: '业务属性',
              subtitle: '勾选您的服务能力，宠主发单时可作为筛选条件',
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _kBusinessAttributeLabels.map((label) {
                      final selected = _businessAttributes.contains(label);
                      return GestureDetector(
                        onTap: () => _toggleBusinessAttribute(label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF004D36)
                                : const Color(0xFFF0F4F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF5A6B62),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: '特色标签',
              subtitle: '最多选 3 个，展示在档案主页',
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _kPresetLabels.map((label) {
                      final selected = _featureLabels.contains(label);
                      return GestureDetector(
                        onTap: () => _toggleFeatureLabel(label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF004D36)
                                : const Color(0xFFF0F4F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF5A6B62),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_featureLabels.isNotEmpty) ...[
                  const Divider(height: 1, color: Color(0xFFF0F4F2)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Text(
                          '已选：',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF8BA49A)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            children: _featureLabels
                                .map((l) => Chip(
                                      label: Text(l),
                                      labelStyle: const TextStyle(
                                          fontSize: 12, color: Color(0xFF004D36)),
                                      backgroundColor:
                                          const Color(0xFFD4EDE4),
                                      deleteIconColor:
                                          const Color(0xFF5A6B62),
                                      onDeleted: () => _toggleFeatureLabel(l),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: EdgeInsets.zero,
                                      visualDensity:
                                          VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── 头像选择器 ───────────────────────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  final String avatarUrl;
  final File? pendingFile;
  final bool isUploading;
  final VoidCallback onTap;

  const _AvatarPicker({
    required this.avatarUrl,
    required this.pendingFile,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? bg;
    if (pendingFile != null) {
      bg = FileImage(pendingFile!);
    } else if (avatarUrl.isNotEmpty) {
      bg = NetworkImage(avatarUrl);
    }

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFFE8F2EF),
              backgroundImage: bg,
              child: bg == null
                  ? const Icon(Icons.person,
                      color: Color(0xFF004D36), size: 48)
                  : null,
            ),
            if (isUploading)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0x88000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF004D36),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 分组卡片 ─────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2621),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF8BA49A)),
                ),
              ],
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEBEBEB)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ─── 字段行 ───────────────────────────────────────────────────────────────────

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF8BA49A)),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
