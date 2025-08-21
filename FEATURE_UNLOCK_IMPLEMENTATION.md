# 功能解鎖系統實現方案

## 需求概述

1. **登入時決定按鈕鎖定狀態**：在用戶登入時就決定選單中的按鈕是否有被 lock，而不是在點選選單後才判斷
2. **等級自動解鎖**：
   - 6等時自動解除"桌寵"的 lock，且永遠呈現解鎖狀態
   - 11等時自動解除"挑戰任務"和"勳章"的 lock，且永遠呈現解鎖狀態

## 已創建的服務

### FeatureUnlockService (lib/feature_unlock_service.dart)

這個服務負責管理所有功能的解鎖狀態：

#### 主要功能
1. **初始化功能解鎖狀態** (`initializeFeatureUnlockStatus`)
   - 在用戶登入時調用
   - 從 Firebase 獲取用戶等級
   - 計算每個功能的解鎖狀態
   - 保存到本地存儲

2. **獲取解鎖狀態** (`getUnlockStatus`)
   - 從本地存儲讀取解鎖狀態
   - 如果沒有數據則重新初始化

3. **升級時更新狀態** (`updateUnlockStatusOnLevelUp`)
   - 當用戶升級時自動調用
   - 檢查是否有新解鎖的功能
   - 更新本地存儲

#### 功能等級要求
```dart
static const Map<String, int> _featureRequirements = {
  '桌寵': 6,
  '挑戰任務': 11,
  '勳章': 11,
  '商城': 0, // 商城不需要等級限制
  '捷運知識王': 0, // 登入就可以玩
};
```

## 需要修改的文件

### 1. chat_page.dart

#### 需要添加的變數
```dart
// 功能解鎖狀態
Map<String, bool> _featureUnlockStatus = {};
```

#### 需要修改的方法

1. **`_loadUserData` 方法**
   ```dart
   // 在載入用戶資料後添加
   await _initializeFeatureUnlockStatus();
   ```

2. **`_initializeFeatureUnlockStatus` 方法**（新增）
   ```dart
   Future<void> _initializeFeatureUnlockStatus() async {
     try {
       final unlockStatus = await FeatureUnlockService.initializeFeatureUnlockStatus();
       setState(() {
         _featureUnlockStatus = unlockStatus;
       });
       LoggerService.info('功能解鎖狀態初始化完成: $_featureUnlockStatus');
     } catch (e) {
       LoggerService.error('初始化功能解鎖狀態時發生錯誤: $e');
     }
   }
   ```

3. **`_buildMenuItem` 方法**
   ```dart
   Widget _buildMenuItem(IconData icon, String label, Color color) {
     // 使用預先載入的功能解鎖狀態
     final isUnlocked = _featureUnlockStatus[label] ?? false;
     final requiredLevel = FeatureUnlockService.getRequiredLevel(label);
     
     LoggerService.debug('功能檢查: $label, 已解鎖: $isUnlocked, 需要等級: $requiredLevel');
     
     return GestureDetector(
       onTap: () {
         LoggerService.info('點擊菜單項: $label');
         _handleMenuItemTap(label, requiredLevel, isUnlocked);
       },
       // ... 其餘 UI 代碼保持不變
     );
   }
   ```

4. **`_onLevelUp` 方法**
   ```dart
   void _onLevelUp(int newLevel) async {
     if (mounted) {
       LoggerService.info('聊天頁面收到升級事件: 等級 $newLevel');
       LevelUpAnimationManager.instance.showLevelUpAnimation(context, newLevel);
       
       // 更新功能解鎖狀態
       await FeatureUnlockService.updateUnlockStatusOnLevelUp(newLevel);
       
       // 重新載入功能解鎖狀態
       final newUnlockStatus = await FeatureUnlockService.getUnlockStatus();
       setState(() {
         _featureUnlockStatus = newUnlockStatus;
       });
       
       LoggerService.info('功能解鎖狀態已更新: $_featureUnlockStatus');
     }
   }
   ```

#### 需要移除的方法
- `_isFeatureUnlocked` 方法（不再需要）
- `_getRequiredLevel` 方法（使用 FeatureUnlockService.getRequiredLevel）

## 實現優勢

### 1. 性能優化
- **一次性判斷**：登入時就決定所有按鈕狀態，避免每次點擊都檢查
- **本地存儲**：解鎖狀態保存在本地，讀取速度快
- **減少網絡請求**：不需要每次點擊都查詢 Firebase

### 2. 用戶體驗
- **即時反饋**：按鈕狀態立即可見，無需等待
- **自動解鎖**：升級時自動更新狀態，無需手動刷新
- **視覺一致性**：鎖定/解鎖狀態在整個會話中保持一致

### 3. 數據一致性
- **集中管理**：所有解鎖邏輯集中在 FeatureUnlockService
- **狀態同步**：本地存儲與 Firebase 數據保持同步
- **錯誤處理**：完整的錯誤處理和回退機制

## 測試建議

### 1. 基本功能測試
- 新用戶登入時按鈕狀態正確
- 不同等級用戶看到正確的按鈕狀態
- 升級時按鈕狀態自動更新

### 2. 邊界情況測試
- 網絡異常時的處理
- 本地存儲損壞時的處理
- 用戶數據為空時的處理

### 3. 性能測試
- 登入速度不受影響
- 按鈕點擊響應速度
- 升級時狀態更新速度

## 注意事項

1. **數據遷移**：現有用戶需要重新初始化解鎖狀態
2. **版本兼容**：確保新舊版本的功能解鎖邏輯兼容
3. **測試覆蓋**：確保所有等級和功能組合都經過測試

## 下一步

1. 修復 chat_page.dart 的語法錯誤
2. 測試功能解鎖邏輯
3. 確保升級時狀態正確更新
4. 驗證所有功能的正常運作
