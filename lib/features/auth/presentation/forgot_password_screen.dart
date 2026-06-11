import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/auth_remote_data_source.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthRemoteDataSource _authDataSource;

  bool _isSubmitting = false;
  bool _isSendingCode = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _codeCountdown = 0;
  Timer? _countdownTimer;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _authDataSource = AuthRemoteDataSource(ApiClient());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(value.trim());
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '请输入新密码';
    if (password.length < 8) return '密码至少8位';
    var categoryCount = 0;
    if (RegExp(r'[A-Za-z]').hasMatch(password)) categoryCount++;
    if (RegExp(r'\d').hasMatch(password)) categoryCount++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) categoryCount++;
    if (categoryCount < 2) return '密码需包含字母、数字、符号中至少两类';
    return null;
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      setState(() {
        _errorMessage = phone.isEmpty ? '请输入手机号' : '手机号格式不正确';
        _successMessage = null;
      });
      return;
    }
    if (_isSendingCode || _codeCountdown > 0) return;

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await _authDataSource.sendCode(
      phone: phone,
      scene: 'reset_password',
    );
    if (!mounted) return;

    result.when(
      success: (_) {
        setState(() {
          _isSendingCode = false;
          _successMessage = '验证码已发送';
          _codeCountdown = 60;
        });
        _startCountdown();
      },
      failure: (error) {
        setState(() {
          _isSendingCode = false;
          _errorMessage = error.message;
        });
      },
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_codeCountdown <= 1) {
        timer.cancel();
        setState(() => _codeCountdown = 0);
        return;
      }
      setState(() => _codeCountdown--);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final result = await _authDataSource.resetPassword(
      phone: _phoneController.text.trim(),
      code: _codeController.text.trim(),
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码重置成功，请使用新密码登录')),
        );
        context.go('/login');
      },
      failure: (error) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = error.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('忘记密码'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    '通过短信验证码重置登录密码',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5A6B62),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final phone = value?.trim() ?? '';
                      if (phone.isEmpty) return '请输入手机号';
                      if (!_isValidPhone(phone)) return '手机号格式不正确';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '验证码',
                      prefixIcon: const Icon(Icons.sms_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: TextButton(
                        onPressed: (_isSendingCode || _codeCountdown > 0)
                            ? null
                            : _sendCode,
                        child: _isSendingCode
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _codeCountdown > 0
                                    ? '${_codeCountdown}s'
                                    : '发送验证码',
                              ),
                      ),
                    ),
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      if (code.isEmpty) return '请输入验证码';
                      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                        return '请输入6位验证码';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: '新密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: '确认新密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return '请再次输入新密码';
                      if (value != _newPasswordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _successMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('重置密码', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSubmitting ? null : () => context.go('/login'),
                    child: const Text('返回登录'),
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
