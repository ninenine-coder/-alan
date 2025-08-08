import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'data_service.dart';

class AdminStoreManagementPage extends StatefulWidget {
  const AdminStoreManagementPage({super.key});

  @override
  State<AdminStoreManagementPage> createState() => _AdminStoreManagementPageState();
}

class _AdminStoreManagementPageState extends State<AdminStoreManagementPage> {
  final List<String> categories = ['造型', '裝飾', '語氣', '動作', '飼料'];
  final Map<String, IconData> categoryIcons = {
    '造型': Icons.face,
    '裝飾': Icons.diamond,
    '語氣': Icons.chat_bubble,
    '動作': Icons.directions_run,
    '飼料': Icons.restaurant,
  };
  
  List<StoreItem> storeItems = [];
  String selectedCategory = '造型';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoreItems();
  }

  Future<void> _loadStoreItems() async {
    setState(() {
      isLoading = true;
    });

    final items = await DataService.getStoreItems();
    
    setState(() {
      storeItems = items;
      isLoading = false;
    });
  }

  Future<File?> _pickImage() async {
    try {
      developer.log('Starting image picker...');
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        developer.log('Image selected: ${image.path}');
        final file = File(image.path);
        
        // 檢查檔案是否存在
        if (await file.exists()) {
          developer.log('Selected image file exists and is accessible');
          return file;
        } else {
          developer.log('Error: Selected image file does not exist: ${image.path}');
          return null;
        }
      } else {
        developer.log('No image selected');
        return null;
      }
    } catch (e) {
      developer.log('Error picking image: $e');
      developer.log('Error details: ${e.toString()}');
      // 顯示錯誤訊息給使用者
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('選擇圖片時發生錯誤: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = this.selectedCategory; // 使用類別成員變數的初始值
    String selectedRarity = '常見';
    String selectedIconName = 'shopping_bag';
    File? selectedImage;
    File? uploadedImage; // 新增：用於存儲已上傳的圖片

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // 添加調試信息
          developer.log('Dialog state - selectedImage: ${selectedImage?.path}');
          developer.log('Dialog state - uploadedImage: ${uploadedImage?.path}');
          
          return AlertDialog(
            title: const Text('新增商品'),
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
                    child: uploadedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              uploadedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                              errorBuilder: (context, error, stackTrace) {
                                developer.log('Error loading image: $error');
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
                                uploadedImage != null ? '圖片已上傳' : '點擊選擇商品圖片',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  // 圖片選擇按鈕
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        developer.log('Image selection button pressed');
                        final image = await _pickImage();
                        if (image != null) {
                          developer.log('Image picked successfully: ${image.path}');
                          setDialogState(() {
                            selectedImage = image;
                          });
                          developer.log('Selected image set in state: ${selectedImage?.path}');
                        } else {
                          developer.log('No image selected or error occurred');
                        }
                      } catch (e) {
                        developer.log('Error in image selection button: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('選擇圖片時發生錯誤: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('選擇圖片'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade700,
                    ),
                  ),
                  // 上傳按鈕（僅在選擇圖片後顯示）
                  if (selectedImage != null && uploadedImage == null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        developer.log('Upload button pressed');
                        developer.log('Selected image: ${selectedImage?.path}');
                        setDialogState(() {
                          uploadedImage = selectedImage;
                          selectedImage = null; // 清除選擇的圖片，避免重複上傳
                        });
                        developer.log('Uploaded image set: ${uploadedImage?.path}');
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
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: '類別'),
                    items: categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '商品名稱'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: '價格'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: '描述'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRarity,
                    decoration: const InputDecoration(labelText: '稀有度'),
                    items: ['常見', '普通', '稀有'].map((rarity) {
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
                  try {
                    if (nameController.text.isNotEmpty && 
                        priceController.text.isNotEmpty &&
                        descriptionController.text.isNotEmpty) {
                      
                                             developer.log('Creating new item...');
                       final itemId = '$selectedCategory-${DateTime.now().millisecondsSinceEpoch}';
                      String? imagePath;
                      
                      // 保存圖片
                      if (uploadedImage != null) {
                        developer.log('Saving image for item: $itemId');
                        try {
                          imagePath = await DataService.saveImage(uploadedImage!, itemId);
                          if (imagePath != null) {
                            developer.log('Image saved successfully: $imagePath');
                          } else {
                            developer.log('Failed to save image');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('圖片保存失敗，但商品已新增'),
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
                                content: Text('圖片保存失敗: ${imageError.toString()}'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      } else {
                        developer.log('No image selected for this item');
                      }
                      
                      final newItem = StoreItem(
                        id: itemId,
                        name: nameController.text,
                        price: int.tryParse(priceController.text) ?? 0,
                        description: descriptionController.text,
                        category: selectedCategory,
                        rarity: selectedRarity,
                        iconName: selectedIconName,
                        imagePath: imagePath,
                      );
                      
                      developer.log('Adding new item to database...');
                      await DataService.addStoreItem(newItem);
                      
                      if (mounted) {
                        await _loadStoreItems();
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(imagePath != null ? '商品新增成功' : '商品新增成功（圖片保存失敗）'),
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
                    developer.log('Error creating item: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('新增商品時發生錯誤: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('新增'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditItemDialog(StoreItem item) {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(text: item.price.toString());
    final descriptionController = TextEditingController(text: item.description);
    String selectedRarity = item.rarity;
    File? selectedImage;
    String? currentImagePath = item.imagePath;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('編輯商品'),
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
                              developer.log('Error loading image: $error');
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
                                  developer.log('Error loading image: $error');
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
                                  '點擊選擇商品圖片',
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
                          final image = await _pickImage();
                          if (image != null) {
                            setDialogState(() {
                              selectedImage = image;
                              currentImagePath = null;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library),
                        label: const Text('選擇新圖片'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue.shade700,
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
                  decoration: const InputDecoration(labelText: '商品名稱'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: '價格'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: '描述'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRarity,
                  decoration: const InputDecoration(labelText: '稀有度'),
                  items: ['常見', '普通', '稀有'].map((rarity) {
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
                if (nameController.text.isNotEmpty && 
                    priceController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty) {
                  
                  String? imagePath = currentImagePath;
                  
                  // 如果有新選擇的圖片，保存它
                  if (selectedImage != null) {
                    // 刪除舊圖片
                    if (currentImagePath != null) {
                      await DataService.deleteImage(currentImagePath);
                    }
                    // 保存新圖片
                    imagePath = await DataService.saveImage(selectedImage!, item.id);
                  } else if (currentImagePath == null && item.imagePath != null) {
                    // 如果移除了圖片，刪除舊圖片
                    await DataService.deleteImage(item.imagePath);
                    imagePath = null;
                  }
                  
                  final updatedItem = StoreItem(
                    id: item.id,
                    name: nameController.text,
                    price: int.tryParse(priceController.text) ?? 0,
                    description: descriptionController.text,
                    category: item.category,
                    rarity: selectedRarity,
                    iconName: item.iconName,
                    imagePath: imagePath,
                  );
                  
                  await DataService.updateStoreItem(updatedItem);
                  await _loadStoreItems();
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('商品更新成功')),
                  );
                }
              },
              child: const Text('更新'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(StoreItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除商品「${item.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await DataService.deleteStoreItem(item.id);
              await _loadStoreItems();
              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('商品刪除成功')),
              );
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

  List<StoreItem> get filteredItems {
    return storeItems.where((item) => item.category == selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商城管理'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddItemDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 類別選擇器
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                      avatar: Icon(categoryIcons[category]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // 商品列表
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '此類別尚無商品',
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
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: item.imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: Image.file(
                                          File(item.imagePath!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                categoryIcons[item.category],
                                                color: Colors.blue.shade600,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Icon(
                                        categoryIcons[item.category],
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                              title: Text(item.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.description),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getRarityColor(item.rarity),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          item.rarity,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.monetization_on,
                                        size: 16,
                                        color: Colors.amber.shade600,
                                      ),
                                      Text(
                                        ' ${item.price}',
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
                                    onPressed: () => _showEditItemDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _deleteItem(item),
                                    color: Colors.red,
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