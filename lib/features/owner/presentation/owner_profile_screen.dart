import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/utils/image_url_helper.dart';
import 'package:pets/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:pets/features/auth/data/datasources/apply_caretaker_remote_data_source.dart';
import 'package:pets/features/caretaker/data/datasources/caretaker_profile_remote_data_source.dart';

import 'pet_archive_model.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          '我的',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF5A6B62)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _UserInfoSection(),
            SizedBox(height: 16),
            _OwnerBalanceCard(),
            SizedBox(height: 24),
            _PetArchiveSection(),
            SizedBox(height: 24),
            _AddressTemplateSection(),
            SizedBox(height: 16),
            _MenuListSection(),
            SizedBox(height: 16),
            _SwitchRoleCard(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _UserInfoSection extends StatefulWidget {
  const _UserInfoSection();

  @override
  State<_UserInfoSection> createState() => _UserInfoSectionState();
}

class _UserInfoSectionState extends State<_UserInfoSection> {
  final ApiClient _apiClient = ApiClient();

  _OwnerProfileSummary? _profile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get<_OwnerProfileSummary>(
        path: '/api/v1/me/pet-owner',
        dataParser: (json) => _OwnerProfileSummary.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      );

      if (!mounted) {
        return;
      }

      if (response.isSuccess && response.data != null) {
        setState(() {
          _profile = response.data;
          _isLoading = false;
        });
        return;
      }

      final fallback = await _buildLocalFallback();
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = fallback;
        _errorMessage = response.message.isEmpty
            ? '加载个人信息失败'
            : response.message;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      final fallback = await _buildLocalFallback();
      if (!mounted) {
        return;
      }

      setState(() {
        _profile = fallback;
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<_OwnerProfileSummary?> _buildLocalFallback() async {
    final nickname = (await AuthTokenStore.instance.readNickname())?.trim();
    final phone = (await AuthTokenStore.instance.readPhone())?.trim();
    if ((nickname == null || nickname.isEmpty) &&
        (phone == null || phone.isEmpty)) {
      return null;
    }
    return _OwnerProfileSummary(
      ownerId: 0,
      nickname: nickname ?? '',
      avatarUrl: '',
      phone: phone ?? '',
    );
  }

  String _maskPhone(String phone) {
    final normalized = phone.trim();
    if (normalized.length < 7) {
      return normalized;
    }
    return '${normalized.substring(0, 3)}****${normalized.substring(normalized.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return const _UserInfoSkeleton();
    }

    if (_profile == null) {
      return _UserInfoErrorCard(
        message: _errorMessage ?? '加载个人信息失败',
        onRetry: _loadProfile,
      );
    }

    final profile = _profile!;
    final nickname = profile.nickname.trim().isEmpty
        ? '宠物主'
        : profile.nickname.trim();
    final phone = profile.phone.trim();
    final avatarUrl = profile.avatarUrl.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: const Color(0xFFE8F2EF),
          backgroundImage: avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl.isEmpty
              ? const Icon(Icons.person, color: Color(0xFF004D36), size: 34)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2621),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: const [
                  _ProfileTag(text: '宠物主', color: Color(0xFFE8F2EF)),
                ],
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _maskPhone(phone),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8BA49A),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB26A3C),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileTag extends StatelessWidget {
  final String text;
  final Color color;

  const _ProfileTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF004D36),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _UserInfoSkeleton extends StatelessWidget {
  const _UserInfoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(radius: 34, backgroundColor: Color(0xFFE8F2EF)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2EF),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 64,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2EF),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2EF),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserInfoErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _UserInfoErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A4D4D)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _OwnerProfileSummary {
  final int ownerId;
  final String nickname;
  final String avatarUrl;
  final String phone;

  const _OwnerProfileSummary({
    required this.ownerId,
    required this.nickname,
    required this.avatarUrl,
    required this.phone,
  });

  factory _OwnerProfileSummary.fromJson(Map<String, dynamic> json) {
    return _OwnerProfileSummary(
      ownerId: _asInt(json['ownerId']),
      nickname: json['nickname']?.toString() ?? '',
      avatarUrl: normalizeRemoteImageUrl(json['avatarUrl']?.toString()),
      phone: json['phone']?.toString() ?? '',
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _OwnerBalanceCard extends StatefulWidget {
  const _OwnerBalanceCard();

  @override
  State<_OwnerBalanceCard> createState() => _OwnerBalanceCardState();
}

class _OwnerBalanceCardState extends State<_OwnerBalanceCard> {
  late final CaretakerProfileRemoteDataSource _dataSource;
  String? _balance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dataSource = CaretakerProfileRemoteDataSource(ApiClient());
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _isLoading = true);
    try {
      final response = await _dataSource.getCurrentUserWallet();
      if (!mounted) return;
      setState(() {
        _balance = response.data?.balance ?? '0.00';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _balance = '0.00';
        _isLoading = false;
      });
    }
  }

  Future<void> _openRecharge() async {
    final balance = _balance ?? '0.00';
    await context.push('/wallet/recharge?balance=$balance');
    if (mounted) _loadWallet();
  }

  Future<void> _openWithdraw() async {
    final balance = _balance ?? '0.00';
    final newBalance = await context.push<String>(
      '/wallet/withdraw?balance=$balance',
    );
    if (newBalance != null && mounted) {
      setState(() => _balance = newBalance);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF004D36),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33004D36),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '我的钱包',
                style: TextStyle(color: Color(0xFFC3D5CC), fontSize: 13),
              ),
              const SizedBox(height: 4),
              _isLoading
                  ? Container(
                      height: 36,
                      width: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF33705E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    )
                  : Text(
                      '¥${_balance ?? '0.00'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ],
          ),
          Column(
            children: [
              ElevatedButton(
                onPressed: _isLoading ? null : _openRecharge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF004D36),
                  disabledBackgroundColor: const Color(0xFF33705E),
                  disabledForegroundColor: const Color(0xFFC3D5CC),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  '充值',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _openWithdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF33705E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF33705E),
                  disabledForegroundColor: const Color(0xFFC3D5CC),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  '提现',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchRoleCard extends StatefulWidget {
  const _SwitchRoleCard();

  @override
  State<_SwitchRoleCard> createState() => _SwitchRoleCardState();
}

class _SwitchRoleCardState extends State<_SwitchRoleCard> {
  late final ApplyCaretakerRemoteDataSource _dataSource;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _dataSource = ApplyCaretakerRemoteDataSource(ApiClient());
  }

  Future<void> _switchToCaretaker() async {
    if (_isSwitching) return;

    final currentRoleType = await AuthTokenStore.instance.readRoleType();
    if (currentRoleType == 2 || currentRoleType == 3) {
      if (mounted) context.go('/caretaker/profile');
      return;
    }

    setState(() => _isSwitching = true);
    final result = await _dataSource.applyCaretaker();
    if (!mounted) return;

    result.when(
      success: (data) async {
        final newToken = data.newToken?.trim();
        if (newToken != null && newToken.isNotEmpty) {
          await AuthTokenStore.instance.writeToken(newToken);
        }
        final nextRoleType = currentRoleType == null
            ? 2
            : (currentRoleType == 1 ? 3 : currentRoleType);
        await AuthTokenStore.instance.writeRoleType(nextRoleType);
        if (!mounted) return;
        setState(() => _isSwitching = false);
        context.go('/caretaker/profile');
      },
      failure: (error) {
        setState(() => _isSwitching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isSwitching ? null : _switchToCaretaker,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEBEBEB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFC8DED6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.people_outline, color: Color(0xFF004D36)),
            ),
            const SizedBox(width: 16),
            const Expanded(child: _SwitchRoleText()),
            _isSwitching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF004D36),
                    ),
                  )
                : const Icon(Icons.chevron_right, color: Color(0xFF5A6B62)),
          ],
        ),
      ),
    );
  }
}

class _SwitchRoleText extends StatelessWidget {
  const _SwitchRoleText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '切换为宠托师',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2621),
          ),
        ),
        SizedBox(height: 2),
        Text(
          '开启您的宠物照护职业生涯',
          style: TextStyle(fontSize: 13, color: Color(0xFF5A6B62)),
        ),
      ],
    );
  }
}

class _PetArchiveSection extends StatefulWidget {
  const _PetArchiveSection();

  @override
  State<_PetArchiveSection> createState() => _PetArchiveSectionState();
}

class _PetArchiveSectionState extends State<_PetArchiveSection> {
  final ApiClient _apiClient = ApiClient();

  bool _isLoading = true;
  String? _errorMessage;
  List<PetArchiveModel> _pets = const [];

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get<List<PetArchiveModel>>(
        path: '/api/v1/pet-archives',
        dataParser: (json) {
          final list = json as List<dynamic>;
          return list
              .map(
                (item) => PetArchiveModel.fromJson(
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
          _pets = response.data ?? const [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _errorMessage = response.message.isEmpty
            ? '加载宠物档案失败'
            : response.message;
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

  Future<void> _openAddPet(BuildContext context) async {
    await context.push('/profile/add-pet');
    if (mounted) {
      _loadPets();
    }
  }

  Future<void> _openPetDetail(BuildContext context, int petId) async {
    await context.push('/profile/add-pet?petId=$petId');
    if (mounted) {
      _loadPets();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '宠物数字档案',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2621),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEBEBEB)),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A4D4D)),
            ),
          )
        else if (_pets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEBEBEB)),
            ),
            child: const Text(
              '还没有宠物档案，先添加一只毛孩子吧',
              style: TextStyle(fontSize: 14, color: Color(0xFF5A6B62)),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _pets
                .map(
                  (pet) => SizedBox(
                    width: (MediaQuery.of(context).size.width - 44) / 2,
                    child: _PetCard(
                      pet: pet,
                      onTap: () => _openPetDetail(context, pet.petId),
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _openAddPet(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEBEBEB)),
            ),
            child: Column(
              children: const [
                Icon(Icons.add, color: Color(0xFF5A6B62), size: 28),
                SizedBox(height: 8),
                Text(
                  '添加新的毛孩子',
                  style: TextStyle(color: Color(0xFF5A6B62), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PetCard extends StatelessWidget {
  final PetArchiveModel pet;
  final VoidCallback onTap;

  const _PetCard({required this.pet, required this.onTap});

  ImageProvider<Object> _buildImageProvider() {
    final image = pet.displayImagePath;
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return NetworkImage(image);
    }
    return AssetImage(image);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEBEBEB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 26, backgroundImage: _buildImageProvider()),
            const SizedBox(height: 12),
            Text(
              pet.petName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2621),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              pet.typeLabel,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B62)),
            ),
            if (pet.profileTags.displayLabels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: pet.profileTags.displayLabels.take(4).map((label) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F2EF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF004D36),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              pet.defaultReq,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B62)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTemplateSection extends StatelessWidget {
  const _AddressTemplateSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        InkWell(
          onTap: () => context.push('/profile/address-template/create'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEBEBEB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2EF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_location_alt_outlined,
                    color: Color(0xFF004D36),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '我的地址模板',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2621),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '提前保存地址、联系人和电话，下单时一键选择。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF5A6B62),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFFC3D5CC)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuListSection extends StatelessWidget {
  const _MenuListSection();

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AuthTokenStore.instance.clearAll();
    if (context.mounted) context.go('/login');
  }

  Future<void> _deactivate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('账号注销'),
        content: const Text(
          '注销后将无法恢复当前账号。系统会先校验进行中订单、售后纠纷以及账户资金/保证金状态，满足条件后才可完成注销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认注销'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final apiClient = ApiClient();
    final authRemoteDataSource = AuthRemoteDataSource(apiClient);
    try {
      final result = await authRemoteDataSource.deactivateAccount();
      if (!context.mounted) return;
      result.when(
        success: (_) => context.go('/login'),
        failure: (error) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.message)));
        },
      );
    } finally {
      apiClient.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.info_outline,
            title: '关于宠托',
            subtitle: '版本与平台信息',
            onTap: () {},
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.lock_outline,
            title: '账号密码',
            subtitle: '设置或修改登录密码',
            onTap: () => context.push('/profile/password'),
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.logout,
            title: '退出登录',
            subtitle: '切换其他账号',
            onTap: () => _logout(context),
          ),
          const _MenuDivider(),
          _MenuItem(
            icon: Icons.person_off_outlined,
            title: '账号注销',
            subtitle: '校验订单、纠纷与资金后注销账号',
            onTap: () => _deactivate(context),
          ),
        ],
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF7F9F8),
      indent: 56,
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: const Color(0xFF004D36), size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A2621),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFC3D5CC)),
    );
  }
}
