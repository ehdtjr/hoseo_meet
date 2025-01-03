import 'package:flutter/material.dart';

/// 채팅방 카테고리
enum ChatCategory { all, meet, delivery, taxiCarpool }

class ChatCategoryBar extends StatefulWidget {
  const ChatCategoryBar({Key? key}) : super(key: key);

  @override
  State<ChatCategoryBar> createState() => _ChatCategoryBarState();
}

class _ChatCategoryBarState extends State<ChatCategoryBar> {
  ChatCategory _selectedCategory = ChatCategory.all;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // (1) '전체'
        _buildChip(label: '전체', category: ChatCategory.all, width: 53),
        const SizedBox(width: 8),
        // (2) '모임'
        _buildChip(label: '모임', category: ChatCategory.meet, width: 53),
        const SizedBox(width: 8),
        // (3) '배달'
        _buildChip(label: '배달', category: ChatCategory.delivery, width: 53),
        const SizedBox(width: 8),
        // (4) '택시 · 카풀' (폭 88으로)
        _buildChip(label: '택시 · 카풀', category: ChatCategory.taxiCarpool, width: 88),
      ],
    );
  }

  /// width 파라미터로 폭을 조절 (기본 53, 택시 카풀은 88)
  Widget _buildChip({
    required String label,
    required ChatCategory category,
    required double width,
  }) {
    final isSelected = (_selectedCategory == category);

    // 선택/미선택 색상
    final backgroundColor = isSelected ? const Color(0xFFE72410) : Colors.white;
    final textColor = isSelected ? Colors.white : Colors.black;
    final borderColor = isSelected ? const Color(0xFFE72410) : Colors.grey;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = category);
      },
      child: SizedBox(
        width: width,   // 매개변수로 받은 폭
        height: 32,
        child: Container(
          decoration: ShapeDecoration(
            color: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(43),
              side: BorderSide(
                color: borderColor,
                width: 0.5,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.60,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
