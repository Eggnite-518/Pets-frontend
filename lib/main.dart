import 'package:flutter/material.dart';

import 'core/auth/auth_token_store.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthTokenStore.instance = await SharedPreferencesAuthTokenStore.create();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const PetsApp();
  }
}
