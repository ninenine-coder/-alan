# Chat Page 修復指南

## 問題描述

chat_page.dart 文件目前有以下問題：
1. 語法錯誤：重複的大括號和缺少的類成員
2. 方法定義錯誤：`_buildMenuItem` 方法結構不正確
3. 變數未定義：`_featureUnlockStatus` 等變數未正確聲明

## 修復步驟

### 1. 修復類結構

在 `_ChatPageState` 類中，確保有以下變數聲明：

```dart
class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  // ... 其他變數 ...
  
  // 功能解鎖狀態
  Map<String, bool> _featureUnlockStatus = {};
  
  // ... 其他變數 ...
}
```

### 2. 修復 `_loadUserData` 方法

確保 `_loadUserData` 方法結構正確：

```dart
Future<void> _loadUserData() async {
  // 確保用戶資料已初始化
  await UserService.initializeUserData();
  
  final userData = await UserService.getCurrentUserData();
  if (userData != null) {
    setState(() {
      _currentUser = userData;
    });
    
    // 載入聊天紀錄
    await _loadMessages();
    
    final loginCount = userData['loginCount'] ?? 0;
    LoggerService.debug('User login count = $loginCount');
    
    if (loginCount == 1) {
      LoggerService.info('First login detected, showing animation');
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        setState(() {
          _showWelcomeAnimation = true;
        });
      }
    }
    
    // 初始化功能解鎖狀態
    await _initializeFeatureUnlockStatus();
  }
}
```

### 3. 添加 `_initializeFeatureUnlockStatus` 方法

在類中添加這個新方法：

```dart
/// 初始化功能解鎖狀態
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

### 4. 修復 `_buildMenuItem` 方法

將 `_buildMenuItem` 方法修改為：

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
    child: Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isUnlocked 
                ? color.withValues(alpha: 0.1) 
                : Colors.grey.withValues(alpha: 0.1),
            isUnlocked 
                ? color.withValues(alpha: 0.2) 
                : Colors.grey.withValues(alpha: 0.2)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked 
              ? color.withValues(alpha: 0.3) 
              : Colors.grey.withValues(alpha: 0.3), 
          width: 1
        ),
        boxShadow: [
          BoxShadow(
            color: isUnlocked 
                ? color.withValues(alpha: 0.2) 
                : Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: isUnlocked ? color : Colors.grey.shade400,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isUnlocked ? color : Colors.grey.shade400,
                ),
              ),
            ],
          ),
          if (!isUnlocked)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lock,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
```

### 5. 修復 `_onLevelUp` 方法

將 `_onLevelUp` 方法修改為：

```dart
/// 處理升級事件
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

### 6. 移除不需要的方法

可以移除以下方法，因為現在使用 FeatureUnlockService：
- `_isFeatureUnlocked` 方法
- `_getRequiredLevel` 方法（保留但使用 FeatureUnlockService.getRequiredLevel）

### 7. 確保導入正確

確保文件頂部有正確的導入：

```dart
import 'feature_unlock_service.dart';
```

## 驗證修復

修復完成後，應該：
1. 沒有語法錯誤
2. 沒有未定義的變數
3. 所有方法都在正確的類中
4. 功能解鎖邏輯正常工作

## 測試建議

1. 編譯項目確保沒有錯誤
2. 測試登入時功能解鎖狀態初始化
3. 測試升級時功能解鎖狀態更新
4. 測試不同等級用戶的按鈕顯示狀態
