import 'package:pets/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// 在系统浏览器打开支付宝 page pay 页面（由后端托管 HTML 表单）
Future<bool> launchAlipayPagePayInBrowser(String outTradeNo) {
  final url = AppConfig.uri('/api/v1/payments/wallet/page-pay/$outTradeNo');
  return launchUrl(url, mode: LaunchMode.externalApplication);
}
