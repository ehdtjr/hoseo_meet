// file: lib/features/navigation/widgets/app_bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BottomNavItem {
  final IconData? icon;
  final String? svgAsset;
  final String? label;

  BottomNavItem({
    this.icon,
    this.svgAsset,
    this.label,
  });
}

class AppBottomNavBar extends StatelessWidget {
  final double barHeight;
  final Color backgroundColor;
  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNavBar({
    super.key,
    this.barHeight = 74.0,
    this.backgroundColor = Colors.white,
    required this.items,
    this.currentIndex = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / items.length;

    return Container(
      width: screenWidth,
      height: barHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 19.70,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = (index == currentIndex);

          // 선택된 탭이면 빨간색, 아니면 #404040
          final iconColor = selected ? Colors.red : const Color(0xFF404040);

          return SizedBox(
            width: itemWidth,
            height: barHeight,
            // Material + InkWell로 터치 효과
            child: Material(
              color: Colors.transparent, // 배경 투명 (바텀 바 배경은 부모가 이미 흰색)
              child: InkWell(
                onTap: () => onTap?.call(index),
                // (A) Hover/Tap 시 회색 음영 효과가 표시됨
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // (B) 선택된 탭이면 맨 윗 부분 라인
                    if (selected) ...[
                      Container(
                        width: 57,
                        height: 2,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 6), // 라인과 아이콘 사이 간격
                    ],

                    // (C) 아이콘 + 라벨을 감싸는 패딩
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          // 아이콘 or SVG
                          if (item.svgAsset != null)
                            SvgPicture.asset(
                              item.svgAsset!,
                              width: 24,
                              height: 24,
                              colorFilter: ColorFilter.mode(
                                iconColor,
                                BlendMode.srcIn
                              ),
                            )
                          else if (item.icon != null)
                            Icon(
                              item.icon,
                              size: 24,
                              color: iconColor,
                            ),

                          // 라벨
                          if (item.label != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.label!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: iconColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
