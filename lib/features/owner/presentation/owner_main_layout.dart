import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 宠主端主框架（带有固定的底部导航栏）
class OwnerMainLayout extends StatelessWidget {
  const OwnerMainLayout({super.key, required this.navigationShell});

  // 这是 go_router 传进来的“子路由壳”，用来控制当前显示哪个 Tab
  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    // goBranch 是平滑切换的核心，没有多余的 push 动画
    navigationShell.goBranch(
      index,
      // 如果点击的是当前已经选中的 Tab，强制刷新回到初始状态
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 这里的 body 就是根据路由自动切换的首页、订单、消息或我的页面
      body: navigationShell,
      bottomNavigationBar: Container(
        height: 96,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomItem(
                icon: Icons.home_outlined,
                label: '首页',
                active: navigationShell.currentIndex == 0,
                onTap: () => _onTap(0),
              ),
              _BottomItem(
                icon: Icons.description_outlined,
                label: '订单',
                active: navigationShell.currentIndex == 1,
                onTap: () => _onTap(1),
              ),
              _BottomItem(
                icon: Icons.forum_outlined,
                label: '消息',
                active: navigationShell.currentIndex == 2,
                onTap: () => _onTap(2),
              ),
              _BottomItem(
                icon: Icons.person_outline,
                label: '我的',
                active: navigationShell.currentIndex == 3,
                onTap: () => _onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部导航栏 Item 通用样式
class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 66,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: active
                      ? const Color(0xFF005E47)
                      : const Color(0xFF5C6661),
                  size: 27,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? const Color(0xFF005E47)
                        : const Color(0xFF5C6661),
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
