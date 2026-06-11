import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';

class AddressTemplateEditorScreen extends StatefulWidget {
  final int? addressId;

  const AddressTemplateEditorScreen({super.key, this.addressId});

  @override
  State<AddressTemplateEditorScreen> createState() =>
      _AddressTemplateEditorScreenState();
}

class _AddressTemplateEditorScreenState
    extends State<AddressTemplateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _provinceController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _addressTagController = TextEditingController();
  final _apiClient = ApiClient();

  bool _isDefault = false;
  double? _latitude;
  double? _longitude;
  bool _isSubmitting = false;
  bool _isLoadingDetail = false;
  String? _detailErrorMessage;

  bool get _isEditMode => widget.addressId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadDetail();
    }
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _provinceController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _detailAddressController.dispose();
    _addressTagController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final addressId = widget.addressId;
    if (addressId == null) {
      return;
    }

    setState(() {
      _isLoadingDetail = true;
      _detailErrorMessage = null;
    });

    try {
      final response = await _apiClient.get<_AddressTemplateDetail>(
        path: '/api/v1/user-addresses/$addressId',
        dataParser: (json) => _AddressTemplateDetail.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      );

      if (!mounted) {
        return;
      }

      if (response.isSuccess && response.data != null) {
        final detail = response.data!;
        _contactNameController.text = detail.contactName;
        _contactPhoneController.text = detail.contactPhone;
        _provinceController.text = detail.province;
        _cityController.text = detail.city;
        _districtController.text = detail.district;
        _detailAddressController.text = detail.detailAddress;
        _addressTagController.text = detail.addressTag;
        setState(() {
          _isDefault = detail.isDefault == 1;
          _latitude = detail.latitude;
          _longitude = detail.longitude;
          _isLoadingDetail = false;
        });
        return;
      }

      setState(() {
        _detailErrorMessage =
            response.message.isEmpty ? '加载地址详情失败，请稍后重试' : response.message;
        _isLoadingDetail = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _detailErrorMessage = error.message;
        _isLoadingDetail = false;
      });
    }
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (_isSubmitting || formState == null || !formState.validate()) {
      return;
    }
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('请先选择地图位置')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final body = {
        'contactName': _contactNameController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'province': _provinceController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'detailAddress': _detailAddressController.text.trim(),
        'addressTag': _addressTagController.text.trim(),
        'isDefault': _isDefault ? 1 : 0,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      final response = _isEditMode
          ? await _apiClient.put<Map<String, dynamic>>(
              path: '/api/v1/user-addresses/${widget.addressId}',
              body: body,
              dataParser: (json) => Map<String, dynamic>.from(json as Map),
            )
          : await _apiClient.post<Map<String, dynamic>>(
              path: '/api/v1/user-addresses',
              body: body,
              dataParser: (json) => Map<String, dynamic>.from(json as Map),
            );

      if (!mounted) {
        return;
      }

      if (response.isSuccess) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_isEditMode ? '地址模板已更新' : '地址模板已创建'),
            ),
          );
        context.pop(true);
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              response.message.isEmpty
                  ? (_isEditMode ? '更新地址模板失败，请稍后重试' : '创建地址模板失败，请稍后重试')
                  : response.message,
            ),
          ),
        );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '请输入$label';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final requiredError = _validateRequired(value, '联系电话');
    if (requiredError != null) {
      return requiredError;
    }

    final normalizedValue = value!.trim();
    final phonePattern = RegExp(r'^\d{11}$');
    if (!phonePattern.hasMatch(normalizedValue)) {
      return '请输入11位手机号';
    }
    return null;
  }

  Future<void> _pickLocation() async {
    final result = await context.push<Map<String, dynamic>>(
      '/profile/address-template/location-picker',
      extra: {
        'latitude': _latitude,
        'longitude': _longitude,
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _latitude = (result['latitude'] as num?)?.toDouble();
      _longitude = (result['longitude'] as num?)?.toDouble();
      final province = result['province']?.toString();
      final city = result['city']?.toString();
      final district = result['district']?.toString();
      final detailAddress = result['detailAddress']?.toString();
      if (province != null && province.isNotEmpty) {
        _provinceController.text = province;
      }
      if (city != null && city.isNotEmpty) {
        _cityController.text = city;
      }
      if (district != null && district.isNotEmpty) {
        _districtController.text = district;
      }
      if (detailAddress != null && detailAddress.isNotEmpty) {
        _detailAddressController.text = detailAddress;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isEditMode ? '编辑地址模板' : '创建地址模板',
          style: const TextStyle(
            color: Color(0xFF004D36),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoadingDetail
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_detailErrorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEBEBEB)),
                        ),
                        child: Text(
                          _detailErrorMessage!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8A4D4D),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const _FormLabel('联系人'),
                    _AddressTextField(
                      controller: _contactNameController,
                      hintText: '请输入联系人姓名',
                      enabled: !_isSubmitting,
                      validator: (value) => _validateRequired(value, '联系人姓名'),
                    ),
                    const SizedBox(height: 16),
                    const _FormLabel('联系电话'),
                    _AddressTextField(
                      controller: _contactPhoneController,
                      hintText: '请输入11位手机号',
                      keyboardType: TextInputType.phone,
                      enabled: !_isSubmitting,
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    const _FormLabel('省份'),
                    _AddressTextField(
                      controller: _provinceController,
                      hintText: '例如：北京市',
                      enabled: !_isSubmitting,
                      validator: (value) => _validateRequired(value, '省份'),
                    ),
                    const SizedBox(height: 16),
                    const _FormLabel('城市'),
                    _AddressTextField(
                      controller: _cityController,
                      hintText: '例如：北京市',
                      enabled: !_isSubmitting,
                      validator: (value) => _validateRequired(value, '城市'),
                    ),
                    const SizedBox(height: 16),
                    const _FormLabel('区 / 县'),
                    _AddressTextField(
                      controller: _districtController,
                      hintText: '例如：朝阳区',
                      enabled: !_isSubmitting,
                      validator: (value) => _validateRequired(value, '区县'),
                    ),
                    const SizedBox(height: 16),
                    const _FormLabel('详细地址'),
                    _AddressTextField(
                      controller: _detailAddressController,
                      hintText: '请输入街道、门牌号、楼栋房间号',
                      maxLines: 3,
                      enabled: !_isSubmitting,
                      validator: (value) => _validateRequired(value, '详细地址'),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _isSubmitting ? null : _pickLocation,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8E5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              color: Color(0xFF004D36),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _latitude != null && _longitude != null
                                    ? '已选择坐标：${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                                    : '点击选择地图位置',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1A2621),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFC3D5CC),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _FormLabel('地址标签'),
                    _AddressTextField(
                      controller: _addressTagController,
                      hintText: '例如：家、公司、父母家',
                      enabled: !_isSubmitting,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8E5)),
                      ),
                      child: SwitchListTile(
                        value: _isDefault,
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _isDefault = value;
                                });
                              },
                        activeColor: const Color(0xFF004D36),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '设为默认地址',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2621),
                          ),
                        ),
                        subtitle: const Text(
                          '创建订单时优先展示这条地址模板',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5A6B62),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
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
          onPressed: _isSubmitting || _isLoadingDetail ? null : _submit,
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
                  _isEditMode ? '保存更新' : '保存地址模板',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _AddressTemplateDetail {
  final String contactName;
  final String contactPhone;
  final String province;
  final String city;
  final String district;
  final String detailAddress;
  final String addressTag;
  final int isDefault;
  final double? latitude;
  final double? longitude;

  const _AddressTemplateDetail({
    required this.contactName,
    required this.contactPhone,
    required this.province,
    required this.city,
    required this.district,
    required this.detailAddress,
    required this.addressTag,
    required this.isDefault,
    required this.latitude,
    required this.longitude,
  });

  factory _AddressTemplateDetail.fromJson(Map<String, dynamic> json) {
    return _AddressTemplateDetail(
      contactName: json['contactName']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      detailAddress: json['detailAddress']?.toString() ?? '',
      addressTag: json['addressTag']?.toString() ?? '',
      isDefault: _asInt(json['isDefault']),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A2621),
      ),
    );
  }
}

class _AddressTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;
  final FormFieldValidator<String>? validator;

  const _AddressTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFB0BDB7)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    );
  }
}
