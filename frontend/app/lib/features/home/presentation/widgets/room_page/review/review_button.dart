import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReviewButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ReviewButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width; // 화면 전체 너비

    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: screenWidth * 0.8, // 화면 너비의 80%
          height: 31,
          child: Stack(
            children: [
              // 버튼 배경
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: screenWidth * 0.8, // 동일하게 80% 너비
                  height: 31,
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0xFFF0B3AD)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              // 버튼 안의 SVG 아이콘
              Positioned(
                left: (screenWidth * 0.8) / 2 - 11, // 아이콘을 버튼 중앙에 배치
                top: 4,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: SvgPicture.asset(
                    'assets/icons/fi-rr-angle-small-down.svg', // SVG 파일 경로
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
