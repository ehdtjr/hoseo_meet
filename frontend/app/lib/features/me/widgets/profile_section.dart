import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/tag_provider.dart';
import '../../auth/providers/user_profile_provider.dart';

class ProfileSection extends ConsumerStatefulWidget {
  const ProfileSection({super.key});

  @override
  ConsumerState<ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<ProfileSection> {
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(tagNotifierProvider.notifier).fetchTags();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasFetched) {
      _hasFetched = true;
      Future.microtask(() {
        ref.read(tagNotifierProvider.notifier).fetchTags();
      });
    }
  }

  /// 카테고리 분류 맵
  static const Map<String, String> tagCategories = {
    "커피": "음료",
    "술": "음료",
    "차": "음료",
    "주스": "음료",
    "와인": "음료",
    "맥주": "음료",
    //
    "한식": "음식",
    "중식": "음식",
    "일식": "음식",
    "양식": "음식",
    "분식": "음식",
    "패스트푸드": "음식",
    "디저트": "음식",
    "맛집": "음식",
    //
    "음악": "음악",
    "팝송": "음악",
    "힙합": "음악",
    "클래식": "음악",
    "EDM": "음악",
    "밴드": "음악",
    //
    "게임": "게임",
    "rpg": "게임",
    "fps": "게임",
    "보드게임": "게임",
    //
    "운동": "운동",
    "헬스": "운동",
    "등산": "운동",
    "러닝": "운동",
    "요가": "운동",
    //
    "여행": "여행",
    "자연": "여행",
    "캠핑": "여행",
    "호텔": "여행",
    "펜션": "여행",
    //
    "AI": "기술",
    "GPT": "기술",
    "개발": "기술",
    "프로그래밍": "기술",
    "UX": "기술",
    "디자인": "기술",
  };

  Color _getTagColor(String tag) {
    final category = tagCategories[tag] ?? "기타";

    switch (category) {
      case "음료":
        return const Color(0xFFFFE0B2); // 주황빛 파스텔
      case "음식":
        return const Color(0xFFFFCDD2); // 핑크빛 파스텔
      case "음악":
        return const Color(0xFFE1BEE7); // 연보라
      case "게임":
        return const Color(0xFFBBDEFB); // 연파랑
      case "운동":
        return const Color(0xFFC8E6C9); // 연녹색
      case "여행":
        return const Color(0xFFB2DFDB); // 민트
      case "기술":
        return const Color(0xFFFFF9C4); // 노랑 파스텔
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileState = ref.watch(userProfileNotifierProvider);
    final tagState = ref.watch(tagNotifierProvider);
    final userProfile = userProfileState.userProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사용자 정보
        Row(
          children: [
            CircleAvatar(
              radius: 38.5,
              backgroundColor: Colors.grey[300],
              child: userProfile != null && userProfile.profile.isNotEmpty
                  ? ClipOval(
                child: Image.network(
                  userProfile.profile,
                  fit: BoxFit.cover,
                  width: 77,
                  height: 77,
                ),
              )
                  : const Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userProfile?.name.isNotEmpty == true
                          ? userProfile!.name
                          : '비회원',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text("·",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE72410),
                        )),
                    const SizedBox(width: 6),
                    Text(
                      userProfile?.name.isNotEmpty == true
                          ? userProfile!.name
                          : '정보 없음',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 태그 표시
        if (tagState.isLoading)
          const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (tagState.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, top: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tagState.tags
                  .map((tag) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getTagColor(tag.name),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag.name,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ))
                  .toList(),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(left: 12.0, top: 8.0),
            child: Text(
              '태그 없음',
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
