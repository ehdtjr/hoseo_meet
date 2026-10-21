import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AddShowButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AddShowButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: screenWidth * 0.8,
          height: 31,
          child: Stack(
            children: [
              // 버튼 배경
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: screenWidth * 0.8,
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
              // 가운데 SVG 아이콘
              Positioned(
                left: (screenWidth * 0.8) / 2 - 11, // 중심 정렬
                top: 4.5,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: SvgPicture.asset(
                    'assets/icons/fi-rr-angle-small-down.svg', // 아이콘 경로 (ReviewButton과 동일)
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
