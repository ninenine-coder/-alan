import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';

/// 添加商城商品到 Firebase Firestore
/// 
/// [collectionName] - Firestore 集合名稱（例如：'造型', '裝飾', '語氣', '動作', '飼料'）
/// [name] - 商品名稱
/// [price] - 商品價格
/// [imageUrl] - 商品圖片 URL
/// [popularity] - 商品常見度（可選，預設為 '常見'）
Future<void> addMallItem(
    String collectionName,
    String name,
    double price,
    String imageUrl,
    {String popularity = '常見'}) async {
  try {
    await FirebaseFirestore.instance.collection(collectionName).add({
      'name': name,
      '價格': price, // 使用中文欄位名稱
      '圖片': imageUrl, // 使用中文欄位名稱
      '常見度': popularity, // 使用中文欄位名稱
      'createdAt': FieldValue.serverTimestamp(),
    });
    LoggerService.info('商品 $name 已成功添加到 $collectionName 集合');
  } catch (e) {
    LoggerService.error('添加商品時發生錯誤: $e');
    rethrow;
  }
}

/// 測試添加商品功能
Future<void> testAddMallItem() async {
  try {
    await addMallItem(
      '造型',
      '測試造型',
      100.0,
      'https://example.com/test-image.jpg',
      popularity: '常見',
    );
    LoggerService.info('測試商品添加成功！');
  } catch (e) {
    LoggerService.error('測試失敗: $e');
  }
}

/// 添加測試飼料數據
Future<void> addTestFoodData() async {
  try {
    LoggerService.info('開始添加測試飼料數據...');
    
    final testFoods = [
      {
        'name': '高級貓糧',
        'price': 50.0,
        'imageUrl': 'https://i.postimg.cc/VkQZ8Y9L/cat-food-1.jpg',
        'popularity': '常見',
        'description': '營養豐富的貓糧，適合所有年齡的貓咪',
      },
      {
        'name': '特製狗糧',
        'price': 60.0,
        'imageUrl': 'https://i.postimg.cc/XqY8Z9L/dog-food-1.jpg',
        'popularity': '常見',
        'description': '專為狗狗設計的營養狗糧',
      },
      {
        'name': '小魚乾',
        'price': 30.0,
        'imageUrl': 'https://i.postimg.cc/YqX8Z9L/fish-food-1.jpg',
        'popularity': '常見',
        'description': '新鮮的小魚乾，貓咪的最愛',
      },
    ];
    
    for (final food in testFoods) {
      await addMallItem(
        '飼料',
        food['name'] as String,
        food['price'] as double,
        food['imageUrl'] as String,
        popularity: food['popularity'] as String,
      );
    }
    
    LoggerService.info('測試飼料數據添加完成！');
  } catch (e) {
    LoggerService.error('添加測試飼料數據失敗: $e');
  }
}

/// 測試讀取 Firebase 資料
Future<void> testReadFirebaseData() async {
  try {
    LoggerService.info('開始測試讀取 Firebase 資料...');
    
    // 測試讀取所有類別的資料
    final categories = ['造型', '裝飾', '語氣', '動作', '飼料'];
    
    for (final category in categories) {
      LoggerService.info('正在讀取 $category 類別的資料...');
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection(category)
          .get();
      
      LoggerService.info('$category 類別有 ${querySnapshot.docs.length} 個文檔');
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        LoggerService.info('文檔 ID: ${doc.id}, 資料: $data');
      }
    }
    
    LoggerService.info('Firebase 資料讀取測試完成！');
  } catch (e) {
    LoggerService.error('讀取 Firebase 資料時發生錯誤: $e');
  }
}
