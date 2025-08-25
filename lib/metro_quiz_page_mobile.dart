import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MetroQuizPage extends StatefulWidget {
  const MetroQuizPage({super.key});
  @override
  State<MetroQuizPage> createState() => _MetroQuizPageState();
}

class _MetroQuizPageState extends State<MetroQuizPage> {
  WebViewController? _controller;

  String get _apiBase {
    if (Platform.isAndroid) return 'http://10.0.2.2:5000';
    return 'http://127.0.0.1:5000';
  }

  @override
  void initState() {
    super.initState();

    // 只在「非 Web」建立 WebView（Web 會有另一個檔案負責 iframe）
    if (!kIsWeb) {
      final controller = WebViewController();

      // 先賦值到欄位，讓後面 onPageFinished 的閉包可以安全引用
      _controller = controller;

      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      controller.setBackgroundColor(Colors.white);
      controller.setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (err) {
            debugPrint('WebView error: ${err.errorCode} ${err.description}');
          },
          onPageFinished: (_) async {
            // 用欄位而不是區域變數，避免「變數尚未完成宣告」的錯誤
            final js = "window.FLUTTER_API_BASE='$_apiBase';";
            await _controller?.runJavaScript(js);
          },
        ),
      );
      controller.loadFlutterAsset('assets/mrt_quiz/index.html');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // 這個檔案不會在 Web 被用到（條件匯出），保險再擋一次
      return const Scaffold(
        body: Center(child: Text('MetroQuizPage (mobile/desktop) only')),
      );
    }
    if (_controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('台北捷運知識王')),
      body: WebViewWidget(controller: _controller!),
    );
  }
}
