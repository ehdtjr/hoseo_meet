import 'package:flutter/material.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 프로필 섹션
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[300],
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "박소정",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "zeong231",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "호서대학교",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 32, thickness: 1, color: Colors.grey[300]),
          // 메뉴 섹션
          ..._buildMenuSection(
            "계정",
            ["아이디", "비밀번호 변경", "이메일 변경"],
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
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
      ...items.map((item) => ListTile(
        title: Text(
          item,
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () {
          // 여기에 각 항목별 동작 추가
        },
      )),
      Divider(height: 24, thickness: 1, color: Colors.grey[300]),
    ];
  }
}
