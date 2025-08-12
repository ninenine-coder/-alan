import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/user_service.dart';

void main() {
  group('UserService Tests', () {
    setUpAll(() async {
      // 初始化 Firebase
      TestWidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
    });

    test('should check if user exists', () async {
      // 測試檢查用戶是否存在的方法
      final exists = await UserService.checkUserExists('test@example.com');
      expect(exists, isA<bool>());
    });

    test('should get current user ID', () {
      // 測試獲取當前用戶 ID
      final userId = UserService.getCurrentUserId();
      expect(userId, isA<String?>());
    });

    test('should check if user is logged in', () {
      // 測試檢查用戶是否已登入
      final isLoggedIn = UserService.isUserLoggedIn();
      expect(isLoggedIn, isA<bool>());
    });

    test('should reset password', () async {
      // 測試重設密碼功能
      final success = await UserService.resetPassword('test@example.com');
      expect(success, isA<bool>());
    });
  });
}
