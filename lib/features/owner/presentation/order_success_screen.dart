import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrderSuccessScreen extends StatelessWidget {
  final String? orderId;

  const OrderSuccessScreen({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8), // 统一的浅灰背景色
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 1. 成功大图标
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F2EF), // 浅绿色背景底
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: Color(0xFF004D36) // 主题深绿
                ),
              ),
              const SizedBox(height: 32),

              // 2. 标题文本
              const Text(
                '订单发布成功',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF003827),
                ),
              ),
              const SizedBox(height: 12),

              // 3. 副标题提示
              const Text(
                '您的订单已成功发布，请等待宠托师接单',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF5A6B62),
                ),
              ),
              const SizedBox(height: 64), // 拉开文字和按钮的间距

              // 4. 返回首页按钮 (主按钮)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/home'), // go() 会清空路由栈，直接回到首页
                  icon: const Icon(Icons.home_outlined, size: 20),
                  label: const Text('返回首页', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF004D36),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. 查看订单详情按钮 (次按钮)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: orderId == null
                      ? null
                      : () {
                          context.push('/order/$orderId');
                        },
                  icon: const Icon(Icons.description_outlined, size: 20, color: Color(0xFF004D36)),
                  label: const Text('查看订单详情', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF004D36))),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFD4E0DB), width: 1.2), // 浅绿色边框
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                ),
              ),

              // 底部垫高，让整体内容在视觉上稍微偏上一点，更好看
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}