import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'caretaker_home_screen.dart';

/// 宠托师端的全局主框架（带有固定的底部导航栏）
class CaretakerMainLayout extends StatelessWidget {
  const CaretakerMainLayout({super.key, required this.navigationShell});

  // go_router 传进来的路由壳，用于控制当前显示哪个 Tab
  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    // 平滑无缝切换，保留各个 Tab 的滑动状态
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    if (index == 0) {
      CaretakerHomeScreen.requestApplicationsRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 这里的 body 就是根据路由自动切换的首页、接单、消息或我的页面
      body: navigationShell,
      bottomNavigationBar: Container(
        height: 96,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_outlined, label: '首页', isActive: navigationShell.currentIndex == 0, onTap: () => _onTap(0)),
              _buildNavItem(icon: Icons.pets_outlined, label: '接单', isActive: navigationShell.currentIndex == 1, onTap: () => _onTap(1)),
              _buildNavItem(icon: Icons.chat_bubble_outline, label: '消息', isActive: navigationShell.currentIndex == 2, onTap: () => _onTap(2)),
              _buildNavItem(icon: Icons.person_outline, label: '我的', isActive: navigationShell.currentIndex == 3, onTap: () => _onTap(3)),
            ],
          ),
        ),
      ),
    );
  }

  // 宠托师专属的底部按钮样式（带浅绿色圆形底）
  Widget _buildNavItem({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFE8F2EF) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isActive ? const Color(0xFF004D36) : const Color(0xFF5A6B62), size: 24),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: isActive ? const Color(0xFF004D36) : const Color(0xFF5A6B62), fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}