import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/domain/pet_profile_tags.dart';
import '../../../core/domain/pet_type.dart';
import 'pet_profile_tags_form.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../caretaker/data/datasources/upload_remote_data_source.dart';
import '../../caretaker/domain/usecases/upload_image_use_case.dart';
import '../../pet_archive/data/datasources/pet_archive_remote_data_source.dart';
import '../../pet_archive/data/models/create_pet_archive_request.dart';
import '../../pet_archive/data/repositories/pet_archive_repository_impl.dart';
import '../../pet_archive/domain/entities/pet_archive.dart';
import '../../pet_archive/domain/usecases/create_pet_archive_use_case.dart';
import '../../pet_archive/domain/usecases/get_pet_archive_use_case.dart';
import '../../pet_archive/domain/usecases/delete_pet_archive_use_case.dart';
import '../../pet_archive/domain/usecases/update_pet_archive_use_case.dart';

class AddPetScreen extends StatefulWidget {
  final int? petId;
  final CreatePetArchiveUseCase? createPetArchiveUseCase;
  final GetPetArchiveUseCase? getPetArchiveUseCase;
  final UpdatePetArchiveUseCase? updatePetArchiveUseCase;
  final DeletePetArchiveUseCase? deletePetArchiveUseCase;

  const AddPetScreen({
    super.key,
    this.petId,
    this.createPetArchiveUseCase,
    this.getPetArchiveUseCase,
    this.updatePetArchiveUseCase,
    this.deletePetArchiveUseCase,
  });

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _petNameController = TextEditingController();
  final _defaultReqController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  late final ApiClient _apiClient;
  late final http.Client _httpClient;

  late final CreatePetArchiveUseCase _createPetArchiveUseCase;
  late final GetPetArchiveUseCase _getPetArchiveUseCase;
  late final UpdatePetArchiveUseCase _updatePetArchiveUseCase;
  late final DeletePetArchiveUseCase _deletePetArchiveUseCase;
  late final UploadImageUseCase _uploadImageUseCase;

  int? _selectedPetType;
  PetProfileTags _profileTags = const PetProfileTags();
  String _petImageUrl = '';
  File? _pickedImageFile;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  bool _isLoadingDetail = false;
  bool _isUploadingImage = false;
  String? _loadError;

  bool get _isEditMode => widget.petId != null;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _httpClient = http.Client();
    final repository = _buildRepository();
    _createPetArchiveUseCase =
        widget.createPetArchiveUseCase ?? CreatePetArchiveUseCase(repository);
    _getPetArchiveUseCase =
        widget.getPetArchiveUseCase ?? GetPetArchiveUseCase(repository);
    _updatePetArchiveUseCase =
        widget.updatePetArchiveUseCase ?? UpdatePetArchiveUseCase(repository);
    _deletePetArchiveUseCase =
        widget.deletePetArchiveUseCase ?? DeletePetArchiveUseCase(repository);
    _uploadImageUseCase = UploadImageUseCase(
      UploadRemoteDataSource(_httpClient),
    );

    if (_isEditMode) {
      _loadPetDetail();
    }
  }

  PetArchiveRepositoryImpl _buildRepository() {
    final remoteDataSource = PetArchiveRemoteDataSource(_apiClient);
    return PetArchiveRepositoryImpl(remoteDataSource);
  }

  Future<void> _loadPetDetail() async {
    final petId = widget.petId;
    if (petId == null) return;

    setState(() {
      _isLoadingDetail = true;
      _loadError = null;
    });

    final result = await _getPetArchiveUseCase(petId);
    if (!mounted) return;

    result.when(
      success: (pet) {
        _petNameController.text = pet.petName;
        _defaultReqController.text = pet.defaultReq;
        setState(() {
          _selectedPetType = pet.petType;
          _profileTags = pet.profileTags;
          _petImageUrl = normalizeRemoteImageUrl(pet.image);
          _pickedImageFile = null;
          _isLoadingDetail = false;
        });
      },
      failure: (error) {
        setState(() {
          _loadError = error.message;
          _isLoadingDetail = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _defaultReqController.dispose();
    _apiClient.close();
    _httpClient.close();
    super.dispose();
  }

  CreatePetArchiveRequest _buildRequest() {
    return CreatePetArchiveRequest(
      petName: _petNameController.text.trim(),
      petType: _selectedPetType!,
      defaultReq: _defaultReqController.text.trim(),
      image: _petImageUrl.trim().isEmpty ? null : _petImageUrl.trim(),
      profileTags: _profileTags.isEmpty ? null : _profileTags,
    );
  }

  Future<void> _pickPetImage() async {
    if (_isSubmitting || _isDeleting || _isUploadingImage || _isLoadingDetail) {
      return;
    }
    final action = await showModalBottomSheet<_PetImageAction>(
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
              onTap: () => Navigator.pop(context, _PetImageAction.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: Color(0xFF004D36),
              ),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, _PetImageAction.gallery),
            ),
            if (_petImageUrl.isNotEmpty || _pickedImageFile != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('移除当前照片'),
                onTap: () => Navigator.pop(context, _PetImageAction.remove),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == _PetImageAction.remove) {
      setState(() {
        _petImageUrl = '';
        _pickedImageFile = null;
      });
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: action == _PetImageAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (!mounted || picked == null) return;

    final file = File(picked.path);
    setState(() {
      _pickedImageFile = file;
      _isUploadingImage = true;
    });

    final result = await _uploadImageUseCase(file);
    if (!mounted) return;
    result.when(
      success: (url) {
        setState(() {
          _petImageUrl = url;
          _pickedImageFile = file;
          _isUploadingImage = false;
        });
        _showSnackBar('宠物头像上传成功');
      },
      failure: (error) {
        setState(() {
          _pickedImageFile = null;
          _isUploadingImage = false;
        });
        _showSnackBar(error.message);
      },
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isLoadingDetail || _isUploadingImage) return;
    if (!_formKey.currentState!.validate()) return;
    final petType = _selectedPetType;
    if (petType == null) {
      _showSnackBar('请选择宠物类型');
      return;
    }

    setState(() => _isSubmitting = true);

    final request = _buildRequest();
    final result = _isEditMode
        ? await _updatePetArchiveUseCase(petId: widget.petId!, request: request)
        : await _createPetArchiveUseCase(request);

    if (!mounted) return;
    result.when(
      success: (PetArchive petArchive) {
        _showSnackBar(_isEditMode ? '宠物档案已更新' : '宠物档案创建成功');
        if (context.canPop()) {
          context.pop(petArchive);
        }
      },
      failure: (ApiException error) {
        _showSnackBar(error.message);
      },
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete() async {
    if (!_isEditMode || _isDeleting || _isSubmitting) return;

    final petName = _petNameController.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除宠物档案'),
        content: Text(
          petName.isEmpty
              ? '确定要删除该宠物档案吗？删除后无法恢复。'
              : '确定要删除「$petName」的档案吗？删除后无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    final result = await _deletePetArchiveUseCase(widget.petId!);
    if (!mounted) return;

    result.when(
      success: (_) {
        _showSnackBar('宠物档案已删除');
        if (context.canPop()) {
          context.pop(true);
        }
      },
      failure: (error) => _showSnackBar(error.message),
    );

    if (mounted) {
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: _isSubmitting || _isDeleting
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
        ),
        title: Text(
          _isEditMode ? '编辑宠物档案' : '添加宠物档案',
          style: const TextStyle(
            color: Color(0xFF004D36),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isEditMode && !_isLoadingDetail && _loadError == null)
            TextButton(
              onPressed: _isSubmitting || _isDeleting ? null : _confirmDelete,
              child: _isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    )
                  : const Text(
                      '删除',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoadingDetail || _loadError != null
          ? null
          : Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: FilledButton(
                onPressed: _isSubmitting || _isDeleting || _isUploadingImage
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF004D36),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditMode ? '保存修改' : '保存',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF5A6B62)),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadPetDetail, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PhotoUploadSection(
              imageUrl: _petImageUrl,
              localImageFile: _pickedImageFile,
              isUploading: _isUploadingImage,
              enabled: !_isSubmitting && !_isDeleting && !_isLoadingDetail,
              onTap: _pickPetImage,
            ),
            const SizedBox(height: 32),
            const _FormLabel('宠物名称'),
            _CustomTextField(
              controller: _petNameController,
              hintText: '请输入宠物名称',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入宠物名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const _FormLabel('宠物类型'),
            _PetTypeDropdownField(
              value: _selectedPetType,
              enabled: !_isSubmitting,
              onChanged: (value) => setState(() => _selectedPetType = value),
            ),
            const SizedBox(height: 16),
            const _FormLabel('默认需求'),
            _CustomTextField(
              controller: _defaultReqController,
              hintText: '请输入默认需求说明',
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入默认需求说明';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            PetProfileTagsForm(
              key: ValueKey(
                _isEditMode
                    ? 'edit-${widget.petId}-${_profileTags.weightKg}'
                    : 'create',
              ),
              tags: _profileTags,
              onChanged: (tags) => setState(() => _profileTags = tags),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PhotoUploadSection extends StatelessWidget {
  final String imageUrl;
  final File? localImageFile;
  final bool isUploading;
  final bool enabled;
  final VoidCallback onTap;

  const _PhotoUploadSection({
    required this.imageUrl,
    required this.localImageFile,
    required this.isUploading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (localImageFile != null) {
      imageProvider = FileImage(localImageFile!);
    } else if (imageUrl.trim().isNotEmpty) {
      imageProvider = NetworkImage(imageUrl);
    }

    return Center(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(60),
        child: Column(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6EFEA),
                      shape: BoxShape.circle,
                    ),
                    child: imageProvider == null
                        ? const Icon(
                            Icons.pets_outlined,
                            color: Color(0xFF8BA49A),
                            size: 42,
                          )
                        : ClipOval(
                            child: Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                              width: 112,
                              height: 112,
                            ),
                          ),
                  ),
                  if (isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0x66000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: enabled
                            ? const Color(0xFF004D36)
                            : const Color(0xFF8BA49A),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF7F9F8),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isUploading
                  ? '图片上传中...'
                  : imageProvider == null
                  ? '上传宠物头像'
                  : '点击更换照片',
              style: const TextStyle(color: Color(0xFF5A6B62), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PetImageAction { camera, gallery, remove }

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, color: Color(0xFF4A5550)),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final String? Function(String?)? validator;

  const _CustomTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFB0BDB7)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE2E8E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE2E8E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF004D36)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _PetTypeDropdownField extends StatelessWidget {
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _PetTypeDropdownField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE2E8E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE2E8E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF004D36)),
        ),
      ),
      hint: const Text('请选择宠物类型', style: TextStyle(color: Color(0xFFB0BDB7))),
      items: PetType.selectableOptions
          .map(
            (option) => DropdownMenuItem<int>(
              value: option.value,
              child: Text(option.label),
            ),
          )
          .toList(),
    );
  }
}
