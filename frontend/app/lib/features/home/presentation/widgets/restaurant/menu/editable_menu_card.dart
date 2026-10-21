import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/restaurant/menu/restaurant_menu_provider.dart';
import '../../../../data/models/restaurant/restaurant_menu.dart';
import 'menu_Image_picker_screen.dart';

class EditableMenuCard extends ConsumerStatefulWidget {
  final RestaurantMenu menu;

  const EditableMenuCard({super.key, required this.menu});

  @override
  ConsumerState<EditableMenuCard> createState() => _EditableMenuCardState();
}

class _EditableMenuCardState extends ConsumerState<EditableMenuCard> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  File? _selectedImage;
  bool _isSaving = false; // ✅ 로딩 상태

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.menu.name);
    _priceController = TextEditingController(text: widget.menu.price.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, width: 100, height: 100, fit: BoxFit.cover)
                      : _buildImageOrPlaceholder(),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '메뉴 이름',
                      labelStyle: TextStyle(color: Colors.red),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '가격',
                      labelStyle: TextStyle(color: Colors.red),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () {
                          ref.read(restaurantMenuProvider.notifier).exitEditMode();
                        },
                        child: const Text("취소"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSaving ? null : _saveMenu,
                        child: _isSaving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text("저장"),
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildImageOrPlaceholder() {
    final isValidImage = widget.menu.image.isNotEmpty && widget.menu.image.startsWith('http');
    return isValidImage
        ? Image.network(widget.menu.image, width: 100, height: 100, fit: BoxFit.cover)
        : Container(
      width: 100,
      height: 100,
      color: Colors.grey[300],
      child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 36),
    );
  }

  Future<void> _pickImage() async {
    final selectedPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const MenuImagePickerScreen()),
    );

    if (selectedPath != null) {
      setState(() {
        _selectedImage = File(selectedPath);
      });
    }
  }

  Future<void> _saveMenu() async {
    setState(() {
      _isSaving = true;
    });

    final updated = widget.menu.copyWith(
      name: _nameController.text,
      price: int.tryParse(_priceController.text) ?? widget.menu.price,
      image: _selectedImage?.path ?? widget.menu.image,
    );

    await ref.read(restaurantMenuProvider.notifier).updateMenuInState(
      updated,
      imageFile: _selectedImage,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }
}
