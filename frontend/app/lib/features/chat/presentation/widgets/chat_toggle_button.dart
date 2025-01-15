import 'package:flutter/material.dart';

class ToggleCircleButton extends StatelessWidget {
  final bool isSelected; // 부모로부터 전달받는 선택 상태
  final VoidCallback onTap; // 부모로부터 전달받는 onTap 콜백

  const ToggleCircleButton({
    super.key,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // 부모 콜백 호출
      child: Container(
        width: 21,
        height: 21,
        decoration: const ShapeDecoration(
          color: Colors.white,
          shape: OvalBorder(
            side: BorderSide(
              width: 1,
              color: Color(0xFFE72410),
            ),
          ),
        ),
        child: Center(
          child: Container(
            width: 14.79,
            height: 14.79,
            decoration: ShapeDecoration(
              color: isSelected ? const Color(0xFFE72410) : Colors.white, // 선택 상태에 따라 색상 변경
              shape: const OvalBorder(
                side: BorderSide(
                  width: 1,
                  color: Color(0xFFE72410),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
