import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/user_profile_provider.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart'; // ← 비밀번호 변경 페이지 import 추가

class MePage extends ConsumerStatefulWidget {
  const MePage({Key? key}) : super(key: key);

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> {
  @override
  void initState() {
    super.initState();
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: userProfileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 프로필 섹션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 38.5,
                    backgroundColor: Colors.grey[300],
                    child: userProfile != null
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
                            userProfile?.name ?? '이름 없음',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          const Text("·",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE72410))),
                          const SizedBox(width: 6),
                          Text(
                            userProfile?.name ?? 'username 없음',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text("호서대학",
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32, thickness: 1, color: Color(0xFFF0B4AD)),

          // 메뉴 섹션
          ..._buildMenuSection("계정", ["프로필 변경", "비밀번호 변경"]),
          ..._buildMenuSection("게시글", ["내가 작성한 글"]),
          ..._buildMenuSection("이용 안내", ["문의하기", "이용 규칙"]),
          ..._buildMenuSection("기타", ["자주 묻는 질문", "약관 및 정책", "회원 탈퇴"]),
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
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      ...items.map((item) => ListTile(
        title: Text(item,
            style: const TextStyle(fontSize: 16, color: Colors.black87)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          switch (item) {
            case "프로필 변경":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileImagePage()),
              );
              break;
            case "비밀번호 변경":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              );
              break;
            case "내가 작성한 글":
            // TODO: 해당 페이지로 이동 구현
              break;
            case "문의하기":
            // TODO: 해당 페이지로 이동 구현
              break;
            case "이용 규칙":
            // TODO: 해당 페이지로 이동 구현
              break;
            case "자주 묻는 질문":
            // TODO: 해당 페이지로 이동 구현
              break;
            case "약관 및 정책":
            // TODO: 해당 페이지로 이동 구현
              break;
            case "회원 탈퇴":
            // TODO: 해당 페이지로 이동 구현
              break;
            default:
              break;
          }
        },
      )),
      const Divider(height: 24, thickness: 1, color: Color(0xFFF0B4AD)),
    ];
  }
}
