import 'dart:io';

class AppConfig {
  AppConfig._();

  /// 后端端口（本机 `mvnw spring-boot:run` 默认 8080）
  static const int backendPort = 8080;

  /// 本地开发服务器地址：
  ///   - Android 模拟器：10.0.2.2 映射到宿主机 localhost
  ///   - Windows / iOS 模拟器：直接使用 localhost
  ///   - 真机调试：改成电脑局域网 IP，例如 192.168.3.2
  static String get baseUrl {
    final host = Platform.isAndroid ? '192.168.3.2' : 'localhost';
    return 'http://$host:$backendPort';
  }

  static const Duration requestTimeout = Duration(seconds: 15);

  static Uri uri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }
}
