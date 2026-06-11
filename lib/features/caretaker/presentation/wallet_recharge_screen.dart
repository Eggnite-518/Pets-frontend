import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_profile_remote_data_source.dart';
import '../domain/entities/wallet_recharge.dart';

class WalletRechargeScreen extends StatefulWidget {
  const WalletRechargeScreen({super.key, required this.currentBalance});

  final String currentBalance;

  @override
  State<WalletRechargeScreen> createState() => _WalletRechargeScreenState();
}

class _WalletRechargeScreenState extends State<WalletRechargeScreen> {
  late final CaretakerProfileRemoteDataSource _dataSource;
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSubmitting = false;
  String? _inputError;
  WalletRecharge? _recharge;

  static const List<int> _quickAmounts = [50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _dataSource = CaretakerProfileRemoteDataSource(ApiClient());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setAmount(int amount) {
    _amountController.text = amount.toString();
    setState(() {
      _inputError = null;
      _recharge = null;
    });
  }

  void _onAmountChanged(String value) {
    if (_inputError != null || _recharge != null) {
      setState(() {
        _inputError = null;
        _recharge = null;
      });
    }
  }

  String? _validate() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return '请输入充值金额';
    final amount = double.tryParse(text);
    if (amount == null) return '金额格式不正确';
    if (amount <= 0) return '充值金额必须大于 0';
    if (amount > 99999) return '单次充值金额过大';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _inputError = error);
      return;
    }

    FocusScope.of(context).unfocus();
    final amount = double.parse(_amountController.text.trim());
    setState(() {
      _isSubmitting = true;
      _inputError = null;
      _recharge = null;
    });

    try {
      final response = await _dataSource.rechargeWallet(amount: amount);
      if (!mounted) return;
      if (!response.isSuccess || response.data == null) {
        setState(() {
          _isSubmitting = false;
          _inputError = response.message.isEmpty ? '发起充值失败' : response.message;
        });
        return;
      }
      setState(() {
        _isSubmitting = false;
        _recharge = response.data!.toEntity();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _inputError = '发起充值失败，请稍后重试';
      });
    }
  }

  Future<void> _copyPayForm() async {
    final payForm = _recharge?.payForm;
    if (payForm == null || payForm.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: payForm));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('支付表单已复制')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        title: const Text(
          '充值',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BalanceHeader(balance: widget.currentBalance),
              const SizedBox(height: 24),
              _AmountPanel(
                controller: _amountController,
                focusNode: _focusNode,
                quickAmounts: _quickAmounts,
                inputError: _inputError,
                onAmountChanged: _onAmountChanged,
                onQuickAmountTap: _setAmount,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.payment_outlined, size: 18),
                  label: Text(_isSubmitting ? '正在发起' : '发起支付宝充值'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF004D36),
                    disabledBackgroundColor: const Color(0xFFC3D5CC),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
              if (_recharge != null) ...[
                const SizedBox(height: 24),
                _PayFormResult(recharge: _recharge!, onCopy: _copyPayForm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final String currentBalance;

  const _BalanceHeader({required String balance}) : currentBalance = balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '当前余额',
            style: TextStyle(color: Color(0xFFC3D5CC), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '¥$currentBalance',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountPanel extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<int> quickAmounts;
  final String? inputError;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<int> onQuickAmountTap;

  const _AmountPanel({
    required this.controller,
    required this.focusNode,
    required this.quickAmounts,
    required this.inputError,
    required this.onAmountChanged,
    required this.onQuickAmountTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '充值金额',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                '¥',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2621),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  onChanged: onAmountChanged,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC3D5CC),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFEBEBEB)),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final amount in quickAmounts)
                OutlinedButton(
                  onPressed: () => onQuickAmountTap(amount),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF004D36),
                    side: const BorderSide(color: Color(0xFFC3D5CC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text('¥$amount'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            inputError ?? '支付完成后需等待支付宝异步回调到账，可稍后刷新余额。',
            style: TextStyle(
              fontSize: 13,
              color: inputError == null
                  ? const Color(0xFF8BA49A)
                  : const Color(0xFFF06A42),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayFormResult extends StatelessWidget {
  final WalletRecharge recharge;
  final VoidCallback onCopy;

  const _PayFormResult({required this.recharge, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF004D36)),
              SizedBox(width: 8),
              Text(
                '充值单已创建',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2621),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '单号：${recharge.outTradeNo}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF5A6B62)),
          ),
          const SizedBox(height: 12),
          const Text(
            '后端返回的是支付宝网页支付 form。当前 App 还没有内嵌 WebView/支付宝 SDK，联调时可复制表单到测试 HTML 页面提交。',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8BA49A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('复制支付表单'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF004D36),
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFC3D5CC)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
