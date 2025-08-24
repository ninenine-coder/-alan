import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'effect_model.dart';
import 'logger_service.dart';
import 'video_player_page.dart';

class StoreEffectPage extends StatefulWidget {
  const StoreEffectPage({super.key});

  @override
  State<StoreEffectPage> createState() => _StoreEffectPageState();
}

class _StoreEffectPageState extends State<StoreEffectPage> {
  // 快取已生成的縮圖
  final Map<String, Uint8List> _thumbnailCache = {};

  Future<Uint8List?> _generateThumbnail(String assetPath) async {
    // 檢查快取
    if (_thumbnailCache.containsKey(assetPath)) {
      return _thumbnailCache[assetPath];
    }

    try {
      LoggerService.info('正在生成縮圖: $assetPath');
      
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: assetPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 256,
        maxHeight: 256,
        quality: 80,
      );

      if (thumbnailData != null) {
        // 儲存到快取
        _thumbnailCache[assetPath] = thumbnailData;
        LoggerService.info('縮圖生成成功: $assetPath');
      }

      return thumbnailData;
    } catch (e) {
      LoggerService.error('縮圖生成失敗: $e');
      return null;
    }
  }

  void _playVideo(String assetPath, String effectName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          assetPath: assetPath,
          effectName: effectName,
        ),
      ),
    );
  }

  void _purchaseEffect(EffectModel effect) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('購買 ${effect.name}'),
          content: Text('確定要購買這個特效嗎？\n價格: ${effect.price ?? 0} 元'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: 實現購買邏輯
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已購買 ${effect.name}')),
                );
              },
              child: const Text('購買'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("商城 - 特效區"),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("effects").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '載入失敗',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '請檢查網路連線',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('載入中...'),
                ],
              ),
            );
          }

          final effects = snapshot.data!.docs.map((doc) {
            return EffectModel.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
          }).toList();

          if (effects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '暫無特效商品',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '請稍後再來查看',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: effects.length,
            itemBuilder: (context, index) {
              final effect = effects[index];
              return _buildEffectCard(effect);
            },
          );
        },
      ),
    );
  }

  Widget _buildEffectCard(EffectModel effect) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 縮圖區域
          Expanded(
            flex: 3,
            child: FutureBuilder<Uint8List?>(
              future: _generateThumbnail(effect.assetPath),
              builder: (context, thumbSnapshot) {
                if (thumbSnapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!thumbSnapshot.hasData) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade300, Colors.purple.shade300],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.video_library,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () => _playVideo(effect.assetPath, effect.name),
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          image: DecorationImage(
                            image: MemoryImage(thumbSnapshot.data!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // 播放按鈕
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // 擁有狀態或價格
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: effect.owned ? Colors.green : Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            effect.owned ? '已擁有' : '${effect.price ?? 0} 元',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // 稀有度標籤
                      if (effect.rarity != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRarityColor(effect.rarity!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              effect.rarity!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 資訊區域
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effect.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (effect.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      effect.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  // 操作按鈕
                  SizedBox(
                    width: double.infinity,
                    child: effect.owned
                        ? ElevatedButton.icon(
                            onPressed: () => _playVideo(effect.assetPath, effect.name),
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('播放'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _purchaseEffect(effect),
                            icon: const Icon(Icons.shopping_cart, size: 16),
                            label: const Text('購買'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case '常見':
        return Colors.green;
      case '稀有':
        return Colors.blue;
      case '史詩':
        return Colors.purple;
      case '傳說':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
