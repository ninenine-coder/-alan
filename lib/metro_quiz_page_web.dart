// 只有在 Web 會被編譯進來
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

class MetroQuizPage extends StatelessWidget {
  const MetroQuizPage({super.key});

  static bool _registered = false;

  static void _ensureRegistered(String viewType, String url) {
    if (_registered) return;
    _registered = true;
    ui.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final el = html.IFrameElement()
        ..src = url
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      return el;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Flutter Web 提供的資產是以 /assets/ 為根，再接你 pubspec 宣告的相對路徑
    // assets/mrt_quiz/index.html 會被服務在：/assets/assets/mrt_quiz/index.html
    const apiBase = 'http://127.0.0.1:5000'; // Web 版打後端，用不到 10.0.2.2
    final url = '/assets/assets/mrt_quiz/index.html'
        '?apiBase=${Uri.encodeComponent(apiBase)}';

    const viewType = 'mrt_quiz_iframe';
    _ensureRegistered(viewType, url);

    return Scaffold(
      appBar: AppBar(title: const Text('台北捷運知識王')),
      body: const SizedBox.expand(child: HtmlElementView(viewType: viewType)),
    );
  }
}
