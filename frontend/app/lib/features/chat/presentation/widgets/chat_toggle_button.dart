import 'package:flutter/material.dart';

class ToggleCircleButton extends StatefulWidget {
  const ToggleCircleButton({super.key});

  @override
  _ToggleCircleButtonState createState() => _ToggleCircleButtonState();
}

class _ToggleCircleButtonState extends State<ToggleCircleButton> {
  bool _isToggled = false; // 토글 상태

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isToggled = !_isToggled; // 상태 변경
        });
      },
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
              color: _isToggled ? const Color(0xFFE72410) : Colors.white, // 토글 상태에 따라 색상 변경
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
