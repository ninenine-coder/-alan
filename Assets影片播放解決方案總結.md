# Assets 影片播放解決方案總結

## 🎯 問題分析

### ❌ 原始問題
Flutter 的 `video_player` 套件無法直接播放 assets 中的影片檔案，會出現 `FileNotFoundException` 錯誤。

### ✅ 解決方案
將 assets 影片檔案複製到裝置的暫存資料夾，然後使用 `VideoPlayerController.file()` 播放。

## 🔧 技術實現

### 1. 核心原理
```dart
// 1. 從 assets 載入影片資料
final byteData = await rootBundle.load(assetPath);

// 2. 複製到暫存資料夾
final tempDir = await getTemporaryDirectory();
final fileName = assetPath.split('/').last;
final tempFile = File('${tempDir.path}/$fileName');
await tempFile.writeAsBytes(byteData.buffer.asUint8List());

// 3. 使用檔案路徑播放
final controller = VideoPlayerController.file(tempFile);
await controller.initialize();
```

### 2. 依賴套件
```yaml
dependencies:
  video_player: ^2.8.2
  video_thumbnail: ^0.5.6
  path_provider: ^2.1.2  # 已安裝
  flutter:
    assets:
      - assets/MRT影片/
```

## 📱 組件架構

### 1. AssetVideoPlayer - 基礎播放器
```dart
class AssetVideoPlayer extends StatefulWidget {
  final String assetPath;
  final String? title;
  final bool autoPlay;
  final bool showControls;
  final BoxFit fit;
}
```

**特色功能：**
- 自動複製 assets 到暫存資料夾
- 完整的載入和錯誤狀態處理
- 播放控制（播放/暫停、重新播放、循環播放）
- 自動清理暫存檔案

### 2. FullScreenVideoPlayer - 全螢幕播放器
```dart
class FullScreenVideoPlayer extends StatefulWidget {
  final String assetPath;
  final String title;
}
```

**特色功能：**
- 全螢幕播放體驗
- 進度條控制
- 時間顯示
- 完整的播放控制介面

### 3. 更新的縮圖生成
```dart
// 在 EffectThumbnail 中
Future<void> _generateThumbnail() async {
  // 複製 asset 到暫存資料夾
  final byteData = await rootBundle.load(widget.videoPath);
  final tempDir = await getTemporaryDirectory();
  final fileName = widget.videoPath.split('/').last;
  final tempFile = File('${tempDir.path}/$fileName');
  
  await tempFile.writeAsBytes(byteData.buffer.asUint8List());
  
  // 使用暫存檔案生成縮圖
  final thumb = await VideoThumbnail.thumbnailFile(
    video: tempFile.path,
    imageFormat: ImageFormat.JPEG,
    maxHeight: 300,
    maxWidth: 300,
    quality: 80,
  );
}
```

## 🎨 使用方式

### 1. 基本播放器
```dart
AssetVideoPlayer(
  assetPath: 'assets/MRT影片/特效1.mp4',
  autoPlay: true,
  showControls: true,
)
```

### 2. 全螢幕播放器
```dart
FullScreenVideoPlayer(
  assetPath: 'assets/MRT影片/特效1.mp4',
  title: '夜市生活',
)
```

### 3. 在商城頁面中使用
```dart
// 點擊縮圖播放影片
void _playVideo(String assetPath, String effectName) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FullScreenVideoPlayer(
        assetPath: assetPath,
        title: effectName,
      ),
    ),
  );
}
```

## ⚡ 性能優化

### 1. 暫存檔案管理
- 自動清理暫存檔案
- 使用檔案名避免衝突
- 錯誤處理和重試機制

### 2. 記憶體管理
- 正確釋放 VideoPlayerController
- 避免記憶體洩漏
- 組件銷毀時清理資源

### 3. 錯誤處理
- 完整的載入狀態
- 用戶友善的錯誤提示
- 重試機制

## 🔄 資料流程

### 1. 影片載入流程
```
1. 組件初始化
2. 從 assets 載入影片資料
3. 複製到暫存資料夾
4. 初始化 VideoPlayerController
5. 開始播放
```

### 2. 縮圖生成流程
```
1. 複製 assets 影片到暫存資料夾
2. 使用 video_thumbnail 生成縮圖
3. 儲存縮圖路徑到快取
4. 顯示縮圖
```

### 3. 清理流程
```
1. 組件銷毀
2. 釋放 VideoPlayerController
3. 刪除暫存檔案
4. 清理快取
```

## 🛠️ 檔案結構

```
lib/
├── asset_video_player.dart      # 影片播放組件
├── effect_thumbnail.dart        # 縮圖生成組件
├── video_player_page.dart       # 影片播放頁面
├── effect_shop_page.dart        # 商城特效頁面
└── effect_model.dart           # 特效資料模型

assets/
└── MRT影片/
    ├── 特效1.mp4
    ├── 特效2.mp4
    └── ...
```

## ✅ 優勢特點

1. **完全解決 assets 播放問題**：使用暫存檔案方式播放
2. **自動化處理**：無需手動管理檔案
3. **完整錯誤處理**：載入失敗時提供重試機制
4. **性能優化**：自動清理暫存檔案
5. **用戶體驗**：流暢的播放體驗和完整的控制介面

## 🎯 使用建議

### 1. 檔案命名
- 使用有意義的檔案名
- 避免特殊字符
- 保持一致的命名規則

### 2. 檔案大小
- 控制影片檔案大小
- 考慮使用壓縮格式
- 避免過大的檔案影響載入速度

### 3. 錯誤處理
```dart
// 提供重試機制
if (_hasError) {
  return ElevatedButton(
    onPressed: _loadVideo,
    child: const Text('重試'),
  );
}
```

這個解決方案完美解決了 Flutter 中播放 assets 影片的問題，提供了穩定可靠的影片播放功能！
