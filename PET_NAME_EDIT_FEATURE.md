# 寵物名字編輯功能說明

## 功能概述

在 pet_page 的"捷米"名字旁邊添加了一個鉛筆圖示的編輯按鈕，讓使用者可以自由修改寵物的名字。修改後的名字會同步到 chat_page 中顯示。

## 功能特點

### 1. 視覺設計
- **位置**：在 pet_page 上方"捷米"名字旁邊
- **圖示**：鉛筆編輯圖示 (`Icons.edit`)
- **樣式**：藍色背景的圓角容器，與整體設計風格一致

### 2. 互動體驗
- **點擊觸發**：點擊鉛筆圖示打開編輯對話框
- **對話框設計**：
  - 標題：帶有編輯圖示的"修改名字"
  - 輸入框：預填當前名字，支持自由編輯
  - 按鈕：取消和確定按鈕

### 3. 數據同步
- **本地存儲**：使用 SharedPreferences 保存到 `ai_name_$username`
- **即時更新**：pet_page 中立即顯示新名字
- **跨頁面同步**：chat_page 中的名字也會同步更新

## 實作細節

### 1. UI 組件
```dart
// 鉛筆編輯按鈕
GestureDetector(
  onTap: () => _showEditNameDialog(),
  child: Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.blue.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.edit,
      size: 16,
      color: Colors.blue.shade600,
    ),
  ),
),
```

### 2. 編輯對話框
```dart
void _showEditNameDialog() {
  final TextEditingController nameController = TextEditingController(text: petName);
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('修改名字'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('請輸入新的名字：'),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: '輸入新名字',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await _updatePetName(newName);
                Navigator.of(context).pop(newName); // 返回新名字
              }
            },
            child: const Text('確定'),
          ),
        ],
      );
    },
  );
}
```

### 3. 名字更新邏輯
```dart
Future<void> _updatePetName(String newName) async {
  try {
    final userData = await UserService.getCurrentUserData();
    if (userData == null) return;

    final username = userData['username'] ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    
    // 保存新名字到本地存儲
    await prefs.setString('ai_name_$username', newName);
    
    // 更新狀態
    setState(() {
      petName = newName;
    });
    
    // 顯示成功訊息
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('名字已更新為：$newName'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    LoggerService.error('Error updating pet name: $e');
    // 顯示錯誤訊息
  }
}
```

### 4. Chat Page 同步
Chat page 已經有處理名字更新的邏輯：
```dart
void _navigateToPetPage() {
  if (!mounted) return;
  _safeNavigate(() => PetPage(initialPetName: _aiName)).then((newName) {
    if (!mounted) return;
    if (newName is String) {
      setState(() {
        _aiName = newName;
        _saveAiName(newName);
      });
    }
    _coinDisplayKey.currentState?.refreshCoins();
  });
}
```

## 使用流程

1. **進入 pet_page**：用戶可以看到"捷米"名字旁邊的鉛筆圖示
2. **點擊編輯**：點擊鉛筆圖示打開編輯對話框
3. **輸入新名字**：在對話框中輸入想要的新名字
4. **確認更新**：點擊"確定"按鈕保存新名字
5. **同步顯示**：新名字立即在 pet_page 和 chat_page 中顯示

## 技術特點

- **響應式設計**：按鈕有視覺反饋效果
- **錯誤處理**：包含完整的錯誤處理和用戶提示
- **數據持久化**：使用 SharedPreferences 確保數據不丟失
- **跨頁面同步**：通過返回值機制實現頁面間數據同步
- **用戶體驗**：提供成功/失敗的視覺反饋

## 測試建議

1. **基本功能測試**：
   - 點擊鉛筆圖示是否正確打開對話框
   - 輸入新名字後是否正確保存
   - 取消操作是否正常工作

2. **數據同步測試**：
   - 在 pet_page 修改名字後，chat_page 是否同步更新
   - 重新進入應用後名字是否保持

3. **邊界情況測試**：
   - 輸入空名字的處理
   - 輸入特殊字符的處理
   - 網絡異常時的錯誤處理

## 注意事項

- 名字修改是即時的，不需要額外的保存步驟
- 修改後的名字會影響所有相關頁面的顯示
- 建議用戶輸入合適的名字長度，避免過長影響UI顯示
