import 'package:flutter/material.dart';
import 'coin_display.dart';

class Medal {
  final String name;
  final String description;
  final String assetPath; // 勳章圖示路徑
  bool acquired; // 是否取得

  Medal({
    required this.name,
    required this.description,
    required this.assetPath,
    this.acquired = false,
  });
}

class MedalPage extends StatefulWidget {
  const MedalPage({super.key});

  @override
  State<MedalPage> createState() => _MedalPageState();
}

class _MedalPageState extends State<MedalPage> {
  final GlobalKey<CoinDisplayState> _coinDisplayKey = GlobalKey<CoinDisplayState>();
  
  // 模擬初始勳章資料
  final List<Medal> medals = List.generate(10, (index) {
    return Medal(
      name: '勳章 #${index + 1}',
      description: '這是勳章 #${index + 1} 的說明。',
      assetPath: 'assets/medals/medal_${index + 1}.png',
      acquired: index % 3 == 0, // 模擬取得狀態 (0,3,6,9號亮起)
    );
  });

  void _showMedalInfo(Medal medal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(medal.name),
        content: Text(medal.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
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
                child: Image.asset(
                  medal.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // 若圖片不存在，顯示預設圖示
                    return Icon(Icons.emoji_events,
                        size: 48,
                        color: medal.acquired ? Colors.amber : Colors.grey);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                medal.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: medal.acquired ? Colors.black : Colors.grey.shade700,
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
      body: Padding(
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
