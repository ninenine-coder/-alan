# Firebase 與影片檔案映射關係

## 🎯 映射規則

根據 Firebase 的 `name` 欄位自動映射到對應的影片檔案：

| Firebase Name | 影片檔案 | 說明 |
|---------------|----------|------|
| 夜市生活 | `night.mp4` | 夜市氛圍特效 |
| B-Boy | `boy.mp4` | 街舞風格特效 |
| 文青少年 | `coffee.mp4` | 咖啡廳文青風格 |
| 來去泡溫泉 | `hotspring.mp4` | 溫泉放鬆特效 |
| 登山客 | `mt.mp4` | 登山戶外特效 |
| 淡水夕陽 | `sun.mp4` | 夕陽美景特效 |
| 跑酷少年 | `run.mp4` | 跑酷運動特效 |
| 校外教學 | `zoo.mp4` | 動物園教學特效 |
| 出門踏青 | `walk.mp4` | 戶外踏青特效 |
| 下雨天 | `rain.mp4` | 雨天氛圍特效 |
| 買米買菜買冬瓜 | `market.mp4` | 市場購物特效 |

## 🔧 技術實現

### 1. EffectModel 映射邏輯
```dart
factory EffectModel.fromFirestore(String id, Map<String, dynamic> data) {
  final name = data['name'] ?? '特效$number';
  
  // 根據 Firebase name 欄位映射到對應的影片檔案
  String getAssetPath(String effectName) {
    switch (effectName) {
      case '夜市生活':
        return 'assets/MRT影片/night.mp4';
      case 'B-Boy':
        return 'assets/MRT影片/boy.mp4';
      case '文青少年':
        return 'assets/MRT影片/coffee.mp4';
      // ... 其他映射
      default:
        return 'assets/MRT影片/特效$number.mp4';
    }
  }
  
  return EffectModel(
    id: id,
    name: name,
    assetPath: getAssetPath(name),  // 使用映射的檔案路徑
    owned: data['owned'] ?? false,
    number: number,
    description: data['description'],
    price: data['price'],
    rarity: data['rarity'],
  );
}
```

### 2. 檔案結構
```
assets/
└── MRT影片/
    ├── night.mp4      ← 夜市生活
    ├── boy.mp4        ← B-Boy
    ├── coffee.mp4     ← 文青少年
    ├── hotspring.mp4  ← 來去泡溫泉
    ├── mt.mp4         ← 登山客
    ├── sun.mp4        ← 淡水夕陽
    ├── run.mp4        ← 跑酷少年
    ├── zoo.mp4        ← 校外教學
    ├── walk.mp4       ← 出門踏青
    ├── rain.mp4       ← 下雨天
    └── market.mp4     ← 買米買菜買冬瓜
```

## 📱 使用流程

### 1. Firebase 資料結構
```json
{
  "effects": {
    "1": {
      "name": "夜市生活",
      "number": 1,
      "price": 300,
      "rarity": "常見",
      "description": "熱鬧的夜市氛圍",
      "owned": false
    },
    "2": {
      "name": "B-Boy",
      "number": 2,
      "price": 500,
      "rarity": "稀有",
      "description": "街舞風格特效",
      "owned": false
    }
  }
}
```

### 2. 自動映射過程
```
1. 從 Firebase 讀取資料
   ↓
2. 取得 name 欄位（如："夜市生活"）
   ↓
3. 根據映射表找到對應檔案（night.mp4）
   ↓
4. 生成 assetPath（assets/MRT影片/night.mp4）
   ↓
5. 播放對應影片
```

## ✅ 優勢特點

1. **自動映射**：無需手動設定檔案路徑
2. **易於維護**：新增特效只需更新映射表
3. **錯誤處理**：找不到映射時使用預設編號
4. **靈活性**：支援任意命名規則

## 🛠️ 擴展方式

### 新增特效映射
```dart
case '新特效名稱':
  return 'assets/MRT影片/新檔案名.mp4';
```

### 批量處理
```dart
// 可以擴展為從配置檔案讀取映射關係
final Map<String, String> effectMapping = {
  '夜市生活': 'night.mp4',
  'B-Boy': 'boy.mp4',
  // ...
};
```

## 🎯 注意事項

1. **檔案命名**：確保影片檔案名稱與映射表一致
2. **大小寫**：Firebase 的 name 欄位要完全匹配
3. **檔案存在**：確保所有映射的影片檔案都存在於 assets 目錄
4. **備用方案**：使用 default 處理未映射的特效

這個映射系統讓 Firebase 資料與本地影片檔案完美對應，提供靈活且易於維護的特效管理方案！
