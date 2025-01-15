import 'package:flutter/material.dart';

class CreateMeetPage extends StatelessWidget {
  const CreateMeetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '모임 생성',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 채팅방 이름 입력 필드
            const Text(
              '채팅방 이름을 입력해주세요.',
              style: TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: '채팅방 이름',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 채팅방 소개 입력 필드
            const Text(
              '채팅방을 소개해주세요.',
              style: TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '채팅방 소개',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 카테고리 선택 버튼
            const Text(
              '카테고리',
              style: TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCategoryButton('모임'),
                const SizedBox(width: 10),
                _buildCategoryButton('배달'),
                const SizedBox(width: 10),
                _buildCategoryButton('택시 카풀'),
              ],
            ),
            const SizedBox(height: 20),

            // 인원수 선택 버튼
            const Text(
              '인원수',
              style: TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(6, (index) {
                final peopleOptions = ['1명', '2명', '3명', '4명', '5명', '제한없음'];
                return _buildPeopleButton(peopleOptions[index]);
              }),
            ),
            const Spacer(),

            // 만들기 버튼
            Center(
              child: SizedBox(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // 만들기 버튼 클릭 시 동작
                    print('모임 생성 버튼 클릭');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE72410),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                  child: const Text(
                    '만들기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 카테고리 버튼 위젯
  Widget _buildCategoryButton(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFE72410)),
          borderRadius: BorderRadius.circular(43),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFE72410),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // 인원수 버튼 위젯
  Widget _buildPeopleButton(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(43),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 9.40,
            offset: Offset(0, 0),
            spreadRadius: 0,
          )
        ],
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
