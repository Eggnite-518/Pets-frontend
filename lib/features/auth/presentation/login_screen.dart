import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/auth/auth_token_store.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/auth_remote_data_source.dart';
import '../data/models/login_user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isCodeMode = true;
  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _obscurePassword = true;
  int _codeCountdown = 0;
  Timer? _countdownTimer;
  String? _errorMessage;
  String? _successMessage;

  late final AuthRemoteDataSource _authDataSource;

  @override
  void initState() {
    super.initState();
    _authDataSource = AuthRemoteDataSource(ApiClient());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^1[3-9]\d{9}$').hasMatch(value.trim());
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

    final result = await _authDataSource.sendCode(phone: phone);
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
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final phone = _phoneController.text.trim();
    final result = _isCodeMode
        ? await _authDataSource.loginByCode(
            phone: phone,
            code: _codeController.text.trim(),
          )
        : await _authDataSource.login(
            phone: phone,
            password: _passwordController.text,
          );

    if (!mounted) return;

    result.when(
      success: _handleLoginSuccess,
      failure: (error) {
        final passwordNotSet = error.businessCode == 'A000122';
        setState(() {
          _isLoading = false;
          if (passwordNotSet) {
            _isCodeMode = true;
            _errorMessage = '该账号尚未设置密码，请先使用验证码登录，登录后可在我的页面设置密码。';
          } else {
            _errorMessage = error.message;
          }
        });
      },
    );
  }

  Future<void> _handleLoginSuccess(LoginUserModel user) async {
    await AuthTokenStore.instance.writeUserId(user.userId);
    await AuthTokenStore.instance.writeRoleType(user.roleType);
    if (user.nickname.isNotEmpty) {
      await AuthTokenStore.instance.writeNickname(user.nickname);
    }
    if (user.phone.isNotEmpty) {
      await AuthTokenStore.instance.writePhone(user.phone);
    }
    if (!mounted) return;
    if (user.roleType == 2 || user.roleType == 3) {
      context.go('/caretaker');
    } else {
      context.go('/home');
    }
  }

  void _switchMode(bool codeMode) {
    if (_isLoading || _isCodeMode == codeMode) return;
    setState(() {
      _isCodeMode = codeMode;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Icon(Icons.pets, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    '宠托',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _LoginModeTabs(
                    isCodeMode: _isCodeMode,
                    onCodeTap: () => _switchMode(true),
                    onPasswordTap: () => _switchMode(false),
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
                  if (_isCodeMode)
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
                    )
                  else
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '请输入密码';
                        return null;
                      },
                    ),
                  if (!_isCodeMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => context.push('/forgot-password'),
                        child: const Text('忘记密码？'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _successMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isCodeMode ? '登录/注册' : '登录',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => _switchMode(!_isCodeMode),
                    child: Text(_isCodeMode ? '已有密码？使用密码登录' : '没有账号？验证码登录/注册'),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginModeTabs extends StatelessWidget {
  final bool isCodeMode;
  final VoidCallback onCodeTap;
  final VoidCallback onPasswordTap;

  const _LoginModeTabs({
    required this.isCodeMode,
    required this.onCodeTap,
    required this.onPasswordTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTabButton(
              label: '验证码登录/注册',
              selected: isCodeMode,
              onTap: onCodeTap,
            ),
          ),
          Expanded(
            child: _ModeTabButton(
              label: '密码登录',
              selected: !isCodeMode,
              onTap: onPasswordTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF004D36) : const Color(0xFF5A6B62),
          ),
        ),
      ),
    );
  }
}
