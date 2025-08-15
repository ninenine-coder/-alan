import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'logger_service.dart';
import 'dart:convert';

class MetroQuizPage extends StatefulWidget {
  final String? htmlString;
  
  const MetroQuizPage({
    super.key,
    this.htmlString,
  });

  @override
  State<MetroQuizPage> createState() => _MetroQuizPageState();
}

class _MetroQuizPageState extends State<MetroQuizPage> {
  bool _isLoading = true;

  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createWebViewController();
    
    // 載入原始的 HTML 文件
    if (widget.htmlString != null && widget.htmlString!.isNotEmpty) {
      LoggerService.info('使用預載入的 HTML 字串');
      _controller.loadRequest(
        Uri.dataFromString(
          widget.htmlString!,
          mimeType: 'text/html',
          encoding: const Utf8Codec(),
        ),
      );
    } else {
      LoggerService.info('載入資產 HTML 文件');
      _controller.loadFlutterAsset('assets/捷運知識王/index.html');
    }
  }

  WebViewController _createWebViewController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            LoggerService.info('WebView loading progress: $progress%');
          },
          onPageStarted: (String url) {
            LoggerService.info('WebView page started: $url');
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            LoggerService.info('WebView page finished: $url');
            setState(() {
              _isLoading = false;
            });
            // 注入修復 JavaScript 代碼
            _injectTouchFix();
          },
          onWebResourceError: (WebResourceError error) {
            LoggerService.error('WebView error: ${error.description}');
          },
        ),
      );
  }

  void _injectTouchFix() {
    const String jsCode = '''
      // 修復觸摸事件和 API 調用
      console.log('Starting touch fix and API mock injection...');
      
      // 修復所有按鈕的觸摸事件
      function fixButtonTouchEvents() {
        console.log('Fixing button touch events...');
        const buttons = document.querySelectorAll('button');
        console.log('Found', buttons.length, 'buttons');
        
        buttons.forEach(function(button, index) {
          console.log('Processing button', index, ':', button.textContent || button.id);
          
          // 移除舊的事件監聽器
          if (button._touchHandler) {
            button.removeEventListener('touchstart', button._touchHandler);
          }
          if (button._clickHandler) {
            button.removeEventListener('click', button._clickHandler);
          }
          
                     // 添加新的事件處理器
           button._touchHandler = function(e) {
             console.log('Touch event on button:', button.textContent || button.id);
             button.click();
           };
          
          button._clickHandler = function(e) {
            console.log('Click event on button:', button.textContent || button.id);
          };
          
          // 綁定事件
          button.addEventListener('touchstart', button._touchHandler, { passive: false });
          button.addEventListener('click', button._clickHandler);
          
          // 確保按鈕可點擊
          button.style.pointerEvents = 'auto';
          button.style.cursor = 'pointer';
        });
      }
      
      // 修復 API 調用
      window.originalFetch = window.fetch;
      window.fetch = function(url, options) {
        console.log('Fetch called with:', url, options);
        
        // 如果是 API 調用，返回模擬數據
        if (url.includes('/api/')) {
          console.log('Intercepting API call:', url);
          
          if (url.includes('/api/start_game')) {
            console.log('Returning mock start_game data');
            return Promise.resolve({
              ok: true,
              json: () => Promise.resolve({
                total_questions: 5,
                question: {
                  id: 1,
                  text: '台北捷運第一條通車的路線是？',
                  options: [
                    { id: 'A', text: '淡水信義線' },
                    { id: 'B', text: '板南線' },
                    { id: 'C', text: '文湖線' },
                    { id: 'D', text: '中和新蘆線' }
                  ],
                  correct_answer: 'C',
                  explanation: '文湖線（原木柵線）是台北捷運第一條通車的路線，於1996年3月28日通車。'
                }
              })
            });
          }
          
          if (url.includes('/api/submit_answer')) {
            console.log('Returning mock submit_answer data');
            return Promise.resolve({
              ok: true,
              json: () => Promise.resolve({
                correct: Math.random() > 0.3, // 70% 正確率
                correct_answer: 'C',
                explanation: '這是正確答案的解釋。',
                next_question: {
                  id: 2,
                  text: '台北捷運目前有幾條路線？',
                  options: [
                    { id: 'A', text: '4條' },
                    { id: 'B', text: '5條' },
                    { id: 'C', text: '6條' },
                    { id: 'D', text: '7條' }
                  ],
                  correct_answer: 'C',
                  explanation: '台北捷運目前有6條路線：淡水信義線、板南線、文湖線、中和新蘆線、松山新店線、環狀線。'
                }
              })
            });
          }
        }
        
        // 其他請求使用原始 fetch
        return window.originalFetch(url, options);
      };
      
      // 等待 DOM 載入完成後執行修復
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
          console.log('DOM loaded, applying fixes...');
          fixButtonTouchEvents();
          
          // 監聽 DOM 變化，修復動態添加的按鈕
          const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.type === 'childList') {
                console.log('DOM changed, re-applying button fixes...');
                setTimeout(fixButtonTouchEvents, 100);
              }
            });
          });
          
          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
        });
      } else {
        console.log('DOM already loaded, applying fixes immediately...');
        fixButtonTouchEvents();
        
        // 監聽 DOM 變化，修復動態添加的按鈕
        const observer = new MutationObserver(function(mutations) {
          mutations.forEach(function(mutation) {
            if (mutation.type === 'childList') {
              console.log('DOM changed, re-applying button fixes...');
              setTimeout(fixButtonTouchEvents, 100);
            }
          });
        });
        
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
      }
      
      console.log('Touch fix and API mock injection completed');
    ''';
    
    _controller.runJavaScript(jsCode).then((_) {
      LoggerService.info('Touch fix and API mock injected successfully');
    }).catchError((error) {
      LoggerService.error('Failed to inject touch fix: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '捷運知識王',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
            tooltip: '重新載入',
          ),
        ],
      ),
      body: Stack(
        children: [
                     // 使用 WebViewWidget 和 WebViewController
           WebViewWidget(
             controller: _controller,
           ),
                     if (_isLoading)
             IgnorePointer(
               ignoring: true, // 讓點擊穿透到 WebView
               child: Container(
                 color: Colors.white.withValues(alpha: 0.7), // 半透明
                 child: const Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       CircularProgressIndicator(),
                       SizedBox(height: 16),
                       Text(
                         '載入捷運知識王遊戲中...',
                         style: TextStyle(
                           fontSize: 16,
                           color: Colors.grey,
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
        ],
      ),
    );
  }


}
