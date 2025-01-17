import 'package:flutter/material.dart';

class BottomSheetHeader extends StatelessWidget {
  final String? category; // 카테고리 이름 (null 가능)
  final String userName; // 사용자 이름
  final List<String> dropdownItems; // 드롭다운 메뉴 항목
  final ValueChanged<String> onDropdownItemSelected; // 드롭다운 항목 선택 이벤트

  const BottomSheetHeader({
    super.key,
    required this.category,
    required this.userName,
    required this.dropdownItems,
    required this.onDropdownItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 동적 텍스트 생성
    String titleText;
    if (category == null) {
      titleText = '지금 $userName님을 기다리고 있어요!';
    } else {
      titleText = '지금 $userName님 주위에 있는 $category';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 제목
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            children: [
              const TextSpan(text: '지금 '),
              TextSpan(
                text: '$userName님',
                style: const TextStyle(color: Color(0xFFE72410)), // 빨간색
              ),
              if (category == null)
                const TextSpan(text: '을 기다리고 있어요!')
              else ...[
                const TextSpan(text: ' 주위에 있는 '),
                TextSpan(
                  text: category,
                  style: const TextStyle(color: Color(0xFFE72410)), // 빨간색
                ),
              ],
            ],
          ),
        ),
        // 드롭다운 버튼
        PopupMenuButton<String>(
          onSelected: onDropdownItemSelected, // 선택 이벤트 처리
          icon: const Icon(
            Icons.keyboard_arrow_down, // 드롭다운 아이콘
            size: 16,
            color: Colors.grey,
          ),
          itemBuilder: (BuildContext context) {
            return dropdownItems.map((String item) {
              return PopupMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey, // 텍스트 색상
                  ),
                ),
              );
            }).toList();
          },
        ),
      ],
    );
  }
}
