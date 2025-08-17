import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'chat_page.dart';
import 'pet_page.dart';
import 'logger_service.dart';
import 'experience_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 logger
  LoggerService.initialize();
  LoggerService.info('應用程序啟動');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        LoggerService.info('Login time recorded on app resumed');
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
        LoggerService.info('Experience calculated on app background');
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
      initialRoute: '/',
      routes: {
        '/': (context) => const MainSelectionPage(),
        '/chat': (context) => const ChatPage(),
        '/pet': (context) => const PetPage(initialPetName: '捷米'),
      },
    );
  }
}

class MainSelectionPage extends StatelessWidget {
  const MainSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.psychology,
                  size: 120,
                  color: Colors.white,
                ),
                const SizedBox(height: 32),
                const Text(
                  '捷米小助手',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 64),
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      '用戶登入',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),


              ],
            ),
          ),
        ),
      ),
    );
  }
}
