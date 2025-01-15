import 'package:flutter/material.dart';
import 'package:hoseomeet/features/meet/providers/meet_post_category_provider.dart';


class CategoryBar extends StatelessWidget {
  final MeetPostCategory selectedCategory;
  final ValueChanged<MeetPostCategory> onCategorySelected;

  const CategoryBar({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildChip(label: '전체', category: MeetPostCategory.all, width: 53),
        const SizedBox(width: 8),
        _buildChip(label: '모임', category: MeetPostCategory.meet, width: 53),
        const SizedBox(width: 8),
        _buildChip(label: '배달', category: MeetPostCategory.delivery, width: 53),
        const SizedBox(width: 8),
        _buildChip(label: '택시 · 카풀', category: MeetPostCategory.taxi, width: 88),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required MeetPostCategory category,
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
