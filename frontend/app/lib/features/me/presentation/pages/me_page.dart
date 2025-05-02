import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/user_profile_provider.dart';

class MePage extends ConsumerStatefulWidget {
  const MePage({Key? key}) : super(key: key);

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> {
  @override
  void initState() {
    super.initState();
    // 페이지 초기 로드시 프로필 정보를 불러옵니다.
    Future.microtask(() =>
        ref.read(userProfileNotifierProvider.notifier).fetchUserProfile());
  }

  @override
  Widget build(BuildContext context) {
    final userProfileState = ref.watch(userProfileNotifierProvider);
    final userProfile = userProfileState.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "프로필",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: userProfileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 프로필 섹션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 38.5, // 77x77 크기
                    backgroundColor: Colors.grey[300],
                    child: userProfile != null &&
                        userProfile.profile != null
                        ? ClipOval(
                      child: Image.network(
                        userProfile.profile!,
                        fit: BoxFit.cover,
                        width: 77,
                        height: 77,
                      ),
                    )
                        : const Icon(Icons.person,
                        size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            userProfile?.name ?? '이름 없음',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "·",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE72410),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            userProfile?.name?? 'username 없음',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "호서대학교",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFFE72410),
              ),
            ],
          ),
          const Divider(
            height: 32,
            thickness: 1,
            color: Color(0xFFF0B4AD),
          ),
          // 메뉴 섹션
          ..._buildMenuSection(
            "계정",
            ["이메일 변경", "비밀번호 변경"],
          ),
          ..._buildMenuSection(
            "게시글",
            ["내가 작성한 글", "관심 게시글", "이용규칙"],
          ),
          ..._buildMenuSection(
            "이용 안내",
            ["앱 버전", "문의하기"],
          ),
          ..._buildMenuSection(
            "기타",
            ["자주 묻는 질문", "약관 및 정책", "회원 탈퇴", "로그아웃"],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuSection(String title, List<String> items) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      ...items.map(
            (item) => ListTile(
          title: Text(
            item,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          trailing: const Icon(Icons.arrow_forward_ios,
              size: 16, color: Colors.grey),
          onTap: () {
            // 각 메뉴 항목별 동작을 여기에 구현합니다.
          },
        ),
      ),
      const Divider(
        height: 24,
        thickness: 1,
        color: Color(0xFFF0B4AD),
      ),
    ];
  }
}
