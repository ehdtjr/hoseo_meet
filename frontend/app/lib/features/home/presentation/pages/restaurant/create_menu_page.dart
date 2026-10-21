import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/restaurant/menu/restaurant_menu_provider.dart';
import '../../widgets/restaurant/menu/menu_Image_picker_screen.dart';

class MenuCreatePage extends ConsumerStatefulWidget {
  final int postId;

  const MenuCreatePage({super.key, required this.postId});

  @override
  ConsumerState<MenuCreatePage> createState() => _MenuCreatePageState();
}

class _MenuCreatePageState extends ConsumerState<MenuCreatePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  File? _selectedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const MenuImagePickerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _selectedImage = File(result);
      });
    }
  }

  Future<void> _saveMenu() async {
    final name = _nameController.text.trim();
    final price = int.tryParse(_priceController.text.trim()) ?? 0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름과 가격을 올바르게 입력해주세요.')),
      );
      return;
    }

    await ref.read(restaurantMenuProvider.notifier).createMenuInState(
      name: name,
      price: price,
      postId: widget.postId,
      imageFile: _selectedImage,
    );

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.red;
    const textColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('메뉴 추가'),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: _selectedImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              )
                  : Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_a_photo, size: 40, color: primaryColor),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '메뉴 이름',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '가격',
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: textColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _saveMenu,
                child: const Text(
                  '저장하기',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
