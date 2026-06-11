import 'package:flutter/material.dart';

class CaretakerVerificationPlaceholder extends StatelessWidget {
  const CaretakerVerificationPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('宠托师认证')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            '宠托师身份认证（占位页面）\n后续在这里实现证件上传和信息填写流程',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
