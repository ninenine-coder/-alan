# Chat Page 和 Pet Page 修正說明

## 修正內容

### 1. Chat Page 返回按鈕修正

**問題描述**：
- chat_page 左上角的返回按鈕需要跳轉回 login_page
- 這是正確的導航邏輯，用戶點擊返回應該回到登入頁面

**修正內容**：
- **修正前**：`Navigator.of(context).pop()`
- **修正後**：`Navigator.of(context).pushReplacementNamed('/login')`

**修正位置**：
```dart
// lib/chat_page.dart 第 1417 行附近
leading: IconButton(
  icon: const Icon(Icons.arrow_back),
     onPressed: () {
     // 跳轉回登入頁面
     Navigator.of(context).pushReplacementNamed('/login');
   },
),
```

### 2. 頭像顯示邏輯修正

**問題描述**：
- chat_page 和 pet_page 的捷米頭像，當"造型"為空時，顯示的是"經典捷米"圖片
- 根據需求，應該顯示"造型1"圖片

**修正內容**：
- **修正前**：顯示"經典捷米"圖片作為預設
- **修正後**：顯示"造型1"圖片作為預設

**修正位置**：

#### Chat Page (`lib/chat_page.dart`)
```dart
/// 獲取選擇的造型圖片
Future<String?> _getSelectedStyleImage() async {
  try {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return null;

    final username = userData['username'] ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    final selectedImage = prefs.getString('selected_style_image_$username');
    
    // 如果沒有選擇的造型，返回造型1的圖片
    if (selectedImage == null || selectedImage.isEmpty) {
      return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 造型1圖片
    }
    
    return selectedImage;
  } catch (e) {
    LoggerService.error('Error getting selected style image: $e');
    return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 造型1圖片作為預設
  }
}
```

#### Pet Page (`lib/pet_page.dart`)
```dart
/// 獲取選擇的造型圖片
Future<String?> _getSelectedStyleImage() async {
  try {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return null;

    final username = userData['username'] ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    final selectedStyleImage = prefs.getString('selected_style_image_$username');
    
    if (selectedStyleImage != null && selectedStyleImage.isNotEmpty) {
      return selectedStyleImage;
    } else {
      return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 造型1圖片作為預設
    }
  } catch (e) {
    LoggerService.error('Error getting selected style image: $e');
    return 'https://i.postimg.cc/vmzwkwzg/image.jpg'; // 造型1圖片作為預設
  }
}
```

## 修正後的邏輯流程

### 1. 返回按鈕邏輯
1. **用戶點擊返回按鈕** → 觸發 `Navigator.of(context).pushReplacementNamed('/login')`
2. **跳轉到登入頁面** → 正確的導航邏輯，用戶返回登入頁面

### 2. 頭像顯示邏輯
1. **檢查用戶是否選擇了造型** → 讀取 `selected_style_image_$username`
2. **如果有選擇造型** → 顯示用戶選擇的造型圖片
3. **如果沒有選擇造型** → 顯示"造型1"圖片 (`https://i.postimg.cc/vmzwkwzg/image.jpg`)

## 測試建議

### 1. 返回按鈕測試
- 從不同頁面進入 chat_page，測試返回按鈕是否正確跳轉到登入頁面
- 確認導航邏輯符合預期

### 2. 頭像顯示測試
- 測試新用戶（沒有選擇造型）是否顯示"造型1"圖片
- 測試已選擇造型的用戶是否顯示正確的造型圖片
- 測試在 chat_page 和 pet_page 中頭像顯示是否一致

## 注意事項

- 返回按鈕現在使用 `Navigator.pushReplacementNamed('/login')` 跳轉到登入頁面
- 頭像預設圖片統一使用"造型1"圖片
- 兩個頁面的頭像顯示邏輯保持一致
- 圖片 URL 保持不變，只是註釋說明更新為"造型1"
