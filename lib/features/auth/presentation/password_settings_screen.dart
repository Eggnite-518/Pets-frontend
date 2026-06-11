import 'package:flutter/material.dart';
import 'package:pets/core/network/api_client.dart';

import '../data/datasources/auth_remote_data_source.dart';

class PasswordSettingsScreen extends StatefulWidget {
  const PasswordSettingsScreen({super.key});

  @override
  State<PasswordSettingsScreen> createState() => _PasswordSettingsScreenState();
}

class _PasswordSettingsScreenState extends State<PasswordSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthRemoteDataSource _authDataSource;

  bool _isSetMode = true;
  bool _isSubmitting = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authDataSource = AuthRemoteDataSource(ApiClient());
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(bool setMode) {
    if (_isSubmitting || _isSetMode == setMode) return;
    setState(() {
      _isSetMode = setMode;
      _errorMessage = null;
      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = _isSetMode
        ? await _authDataSource.setPassword(
            newPassword: _newPasswordController.text,
          )
        : await _authDataSource.changePassword(
            oldPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );

    if (!mounted) return;

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isSetMode ? '密码设置成功' : '密码修改成功')),
        );
        Navigator.of(context).pop();
      },
      failure: (error) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = _friendlyError(error.message, error.businessCode);
        });
      },
    );
  }

  String _friendlyError(String message, String? code) {
    if (code == 'A000122') return '当前账号还没有密码，请使用首次设置密码。';
    if (code == 'A000123') return '当前账号已有密码，请使用修改密码。';
    return message;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return '请输入密码';
    if (password.length < 8) return '密码至少8位';
    var categoryCount = 0;
    if (RegExp(r'[A-Za-z]').hasMatch(password)) categoryCount++;
    if (RegExp(r'\d').hasMatch(password)) categoryCount++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) categoryCount++;
    if (categoryCount < 2) return '密码需包含字母、数字、符号中至少两类';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        title: const Text(
          '账号密码',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PasswordModeTabs(
                isSetMode: _isSetMode,
                onSetTap: () => _switchMode(true),
                onChangeTap: () => _switchMode(false),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFEBEBEB)),
                ),
                child: Column(
                  children: [
                    if (!_isSetMode) ...[
                      _PasswordField(
                        controller: _oldPasswordController,
                        label: '原密码',
                        obscureText: _obscureOldPassword,
                        onToggleObscure: () => setState(
                          () => _obscureOldPassword = !_obscureOldPassword,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return '请输入原密码';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    _PasswordField(
                      controller: _newPasswordController,
                      label: _isSetMode ? '设置密码' : '新密码',
                      obscureText: _obscureNewPassword,
                      onToggleObscure: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 14),
                    _PasswordField(
                      controller: _confirmPasswordController,
                      label: '确认密码',
                      obscureText: _obscureConfirmPassword,
                      onToggleObscure: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '请再次输入密码';
                        if (value != _newPasswordController.text) {
                          return '两次输入的密码不一致';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFD14343),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF004D36),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_isSetMode ? '设置密码' : '修改密码'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordModeTabs extends StatelessWidget {
  final bool isSetMode;
  final VoidCallback onSetTap;
  final VoidCallback onChangeTap;

  const _PasswordModeTabs({
    required this.isSetMode,
    required this.onSetTap,
    required this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PasswordTabButton(
              label: '首次设置密码',
              selected: isSetMode,
              onTap: onSetTap,
            ),
          ),
          Expanded(
            child: _PasswordTabButton(
              label: '修改密码',
              selected: !isSetMode,
              onTap: onChangeTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PasswordTabButton({
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

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final VoidCallback onToggleObscure;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.onToggleObscure,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: onToggleObscure,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}
