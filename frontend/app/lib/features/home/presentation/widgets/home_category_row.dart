import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart'; // SVG 사용을 위한 import
import '../../data/models/category.dart';
import '../../providers/category_provider.dart';

class CategoryRow extends ConsumerWidget {
  const CategoryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(categoryProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = selectedCategory == category;
          return GestureDetector(
            onTap: () => ref.read(categoryProvider.notifier).selectCategory(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE72410) : Colors.white, // 배경색
                borderRadius: BorderRadius.circular(43),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1C000000),
                    blurRadius: 6.90,
                  ),
                ],
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    '${category.iconPath}', // 아이콘 경로
                    width: 13,
                    height: 13,
                    color: isSelected ? Colors.white : const Color(0xFFE72410), // 아이콘 색상
                  ),
                  const SizedBox(width: 7), // 텍스트와 아이콘 간 간격
                  Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black, // 텍스트 색상
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
