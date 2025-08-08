import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'data_service.dart';

class AdminMedalManagementPage extends StatefulWidget {
  const AdminMedalManagementPage({super.key});

  @override
  State<AdminMedalManagementPage> createState() => _AdminMedalManagementPageState();
}

class _AdminMedalManagementPageState extends State<AdminMedalManagementPage> {
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



  Future<File?> _pickImageWithContext(BuildContext context) async {
    try {
      // 檢查權限
      if (!mounted) {
        return null;
      }
      
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (!mounted) {
        return null;
      }
      
      if (image != null) {
        // 檢查檔案路徑是否有效
        if (image.path.isEmpty) {
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('選擇的圖片路徑無效'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return null;
        }
        
        final file = File(image.path);
        
        // 檢查檔案是否存在
        if (await file.exists()) {
          // 檢查檔案大小
          final fileSize = await file.length();
          
          if (fileSize > 10 * 1024 * 1024) { // 10MB 限制
            if (mounted) {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('圖片檔案太大，請選擇較小的圖片'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return null;
          }
          
          return file;
        } else {
          if (mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('選擇的圖片檔案不存在'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      // 顯示錯誤訊息給使用者
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('選擇圖片時發生錯誤: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  void _showAddMedalDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final requirementController = TextEditingController();
    String selectedRarity = '常見';
    String selectedIconName = 'emoji_events';
    File? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('新增徽章'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 圖片選擇區域
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            selectedImage!,
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
                ElevatedButton.icon(
                  onPressed: () async {
                    final dialogContext = context;
                    try {
                      // 檢查對話框是否仍然存在
                      if (!mounted) {
                        return;
                      }
                      
                      final image = await _pickImageWithContext(dialogContext);
                      
                      // 再次檢查對話框是否仍然存在
                      if (!mounted) {
                        return;
                      }
                      
                      if (image != null) {
                        setDialogState(() {
                          selectedImage = image;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('選擇圖片時發生錯誤: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '徽章名稱'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: '描述'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: requirementController,
                  decoration: const InputDecoration(labelText: '獲得條件'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRarity,
                  decoration: const InputDecoration(labelText: '稀有度'),
                  items: ['常見', '普通', '稀有', '傳說'].map((rarity) {
                    return DropdownMenuItem(
                      value: rarity,
                      child: Text(rarity),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedRarity = value!;
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
                    final dialogContext = context;
                    try {
                      if (nameController.text.isNotEmpty && 
                          descriptionController.text.isNotEmpty &&
                          requirementController.text.isNotEmpty) {
                        
                        final medalId = 'medal-${DateTime.now().millisecondsSinceEpoch}';
                        String? imagePath;
                        
                        // 保存圖片
                        if (selectedImage != null) {
                          try {
                            imagePath = await DataService.saveImage(selectedImage!, medalId);
                            if (imagePath == null) {
                              if (mounted) {
                                final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('圖片保存失敗，但徽章已新增'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          } catch (imageError) {
                            if (mounted) {
                              final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                              scaffoldMessenger.showSnackBar(
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
                          iconName: selectedIconName,
                          rarity: selectedRarity,
                          requirement: int.tryParse(requirementController.text) ?? 0,
                          imagePath: imagePath,
                        );
                        
                        await DataService.addMedal(newMedal);
                        
                        if (mounted) {
                          await _loadMedals();
                          Navigator.pop(dialogContext);
                          
                          final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(imagePath != null ? '徽章新增成功' : '徽章新增成功（圖片保存失敗）'),
                              backgroundColor: imagePath != null ? Colors.green : Colors.orange,
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('請填寫所有必要欄位'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                        scaffoldMessenger.showSnackBar(
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

  void _showEditMedalDialog(Medal medal) {
    final nameController = TextEditingController(text: medal.name);
    final descriptionController = TextEditingController(text: medal.description);
    final requirementController = TextEditingController(text: medal.requirement.toString());
    String selectedRarity = medal.rarity;
    File? selectedImage;
    String? currentImagePath = medal.imagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('編輯徽章'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 圖片選擇區域
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            selectedImage!,
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
                      : currentImagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(currentImagePath!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '圖片載入失敗',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final dialogContext = context;
                          try {
                            // 檢查對話框是否仍然存在
                            if (!mounted) {
                              return;
                            }
                            
                            final image = await _pickImageWithContext(dialogContext);
                            
                            // 再次檢查對話框是否仍然存在
                            if (!mounted) {
                              return;
                            }
                            
                            if (image != null) {
                              setDialogState(() {
                                selectedImage = image;
                                currentImagePath = null;
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('選擇圖片時發生錯誤: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('選擇新圖片'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade100,
                          foregroundColor: Colors.amber.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (currentImagePath != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              currentImagePath = null;
                              selectedImage = null;
                            });
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('移除圖片'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade100,
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '徽章名稱'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: '描述'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: requirementController,
                  decoration: const InputDecoration(labelText: '獲得條件'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRarity,
                  decoration: const InputDecoration(labelText: '稀有度'),
                  items: ['常見', '普通', '稀有', '傳說'].map((rarity) {
                    return DropdownMenuItem(
                      value: rarity,
                      child: Text(rarity),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedRarity = value!;
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
                final dialogContext = context;
                if (nameController.text.isNotEmpty && 
                    descriptionController.text.isNotEmpty &&
                    requirementController.text.isNotEmpty) {
                  
                  String? imagePath = currentImagePath;
                  
                  // 如果有新選擇的圖片，保存它
                  if (selectedImage != null) {
                    // 刪除舊圖片
                    if (currentImagePath != null) {
                      await DataService.deleteImage(currentImagePath);
                    }
                    // 保存新圖片
                    imagePath = await DataService.saveImage(selectedImage!, medal.id);
                  } else if (currentImagePath == null && medal.imagePath != null) {
                    // 如果移除了圖片，刪除舊圖片
                    await DataService.deleteImage(medal.imagePath);
                    imagePath = null;
                  }
                  
                  final updatedMedal = Medal(
                    id: medal.id,
                    name: nameController.text,
                    description: descriptionController.text,
                    iconName: medal.iconName,
                    rarity: selectedRarity,
                    requirement: int.tryParse(requirementController.text) ?? 0,
                    imagePath: imagePath,
                  );
                  
                  await DataService.updateMedal(updatedMedal);
                  await _loadMedals();
                  Navigator.pop(dialogContext);
                  
                  if (mounted) {
                    final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('徽章更新成功')),
                    );
                  }
                }
              },
              child: const Text('更新'),
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
              final dialogContext = context;
              await DataService.deleteMedal(medal.id);
              await _loadMedals();
              Navigator.pop(dialogContext);
              
              if (mounted) {
                final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('徽章刪除成功')),
                );
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditMedalDialog(medal),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteMedal(medal),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
} 