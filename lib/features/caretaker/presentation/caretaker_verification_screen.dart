import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_training_remote_data_source.dart';
import '../data/datasources/caretaker_verification_remote_data_source.dart';
import '../data/datasources/ocr_remote_data_source.dart';

class CaretakerVerificationScreen extends StatefulWidget {
  /// 是否显示右上角跳过按钮。
  final bool canSkip;

  /// true = 宠托师认证（含年龄限制）；false = 宠物主实名认证
  final bool isCaretaker;

  const CaretakerVerificationScreen({
    super.key,
    this.canSkip = false,
    this.isCaretaker = true,
  });

  @override
  State<CaretakerVerificationScreen> createState() =>
      _CaretakerVerificationScreenState();
}

class _CaretakerVerificationScreenState
    extends State<CaretakerVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idCardController = TextEditingController();
  final _picker = ImagePicker();

  late final CaretakerVerificationRemoteDataSource _verificationDataSource;
  late final OcrRemoteDataSource _ocrDataSource;
  late final CaretakerTrainingRemoteDataSource _trainingDataSource;

  File? _frontImage;
  File? _backImage;
  bool _isOcrRunning = false;
  bool _isSubmitting = false;
  String? _submitError;

  // null = 查询中, true = 已认证, false = 未认证
  bool? _isVerified;

  // ID card validation live state
  String? _idCardError;

  @override
  void initState() {
    super.initState();
    final httpClient = http.Client();
    _ocrDataSource = OcrRemoteDataSource(httpClient);
    _verificationDataSource =
        CaretakerVerificationRemoteDataSource(httpClient);
    _trainingDataSource = CaretakerTrainingRemoteDataSource(ApiClient());
    _idCardController.addListener(_onIdCardChanged);
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idCardController.removeListener(_onIdCardChanged);
    _idCardController.dispose();
    super.dispose();
  }

  Future<void> _checkVerificationStatus() async {
    final result = await _trainingDataSource.getStatus();
    if (!mounted) return;
    result.when(
      success: (status) =>
          setState(() => _isVerified = status.realNameVerified),
      failure: (_) => setState(() => _isVerified = false),
    );
  }

  // ── ID 卡校验 ────────────────────────────────────────────────────────────

  void _onIdCardChanged() {
    final val = _idCardController.text;
    if (val.isEmpty) {
      if (_idCardError != null) setState(() => _idCardError = null);
      return;
    }
    final err = _validateIdCard(val, checkAge: widget.isCaretaker);
    if (err != _idCardError) setState(() => _idCardError = err);
  }

  static String? _validateIdCard(String id, {bool checkAge = true}) {
    if (id.length < 18) return null;
    if (id.length > 18) return '身份证号码为18位';
    final regex = RegExp(
        r'^[1-9]\d{5}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[\dXx]$');
    if (!regex.hasMatch(id)) return '身份证号码格式不正确';
    // 校验码
    const weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];
    const checkCodes = ['1', '0', 'X', '9', '8', '7', '6', '5', '4', '3', '2'];
    int sum = 0;
    for (int i = 0; i < 17; i++) {
      sum += int.parse(id[i]) * weights[i];
    }
    if (id[17].toUpperCase() != checkCodes[sum % 11]) return '身份证号码校验位不正确';
    if (!checkAge) return null;
    // 年龄限制（仅宠托师）
    final age = _getAge(id);
    if (age == null) return '无法识别出生日期';
    if (age < 18) return '年龄不满18周岁，不符合服务者要求';
    if (age > 60) return '年龄超过60周岁，不符合服务者要求';
    return null;
  }

  static int? _getAge(String id) {
    try {
      final year = int.parse(id.substring(6, 10));
      final month = int.parse(id.substring(10, 12));
      final day = int.parse(id.substring(12, 14));
      final birthday = DateTime(year, month, day);
      final today = DateTime.now();
      int age = today.year - birthday.year;
      if (today.month < birthday.month ||
          (today.month == birthday.month && today.day < birthday.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  // ── 图片选择 + OCR ────────────────────────────────────────────────────────

  Future<void> _pickImage(bool isFront) async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    setState(() {
      if (isFront) {
        _frontImage = file;
        _isOcrRunning = true;
      } else {
        _backImage = file;
      }
    });

    if (isFront) {
      await _runOcr(file);
    }
  }

  Future<void> _runOcr(File file) async {
    final result = await _ocrDataSource.recognizeIdCard(file);
    if (!mounted) return;
    setState(() => _isOcrRunning = false);
    result.when(
      success: (ocr) {
        bool filled = false;
        if (ocr.realName != null && ocr.realName!.isNotEmpty) {
          _nameController.text = ocr.realName!;
          filled = true;
        }
        if (ocr.idCardNo != null && ocr.idCardNo!.isNotEmpty) {
          _idCardController.text = ocr.idCardNo!.toUpperCase();
          filled = true;
        }
        if (filled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已从身份证自动填写信息，请核对后提交'),
              backgroundColor: Color(0xFF004D36),
            ),
          );
        }
      },
      failure: (_) {
        // OCR 失败静默处理，用户可手动填写
      },
    );
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE8E4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF004D36)),
                title: const Text('从相册选择'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: Color(0xFF004D36)),
                title: const Text('拍照'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 提交 ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final idErr = _validateIdCard(_idCardController.text.trim(),
        checkAge: widget.isCaretaker);
    if (idErr != null) {
      setState(() => _idCardError = idErr);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final result = await _verificationDataSource.submitRealNameVerify(
      realName: _nameController.text.trim(),
      idCardNo: _idCardController.text.trim().toUpperCase(),
      frontImage: _frontImage,
      backImage: _backImage,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        if (widget.isCaretaker) {
          // 优先 pop 回来源页，让调用方能 await 到结果后刷新
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go('/caretaker/profile');
          }
        } else {
          context.canPop() ? context.pop(true) : context.go('/profile');
        }
      },
      failure: (error) => setState(() {
        _submitError = error.message;
        _isSubmitting = false;
      }),
    );
  }

  // ── 验证器（传给 _FormCard）─────────────────────────────────────────────

  String? _idCardFormValidator(String? v) {
    if (v == null || v.isEmpty) return '请输入身份证号码';
    if (v.length < 18) return '身份证号码为18位，请输入完整';
    return _validateIdCard(v, checkAge: widget.isCaretaker);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.isCaretaker ? '宠托师实名认证' : '实名认证';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Color(0xFF5A6B62), size: 20),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        actions: [
          if (widget.canSkip)
            TextButton(
              onPressed: () => widget.isCaretaker
                  ? context.go('/caretaker')
                  : context.canPop()
                      ? context.pop()
                      : context.go('/profile'),
              child: const Text(
                '跳过',
                style: TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isVerified == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF004D36)),
      );
    }
    if (_isVerified == true) {
      return _VerifiedView(
        onBack: () => context.canPop() ? context.pop() : null,
      );
    }
    return _buildForm();
  }

  Widget _buildForm() {
    final infoDesc = widget.isCaretaker
        ? '实名认证用于核验宠托师身份合规，保障宠物主的服务安全。您的信息将被严格保密，不会泄露给第三方。'
        : '实名认证用于核验您的真实身份，保障账号与交易安全。您的信息将被严格保密，不会泄露给第三方。';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoCard(description: infoDesc),
            const SizedBox(height: 28),
            _SectionTitle(title: '上传身份证', subtitle: '请上传清晰照片，支持 JPG / PNG 格式'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ImageUploadCard(
                    label: '身份证正面',
                    hint: '人像面',
                    icon: Icons.badge_outlined,
                    image: _frontImage,
                    isLoading: false,
                    isUploaded: _frontImage != null,
                    onTap: () => _pickImage(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageUploadCard(
                    label: '身份证背面',
                    hint: '国徽面',
                    icon: Icons.credit_card_outlined,
                    image: _backImage,
                    isLoading: false,
                    isUploaded: _backImage != null,
                    onTap: () => _pickImage(false),
                  ),
                ),
              ],
            ),
            if (_isOcrRunning) ...[
              const SizedBox(height: 8),
              const _OcrLoadingTip(),
            ],
            const SizedBox(height: 8),
            const _UploadTip(),
            const SizedBox(height: 28),
            _SectionTitle(title: '证件信息', subtitle: '请填写与身份证一致的信息'),
            const SizedBox(height: 14),
            _FormCard(
              nameController: _nameController,
              idCardController: _idCardController,
              idCardError: _idCardError,
              idCardValidator: _idCardFormValidator,
            ),
            if (widget.isCaretaker) ...[
              const SizedBox(height: 12),
              const _AgeLimitNote(),
            ],
            const SizedBox(height: 24),
            if (_submitError != null) ...[
              _ErrorBanner(message: _submitError!),
              const SizedBox(height: 16),
            ],
            _SubmitButton(
              isLoading: _isSubmitting,
              isDisabled: _isOcrRunning,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 已认证只读视图 ─────────────────────────────────────────────────────────────

class _VerifiedView extends StatelessWidget {
  final VoidCallback onBack;

  const _VerifiedView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD5EDE5)),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD5EDE5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user,
                    color: Color(0xFF004D36),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '实名认证已完成',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '您的账号已通过实名认证。\n宠物主端与宠托师端共用同一账号，两端均已认证。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF5A6B62),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: onBack,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF004D36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '返回',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 顶部说明卡片 ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String description;

  const _InfoCard({required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF004D36),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '为什么需要实名认证？',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF004D36),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF3D6B59),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 段落标题 ──────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2621),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
        ),
      ],
    );
  }
}

// ── 图片上传卡片 ──────────────────────────────────────────────────────────────

class _ImageUploadCard extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final File? image;
  final bool isLoading;
  final bool isUploaded;
  final VoidCallback onTap;

  const _ImageUploadCard({
    required this.label,
    required this.hint,
    required this.icon,
    required this.image,
    required this.isLoading,
    required this.isUploaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded
                ? const Color(0xFF004D36)
                : image != null
                    ? const Color(0xFFC3D5CC)
                    : const Color(0xFFDDE8E4),
            width: isUploaded ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF004D36),
          strokeWidth: 2.5,
        ),
      );
    }
    if (image != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(image!, fit: BoxFit.cover),
          if (isUploaded)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF004D36),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.black.withValues(alpha: 0.35),
              child: Text(
                isUploaded ? '点击重新选择' : '点击重新选择',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F7F4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF8BA49A), size: 26),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF5A6B62),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          hint,
          style: const TextStyle(fontSize: 11, color: Color(0xFFB0C4BC)),
        ),
      ],
    );
  }
}

// ── OCR 识别中提示 ─────────────────────────────────────────────────────────────

class _OcrLoadingTip extends StatelessWidget {
  const _OcrLoadingTip();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF004D36),
            ),
          ),
          SizedBox(width: 6),
          Text(
            '正在识别身份证信息，稍后自动填写…',
            style: TextStyle(fontSize: 12, color: Color(0xFF5A6B62)),
          ),
        ],
      ),
    );
  }
}

// ── 上传提示 ──────────────────────────────────────────────────────────────────

class _UploadTip extends StatelessWidget {
  const _UploadTip();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: Color(0xFF8BA49A), size: 14),
          SizedBox(width: 6),
          Text(
            '照片选填，提交时随表单一并上传',
            style: TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
          ),
        ],
      ),
    );
  }
}

// ── 表单卡片 ──────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController idCardController;
  final String? idCardError;
  final String? Function(String?) idCardValidator;

  const _FormCard({
    required this.nameController,
    required this.idCardController,
    required this.idCardError,
    required this.idCardValidator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '真实姓名',
              labelStyle: TextStyle(color: Color(0xFF8BA49A), fontSize: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A2621)),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入真实姓名';
              if (v.trim().length < 2) return '姓名至少2个字';
              return null;
            },
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: idCardController,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                  LengthLimitingTextInputFormatter(18),
                  _UpperCaseFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: '身份证号码',
                  labelStyle:
                      const TextStyle(color: Color(0xFF8BA49A), fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 16, bottom: 4),
                  suffixIcon:
                      idCardController.text.length == 18 && idCardError == null
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF004D36), size: 18)
                          : null,
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1A2621),
                  letterSpacing: 1.2,
                ),
                validator: idCardValidator,
              ),
              if (idCardError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    idCardError!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFD32F2F)),
                  ),
                ),
              if (idCardError == null && idCardController.text.length == 18)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '出生：${_formatBirthday(idCardController.text)}，年龄：${_CaretakerVerificationScreenState._getAge(idCardController.text)}岁',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF5A6B62)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatBirthday(String id) {
    if (id.length < 14) return '';
    return '${id.substring(6, 10)}年${id.substring(10, 12)}月${id.substring(12, 14)}日';
  }
}

// ── 年龄提示（仅宠托师）──────────────────────────────────────────────────────

class _AgeLimitNote extends StatelessWidget {
  const _AgeLimitNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.info_outline, color: Color(0xFF8BA49A), size: 14),
        SizedBox(width: 6),
        Text(
          '服务者年龄要求：18 – 60 周岁',
          style: TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
        ),
      ],
    );
  }
}

// ── 错误提示条 ────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCCC7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF06A42), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8B3A30)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 提交按钮 ──────────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.isLoading,
    required this.isDisabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: isLoading || isDisabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF004D36),
          disabledBackgroundColor: const Color(0xFFC3D5CC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                '提交认证',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ── 工具：大写格式化 ──────────────────────────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
