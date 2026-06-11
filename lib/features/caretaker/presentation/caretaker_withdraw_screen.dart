import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/caretaker_profile_remote_data_source.dart';

class CaretakerWithdrawScreen extends StatefulWidget {
  const CaretakerWithdrawScreen({super.key, required this.currentBalance});

  final String currentBalance;

  @override
  State<CaretakerWithdrawScreen> createState() =>
      _CaretakerWithdrawScreenState();
}

class _CaretakerWithdrawScreenState extends State<CaretakerWithdrawScreen> {
  late final CaretakerProfileRemoteDataSource _dataSource;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _realNameController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  bool _isSubmitting = false;
  String? _inputError;

  int get _maxAmount {
    final parsed = double.tryParse(widget.currentBalance) ?? 0;
    return parsed.floor();
  }

  static const int _minAmount = 10;

  @override
  void initState() {
    super.initState();
    _dataSource = CaretakerProfileRemoteDataSource(ApiClient());
    AuthTokenStore.instance.readPhone().then((phone) {
      if (!mounted || phone == null || phone.isEmpty) return;
      _accountController.text = phone;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    _realNameController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _clearError(String value) {
    if (_inputError != null) setState(() => _inputError = null);
  }

  String? _validate() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return '请输入提现金额';
    final amount = int.tryParse(text);
    if (amount == null) return '金额必须为整数';
    if (amount < _minAmount) return '最低提现金额为 ¥$_minAmount';
    if (amount > _maxAmount) return '超出可提现余额';
    if (_accountController.text.trim().isEmpty) return '请输入支付宝账号';
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _inputError = error);
      return;
    }

    FocusScope.of(context).unfocus();
    final amount = int.parse(_amountController.text.trim());
    setState(() => _isSubmitting = true);

    try {
      final response = await _dataSource.withdrawWallet(
        amount: amount,
        payeeAccount: _accountController.text.trim(),
        payeeRealName: _realNameController.text.trim(),
        remark: '用户提现',
      );
      if (!mounted) return;
      if (!response.isSuccess) {
        setState(() {
          _isSubmitting = false;
          _inputError = response.message.isEmpty ? '提现失败' : response.message;
        });
        return;
      }
      final newBalance = (double.tryParse(widget.currentBalance) ?? 0) - amount;
      Navigator.of(context).pop(newBalance.toStringAsFixed(2));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _inputError = '提现失败，请稍后重试';
      });
    }
  }

  void _fillMax() {
    _amountController.text = _maxAmount.toString();
    setState(() => _inputError = null);
  }

  @override
  Widget build(BuildContext context) {
    final balanceText = '¥${widget.currentBalance}';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        title: const Text(
          '提现',
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
              _BalanceHeader(balanceText: balanceText),
              const SizedBox(height: 24),
              _WithdrawForm(
                amountController: _amountController,
                accountController: _accountController,
                realNameController: _realNameController,
                amountFocusNode: _amountFocusNode,
                minAmount: _minAmount,
                inputError: _inputError,
                onChanged: _clearError,
                onFillMax: _fillMax,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF004D36),
                    disabledBackgroundColor: const Color(0xFFC3D5CC),
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
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '确认提现',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceHeader extends StatelessWidget {
  final String balanceText;

  const _BalanceHeader({required this.balanceText});

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
            '可提现余额',
            style: TextStyle(color: Color(0xFFC3D5CC), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            balanceText,
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

class _WithdrawForm extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController accountController;
  final TextEditingController realNameController;
  final FocusNode amountFocusNode;
  final int minAmount;
  final String? inputError;
  final ValueChanged<String> onChanged;
  final VoidCallback onFillMax;

  const _WithdrawForm({
    required this.amountController,
    required this.accountController,
    required this.realNameController,
    required this.amountFocusNode,
    required this.minAmount,
    required this.inputError,
    required this.onChanged,
    required this.onFillMax,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '提现金额',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2621),
                ),
              ),
              GestureDetector(
                onTap: onFillMax,
                child: const Text(
                  '全部提现',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF004D36),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
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
                  controller: amountController,
                  focusNode: amountFocusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2621),
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
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
          const Divider(height: 22, color: Color(0xFFEBEBEB)),
          TextField(
            controller: accountController,
            keyboardType: TextInputType.emailAddress,
            onChanged: onChanged,
            decoration: const InputDecoration(
              labelText: '支付宝账号',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: realNameController,
            onChanged: onChanged,
            decoration: const InputDecoration(
              labelText: '支付宝姓名（选填）',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            inputError ?? '最低提现 ¥$minAmount · 整数元 · 到账结果以支付宝处理为准',
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
