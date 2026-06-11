import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_exception.dart';

/// 报名等场景需引导缴纳保证金的业务错误
bool isDepositRelatedError(ApiException error) {
  final code = error.businessCode ?? '';
  if (code == 'A000710' ||
      code == 'A000711' ||
      code == 'A000712') {
    return true;
  }
  return error.message.contains('保证金');
}

Future<bool> showDepositRequiredDialog(
  BuildContext context, {
  String? message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('需要缴纳保证金'),
      content: Text(
        message ??
            '首次接单前需缴纳 ¥200 服务保证金，缴纳后即可报名接单。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('稍后再说'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF004D36),
          ),
          child: const Text('去缴纳'),
        ),
      ],
    ),
  );
  if (result == true && context.mounted) {
    await context.push('/caretaker/deposit');
    return true;
  }
  return false;
}

String formatMoney(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}
