import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_page.dart' as login;
import 'chat_page.dart';
import 'pet_page.dart' as pet;
import 'medal_page.dart';
import 'logger_service.dart';
import 'experience_service.dart';
import 'experience_sync_service.dart';
import 'store_page.dart';
import 'test_food_data.dart';


// 為了處理 SSL 驗證問題 (相當於 Python 的 verify=False)
class _MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 【重要】在 App 啟動前，設定全域的 HTTP client 規則來忽略憑證錯誤
  HttpOverrides.global = _MyHttpOverrides();

  // 初始化 logger
  LoggerService.initialize();
  LoggerService.info('應用程序啟動');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  LoggerService.info('Firebase 初始化完成');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // 應用程序恢復時，記錄登入時間
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // 當應用程式進入背景或暫停狀態時，計算經驗值
        _handleAppBackground();
        break;
      default:
        break;
    }
  }

  Future<void> _handleAppResumed() async {
    try {
      // 檢查用戶是否已登入
      if (FirebaseAuth.instance.currentUser != null) {
        // 記錄登入時間
        await ExperienceService.recordLoginTime();

        // 初始化經驗值同步，顯示上次離線經驗值
        await ExperienceSyncService.initializeExperienceSync();

        LoggerService.info(
          'Login time recorded and experience sync initialized on app resumed',
        );
      }
    } catch (e) {
      LoggerService.error('Error handling app resumed: $e');
    }
  }

  Future<void> _handleAppBackground() async {
    try {
      // 檢查用戶是否已登入
      if (FirebaseAuth.instance.currentUser != null) {
        // 計算並添加基於登入時間的經驗值
        await ExperienceService.calculateAndAddLoginExperience();

        // 保存當前經驗值作為離線數據
        await ExperienceSyncService.saveOfflineExperience();

        LoggerService.info(
          'Experience calculated and offline data saved on app background',
        );
      }
    } catch (e) {
      LoggerService.error('Error handling app background: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '捷米小助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const login.LoginPage(),
        '/chat': (context) => const ChatPage(),
        '/pet': (context) => const pet.PetPage(initialPetName: '捷米'),
        '/medal': (context) => const MedalPage(),
        '/store': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? initialCategory;
          if (args is Map && args['category'] is String) {
            initialCategory = args['category'] as String?;
          }
          return StorePage(initialCategory: initialCategory);
        },
        '/test_food': (context) => const TestFoodDataPage(),
      },
    );
  }
}
