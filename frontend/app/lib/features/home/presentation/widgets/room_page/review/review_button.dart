import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReviewButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ReviewButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: 381,
          height: 31,
          child: Stack(
            children: [
              // 버튼 배경
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: 381,
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
                left: 180,
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
