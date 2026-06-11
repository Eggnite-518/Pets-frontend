import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';

class CreateAddressTemplateScreen extends StatefulWidget {
  final bool selectMode;

  const CreateAddressTemplateScreen({super.key, this.selectMode = false});

  @override
  State<CreateAddressTemplateScreen> createState() =>
      _CreateAddressTemplateScreenState();
}

class _CreateAddressTemplateScreenState
    extends State<CreateAddressTemplateScreen> {
  final _apiClient = ApiClient();

  bool _isLoading = true;
  int? _deletingAddressId;
  String? _errorMessage;
  List<_AddressTemplate> _addresses = const [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get<List<_AddressTemplate>>(
        path: '/api/v1/user-addresses',
        dataParser: (json) {
          final list = json as List<dynamic>;
          return list
              .map(
                (item) => _AddressTemplate.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        },
      );

      if (!mounted) {
        return;
      }

      if (response.isSuccess) {
        setState(() {
          _addresses = response.data ?? const [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage =
            response.message.isEmpty ? '加载地址模板失败，请稍后重试' : response.message;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateForm() async {
    await context.push('/profile/address-template/editor');
    if (mounted) {
      _loadAddresses();
    }
  }

  Future<void> _openEditForm(int addressId) async {
    await context.push('/profile/address-template/editor?addressId=$addressId');
    if (mounted) {
      _loadAddresses();
    }
  }

  Future<void> _deleteAddress(_AddressTemplate address) async {
    if (_deletingAddressId != null) {
      return;
    }

    setState(() {
      _deletingAddressId = address.addressId;
    });

    try {
      final response = await _apiClient.delete<void>(
        path: '/api/v1/user-addresses/${address.addressId}',
      );

      if (!mounted) {
        return;
      }

      if (response.isSuccess) {
        setState(() {
          _addresses = _addresses
              .where((item) => item.addressId != address.addressId)
              .toList();
          _deletingAddressId = null;
        });
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('地址模板已删除')));
        return;
      }

      setState(() {
        _deletingAddressId = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              response.message.isEmpty ? '删除地址模板失败，请稍后重试' : response.message,
            ),
          ),
        );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _deletingAddressId = null;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
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
        title: Text(
          widget.selectMode ? '选择地址模板' : '地址模板',
          style: const TextStyle(
            color: Color(0xFF004D36),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '已创建的地址模板',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF004D36),
              ),
            ),
            const SizedBox(height: 12),
            _buildAddressList(),
            const SizedBox(height: 12),
            InkWell(
              onTap: _openCreateForm,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9F8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFC3D5CC),
                    width: 1.5,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.add,
                      size: 30,
                      color: Color(0xFF5A6B62),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '添加地址模板',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5A6B62),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBEBEB)),
        ),
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8A4D4D),
          ),
        ),
      );
    }

    if (_addresses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEBEBEB)),
        ),
        child: const Text(
          '还没有地址模板，点击下方加号创建第一条。',
          style: TextStyle(fontSize: 14, color: Color(0xFF5A6B62)),
        ),
      );
    }

    return Column(
      children: _addresses
          .map(
            (address) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AddressCard(
                address: address,
                isDeleting: _deletingAddressId == address.addressId,
                onTap: widget.selectMode
                    ? () => context.pop(address.toMap())
                    : () => _openEditForm(address.addressId),
                onDelete: () => _deleteAddress(address),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AddressTemplate {
  final int addressId;
  final String contactName;
  final String contactPhone;
  final String province;
  final String city;
  final String district;
  final String detailAddress;
  final String addressTag;
  final int isDefault;

  const _AddressTemplate({
    required this.addressId,
    required this.contactName,
    required this.contactPhone,
    required this.province,
    required this.city,
    required this.district,
    required this.detailAddress,
    required this.addressTag,
    required this.isDefault,
  });

  factory _AddressTemplate.fromJson(Map<String, dynamic> json) {
    return _AddressTemplate(
      addressId: _asInt(json['addressId']),
      contactName: json['contactName']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      detailAddress: json['detailAddress']?.toString() ?? '',
      addressTag: json['addressTag']?.toString() ?? '',
      isDefault: _asInt(json['isDefault']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool get isDefaultAddress => isDefault == 1;

  String get fullAddress => '$province$city$district$detailAddress';

  Map<String, dynamic> toMap() {
    return {
      'addressId': addressId,
      'fullAddress': fullAddress,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'addressTag': addressTag,
    };
  }
}

class _AddressCard extends StatelessWidget {
  final _AddressTemplate address;
  final bool isDeleting;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Dismissible(
        key: ValueKey<int>(address.addressId),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onDelete();
          return false;
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            color: const Color(0xFFE55454),
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 56,
            child: isDeleting
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: address.isDefaultAddress
                      ? const Color(0xFFB8D4C8)
                      : const Color(0xFFEBEBEB),
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              address.contactName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A2621),
                              ),
                            ),
                            Text(
                              address.contactPhone,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5A6B62),
                              ),
                            ),
                            if (address.isDefaultAddress)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F2EF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '默认',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF004D36),
                                  ),
                                ),
                              ),
                            if (address.addressTag.trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F5F5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  address.addressTag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF5A6B62),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFC3D5CC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    address.fullAddress,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A2621),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
