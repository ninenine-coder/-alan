import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'coin_display.dart';
import 'data_service.dart';
import 'dart:io';

class MedalPage extends StatefulWidget {
  const MedalPage({super.key});

  @override
  State<MedalPage> createState() => _MedalPageState();
}

class _MedalPageState extends State<MedalPage> {
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();
  
  List<Medal> medals = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedals();
  }

  Future<void> _loadMedals() async {
    setState(() {
      isLoading = true;
    });

    final medalsList = await DataService.getMedals();
    
    setState(() {
      medals = medalsList;
      isLoading = false;
    });
  }

  void _showMedalInfo(Medal medal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(medal.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(medal.description),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRarityColor(medal.rarity),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    medal.rarity,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.star,
                  size: 16,
                  color: Colors.amber.shade600,
                ),
                Text(
                  ' 條件: ${medal.requirement}',
                  style: TextStyle(
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case '傳說':
        return Colors.orange.shade400;
      case '稀有':
        return Colors.purple.shade400;
      case '普通':
        return Colors.blue.shade400;
      case '常見':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  Widget _buildMedalItem(Medal medal) {
    return GestureDetector(
      onTap: () => _showMedalInfo(medal),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: medal.acquired ? Colors.amber.shade100 : Colors.grey.shade300,
          boxShadow: medal.acquired
              ? [
                  BoxShadow(
                    color: Colors.amber.shade400.withOpacity(0.7),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        padding: const EdgeInsets.all(12),
        child: Opacity(
          opacity: medal.acquired ? 1.0 : 0.4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: medal.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(medal.imagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.emoji_events,
                              size: 48,
                              color: medal.acquired ? Colors.amber.shade600 : Colors.grey.shade500,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.emoji_events,
                        size: 48,
                        color: medal.acquired ? Colors.amber.shade600 : Colors.grey.shade500,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                medal.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: medal.acquired ? Colors.black : Colors.grey.shade700,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _getRarityColor(medal.rarity),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  medal.rarity,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的勳章'),
        centerTitle: true,
        actions: [
          CoinDisplay(key: _coinDisplayKey),
          const SizedBox(width: 16),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : medals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '尚無徽章',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.builder(
                    itemCount: medals.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 三欄
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      return _buildMedalItem(medals[index]);
                    },
                  ),
                ),
    );
  }
}
