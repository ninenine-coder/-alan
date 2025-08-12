# 帳號管理系統使用指南

## 概述

這個 Flutter 應用程式已經整合了完整的帳號管理系統，使用 Firebase Authentication 和 Cloud Firestore 來實現跨裝置的用戶登入和資料同步。

## 功能特色

### 🔐 用戶認證
- **註冊功能**: 用戶可以使用電子郵件和密碼註冊新帳號
- **登入功能**: 支援電子郵件/密碼登入
- **密碼重設**: 用戶可以透過電子郵件重設密碼
- **跨裝置登入**: 同一帳號可在不同裝置上登入

### 📊 用戶資料管理
- **個人資料**: 儲存用戶名、電子郵件、手機號碼等基本資訊
- **登入記錄**: 追蹤註冊時間、最後登入時間、登入次數
- **遊戲資料**: 金幣、購買物品、獲得的勳章等遊戲相關資料
- **設備管理**: 支援多設備登入，可管理設備令牌

### 🛡️ 安全性
- **密碼驗證**: 密碼長度至少6個字元
- **電子郵件驗證**: 使用正則表達式驗證電子郵件格式
- **重複註冊檢查**: 防止同一電子郵件重複註冊
- **錯誤處理**: 完整的錯誤處理和用戶友好的錯誤訊息

## 技術架構

### 後端服務
- **Firebase Authentication**: 處理用戶認證
- **Cloud Firestore**: 儲存用戶資料和遊戲資料
- **SharedPreferences**: 本地資料快取

### 主要檔案
- `lib/user_service.dart`: 核心用戶服務類別
- `lib/login_page.dart`: 登入頁面
- `lib/register_page.dart`: 註冊頁面
- `lib/main.dart`: 應用程式入口點

## 使用方法

### 1. 用戶註冊
```dart
// 使用 UserService 註冊新用戶
final success = await UserService.registerUser(
  email: 'user@example.com',
  password: 'password123',
  username: 'username',
  phone: '0912345678',
);
```

### 2. 用戶登入
```dart
// 使用 UserService 登入
final userData = await UserService.loginUser(
  email: 'user@example.com',
  password: 'password123',
);
```

### 3. 檢查登入狀態
```dart
// 檢查用戶是否已登入
final isLoggedIn = UserService.isUserLoggedIn();

// 獲取當前用戶 ID
final userId = UserService.getCurrentUserId();
```

### 4. 獲取用戶資料
```dart
// 獲取當前用戶的完整資料
final userData = await UserService.getCurrentUserData();
```

### 5. 更新用戶資料
```dart
// 更新用戶資料
final success = await UserService.updateUserData({
  'username': 'newUsername',
  'phone': '0987654321',
});
```

### 6. 重設密碼
```dart
// 發送重設密碼郵件
final success = await UserService.resetPassword('user@example.com');
```

### 7. 用戶登出
```dart
// 登出用戶
await UserService.logoutUser();
```

### 8. 刪除帳號
```dart
// 刪除用戶帳號（需要重新登入）
final success = await UserService.deleteUserAccount();
```

## 資料結構

### 用戶資料模型
```dart
{
  'uid': '用戶唯一識別碼',
  'email': '電子郵件',
  'username': '用戶名',
  'phone': '手機號碼',
  'registrationDate': '註冊時間',
  'lastLoginDate': '最後登入時間',
  'loginCount': '登入次數',
  'coins': '金幣數量',
  'purchasedItems': ['購買的物品列表'],
  'earnedMedals': ['獲得的勳章列表'],
  'isActive': '帳號是否啟用',
  'profileImageUrl': '個人照片URL',
  'deviceTokens': ['設備令牌列表'],
}
```

## 錯誤處理

### 常見錯誤代碼
- `user-not-found`: 用戶不存在
- `wrong-password`: 密碼錯誤
- `invalid-email`: 電子郵件格式不正確
- `user-disabled`: 帳號已被停用
- `too-many-requests`: 登入嘗試次數過多
- `email-already-in-use`: 電子郵件已被使用

### 錯誤處理範例
```dart
try {
  final userData = await UserService.loginUser(
    email: email,
    password: password,
  );
} on FirebaseAuthException catch (e) {
  String message = '登入失敗，請稍後再試';
  if (e.code == 'user-not-found' || e.code == 'wrong-password') {
    message = '帳號或密碼錯誤';
  } else if (e.code == 'invalid-email') {
    message = '電子郵件格式不正確';
  }
  // 顯示錯誤訊息
}
```

## 安全性建議

### 密碼安全
- 密碼長度至少6個字元
- 建議使用包含大小寫字母、數字和特殊字元的強密碼
- 定期更換密碼

### 帳號安全
- 不要與他人分享登入資訊
- 在公共設備上使用後記得登出
- 定期檢查登入記錄

### 資料保護
- 用戶資料使用 Firebase 的安全規則保護
- 本地資料使用 SharedPreferences 加密儲存
- 敏感資訊不會在日誌中顯示

## 部署注意事項

### Firebase 配置
1. 確保 `google-services.json` 檔案已正確配置
2. 在 Firebase Console 中啟用 Authentication 和 Firestore
3. 設定適當的 Firestore 安全規則

### 環境變數
- 確保 Firebase 專案 ID 正確
- 檢查 API 金鑰是否有效
- 確認網域白名單設定

## 測試

### 單元測試
```bash
flutter test test/user_service_test.dart
```

### 整合測試
```bash
flutter test integration_test/
```

## 故障排除

### 常見問題
1. **Firebase 初始化失敗**: 檢查 `google-services.json` 檔案
2. **網路連線問題**: 確認網路連線和 Firebase 專案設定
3. **權限錯誤**: 檢查 Firestore 安全規則
4. **版本相容性**: 確保所有 Firebase 套件版本相容

### 除錯技巧
- 使用 `print` 或 `debugPrint` 輸出除錯資訊
- 檢查 Firebase Console 的日誌
- 使用 Flutter Inspector 檢查 UI 問題

## 更新日誌

### v1.0.0
- 初始版本發布
- 基本註冊和登入功能
- Firebase Authentication 整合
- Cloud Firestore 資料儲存
- 跨裝置登入支援

## 支援

如有任何問題或建議，請聯繫開發團隊或查看 Firebase 官方文檔。
