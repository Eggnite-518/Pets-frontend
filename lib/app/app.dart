import 'package:flutter/material.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/auth/auth_token_store.dart';

import 'routes.dart';

class PetsApp extends StatefulWidget {
  const PetsApp({super.key});

  @override
  State<PetsApp> createState() => _PetsAppState();
}

class _PetsAppState extends State<PetsApp> {
  @override
  void initState() {
    super.initState();
    ApiClient.onAuthError = () {
      // 清理本地 token 后再导航到登录页，避免路由重定向认为仍然已登录
      AuthTokenStore.instance.clearToken().then((_) {
        AppRoutes.router.go('/login');
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '宠托',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: AppRoutes.router,
    );
  }
}
