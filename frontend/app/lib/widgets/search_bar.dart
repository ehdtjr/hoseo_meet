import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 382,
      height: 42,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(21),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 7.30,
            offset: Offset(1, 4),
            spreadRadius: 0,
          )
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          // 예: 검색 아이콘
          const SizedBox(width: 8),
          // 검색어 입력 필드(또는 단순 텍스트)
          const Expanded(
            child: Text(
              '검색...',
            ),
          ),
          // 오른쪽 아이콘 (원래 Positioned(left=349, top=11)였던 부분)
          // 여기선 그냥 Row의 끝 부분에 배치
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 12),
            child: const FlutterLogo(), // or Icon(Icons.mic), etc.
          ),
        ],
      ),
    );
  }
}
