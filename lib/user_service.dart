import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data_service.dart';
import 'experience_service.dart';
import 'experience_sync_service.dart';

class UserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 用戶資料模型
  static const String _usersCollection = 'users';
  static const String _userDataKey = 'user_data';

  // 註冊新用戶
  static Future<bool> registerUser({
    required String email,
    required String password,
    required String username,
    required String phone,
  }) async {
    try {
      // 1. 使用 Firebase Auth 創建帳號
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return false;

      // 2. 在 Firestore 中創建用戶資料
      final userData = {
        'uid': user.uid,
        'email': email,
        'username': username,
        'phone': phone,
        'registrationDate': FieldValue.serverTimestamp(),
        'lastLoginDate': FieldValue.serverTimestamp(),
        'loginCount': 1,
        'coins': 100,
        'purchasedItems': [],
        'earnedMedals': [],
        'isActive': true,
        'profileImageUrl': null,
        'deviceTokens': [], // 用於推送通知
      };

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(userData);

      // 3. 儲存到本地 SharedPreferences
      await _saveUserDataLocally(userData);

      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // 登入用戶（使用電子郵件）
  static Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Firebase Auth 登入
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // 2. 從 Firestore 獲取用戶資料
      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // 如果 Firestore 中沒有資料，創建基本資料
        final basicUserData = {
          'uid': user.uid,
          'email': user.email,
          'username': user.email?.split('@')[0] ?? 'User',
          'phone': '',
          'registrationDate': FieldValue.serverTimestamp(),
          'lastLoginDate': FieldValue.serverTimestamp(),
          'loginCount': 1,
          'coins': 100,
          'purchasedItems': [],
          'earnedMedals': [],
          'isActive': true,
          'profileImageUrl': null,
          'deviceTokens': [],
        };

        await _firestore
            .collection(_usersCollection)
            .doc(user.uid)
            .set(basicUserData);

        await _saveUserDataLocally(basicUserData);
        
        // 記錄登入時間
        await ExperienceService.recordLoginTime();
        
        // 初始化經驗值同步
        await ExperienceSyncService.initializeExperienceSync();
        
        return basicUserData;
      }

      // 3. 更新登入資訊
      final userData = userDoc.data()!;
      final updatedData = {
        ...userData,
        'lastLoginDate': FieldValue.serverTimestamp(),
        'loginCount': (userData['loginCount'] ?? 0) + 1,
      };

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(updatedData);

      // 4. 儲存到本地
      await _saveUserDataLocally(updatedData);

      // 5. 記錄登入時間
      await ExperienceService.recordLoginTime();
      
      // 6. 初始化經驗值同步
      await ExperienceSyncService.initializeExperienceSync();

      return updatedData;
    } on FirebaseAuthException {
      return null;
    } catch (_) {
      return null;
    }
  }

  // 登入用戶（使用用戶名）
  static Future<Map<String, dynamic>?> loginUserWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      // 1. 根據用戶名查找用戶的電子郵件
      final userQuery = await _firestore
          .collection(_usersCollection)
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return null; // 用戶名不存在
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final email = userData['email'] as String?;

      if (email == null) {
        return null; // 沒有找到電子郵件
      }

      // 2. 使用電子郵件進行 Firebase Auth 登入
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // 3. 更新登入資訊
      final updatedData = {
        ...userData,
        'lastLoginDate': FieldValue.serverTimestamp(),
        'loginCount': (userData['loginCount'] ?? 0) + 1,
      };

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(updatedData);

      // 4. 儲存到本地
      await _saveUserDataLocally(updatedData);

      // 5. 記錄登入時間
      await ExperienceService.recordLoginTime();
      
      // 6. 初始化經驗值同步
      await ExperienceSyncService.initializeExperienceSync();

      return updatedData;
    } on FirebaseAuthException {
      return null;
    } catch (_) {
      return null;
    }
  }

  // 登出用戶
  static Future<void> logoutUser() async {
    try {
      // 計算並添加基於登入時間的經驗值
      await ExperienceService.calculateAndAddLoginExperience();
      
      // 保存當前經驗值作為離線數據
      await ExperienceSyncService.saveOfflineExperience();
      
      // 同步所有數據到 Firestore
      await DataService.syncAllDataToFirestore();
      
      await _auth.signOut();
      await _clearUserDataLocally();
    } catch (_) {
      // Logout error occurred
    }
  }

  // 獲取當前用戶資料
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 更新用戶資料
  static Future<bool> updateUserData(Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(updates);

      // 更新本地資料
      final currentData = await getCurrentUserData();
      if (currentData != null) {
        final updatedData = {...currentData, ...updates};
        await _saveUserDataLocally(updatedData);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // 檢查用戶是否已登入
  static bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  // 獲取當前用戶 UID
  static String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // 檢查用戶是否存在
  static Future<bool> checkUserExists(String email) async {
    try {
      // 使用 Firestore 查詢來檢查用戶是否存在
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // 重設密碼
  static Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // 刪除用戶帳號
  static Future<bool> deleteUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 刪除 Firestore 資料
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .delete();

      // 刪除 Firebase Auth 帳號
      await user.delete();

      // 清除本地資料
      await _clearUserDataLocally();

      return true;
    } catch (_) {
      return false;
    }
  }

  // 檢查是否為首次登入
  static Future<bool> isFirstLogin() async {
    try {
      final userData = await getCurrentUserData();
      if (userData == null) return true;
      
      final loginCount = userData['loginCount'] ?? 0;
      return loginCount <= 1;
    } catch (e) {
      return true;
    }
  }

  // 初始化用戶資料（用於首次登入）
  static Future<void> initializeUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // 創建初始用戶資料
        final initialUserData = {
          'uid': user.uid,
          'email': user.email,
          'username': user.email?.split('@')[0] ?? 'User',
          'phone': '',
          'registrationDate': FieldValue.serverTimestamp(),
          'lastLoginDate': FieldValue.serverTimestamp(),
          'loginCount': 1,
          'coins': 100, // 初始金幣
          'purchasedItems': [],
          'earnedMedals': [],
          'isActive': true,
          'profileImageUrl': null,
          'deviceTokens': [],
          'experience': 0, // 初始經驗值
          'level': 1, // 初始等級
          'unlockedFeatures': ['login_reward', 'store'], // 初始解鎖功能
        };

        await _firestore
            .collection(_usersCollection)
            .doc(user.uid)
            .set(initialUserData);

        await _saveUserDataLocally(initialUserData);
      }
    } catch (e) {
      // 處理初始化錯誤
    }
  }

  // 獲取用戶統計資料
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
      final userData = await getCurrentUserData();
      if (userData == null) return {};

      return {
        'totalCoins': userData['coins'] ?? 0,
        'totalPurchases': (userData['purchasedItems'] as List<dynamic>?)?.length ?? 0,
        'totalMedals': (userData['earnedMedals'] as List<dynamic>?)?.length ?? 0,
        'loginCount': userData['loginCount'] ?? 0,
        'level': userData['level'] ?? 1,
        'experience': userData['experience'] ?? 0,
        'registrationDate': userData['registrationDate'],
        'lastLoginDate': userData['lastLoginDate'],
      };
    } catch (e) {
      return {};
    }
  }

  // 本地儲存用戶資料
  static Future<void> _saveUserDataLocally(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 將 Map 轉換為 JSON 字串進行儲存
      final userDataJson = userData.map((key, value) {
        if (value is DateTime) {
          return MapEntry(key, value.toIso8601String());
        }
        return MapEntry(key, value);
      });
      final userDataString = userDataJson.toString();
      await prefs.setString(_userDataKey, userDataString);
    } catch (_) {
      // Error saving local user data
    }
  }

  // 清除本地用戶資料
  static Future<void> _clearUserDataLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
    } catch (_) {
      // Error clearing local user data
    }
  }

  // 從本地獲取用戶資料
  static Future<Map<String, dynamic>?> getLocalUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);
      if (userDataString != null) {
        // 這裡需要實作字串到 Map 的轉換
        // 為了簡化，我們直接從 Firestore 獲取
        return await getCurrentUserData();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 添加設備令牌（用於推送通知）
  static Future<bool> addDeviceToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update({
        'deviceTokens': FieldValue.arrayUnion([token]),
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  // 移除設備令牌
  static Future<bool> removeDeviceToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update({
        'deviceTokens': FieldValue.arrayRemove([token]),
      });

      return true;
    } catch (_) {
      return false;
    }
  }
} 