import 'package:campusmeet/features/me/presentation/pages/terms_of_user_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/pages/privacy_policy_page.dart';
import '../../../auth/presentation/pages/terms_policy_page.dart';
import '../../../auth/providers/auth_notifier_provider.dart';
import '../../../auth/providers/user_profile_provider.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';

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
                            userProfile?.name?.isNotEmpty == true ? userProfile!.name : '비회원',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          const Text("·",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE72410))),
                          const SizedBox(width: 6),
                          Text(
                            userProfile?.name?.isNotEmpty == true ? userProfile!.name : '정보 없음',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 32, thickness: 1, color: Color(0xFFF0B4AD)),

          // 메뉴 섹션
          ..._buildMenuSection("계정", ["프로필 변경", "비밀번호 변경"]),
 //         ..._buildMenuSection("게시글", ["내가 작성한 글"]),
          ..._buildMenuSection("이용 안내", ["이용 규칙","약관 및 정책", "개인정보 처리 방침"]),
          ..._buildMenuSection("기타", ["로그아웃", "회원 탈퇴"]),
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
            // TODO: 구현 필
              break;
            case "이용 규칙":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfUsePage()),
              );
              break;
            case "약관 및 정책":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsPolicyPage()),
              );
              case "개인정보 처리 방침":
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
              break;
            case "로그아웃":
              ref.read(authNotifierProvider.notifier).logout();
              break;
            case "회원 탈퇴":
            // TODO: 구현 필요
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