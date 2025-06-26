import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/restaurant/menu/restaurant_menu_provider.dart';
import '../../../../data/models/restaurant/restaurant_menu.dart';
import 'editable_menu_card.dart';

class MenuItemCard extends ConsumerStatefulWidget {
  final RestaurantMenu menu;

  const MenuItemCard({super.key, required this.menu});

  @override
  ConsumerState<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends ConsumerState<MenuItemCard> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  File? _selectedImage;

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
    final menuState = ref.watch(restaurantMenuProvider);

    final isEditMode = menuState.maybeWhen(
      data: (state) => state.editMode,
      orElse: () => false,
    );

    final isEditingThisItem = menuState.maybeWhen(
      data: (state) =>
      state.editMode && state.selectedMenuForEdit?.id == widget.menu.id,
      orElse: () => false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: isEditingThisItem
          ? EditableMenuCard(menu: widget.menu)
          : _buildReadOnlyCard(isEditMode, isEditingThisItem),
    );
  }

  Widget _buildReadOnlyCard(bool isEditMode, bool isEditingThisItem) {
    final isValidImage = widget.menu.image.isNotEmpty && widget.menu.image.startsWith('http');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isValidImage
              ? Image.network(widget.menu.image, width: 100, height: 100, fit: BoxFit.cover)
              : _placeholderImage(),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: SizedBox(
            height: 100,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.menu.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                Text('${widget.menu.price}원',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
              ],
            ),
          ),
        ),
        if (isEditMode && !isEditingThisItem)
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () {
              ref.read(restaurantMenuProvider.notifier).enterEditMode(widget.menu);
            },
          ),
      ],
    );
  }


  Widget _placeholderImage() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[300],
      child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 36),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }
}
