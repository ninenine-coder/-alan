import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as developer;
import 'data_service.dart';

class AdminMedalManagementPage extends StatefulWidget {
  const AdminMedalManagementPage({super.key});

  @override
  State<AdminMedalManagementPage> createState() => _AdminMedalManagementPageState();
}

class _AdminMedalManagementPageState extends State<AdminMedalManagementPage> {
  final List<String> categories = ['常見', '普通', '稀有', '傳說'];
  List<Medal> medals = [];
  bool isLoading = true;
  String selectedCategory = '常見';

  @override
  void initState() {
    super.initState();
    _loadMedals();
  }

  Future<void> _loadMedals() async {
    setState(() {
      isLoading = true;
    });

    try {
      final loadedMedals = await DataService.getMedals();
      setState(() {
        medals = loadedMedals;
        isLoading = false;
      });
    } catch (e) {
      developer.log('Error loading medals: $e');
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入徽章資料時發生錯誤: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddMedalDialog() {
    File? selectedImage;
    File? uploadedImage;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final requirementController = TextEditingController();
    String selectedRarity = '常見';
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增徽章'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 圖片預覽區域
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: uploadedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            uploadedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.red.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '圖片載入失敗',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '點擊選擇徽章圖片',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                // 選擇圖片按鈕
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        maxHeight: 800,
                        imageQuality: 85,
                      );
                      if (pickedFile != null) {
                        setDialogState(() {
                          selectedImage = File(pickedFile.path);
                        });
                      }
                    } catch (e) {
                      developer.log('Error picking image: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('選擇圖片時發生錯誤: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.photo_library),
                  label: const Text('選擇圖片'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade100,
                    foregroundColor: Colors.amber.shade700,
                  ),
                ),
                // 上傳按鈕（僅在選擇圖片後顯示）
                if (selectedImage != null && uploadedImage == null) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        uploadedImage = selectedImage;
                        selectedImage = null;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('圖片上傳成功！'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.upload),
                    label: const Text('上傳圖片'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '徽章名稱'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: '描述'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: requirementController,
                  decoration: const InputDecoration(labelText: '獲得條件'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRarity,
                  decoration: const InputDecoration(labelText: '稀有度'),
                  items: categories.map((rarity) {
                    return DropdownMenuItem(
                      value: rarity,
                      child: Text(rarity),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRarity = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (nameController.text.isNotEmpty && 
                      descriptionController.text.isNotEmpty &&
                      requirementController.text.isNotEmpty) {
                    
                    final medalId = 'medal-${DateTime.now().millisecondsSinceEpoch}';
                    String? imagePath;
                    
                    // 保存圖片
                    if (uploadedImage != null) {
                      try {
                        imagePath = await DataService.saveImage(uploadedImage!, medalId);
                        if (imagePath == null) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('圖片保存失敗，但徽章已新增'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      } catch (imageError) {
                        developer.log('Error saving image: $imageError');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('圖片保存失敗: $imageError'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    }
                    
                    final newMedal = Medal(
                      id: medalId,
                      name: nameController.text,
                      description: descriptionController.text,
                      iconName: 'emoji_events',
                      rarity: selectedRarity,
                      requirement: int.tryParse(requirementController.text) ?? 0,
                      imagePath: imagePath,
                    );
                    
                    await DataService.addMedal(newMedal);
                    
                    if (mounted) {
                      await _loadMedals();
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(imagePath != null ? '徽章新增成功' : '徽章新增成功（圖片保存失敗）'),
                          backgroundColor: imagePath != null ? Colors.green : Colors.orange,
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('請填寫所有必要欄位'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  developer.log('Error creating medal: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('新增徽章時發生錯誤: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('新增'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMedal(Medal medal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除徽章「${medal.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await DataService.deleteMedal(medal.id);
                await _loadMedals();
                Navigator.pop(context);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('徽章刪除成功')),
                  );
                }
              } catch (e) {
                developer.log('Error deleting medal: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('刪除徽章時發生錯誤: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('徽章管理'),
        backgroundColor: Colors.amber.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddMedalDialog,
          ),
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: medals.length,
                  itemBuilder: (context, index) {
                    final medal = medals[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: medal.imagePath != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Image.file(
                                    File(medal.imagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.emoji_events,
                                          color: Colors.amber.shade600,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.amber.shade100,
                                child: Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber.shade600,
                                ),
                              ),
                        title: Text(medal.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(medal.description),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
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
                                  ' ${medal.requirement}',
                                  style: TextStyle(
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteMedal(medal),
                          color: Colors.red,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 