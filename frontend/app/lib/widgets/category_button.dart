import 'package:flutter/material.dart';

class CategoryButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onPressed;

  const CategoryButton({
    Key? key,
    required this.text,
    this.isSelected = false,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0), // 버튼 간격을 조정
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6), // 세로 패딩을 줄여 버튼 크기를 줄임
          minimumSize: Size(60, 36), // 최소 크기를 설정하여 세로 크기를 줄임
          backgroundColor: isSelected ? Colors.red : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // 텍스트 스타일 조정
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // 버튼 모서리를 둥글게 조정
          ),
          side: BorderSide(color: Colors.grey.shade300), // 외곽선 추가
        ),
        child: Text(text),
      ),
    );
  }
}
