import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/home/providers/room/room_post_category_provider.dart';

/// RoomHeaderWidget은 사용자 이름을 표시하고 카테고리 선택 드롭다운을 제공합니다.
class RoomHeaderWidget extends ConsumerWidget {
  final String userName;

  const RoomHeaderWidget({
    super.key,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 사용자 이름이 4글자 초과 시 생략 처리
    final displayUserName = userName.length > 4
        ? '${userName.substring(0, 4)}...'
        : userName;

    // 현재 선택된 카테고리 구독
    final selectedCategory = ref.watch(roomPostCategoryProvider);

    // 원하는 색상 코드
    const Color highlightColor = Color(0xFFE72410); // #E72410

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: '지금 ',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: displayUserName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: highlightColor,
                        ),
                      ),
                      const TextSpan(
                        text: '님 주위에 있는 ',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(
                        text: '자취방',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: highlightColor,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RoomPostCategory>(
                  dropdownColor: Colors.white,
                  value: selectedCategory,
                  isDense: true,
                  menuMaxHeight: 200,
                  items: RoomPostCategory.values.map((category) {
                    return DropdownMenuItem<RoomPostCategory>(
                      value: category,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _categoryToString(category),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9F9F9F),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (RoomPostCategory? value) {
                    if (value != null) {
                      ref.read(roomPostCategoryProvider.notifier).state = value;
                      // 카테고리 변경 시 데이터를 리셋하고 다시 로드하는 기능 추가 가능
                    }
                  },
                  style: const TextStyle(color: Color(0xFF5F5F5F), fontSize: 14),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: Color(0xFF5F5F5F),
                  ),
                  selectedItemBuilder: (BuildContext context) {
                    return RoomPostCategory.values.map((category) {
                      return Text(
                        _categoryToString(category),
                        style: const TextStyle(
                          color: Color(0xFF5F5F5F),
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// RoomPostCategory를 문자열로 변환합니다.
  String _categoryToString(RoomPostCategory category) {
    switch (category) {
      case RoomPostCategory.distance:
        return '거리순';
      case RoomPostCategory.rating:
        return '별점순';
      case RoomPostCategory.reviews:
        return '리뷰순';
      case RoomPostCategory.heart:
        return '찜목록';
      default:
        return '알 수 없음';
    }
  }
}
