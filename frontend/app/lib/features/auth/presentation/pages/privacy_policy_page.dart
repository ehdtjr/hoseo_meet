import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../config.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => debugPrint('📄 페이지 시작: $url'),
          onPageFinished: (url) => debugPrint('✅ 로딩 완료: $url'),
          onWebResourceError: (error) =>
              debugPrint('❌ 오류 발생: ${error.description}'),
        ),
      )
      ..loadRequest(Uri.parse('${AppConfig.baseUrl}/info/privacy-policy')); // ← 실제 URL
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보처리방침'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
