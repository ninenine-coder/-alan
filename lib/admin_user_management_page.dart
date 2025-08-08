import 'package:flutter/material.dart';
import 'data_service.dart';

class UserAccount {
  final String username;
  final String email;
  final DateTime registrationDate;
  final DateTime? lastLoginDate;
  final int loginCount;
  final int coins;
  final List<String> purchasedItems;
  final List<String> earnedMedals;

  UserAccount({
    required this.username,
    required this.email,
    required this.registrationDate,
    this.lastLoginDate,
    this.loginCount = 0,
    this.coins = 0,
    this.purchasedItems = const [],
    this.earnedMedals = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'registrationDate': registrationDate.toIso8601String(),
      'lastLoginDate': lastLoginDate?.toIso8601String(),
      'loginCount': loginCount,
      'coins': coins,
      'purchasedItems': purchasedItems,
      'earnedMedals': earnedMedals,
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      username: json['username'],
      email: json['email'],
      registrationDate: DateTime.parse(json['registrationDate']),
      lastLoginDate: json['lastLoginDate'] != null 
          ? DateTime.parse(json['lastLoginDate']) 
          : null,
      loginCount: json['loginCount'] ?? 0,
      coins: json['coins'] ?? 0,
      purchasedItems: List<String>.from(json['purchasedItems'] ?? []),
      earnedMedals: List<String>.from(json['earnedMedals'] ?? []),
    );
  }
}

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  List<UserAccount> users = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortBy = 'registrationDate';
  bool sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      isLoading = true;
    });

    try {
      final usersData = await DataService.getRegisteredUsers();
      
      final loadedUsers = usersData
          .map((data) => UserAccount.fromJson(data))
          .toList();

      setState(() {
        users = loadedUsers;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入使用者資料時發生錯誤: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<UserAccount> get filteredAndSortedUsers {
    List<UserAccount> filtered = users.where((user) {
      return user.username.toLowerCase().contains(searchQuery.toLowerCase()) ||
             user.email.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      int comparison = 0;
      switch (sortBy) {
        case 'username':
          comparison = a.username.compareTo(b.username);
          break;
        case 'registrationDate':
          comparison = a.registrationDate.compareTo(b.registrationDate);
          break;
        case 'lastLoginDate':
          if (a.lastLoginDate == null && b.lastLoginDate == null) return 0;
          if (a.lastLoginDate == null) return 1;
          if (b.lastLoginDate == null) return -1;
          comparison = a.lastLoginDate!.compareTo(b.lastLoginDate!);
          break;
        case 'loginCount':
          comparison = a.loginCount.compareTo(b.loginCount);
          break;
        case 'coins':
          comparison = a.coins.compareTo(b.coins);
          break;
        case 'purchasedItems':
          comparison = a.purchasedItems.length.compareTo(b.purchasedItems.length);
          break;
        case 'earnedMedals':
          comparison = a.earnedMedals.length.compareTo(b.earnedMedals.length);
          break;
      }
      return sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  void _showUserDetails(UserAccount user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('使用者詳情: ${user.username}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('帳號', user.username),
              _buildDetailRow('電子郵件', user.email),
              _buildDetailRow('註冊日期', _formatDate(user.registrationDate)),
              _buildDetailRow('最後登入', user.lastLoginDate != null 
                  ? _formatDate(user.lastLoginDate!) 
                  : '從未登入'),
              _buildDetailRow('登入次數', user.loginCount.toString()),
              _buildDetailRow('金幣數量', user.coins.toString()),
              _buildDetailRow('購買商品數', user.purchasedItems.length.toString()),
              _buildDetailRow('獲得徽章數', user.earnedMedals.length.toString()),
              const SizedBox(height: 16),
              if (user.purchasedItems.isNotEmpty) ...[
                const Text(
                  '購買的商品:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...user.purchasedItems.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Text('• $item'),
                )),
                const SizedBox(height: 16),
              ],
              if (user.earnedMedals.isNotEmpty) ...[
                const Text(
                  '獲得的徽章:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...user.earnedMedals.map((medal) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Text('• $medal'),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showStatistics() {
    final totalUsers = users.length;
    final activeUsers = users.where((user) => user.lastLoginDate != null).length;
    final totalCoins = users.fold(0, (sum, user) => sum + user.coins);
    final totalPurchases = users.fold(0, (sum, user) => sum + user.purchasedItems.length);
    final totalMedals = users.fold(0, (sum, user) => sum + user.earnedMedals.length);
    final totalLogins = users.fold(0, (sum, user) => sum + user.loginCount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用統計'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('總註冊用戶', totalUsers.toString()),
            _buildStatRow('活躍用戶', '$activeUsers (${totalUsers > 0 ? (activeUsers / totalUsers * 100).toStringAsFixed(1) : 0}%)'),
            _buildStatRow('總登入次數', totalLogins.toString()),
            _buildStatRow('平均登入次數', totalUsers > 0 ? (totalLogins / totalUsers).toStringAsFixed(1) : '0'),
            _buildStatRow('總金幣數量', totalCoins.toString()),
            _buildStatRow('平均金幣數量', totalUsers > 0 ? (totalCoins / totalUsers).toStringAsFixed(1) : '0'),
            _buildStatRow('總購買次數', totalPurchases.toString()),
            _buildStatRow('平均購買次數', totalUsers > 0 ? (totalPurchases / totalUsers).toStringAsFixed(1) : '0'),
            _buildStatRow('總獲得徽章', totalMedals.toString()),
            _buildStatRow('平均徽章數量', totalUsers > 0 ? (totalMedals / totalUsers).toStringAsFixed(1) : '0'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = filteredAndSortedUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('使用者帳號管理'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStatistics,
            tooltip: '使用統計',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: '重新載入',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜尋和排序控制項
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 搜尋欄
                TextField(
                  decoration: const InputDecoration(
                    labelText: '搜尋使用者',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // 排序選項
                Row(
                  children: [
                    const Text('排序方式: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: sortBy,
                      items: [
                        DropdownMenuItem(value: 'username', child: Text('帳號')),
                        DropdownMenuItem(value: 'registrationDate', child: Text('註冊日期')),
                        DropdownMenuItem(value: 'lastLoginDate', child: Text('最後登入')),
                        DropdownMenuItem(value: 'loginCount', child: Text('登入次數')),
                        DropdownMenuItem(value: 'coins', child: Text('金幣數量')),
                        DropdownMenuItem(value: 'purchasedItems', child: Text('購買商品數')),
                        DropdownMenuItem(value: 'earnedMedals', child: Text('徽章數量')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          sortBy = value!;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                      onPressed: () {
                        setState(() {
                          sortAscending = !sortAscending;
                        });
                      },
                      tooltip: '排序方向',
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 使用者列表
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isEmpty ? '尚無註冊用戶' : '沒有符合搜尋條件的用戶',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.green.shade600,
                                ),
                              ),
                              title: Text(user.username),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.email),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                                      Text(' ${_formatDate(user.registrationDate)}'),
                                      const SizedBox(width: 16),
                                      Icon(Icons.login, size: 16, color: Colors.grey.shade600),
                                      Text(' ${user.loginCount}次'),
                                      const SizedBox(width: 16),
                                      Icon(Icons.monetization_on, size: 16, color: Colors.amber.shade600),
                                      Text(' ${user.coins}'),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.info),
                                    onPressed: () => _showUserDetails(user),
                                    tooltip: '查看詳情',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
