import 'package:flutter/material.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_deposit_remote_data_source.dart';
import '../data/repositories/caretaker_deposit_repository_impl.dart';
import '../domain/entities/caretaker_deposit.dart';
import '../domain/usecases/confirm_wallet_recharge_use_case.dart';
import '../domain/usecases/get_caretaker_deposit_use_case.dart';
import '../domain/usecases/recharge_deposit_use_case.dart';
import '../domain/usecases/wallet_recharge_use_case.dart';
import 'alipay_browser_launcher.dart';
import 'deposit_flow_helper.dart';

class CaretakerDepositScreen extends StatefulWidget {
  const CaretakerDepositScreen({super.key});

  @override
  State<CaretakerDepositScreen> createState() => _CaretakerDepositScreenState();
}

class _CaretakerDepositScreenState extends State<CaretakerDepositScreen> {
  late final GetCaretakerDepositUseCase _getDepositUseCase;
  late final RechargeDepositUseCase _rechargeDepositUseCase;
  late final WalletRechargeUseCase _walletRechargeUseCase;
  late final ConfirmWalletRechargeUseCase _confirmWalletRechargeUseCase;

  CaretakerDeposit? _deposit;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final client = ApiClient();
    final repo = CaretakerDepositRepositoryImpl(
      CaretakerDepositRemoteDataSource(client),
    );
    _getDepositUseCase = GetCaretakerDepositUseCase(repo);
    _rechargeDepositUseCase = RechargeDepositUseCase(repo);
    _walletRechargeUseCase = WalletRechargeUseCase(repo);
    _confirmWalletRechargeUseCase = ConfirmWalletRechargeUseCase(repo);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _getDepositUseCase();
    if (!mounted) return;
    result.when(
      success: (deposit) => setState(() {
        _deposit = deposit;
        _isLoading = false;
      }),
      failure: (error) => setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      }),
    );
  }

  Future<void> _payDeposit() async {
    if (_isSubmitting || _deposit == null || _deposit!.basicReady) return;
    setState(() => _isSubmitting = true);
    final result = await _rechargeDepositUseCase();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    result.when(
      success: (deposit) {
        setState(() => _deposit = deposit);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保证金缴纳成功，可以报名接单了'),
            backgroundColor: Color(0xFF004D36),
          ),
        );
      },
      failure: (error) {
        if (isDepositRelatedError(error) &&
            error.businessCode == 'A000712') {
          _startWalletRecharge(_deposit!.walletShortfall);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      },
    );
  }

  Future<void> _startWalletRecharge(double amount) async {
    if (_isSubmitting || amount <= 0) return;
    final balanceBefore = _deposit?.walletBalance ?? 0;
    setState(() => _isSubmitting = true);
    final result = await _walletRechargeUseCase(amount: amount);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    await result.when(
      success: (order) async {
        if (order.outTradeNo.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('充值订单创建失败'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        final opened = await launchAlipayPagePayInBrowser(order.outTradeNo);
        if (!mounted) return;
        if (!opened) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法打开浏览器，请检查是否安装了浏览器应用'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        final confirmed = await _showBrowserPaymentDialog();
        if (!mounted || confirmed != true) return;
        await _confirmAndRefreshRecharge(
          outTradeNo: order.outTradeNo,
          balanceBefore: balanceBefore,
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: Colors.red),
        );
      },
    );
  }

  Future<bool?> _showBrowserPaymentDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('请在浏览器完成支付'),
        content: const Text(
          '已在系统浏览器打开支付宝沙箱支付页。\n\n'
          '请使用沙箱买家账号完成支付，然后返回 App 点击下方按钮。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF004D36),
            ),
            child: const Text('我已完成支付'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndRefreshRecharge({
    required String outTradeNo,
    required double balanceBefore,
  }) async {
    setState(() => _isSubmitting = true);
    for (var attempt = 0; attempt < 3; attempt++) {
      final confirmResult = await _confirmWalletRechargeUseCase(
        outTradeNo: outTradeNo,
      );
      confirmResult.when(
        success: (_) {},
        failure: (_) {},
      );
      await _load();
      if (!mounted) return;
      if ((_deposit?.walletBalance ?? 0) > balanceBefore) {
        break;
      }
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    final balanceAfter = _deposit?.walletBalance ?? 0;
    if (balanceAfter > balanceBefore) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('充值已到账，请点击下方按钮缴纳保证金'),
          backgroundColor: Color(0xFF004D36),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂未检测到到账，请确认浏览器里已支付成功，或下拉刷新重试'),
          backgroundColor: Color(0xFF5A6B62),
        ),
      );
    }
  }

  Future<void> _onPrimaryAction() async {
    final deposit = _deposit;
    if (deposit == null || deposit.basicReady) return;
    if (deposit.canPayDepositFromWallet) {
      await _payDeposit();
    } else {
      await _startWalletRecharge(deposit.walletShortfall);
    }
  }

  String _primaryButtonLabel(CaretakerDeposit deposit) {
    if (deposit.basicReady) return '已缴纳保证金';
    if (deposit.canPayDepositFromWallet) {
      return '缴纳保证金 ¥${formatMoney(deposit.amountStillNeeded)}';
    }
    return '充值钱包 ¥${formatMoney(deposit.walletShortfall)}';
  }

  @override
  Widget build(BuildContext context) {
    final deposit = _deposit;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        title: const Text(
          '服务保证金',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF004D36),
        onRefresh: _load,
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: CircularProgressIndicator(color: Color(0xFF004D36)),
                  ),
                ],
              )
            : _errorMessage != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton(
                          onPressed: _load,
                          child: const Text('重试'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (deposit != null) ...[
                        _StatusCard(deposit: deposit),
                        const SizedBox(height: 16),
                        _InfoCard(deposit: deposit),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: deposit.basicReady || _isSubmitting
                              ? null
                              : _onPrimaryAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF004D36),
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _primaryButtonLabel(deposit),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        if (!deposit.basicReady &&
                            !deposit.canPayDepositFromWallet) ...[
                          const SizedBox(height: 12),
                          Text(
                            '钱包余额不足，需先在系统浏览器通过支付宝充值 ¥${formatMoney(deposit.walletShortfall)}，再从余额划扣保证金。',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF5A6B62),
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          '退出宠托师身份后，保证金将按平台规则退还至您的钱包。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8BA49A),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final CaretakerDeposit deposit;

  const _StatusCard({required this.deposit});

  @override
  Widget build(BuildContext context) {
    final ready = deposit.basicReady;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ready
              ? [const Color(0xFF004D36), const Color(0xFF006B4E)]
              : [const Color(0xFF1A2621), const Color(0xFF004D36)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.verified_outlined : Icons.account_balance_outlined,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                ready ? '保证金已达标' : '待缴纳保证金',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${formatMoney(deposit.depositAmount)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ ¥${formatMoney(deposit.basicRequiredAmount)}',
                  style: const TextStyle(
                    color: Color(0xFFB3D9CC),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (deposit.depositAmount / deposit.basicRequiredAmount)
                  .clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.white24,
              color: const Color(0xFF7FD4B8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final CaretakerDeposit deposit;

  const _InfoCard({required this.deposit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        children: [
          _InfoRow(
            label: '可提现余额',
            value: '¥${formatMoney(deposit.walletBalance)}',
          ),
          const Divider(height: 24, color: Color(0xFFF7F9F8)),
          _InfoRow(
            label: '冻结保证金',
            value: '¥${formatMoney(deposit.frozenAmount)}',
          ),
          if (deposit.custodyRule.isNotEmpty) ...[
            const Divider(height: 24, color: Color(0xFFF7F9F8)),
            Text(
              deposit.custodyRule,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5A6B62),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF5A6B62))),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2621),
          ),
        ),
      ],
    );
  }
}
