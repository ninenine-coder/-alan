# Pet Page 邏輯修正說明

## 問題描述

原本的 pet_page.dart 在顯示用戶已擁有商品時，使用了錯誤的邏輯：

1. **錯誤的狀態判斷**：使用商品的全局 `狀態` 欄位來判斷是否已擁有，這會導致所有用戶看到相同的"已擁有"狀態。

2. **與 store_page 邏輯不一致**：pet_page 和 store_page 使用了不同的邏輯來判斷商品擁有狀態，造成資料不一致。

## 修正內容

### 1. 修正 `_getOwnedItemsByCategory` 函數

**修正前**：
```dart
// 檢查商品的全局狀態欄位
final status = data['狀態'] ?? data['status'] ?? '購買';
if (status == '已擁有') {
  // 添加到已擁有列表
}
```

**修正後**：
```dart
// 從用戶文檔獲取已購買的商品列表
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .get();

final userDocData = userDoc.data() as Map<String, dynamic>;
final purchasedItemIds = List<String>.from(userDocData['purchasedItems'] ?? []);

// 檢查該商品是否在用戶的已購買列表中
if (purchasedItemIds.contains(doc.id)) {
  // 添加到已擁有列表
}
```

### 2. 修正 `_getAllItemsByCategory` 函數

**修正前**：
```dart
// 使用商品的全局狀態欄位
final status = data['狀態'] ?? data['status'] ?? '購買';
allItems.add({
  'status': status,
});
```

**修正後**：
```dart
// 檢查該商品是否在用戶的已購買列表中
final isOwned = purchasedItemIds.contains(doc.id);
allItems.add({
  'status': isOwned ? '已擁有' : '未擁有',
});
```

## 修正後的邏輯流程

1. **獲取用戶資料**：從 `UserService.getCurrentUserData()` 獲取當前用戶資料
2. **讀取已購買列表**：從用戶文檔的 `purchasedItems` 欄位讀取已購買的商品 ID 列表
3. **讀取商品資料**：從 Firebase 讀取指定類別的所有商品
4. **判斷擁有狀態**：檢查每個商品的 ID 是否在用戶的已購買列表中
5. **返回結果**：返回已擁有或所有商品（根據函數類型）

## 資料一致性

現在 pet_page 和 store_page 使用相同的邏輯：

- **store_page**：從用戶的 `purchasedItems` 欄位判斷商品是否已擁有
- **pet_page**：從用戶的 `purchasedItems` 欄位判斷商品是否已擁有

## 測試建議

1. **多用戶測試**：確保不同用戶在 pet_page 中看到不同的已擁有商品
2. **購買後測試**：在 store_page 購買商品後，確認在 pet_page 中也能看到該商品
3. **選擇功能測試**：確保只有已擁有的造型和頭像可以被選擇
4. **資料同步測試**：確保 pet_page 和 store_page 顯示的已擁有商品一致

## 注意事項

- 商品的 `狀態` 欄位不再被 pet_page 使用來判斷擁有狀態
- 每個用戶的已擁有商品完全獨立，基於各自的 `purchasedItems` 列表
- 本地設置（如選擇的造型、頭像）仍然使用 `username` 作為鍵值，這是合理的
- 使用 `uid` 確保 Firebase 查詢的唯一性和正確性

## 修正後的優勢

✅ **資料一致性**：pet_page 和 store_page 使用相同的邏輯
✅ **用戶獨立性**：每個用戶只看到自己已擁有的商品
✅ **即時同步**：購買商品後立即在 pet_page 中可見
✅ **邏輯清晰**：所有擁有狀態判斷都基於用戶文檔的 `purchasedItems` 欄位
