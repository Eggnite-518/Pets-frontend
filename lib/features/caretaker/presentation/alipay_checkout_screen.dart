import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 展示支付宝 page pay 返回的 HTML 表单
class AlipayCheckoutScreen extends StatefulWidget {
  const AlipayCheckoutScreen({
    super.key,
    required this.payFormHtml,
    this.title = '支付宝支付',
  });

  final String payFormHtml;
  final String title;

  @override
  State<AlipayCheckoutScreen> createState() => _AlipayCheckoutScreenState();
}

class _AlipayCheckoutScreenState extends State<AlipayCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  static const _alipayGateway = 'https://openapi.alipaydev.com';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();
            if (url.contains('pay-return') ||
                url.contains('return_url') ||
                url.contains('success')) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(widget.payFormHtml, baseUrl: _alipayGateway);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF004D36),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('关闭', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF004D36)),
            ),
        ],
      ),
    );
  }
}
