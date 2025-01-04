// file: lib/features/chat/presentation/widgets/chat_category_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/chat/providers/chat_category_provider.dart';

class ChatCategoryBar extends ConsumerWidget {
  const ChatCategoryBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 전역 provider 읽기
    ref.watch(chatCategoryProvider);

    return Row(
      children: [
        _buildChip(ref, label: '전체', category: ChatCategory.all, width: 53),
        const SizedBox(width: 8),
        _buildChip(ref, label: '모임', category: ChatCategory.meet, width: 53),
        const SizedBox(width: 8),
        _buildChip(ref, label: '배달', category: ChatCategory.delivery, width: 53),
        const SizedBox(width: 8),
        _buildChip(ref, label: '택시 · 카풀', category: ChatCategory.taxi, width: 88),
      ],
    );
  }

  /// 각 카테고리 Chip
  Widget _buildChip(
      WidgetRef ref, {
        required String label,
        required ChatCategory category,
        required double width,
      }) {
    final selectedCategory = ref.watch(chatCategoryProvider);
    final isSelected = (selectedCategory == category);

    final backgroundColor = isSelected ? const Color(0xFFE72410) : Colors.white;
    final textColor = isSelected ? Colors.white : Colors.black;
    final borderColor = isSelected ? const Color(0xFFE72410) : Colors.grey;

    return GestureDetector(
      onTap: () {
        // 탭 시 전역 상태 변경
        ref.read(chatCategoryProvider.notifier).state = category;
      },
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
