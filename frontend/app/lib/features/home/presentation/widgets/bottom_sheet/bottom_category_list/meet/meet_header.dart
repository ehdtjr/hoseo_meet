import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../meet/providers/meet_post_category_provider.dart';
import '../../../../../../meet/providers/meet_post_provider.dart';

class MeetHeaderWidget extends ConsumerWidget {
  final String userName;

  const MeetHeaderWidget({
    super.key,
    required this.userName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 사용자 이름이 4글자 초과 시 생략 처리
    final displayUserName = userName.length > 4
        ? '${userName.substring(0, 4)}...' // 4글자만 남기고 "..." 추가
        : userName;

    // 현재 선택된 카테고리 구독
    final selectedCategory = ref.watch(meetPostCategoryProvider);

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
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: displayUserName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      const TextSpan(
                        text: '님을 기다리고 있어요!',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  maxLines: 1,
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
                child: DropdownButton<MeetPostCategory>(
                  dropdownColor: Colors.white,
                  value: selectedCategory,
                  isDense: true,
                  menuMaxHeight: 200,
                  items: MeetPostCategory.values
                      .map((category) => _buildMenuItem(category))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(meetPostCategoryProvider.notifier).state = value;
                      ref.read(meetPostProvider.notifier).resetAndLoad();
                    }
                  },
                  // 선택된 항목의 텍스트 스타일을 #5F5F5F로 설정
                  style: const TextStyle(color: Color(0xFF5F5F5F), fontSize: 14),
                  icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF5F5F5F)),
                  // 선택된 항목의 위젯을 커스터마이징하여 확실하게 #5F5F5F로 표시
                  selectedItemBuilder: (BuildContext context) {
                    return MeetPostCategory.values.map((category) {
                      final categoryText = _categoryToString(category);
                      return Text(
                        categoryText,
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

  DropdownMenuItem<MeetPostCategory> _buildMenuItem(MeetPostCategory category) {
    // 카테고리를 텍스트로 변환
    final categoryText = _categoryToString(category);
    return DropdownMenuItem(
      value: category,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          categoryText,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF9F9F9F),
          ),
        ),
      ),
    );
  }

  String _categoryToString(MeetPostCategory category) {
    switch (category) {
      case MeetPostCategory.all:
        return '전체';
      case MeetPostCategory.meet:
        return '모임';
      case MeetPostCategory.delivery:
        return '배달';
      case MeetPostCategory.taxi:
        return '택시';
      default:
        return '알 수 없음';
    }
  }
}
