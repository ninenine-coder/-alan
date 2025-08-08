import 'data_service.dart';

class TestData {
  static Future<void> initializeTestUsers() async {
    final testUsers = [
      {
        'username': 'testuser1',
        'email': 'testuser1@example.com',
        'registrationDate': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'lastLoginDate': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'loginCount': 15,
        'coins': 250,
        'purchasedItems': ['pet_style_1', 'decoration_1', 'voice_1'],
        'earnedMedals': ['medal-1', 'medal-2'],
      },
      {
        'username': 'testuser2',
        'email': 'testuser2@example.com',
        'registrationDate': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'lastLoginDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'loginCount': 8,
        'coins': 180,
        'purchasedItems': ['pet_style_2', 'action_1'],
        'earnedMedals': ['medal-1'],
      },
      {
        'username': 'testuser3',
        'email': 'testuser3@example.com',
        'registrationDate': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'lastLoginDate': null,
        'loginCount': 0,
        'coins': 100,
        'purchasedItems': [],
        'earnedMedals': [],
      },
      {
        'username': 'testuser4',
        'email': 'testuser4@example.com',
        'registrationDate': DateTime.now().subtract(const Duration(days: 45)).toIso8601String(),
        'lastLoginDate': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
        'loginCount': 25,
        'coins': 500,
        'purchasedItems': ['pet_style_1', 'pet_style_2', 'decoration_1', 'decoration_2', 'voice_1', 'voice_2', 'action_1', 'action_2', 'food_1', 'food_2'],
        'earnedMedals': ['medal-1', 'medal-2', 'medal-3'],
      },
      {
        'username': 'testuser5',
        'email': 'testuser5@example.com',
        'registrationDate': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'lastLoginDate': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
        'loginCount': 3,
        'coins': 120,
        'purchasedItems': ['food_1'],
        'earnedMedals': [],
      },
    ];

    for (final userData in testUsers) {
      await DataService.saveUserData(userData['username'] as String, userData);
    }
  }
}
