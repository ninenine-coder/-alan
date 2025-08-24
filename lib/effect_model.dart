class EffectModel {
  final String id;
  final String name;
  final String assetPath;
  final bool owned;
  final int number;
  final String? description;
  final int? price;
  final String? rarity;

  EffectModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.owned,
    required this.number,
    this.description,
    this.price,
    this.rarity,
  });

  factory EffectModel.fromFirestore(String id, Map<String, dynamic> data) {
    final number = data['number'] ?? 1;
    final name = data['name'] ?? '特效$number';
    
    // 根據 Firebase name 欄位映射到對應的影片檔案
    String getAssetPath(String effectName) {
      switch (effectName) {
        case '夜市生活':
          return 'assets/MRTvedio/night.mp4';
        case 'B-Boy':
          return 'assets/MRTvedio/boy.mp4';
        case '文青少年':
          return 'assets/MRTvedio/ccc.mp4';
        case '來去泡溫泉':
          return 'assets/MRTvedio/hotspring.mp4';
        case '登山客':
          return 'assets/MRTvedio/mt.mp4';
        case '淡水夕陽':
          return 'assets/MRTvedio/sun.mp4';
        case '跑酷少年':
          return 'assets/MRTvedio/run.mp4';
        case '校外教學':
          return 'assets/MRTvedio/zoo.mp4';
        case '出門踏青':
          return 'assets/MRTvedio/walk.mp4';
        case '下雨天':
          return 'assets/MRTvedio/rain.mp4';
        case '買米買菜買冬瓜':
          return 'assets/MRTvedio/abc.mp4';
        default:
          // 如果沒有對應的映射，使用預設的編號方式
          return 'assets/MRTvedio/特效$number.mp4';
      }
    }
    
    return EffectModel(
      id: id,
      name: name,
      assetPath: getAssetPath(name),
      owned: data['owned'] ?? false,
      number: number,
      description: data['description'],
      price: data['price'],
      rarity: data['rarity'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'number': number,
      'owned': owned,
      'description': description,
      'price': price,
      'rarity': rarity,
    };
  }

  EffectModel copyWith({
    String? id,
    String? name,
    String? assetPath,
    bool? owned,
    int? number,
    String? description,
    int? price,
    String? rarity,
  }) {
    return EffectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      assetPath: assetPath ?? this.assetPath,
      owned: owned ?? this.owned,
      number: number ?? this.number,
      description: description ?? this.description,
      price: price ?? this.price,
      rarity: rarity ?? this.rarity,
    );
  }

  @override
  String toString() {
    return 'EffectModel(id: $id, name: $name, assetPath: $assetPath, owned: $owned, number: $number)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EffectModel &&
        other.id == id &&
        other.name == name &&
        other.assetPath == assetPath &&
        other.owned == owned &&
        other.number == number;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        assetPath.hashCode ^
        owned.hashCode ^
        number.hashCode;
  }
}
