# Firebase 狀態整合總結

## 需求描述
1. **store_page**: 當 Firebase 的"狀態"欄位為"已擁有"時，按鈕會反灰且不可點選
2. **pet_page**: 當偵測到該帳號不同類別的"狀態"為"已擁有"時，會直接在各個類別視窗中顯示

## 修改內容

### 1. store_page.dart 修改

#### 新增狀態檢查邏輯
```dart
bool isItemUnavailable = false; // 新增：檢查商品是否不可用

// 檢查 Firebase 中商品的狀態欄位
isItemUnavailable = status == '已擁有';
```

#### 修改按鈕顯示邏輯
```dart
// 修改前
child: isPurchased ? Container(...) : Material(...)
onTap: isPurchased ? null : () => _showConfirmDialog(...)

// 修改後
child: (isPurchased || isItemUnavailable) ? Container(...) : Material(...)
onTap: (isPurchased || isItemUnavailable) ? null : () => _showConfirmDialog(...)
```

#### 修改已購買標籤顯示邏輯
```dart
// 修改前
if (isPurchased) Positioned(...)

// 修改後
if (isPurchased || isItemUnavailable) Positioned(...)
```

### 2. pet_page.dart 修改

#### 修改 _getAllItemsByCategory 方法
```dart
for (final doc in querySnapshot.docs) {
  final data = doc.data();
  // 檢查該商品是否在用戶的已購買列表中
  final isOwned = purchasedItemIds.contains(doc.id);
  // 檢查 Firebase 中商品的狀態欄位
  final firebaseStatus = data['狀態'] ?? data['status'] ?? '';
  final isFirebaseOwned = firebaseStatus == '已擁有';
  
  allItems.add({
    'id': doc.id,
    'name': data['name'] ?? '未命名商品',
    '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
    'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
    'category': category,
    'status': (isOwned || isFirebaseOwned) ? '已擁有' : '未擁有',
  });
}
```

#### 修改 _getOwnedItemsByCategory 方法
```dart
for (final doc in querySnapshot.docs) {
  final data = doc.data();
  // 檢查該商品是否在用戶的已購買列表中
  final isOwned = purchasedItemIds.contains(doc.id);
  // 檢查 Firebase 中商品的狀態欄位
  final firebaseStatus = data['狀態'] ?? data['status'] ?? '';
  final isFirebaseOwned = firebaseStatus == '已擁有';
  
  // 如果用戶已購買或 Firebase 狀態為已擁有，則顯示
  if (isOwned || isFirebaseOwned) {
    ownedItems.add({
      'id': doc.id,
      'name': data['name'] ?? '未命名商品',
      '圖片': data['圖片'] ?? data['imageUrl'] ?? '',
      'imageUrl': data['圖片'] ?? data['imageUrl'] ?? '',
      'category': category,
      'status': '已擁有', // 標記為已擁有
    });
  }
}
```

## 功能實現

### ✅ **store_page 功能**
- 當 Firebase 中商品的"狀態"欄位為"已擁有"時：
  - 按鈕會顯示為灰色且不可點選
  - 商品卡片上會顯示"已擁有"標籤
  - 用戶無法再次購買或領取該商品

### ✅ **pet_page 功能**
- 當 Firebase 中商品的"狀態"欄位為"已擁有"時：
  - 該商品會在各個類別視窗中顯示為"已擁有"
  - 用戶可以在寵物頁面中看到所有狀態為"已擁有"的商品
  - 支持所有類別：造型、特效、頭像、主題桌鋪、飼料

### ✅ **邏輯整合**
- 同時考慮用戶的購買記錄和 Firebase 中的狀態欄位
- 如果任一條件滿足（用戶已購買 OR Firebase 狀態為已擁有），則商品顯示為已擁有
- 確保數據一致性和用戶體驗的統一性

## 編譯檢查

### ✅ **編譯狀態**
- `flutter analyze` - 只有一個信息級別警告（不影響功能）
- `flutter analyze lib/store_page.dart lib/pet_page.dart` - 只有一個信息級別警告
- 沒有編譯錯誤

## 技術細節

### 狀態檢查邏輯
```dart
// 用戶購買狀態
final isOwned = purchasedItemIds.contains(doc.id);

// Firebase 狀態欄位
final firebaseStatus = data['狀態'] ?? data['status'] ?? '';
final isFirebaseOwned = firebaseStatus == '已擁有';

// 綜合判斷
final isItemAvailable = isOwned || isFirebaseOwned;
```

### 支持的狀態欄位名稱
- `狀態` (中文)
- `status` (英文)

## 總結
成功整合了 Firebase 中的"狀態"欄位到 store_page 和 pet_page 的邏輯中。現在系統會同時考慮用戶的購買記錄和 Firebase 中的狀態欄位，確保商品狀態的準確顯示和一致的用户體驗。
