import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_result.dart';
import 'package:pets/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:pets/features/auth/data/datasources/apply_caretaker_remote_data_source.dart';

import 'caretaker_edit_profile_screen.dart';

import '../data/datasources/caretaker_deposit_remote_data_source.dart';
import '../data/datasources/caretaker_profile_remote_data_source.dart';
import '../data/repositories/caretaker_deposit_repository_impl.dart';
import '../data/repositories/caretaker_profile_repository_impl.dart';
import '../domain/entities/caretaker_deposit.dart';
import '../domain/entities/caretaker_profile.dart';
import '../domain/entities/caretaker_wallet.dart';
import '../domain/usecases/get_caretaker_deposit_use_case.dart';
import '../domain/usecases/get_caretaker_profile_use_case.dart';
import '../domain/usecases/get_caretaker_wallet_use_case.dart';
import '../domain/usecases/update_service_range_use_case.dart';

import 'deposit_flow_helper.dart';

class CaretakerProfileScreen extends StatefulWidget {
  const CaretakerProfileScreen({super.key});

  @override
  State<CaretakerProfileScreen> createState() => _CaretakerProfileScreenState();
}

class _CaretakerProfileScreenState extends State<CaretakerProfileScreen> {
  late final GetCaretakerProfileUseCase _getProfileUseCase;
  late final GetCaretakerWalletUseCase _getWalletUseCase;
  late final GetCaretakerDepositUseCase _getDepositUseCase;
  late final UpdateProfileUseCase _updateProfileUseCase;

  CaretakerProfile? _profile;
  CaretakerWallet? _wallet;
  CaretakerDeposit? _deposit;
  bool _isLoadingProfile = true;
  bool _isLoadingWallet = true;
  bool _isLoadingDeposit = true;
  bool _isAdminUser = false;
  String? _profileError;

  /// 注册/登录时本地储存的昵称，作为档案为空时的兜底展示
  String _localNickname = '';

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final profileDataSource = CaretakerProfileRemoteDataSource(client);
    final profileRepo = CaretakerProfileRepositoryImpl(profileDataSource);
    _getProfileUseCase = GetCaretakerProfileUseCase(profileRepo);
    _getWalletUseCase = GetCaretakerWalletUseCase(profileRepo);
    _updateProfileUseCase = UpdateProfileUseCase(profileRepo);
    final depositRepo = CaretakerDepositRepositoryImpl(
      CaretakerDepositRemoteDataSource(client),
    );
    _getDepositUseCase = GetCaretakerDepositUseCase(depositRepo);
    _loadLocalNickname();
    _prepareCaretakerSession();
  }

  Future<void> _prepareCaretakerSession() async {
    final roleType = await AuthTokenStore.instance.readRoleType();
    final userId = await AuthTokenStore.instance.readUserId();
    _isAdminUser = userId == 999999;
    if (roleType == 1) {
      final result = await ApplyCaretakerRemoteDataSource(
        ApiClient(),
      ).applyCaretaker();
      if (!mounted) return;
      switch (result) {
        case ApiSuccess(:final data):
          final newToken = data.newToken?.trim();
          if (newToken != null && newToken.isNotEmpty) {
            await AuthTokenStore.instance.writeToken(newToken);
          }
          await AuthTokenStore.instance.writeRoleType(3);
        case ApiFailure(:final error):
          setState(() {
            _profileError = error.message;
            _isLoadingProfile = false;
            _isLoadingWallet = false;
          });
          return;
      }
    }
    if (!mounted) return;
    await _loadAll();
  }

  Future<void> _loadLocalNickname() async {
    final stored = await AuthTokenStore.instance.readNickname();
    if (stored != null && stored.isNotEmpty && mounted) {
      setState(() => _localNickname = stored);
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoadingProfile = true;
      _isLoadingWallet = true;
      _isLoadingDeposit = true;
      _profileError = null;
    });
    await Future.wait([_loadProfile(), _loadWallet(), _loadDeposit()]);
  }

  Future<void> _loadProfile() async {
    final result = await _getProfileUseCase();
    if (!mounted) return;
    result.when(
      success: (profile) async {
        // 新用户：档案 nickname 为空时，用注册时保存的昵称自动初始化档案
        if (profile.nickname.isEmpty) {
          final storedNickname = await AuthTokenStore.instance.readNickname();
          if (storedNickname != null && storedNickname.isNotEmpty && mounted) {
            await _updateProfileUseCase(
              nickname: storedNickname,
              avatarUrl: profile.avatarUrl,
              certLabels: profile.certLabels,
              serviceRangeKm: profile.serviceRangeKm,
              residentAddress: profile.residentAddress,
            );
            if (!mounted) return;
            // 重新拉取以确保数据与服务端同步
            final refreshed = await _getProfileUseCase();
            if (!mounted) return;
            refreshed.when(
              success: (p) => setState(() {
                _profile = p;
                _isLoadingProfile = false;
              }),
              failure: (_) => setState(() {
                _profile = profile;
                _isLoadingProfile = false;
              }),
            );
            return;
          }
        }
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
        });
      },
      failure: (error) => setState(() {
        _profileError = error.message;
        _isLoadingProfile = false;
      }),
    );
  }

  Future<void> _loadWallet() async {
    final result = await _getWalletUseCase();
    if (!mounted) return;
    result.when(
      success: (wallet) => setState(() {
        _wallet = wallet;
        _isLoadingWallet = false;
      }),
      failure: (_) => setState(() => _isLoadingWallet = false),
    );
  }

  Future<void> _loadDeposit() async {
    final result = await _getDepositUseCase();
    if (!mounted) return;
    result.when(
      success: (deposit) => setState(() {
        _deposit = deposit;
        _isLoadingDeposit = false;
      }),
      failure: (_) => setState(() => _isLoadingDeposit = false),
    );
  }

  Future<void> _openDeposit() async {
    await context.push('/caretaker/deposit');
    if (mounted) _loadAll();
  }

  Future<void> _openEditProfile() async {
    if (_profile == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CaretakerEditProfileScreen(profile: _profile!),
      ),
    );
    if (updated == true && mounted) {
      _loadAll();
    }
  }

  bool get _isProfileIncomplete =>
      !_isLoadingProfile &&
      _profileError == null &&
      _profile != null &&
      (_profile!.nickname.isEmpty || _profile!.avatarUrl.isEmpty);

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
      ),
      body: RefreshIndicator(
        color: const Color(0xFF004D36),
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              if (_isLoadingProfile)
                const _ProfileHeaderSkeleton()
              else if (_profileError != null)
                _ErrorBanner(message: _profileError!, onRetry: _loadProfile)
              else if (_profile != null)
                _ProfileHeader(
                  profile: _profile!,
                  fallbackNickname: _localNickname,
                  onEdit: _openEditProfile,
                ),
              // 新用户档案未完善提醒
              if (_isProfileIncomplete) ...[
                const SizedBox(height: 12),
                _CompleteProfileBanner(onTap: _openEditProfile),
              ],
              // 未实名认证时的提醒横幅
              if (!_isLoadingProfile &&
                  _profileError == null &&
                  _profile != null &&
                  !_profile!.certTags.contains('实名认证')) ...[
                const SizedBox(height: 12),
                _VerifyReminderBanner(
                  onTap: () async {
                    await context.push('/caretaker/auth');
                    if (mounted) _loadAll();
                  },
                ),
              ],
              if (!_isLoadingDeposit &&
                  _deposit != null &&
                  !_deposit!.basicReady) ...[
                const SizedBox(height: 12),
                _DepositReminderBanner(onTap: _openDeposit),
              ],
              const SizedBox(height: 16),
              if (_profile != null) _BasicInfoCard(profile: _profile!),
              const SizedBox(height: 24),
              _FinanceCard(
                balance: _wallet?.balance,
                deposit: _deposit,
                isLoading: _isLoadingWallet || _isLoadingDeposit,
                onWithdraw: () async {
                  final balance = _wallet?.balance ?? '0.00';
                  final newBalance = await context.push<String>(
                    '/wallet/withdraw?balance=$balance',
                  );
                  if (newBalance != null && mounted) {
                    setState(() {
                      _wallet = CaretakerWallet(balance: newBalance);
                    });
                  }
                },
                onDepositTap: _openDeposit,
              ),
              const SizedBox(height: 16),
              _MenuList(
                reviewCount: _profile?.reviewCount,
                isRealNameVerified:
                    _profile?.certTags.contains('实名认证') ?? false,
                showDepositMenu: (_deposit?.depositAmount ?? 0) > 0,
                showAdminAppealMenu: _isAdminUser,
                onAfterVerify: _loadAll,
                onDepositTap: _openDeposit,
              ),
              const SizedBox(height: 16),
              const _SwitchToOwnerCard(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 新用户档案未完善提醒横幅 ─────────────────────────────────────────────────

class _CompleteProfileBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CompleteProfileBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF004D36), Color(0xFF006B4E)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '完善您的宠托师档案',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '上传头像、填写昵称与特色标签，让宠主更了解您',
                    style: TextStyle(color: Color(0xFFB3D9CC), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── 保证金提醒横幅 ───────────────────────────────────────────────────────────

class _DepositReminderBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _DepositReminderBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE082).withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Color(0xFF996600),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '首次接单需缴纳 ¥200 保证金',
                    style: TextStyle(
                      color: Color(0xFF996600),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '缴纳后即可报名接单，退出宠托师身份后可退还',
                    style: TextStyle(color: Color(0xFFB8860B), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF996600), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── 实名认证提醒横幅 ─────────────────────────────────────────────────────────

class _VerifyReminderBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _VerifyReminderBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD97A), width: 1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFF996600),
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '您尚未完成实名认证',
                    style: TextStyle(
                      color: Color(0xFF6B4400),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '接单前必须完成实名认证，点击前往认证',
                    style: TextStyle(color: Color(0xFF996600), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF996600), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── 头部：昵称 / 头像 / 评分 / 标签 ────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final CaretakerProfile profile;

  /// 档案 nickname 为空时的本地兜底昵称（来自注册/登录时存储）
  final String fallbackNickname;
  final VoidCallback? onEdit;

  const _ProfileHeader({
    required this.profile,
    this.fallbackNickname = '',
    this.onEdit,
  });

  String get _displayNickname {
    if (profile.nickname.isNotEmpty) return profile.nickname;
    if (fallbackNickname.isNotEmpty) return fallbackNickname;
    return '未填写昵称';
  }

  bool get _isNicknameReal => profile.nickname.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFE8F2EF),
            backgroundImage: profile.avatarUrl.isNotEmpty
                ? NetworkImage(profile.avatarUrl)
                : null,
            child: profile.avatarUrl.isEmpty
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
                        _displayNickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _isNicknameReal
                              ? const Color(0xFF1A2621)
                              : const Color(0xFFB0C4BC),
                        ),
                      ),
                    ),
                    if (profile.rating > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFF9A826),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              profile.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2621),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (profile.levelTag.isNotEmpty)
                      _buildTag(
                        profile.levelTag,
                        const Color(0xFF004D36),
                        const Color(0xFFE8F2EF),
                      ),
                    for (final tag in profile.certTags)
                      _buildTag(
                        tag,
                        const Color(0xFF004D36),
                        const Color(0xFFD4EDE4),
                      ),
                    for (final label in profile.certLabels)
                      _buildTag(
                        label,
                        const Color(0xFF8B4513),
                        const Color(0xFFFFF0E6),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Color(0xFFB0C4BC), size: 22),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E7E5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 20,
                width: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7E5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 14,
                width: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7E5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 基本信息卡片（PRD：个人基础信息 + 养宠能力与经历统计） ─────────────────

class _BasicInfoCard extends StatelessWidget {
  final CaretakerProfile profile;
  const _BasicInfoCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rows = <_InfoRow>[];

    if (profile.genderText.isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: Icons.person_outline,
          label: '性别',
          value: profile.genderText,
        ),
      );
    }

    final address = profile.residentAddress;
    if (address != null && address.isNotEmpty) {
      rows.add(
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: '常驻地址',
          value: address,
        ),
      );
    }

    final rangeKm = profile.serviceRangeKm;
    final rangeLabel = rangeKm == 0 ? '不限距离' : '$rangeKm km 内';
    rows.add(
      _InfoRow(icon: Icons.radar_outlined, label: '服务范围', value: rangeLabel),
    );

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '基本信息',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8BA49A),
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (r) =>
                Padding(padding: const EdgeInsets.only(bottom: 10), child: r),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSystemGenerated;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isSystemGenerated = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF5A6B62)),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A2621),
            ),
          ),
        ),
        if (isSystemGenerated)
          const Text(
            '系统统计',
            style: TextStyle(fontSize: 11, color: Color(0xFFC3D5CC)),
          ),
      ],
    );
  }
}

// ─── 资金卡片（余额 + 保证金）────────────────────────────────────────────────

class _FinanceCard extends StatelessWidget {
  final String? balance;
  final CaretakerDeposit? deposit;
  final bool isLoading;
  final VoidCallback? onWithdraw;
  final VoidCallback? onDepositTap;

  const _FinanceCard({
    this.balance,
    this.deposit,
    required this.isLoading,
    this.onWithdraw,
    this.onDepositTap,
  });

  @override
  Widget build(BuildContext context) {
    final depositReady = deposit?.basicReady ?? false;
    final depositText = deposit == null
        ? '--'
        : depositReady
        ? '已缴纳 ¥${formatMoney(deposit!.depositAmount)}'
        : '待缴 ¥${formatMoney(deposit!.amountStillNeeded)}';

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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '可提现余额',
                    style: TextStyle(color: Color(0xFFC3D5CC), fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  isLoading
                      ? Container(
                          height: 36,
                          width: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF33705E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        )
                      : Text(
                          balance != null ? '¥$balance' : '--',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ],
              ),
              ElevatedButton(
                onPressed: onWithdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF33705E),
                  foregroundColor: Colors.white,
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
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF33705E), height: 1),
          const SizedBox(height: 14),
          InkWell(
            onTap: depositReady ? null : onDepositTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFC3D5CC),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '服务保证金',
                    style: TextStyle(color: Color(0xFFC3D5CC), fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    depositText,
                    style: TextStyle(
                      color: depositReady
                          ? const Color(0xFF7FD4B8)
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!depositReady) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFFC3D5CC),
                      size: 18,
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

// ─── 特色标签 ─────────────────────────────────────────────────────────────────

class _FeaturesGrid extends StatelessWidget {
  final List<String> certLabels;

  const _FeaturesGrid({required this.certLabels});

  static const _icons = [
    Icons.history,
    Icons.content_cut,
    Icons.verified_outlined,
    Icons.star_outline,
    Icons.pets,
  ];

  @override
  Widget build(BuildContext context) {
    if (certLabels.isEmpty) return const SizedBox.shrink();
    final items = certLabels.take(3).toList();
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _buildFeatureItem(_icons[i % _icons.length], items[i]),
          ),
        ],
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF5A6B62), size: 28),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A2621),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 菜单列表 ─────────────────────────────────────────────────────────────────

class _MenuList extends StatelessWidget {
  final int? reviewCount;
  final bool isRealNameVerified;
  final bool showDepositMenu;
  final bool showAdminAppealMenu;
  final VoidCallback? onAfterVerify;
  final VoidCallback? onDepositTap;

  const _MenuList({
    this.reviewCount,
    this.isRealNameVerified = false,
    this.showDepositMenu = false,
    this.showAdminAppealMenu = false,
    this.onAfterVerify,
    this.onDepositTap,
  });

  @override
  Widget build(BuildContext context) {
    final reviewText = reviewCount != null ? '共 $reviewCount 条真实反馈' : '加载中…';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        children: [
          _MenuListItem(
            icon: Icons.verified_user_outlined,
            title: '实名认证',
            subtitle: isRealNameVerified ? '已完成实名认证' : '未认证，接单前必须完成',
            showBadge: !isRealNameVerified,
            onTap: () async {
              await context.push('/caretaker/auth');
              onAfterVerify?.call();
            },
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF7F9F8),
            indent: 56,
          ),
          _MenuListItem(
            icon: Icons.school_outlined,
            title: '培训与考核',
            subtitle: '平台宠托师资格认证',
            onTap: () => context.push('/caretaker/training'),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF7F9F8),
            indent: 56,
          ),
          _MenuListItem(
            icon: Icons.receipt_long_outlined,
            title: '收入明细',
            subtitle: '查看完整历史记录',
            onTap: () => context.push('/caretaker/income'),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF7F9F8),
            indent: 56,
          ),
          _MenuListItem(
            icon: Icons.task_alt_outlined,
            title: '今日完成订单',
            subtitle: '查看今天已结算完成的订单',
            onTap: () => context.push('/caretaker/today-completed'),
          ),
          if (showDepositMenu) ...[
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF7F9F8),
              indent: 56,
            ),
            _MenuListItem(
              icon: Icons.shield_outlined,
              title: '保证金管理',
              subtitle: '查看已缴纳的服务保证金',
              onTap: () => onDepositTap?.call(),
            ),
          ],
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF7F9F8),
            indent: 56,
          ),
          _MenuListItem(
            icon: Icons.chat_outlined,
            title: '我的评价',
            subtitle: reviewText,
            onTap: () => context.push('/caretaker/reviews'),
          ),
          if (showAdminAppealMenu) ...[
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF7F9F8),
              indent: 56,
            ),
            _MenuListItem(
              icon: Icons.gavel_outlined,
              title: '申诉处理台',
              subtitle: '查看申诉、证据链和人工仲裁结果',
              onTap: () => context.push('/admin/review-appeals'),
            ),
          ],
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF7F9F8),
            indent: 56,
          ),
          _MenuListItem(
            icon: Icons.lock_outline,
            title: '账号密码',
            subtitle: '设置或修改登录密码',
            onTap: () => context.push('/profile/password'),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF7F9F8),
            indent: 56,
          ),
          _MenuListItem(
            icon: Icons.logout,
            title: '退出登录',
            subtitle: '切换其他账号',
            onTap: () => _confirmLogout(context),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF7F9F8),
            indent: 56,
          ),
          _MenuListItem(
            icon: Icons.person_off_outlined,
            title: '账号注销',
            subtitle: '校验订单、纠纷与资金后注销账号',
            onTap: () => _confirmDeactivate(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
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

  Future<void> _confirmDeactivate(BuildContext context) async {
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
}

class _MenuListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showBadge;
  final VoidCallback? onTap;

  const _MenuListItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: const Color(0xFF004D36), size: 24),
          if (showBadge)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE53935),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A2621),
            ),
          ),
          if (showBadge) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '待完成',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: showBadge
                ? const Color(0xFFE57373)
                : const Color(0xFF8BA49A),
          ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFC3D5CC)),
    );
  }
}

// ─── 错误条幅 ─────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCCC7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFF06A42), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8B3A30)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF06A42),
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 32),
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

// ─── 切换为宠物主 ─────────────────────────────────────────────────────────────

class _SwitchToOwnerCard extends StatelessWidget {
  const _SwitchToOwnerCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/profile'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDE8E4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F2EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pets_outlined, color: Color(0xFF004D36)),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '切换为宠物主',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2621),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '回到宠物主模式',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5A6B62)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF5A6B62)),
          ],
        ),
      ),
    );
  }
}

