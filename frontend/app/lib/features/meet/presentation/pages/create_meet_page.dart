import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/meet_post_provider.dart';

class CreateMeetPage extends ConsumerStatefulWidget {
  const CreateMeetPage({super.key});

  @override
  ConsumerState<CreateMeetPage> createState() => _CreateMeetPageState();
}

class _CreateMeetPageState extends ConsumerState<CreateMeetPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = '모임'; // 초기 카테고리
  int _selectedMaxPeople = 1; // 초기 인원 수

  // 카테고리 매핑 (보이는 값 -> 서버 전송 값)
  final Map<String, String> categoryMapping = {
    '모임': 'meet',
    '배달': 'delivery',
    '택시 카풀': 'taxi',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

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
              controller: _titleController,
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
              controller: _contentController,
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
              children: List.generate(10, (index) {
                final peopleOptions = List.generate(10, (i) => '${i + 1}명');
                return _buildPeopleButton(peopleOptions[index], index + 1);
              }),
            ),
            const Spacer(),

            // 만들기 버튼
            Center(
              child: SizedBox(
                width: 150,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    // 데이터 생성 요청
                    final notifier = ref.read(meetPostProvider.notifier);
                    try {
                      final categoryForServer = categoryMapping[_selectedCategory] ?? 'meet';
                      await notifier.createMeetPost(
                        title: _titleController.text,
                        type: categoryForServer, // 서버로 전송할 값 사용
                        content: _contentController.text,
                        maxPeople: _selectedMaxPeople,
                      );
                      // 성공 시 이전 화면으로 돌아가기
                      Navigator.pop(context, true);
                    } catch (e) {
                      _showErrorDialog(context, '모임 생성 중 오류가 발생했습니다.');
                    }
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
    final isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: ShapeDecoration(
          color: isSelected ? const Color(0xFFE72410) : Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0xFFE72410)),
            borderRadius: BorderRadius.circular(43),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFE72410),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 인원수 버튼 위젯
  Widget _buildPeopleButton(String title, int value) {
    final isSelected = _selectedMaxPeople == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMaxPeople = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: ShapeDecoration(
          color: isSelected ? const Color(0xFFE72410) : Colors.white,
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
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}
