import 'package:flutter/material.dart';

import '../../../../chat/providers/chat_category_provider.dart';

class CategoryBar extends StatelessWidget {
  final ChatCategory selectedCategory;
  final ValueChanged<ChatCategory> onCategorySelected;

  const CategoryBar({
    Key? key,
    required this.selectedCategory,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip(label: '전체', category: ChatCategory.all, width: 53),
        const SizedBox(width: 8),
        _buildChip(label: '모임', category: ChatCategory.meet, width: 53),
        const SizedBox(width: 8),
        _buildChip(label: '배달', category: ChatCategory.delivery, width: 53),
        const SizedBox(width: 8),
        _buildChip(label: '택시 · 카풀', category: ChatCategory.taxi, width: 88),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required ChatCategory category,
    required double width,
  }) {
    final isSelected = (selectedCategory == category);

    final backgroundColor = isSelected ? const Color(0xFFE72410) : Colors.white;
    final textColor = isSelected ? Colors.white : Colors.black;
    final borderColor = isSelected ? const Color(0xFFE72410) : Colors.grey;

    return GestureDetector(
      onTap: () => onCategorySelected(category),
      child: SizedBox(
        width: width,
        height: 32,
        child: Container(
          decoration: ShapeDecoration(
            color: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(43),
              side: BorderSide(color: borderColor, width: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.60,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
