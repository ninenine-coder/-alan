import 'package:flutter/material.dart';

class PetPage extends StatefulWidget {
  final String initialPetName;

  const PetPage({super.key, required this.initialPetName});

  @override
  State<PetPage> createState() => _PetPageState();
}

class _PetPageState extends State<PetPage> {
  late TextEditingController _controller;
  late String petName;
  double experience = 0.65; // 65% 經驗

  @override
  void initState() {
    super.initState();
    petName = widget.initialPetName;
    _controller = TextEditingController(text: petName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的桌寵'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 上半部：桌寵 + 經驗條 + 命名
          Expanded(
            flex: 1,
            child: Column(
              children: [
                const SizedBox(height: 10),
                // 模型預留區
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: Text('桌寵模型區')),
                  ),
                ),
                const SizedBox(height: 12),

                // 經驗值條
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: experience,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade300,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 6),
                      Text('經驗值：${(experience * 100).toInt()}%'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 改名輸入欄
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '輸入桌寵名稱',
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: () {
                    final newName = _controller.text.trim();
                    if (newName.isNotEmpty) {
                      Navigator.pop(context, newName); // 回傳新名字
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('確定'),
                ),

                const SizedBox(height: 10),

                Text('目前名稱：$petName'),
              ],
            ),
          ),

          const Divider(thickness: 1),

          // 下半部：收藏區
          Expanded(
            flex: 1,
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildCollectionCard('造型', Icons.brush),
                _buildCollectionCard('裝飾', Icons.emoji_objects),
                _buildCollectionCard('語氣', Icons.record_voice_over),
                _buildCollectionCard('動作', Icons.directions_run),
                _buildCollectionCard('飼料', Icons.fastfood),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.indigo),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
