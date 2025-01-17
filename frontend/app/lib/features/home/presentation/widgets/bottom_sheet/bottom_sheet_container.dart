import 'package:flutter/material.dart';
import '../../../../auth/data/models/user.dart';
import '../../../data/models/category.dart';
import 'bottom_sheet_header.dart'; // 수정된 헤더 위젯 import

class BottomSheetContainer extends StatelessWidget {
  final ScrollController scrollController;
  final Category? selectedCategory; // 선택된 카테고리 (null 가능)
  final String userName;

  const BottomSheetContainer({
    super.key,
    required this.scrollController,
    required UserProfile userProfile,
    required this.selectedCategory,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    // 카테고리별 드롭다운 항목
    final dropdownItems = _getDropdownItems(selectedCategory);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // 좌우 20px 패딩, 상단 8px
            child: Center(
              child: Container(
                height: 2, // 높이
                width: 168, // 너비
                color: const Color(0xFFE72410), // 선 색상
              ),
            ),
          ),
          // 동적 헤더
          BottomSheetHeader(
            category: selectedCategory?.name, // 카테고리 이름 전달
            userName: userName,
            dropdownItems: dropdownItems,
            onDropdownItemSelected: (String selectedItem) {
              print('선택된 항목: $selectedItem');
            },
          ),
          const SizedBox(height: 16), // 헤더 아래 여백
          // 리스트 아이템
          ...List.generate(
            10,
                (index) => ListTile(
              leading: const Icon(Icons.place),
              title: Text('게시글 ${index + 1}'),
            ),
          ),
        ],
      ),
    );
  }

  // 카테고리별 드롭다운 항목 설정
  List<String> _getDropdownItems(Category? category) {
    if (category == null) {
      return ['전체', '거리순']; // 카테고리가 선택되지 않았을 경우
    }

    switch (category.name) {
      case '자취방':
        return ['전체', '보증금순', '월세순'];
      case '음식점':
        return ['전체', '별점순', '거리순', '리뷰순'];
      case '카페':
        return ['전체', '거리순', '별점순'];
      case '술집':
        return ['전체', '인기순', '별점순'];
      case '편의점':
        return ['전체', '거리순', '편의성순'];
      default:
        return ['전체', '기본순'];
    }
  }
}
