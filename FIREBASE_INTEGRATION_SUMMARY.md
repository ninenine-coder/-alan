# Firebase 整合總結

## 修改概述
我們已經成功將登入和註冊功能整合到 Firebase，移除了本地管理系統，並使用 Firebase Authentication 和 Cloud Firestore 進行用戶管理。

## 已完成的修改

### 1. 管理系統移除
- **刪除的文件**:
  - `lib/admin_login_page.dart`
  - `lib/admin_store_management_page.dart`
  - `lib/admin_medal_management_page.dart`
  - `lib/admin_user_management_page.dart`

- **修改的文件**:
  - `lib/main.dart` - 移除了管理員登入按鈕和相關導入
  - `lib/data_service.dart` - 將管理相關的鍵值改為通用名稱

### 2. 登入頁面修改 (`lib/login_page.dart`)

#### 主要變更：
- 使用 `FirebaseAuth.instance.signInWithEmailAndPassword()` 進行登入
- 移除了對 `UserService.loginUser()` 的依賴
- 直接使用 Firebase Auth 的用戶憑證

#### 代碼示例：
```dart
try {
  // 使用 Firebase Auth 進行登入
  UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  // 登入成功！
  print('User logged in: ${userCredential.user!.uid}');
  
  // 檢查是否為首次登入
  final user = userCredential.user;
  if (user != null) {
    final creationTime = user.metadata.creationTime;
    final lastSignInTime = user.metadata.lastSignInTime;
    final isFirstLogin = creationTime == lastSignInTime;
    
    // 根據是否首次登入導向不同頁面
    if (isFirstLogin) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const WelcomePage()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ChatPage()));
    }
  }
} on FirebaseAuthException catch (e) {
  // 處理 Firebase Auth 異常
  String message = '登入失敗，請稍後再試';
  if (e.code == 'user-not-found' || e.code == 'wrong-password') {
    message = '帳號或密碼錯誤';
  } else if (e.code == 'invalid-email') {
    message = '電子郵件格式不正確';
  } else if (e.code == 'user-disabled') {
    message = '帳號已被停用';
  } else if (e.code == 'too-many-requests') {
    message = '登入嘗試次數過多，請稍後再試';
  }
  _showErrorDialog(message);
}
```

### 3. 註冊頁面修改 (`lib/register_page.dart`)

#### 主要變更：
- 使用 `FirebaseAuth.instance.createUserWithEmailAndPassword()` 創建用戶帳號
- 註冊成功後將用戶資料上傳到 Firestore
- 移除了對 `UserService.registerUser()` 的依賴

#### 新增導入：
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
```

#### 代碼示例：
```dart
try {
  // 使用 Firebase Auth 創建用戶帳號
  UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  // 註冊成功，將用戶資料上傳到 Firestore
  final user = userCredential.user;
  if (user != null) {
    // 準備用戶資料
    final userData = {
      'uid': user.uid,
      'email': email,
      'username': username,
      'phone': phone,
      'coins': 0,
      'loginCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'lastLoginAt': DateTime.now().toIso8601String(),
      'purchasedItems': [],
      'earnedMedals': [],
    };
    
    // 將資料上傳到 Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(userData);
    
    print('User registered successfully: ${user.uid}');
    
    // 顯示成功訊息並返回登入頁面
    Navigator.pop(context, true);
  }
} on FirebaseAuthException catch (e) {
  String message = '註冊失敗，請稍後再試';
  if (e.code == 'weak-password') {
    message = '密碼強度太弱，請使用更強的密碼';
  } else if (e.code == 'email-already-in-use') {
    message = '此電子郵件已被註冊，請使用其他電子郵件';
  } else if (e.code == 'invalid-email') {
    message = '電子郵件格式不正確';
  }
  _showDialog(message);
}
```

## Firestore 資料結構

### 用戶集合 (`users`)
```json
{
  "uid": "用戶唯一ID",
  "email": "用戶電子郵件",
  "username": "用戶名稱",
  "phone": "電話號碼",
  "coins": 0,
  "loginCount": 0,
  "createdAt": "創建時間",
  "lastLoginAt": "最後登入時間",
  "purchasedItems": [],
  "earnedMedals": []
}
```

## 錯誤處理

### 登入錯誤
- `user-not-found`: 找不到該電子郵件的用戶
- `wrong-password`: 密碼錯誤
- `invalid-email`: 電子郵件格式不正確
- `user-disabled`: 帳號已被停用
- `too-many-requests`: 登入嘗試次數過多

### 註冊錯誤
- `weak-password`: 密碼強度太弱
- `email-already-in-use`: 電子郵件已被註冊
- `invalid-email`: 電子郵件格式不正確

## 下一步建議

1. **更新其他服務**: 將 `UserService`、`CoinService` 等服務更新為使用 Firestore
2. **資料遷移**: 如果有現有用戶資料，需要遷移到 Firestore
3. **安全性規則**: 在 Firebase Console 中設置適當的 Firestore 安全規則
4. **離線支援**: 考慮啟用 Firestore 的離線支援功能
5. **錯誤監控**: 設置 Firebase Crashlytics 來監控應用錯誤

## 測試建議

1. 測試新用戶註冊流程
2. 測試現有用戶登入流程
3. 測試錯誤情況（錯誤密碼、已註冊郵箱等）
4. 驗證 Firestore 中的資料是否正確保存
5. 測試首次登入和後續登入的頁面導向

## 注意事項

- 確保 Firebase 專案已正確配置
- 檢查 `google-services.json` 和 `firebase_options.dart` 文件是否存在
- 確保所有必要的 Firebase 依賴都已添加到 `pubspec.yaml`
- 在 Firebase Console 中啟用 Email/Password 認證方式
