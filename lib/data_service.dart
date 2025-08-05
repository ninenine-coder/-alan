import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StoreItem {
  final String id;
  final String name;
  final int price;
  final String description;
  final String category;
  final String rarity;
  final String iconName;
  final String? imagePath; // 新增圖片路徑

  StoreItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.rarity,
    required this.iconName,
    this.imagePath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'category': category,
      'rarity': rarity,
      'iconName': iconName,
      'imagePath': imagePath,
    };
  }

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      description: json['description'],
      category: json['category'],
      rarity: json['rarity'],
      iconName: json['iconName'],
      imagePath: json['imagePath'],
    );
  }
}

class Medal {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final String rarity;
  final int requirement;
  final String? imagePath; // 新增圖片路徑
  bool acquired;

  Medal({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.rarity,
    required this.requirement,
    this.imagePath,
    this.acquired = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconName': iconName,
      'rarity': rarity,
      'requirement': requirement,
      'imagePath': imagePath,
      'acquired': acquired,
    };
  }

  factory Medal.fromJson(Map<String, dynamic> json) {
    return Medal(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      iconName: json['iconName'],
      rarity: json['rarity'],
      requirement: json['requirement'],
      imagePath: json['imagePath'],
      acquired: json['acquired'] ?? false,
    );
  }
}

class DataService {
  // 商城商品管理
  static Future<List<StoreItem>> getStoreItems() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = prefs.getStringList('admin_store_items') ?? [];
    
    return itemsJson
        .map((json) => StoreItem.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveStoreItems(List<StoreItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final itemsJson = items
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList('admin_store_items', itemsJson);
  }

  static Future<void> addStoreItem(StoreItem item) async {
    final items = await getStoreItems();
    items.add(item);
    await saveStoreItems(items);
  }

  static Future<void> updateStoreItem(StoreItem updatedItem) async {
    final items = await getStoreItems();
    final index = items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      items[index] = updatedItem;
      await saveStoreItems(items);
    }
  }

  static Future<void> deleteStoreItem(String itemId) async {
    final items = await getStoreItems();
    final itemToDelete = items.firstWhere((item) => item.id == itemId);
    
    // 刪除相關的圖片檔案
    if (itemToDelete.imagePath != null) {
      try {
        final file = File(itemToDelete.imagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting image file: $e');
      }
    }
    
    items.removeWhere((item) => item.id == itemId);
    await saveStoreItems(items);
  }

  // 圖片管理
  static Future<String?> saveImage(File imageFile, String itemId) async {
    try {
      print('Starting image save process for item: $itemId');
      
      // 檢查原始圖片檔案是否存在
      if (!await imageFile.exists()) {
        print('Error: Original image file does not exist: ${imageFile.path}');
        throw Exception('原始圖片檔案不存在');
      }
      
      // 檢查檔案大小
      final fileSize = await imageFile.length();
      print('Image file size: ${fileSize} bytes');
      
      if (fileSize > 10 * 1024 * 1024) { // 10MB 限制
        print('Error: Image file too large: ${fileSize} bytes');
        throw Exception('圖片檔案太大，請選擇較小的圖片');
      }
      
      final directory = await getApplicationDocumentsDirectory();
      print('Application documents directory: ${directory.path}');
      
      final imagesDir = Directory('${directory.path}/store_images');
      print('Images directory path: ${imagesDir.path}');
      
      // 確保圖片目錄存在
      if (!await imagesDir.exists()) {
        print('Creating images directory...');
        await imagesDir.create(recursive: true);
        print('Images directory created successfully');
      }
      
      final fileName = '${itemId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = '${imagesDir.path}/$fileName';
      print('Target image path: $targetPath');
      
      // 複製圖片檔案
      final savedImage = await imageFile.copy(targetPath);
      print('Image copied successfully to: ${savedImage.path}');
      
      // 驗證檔案是否真的被保存
      if (await savedImage.exists()) {
        final savedFileSize = await savedImage.length();
        print('Saved image exists and is accessible, size: ${savedFileSize} bytes');
        
        if (savedFileSize > 0) {
          return savedImage.path;
        } else {
          print('Error: Saved image file is empty');
          throw Exception('保存的圖片檔案為空');
        }
      } else {
        print('Error: Saved image file does not exist after copy');
        throw Exception('圖片保存失敗');
      }
    } catch (e) {
      print('Error saving image: $e');
      print('Error details: ${e.toString()}');
      rethrow; // 重新拋出異常，讓調用者處理
    }
  }

  static Future<void> deleteImage(String? imagePath) async {
    if (imagePath != null) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting image: $e');
      }
    }
  }

  // 徽章管理
  static Future<List<Medal>> getMedals() async {
    final prefs = await SharedPreferences.getInstance();
    final medalsJson = prefs.getStringList('admin_medals') ?? [];
    
    return medalsJson
        .map((json) => Medal.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveMedals(List<Medal> medals) async {
    final prefs = await SharedPreferences.getInstance();
    final medalsJson = medals
        .map((medal) => jsonEncode(medal.toJson()))
        .toList();
    await prefs.setStringList('admin_medals', medalsJson);
  }

  static Future<void> addMedal(Medal medal) async {
    final medals = await getMedals();
    medals.add(medal);
    await saveMedals(medals);
  }

  static Future<void> updateMedal(Medal updatedMedal) async {
    final medals = await getMedals();
    final index = medals.indexWhere((medal) => medal.id == updatedMedal.id);
    if (index != -1) {
      medals[index] = updatedMedal;
      await saveMedals(medals);
    }
  }

  static Future<void> deleteMedal(String medalId) async {
    final medals = await getMedals();
    medals.removeWhere((medal) => medal.id == medalId);
    await saveMedals(medals);
  }

  // 清空所有資料
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_store_items');
    await prefs.remove('admin_medals');
    
    // 清空圖片資料夾
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/store_images');
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing images directory: $e');
    }
  }

  // 獲取按類別分組的商品
  static Future<Map<String, List<StoreItem>>> getStoreItemsByCategory() async {
    final items = await getStoreItems();
    final Map<String, List<StoreItem>> groupedItems = {};
    
    for (final item in items) {
      if (!groupedItems.containsKey(item.category)) {
        groupedItems[item.category] = [];
      }
      groupedItems[item.category]!.add(item);
    }
    
    return groupedItems;
  }

  // 已購買商品管理
  static Future<List<String>> getPurchasedItems(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final purchasedKey = 'purchased_items_$username';
    return prefs.getStringList(purchasedKey) ?? [];
  }

  static Future<void> addPurchasedItem(String username, String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final purchasedKey = 'purchased_items_$username';
    final purchasedItems = await getPurchasedItems(username);
    
    if (!purchasedItems.contains(itemId)) {
      purchasedItems.add(itemId);
      await prefs.setStringList(purchasedKey, purchasedItems);
    }
  }

  static Future<void> removePurchasedItem(String username, String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final purchasedKey = 'purchased_items_$username';
    final purchasedItems = await getPurchasedItems(username);
    
    purchasedItems.remove(itemId);
    await prefs.setStringList(purchasedKey, purchasedItems);
  }

  static Future<bool> isItemPurchased(String username, String itemId) async {
    final purchasedItems = await getPurchasedItems(username);
    return purchasedItems.contains(itemId);
  }

  // 獲取已購買的商品詳情
  static Future<List<StoreItem>> getPurchasedStoreItems(String username) async {
    final allItems = await getStoreItems();
    final purchasedItemIds = await getPurchasedItems(username);
    
    return allItems.where((item) => purchasedItemIds.contains(item.id)).toList();
  }

  // 按類別獲取已購買的商品
  static Future<Map<String, List<StoreItem>>> getPurchasedItemsByCategory(String username) async {
    final purchasedItems = await getPurchasedStoreItems(username);
    final Map<String, List<StoreItem>> groupedItems = {};
    
    for (final item in purchasedItems) {
      if (!groupedItems.containsKey(item.category)) {
        groupedItems[item.category] = [];
      }
      groupedItems[item.category]!.add(item);
    }
    
    return groupedItems;
  }
} 