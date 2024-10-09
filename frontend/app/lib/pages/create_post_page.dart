//meet_page에서 게시글 생성시 출력페이지
import 'package:flutter/material.dart';

class CreatePostPage extends StatefulWidget {
  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  String selectedCategory = "모임"; // 기본 선택된 카테고리
  String selectedPeopleCount = "1명"; // 기본 선택된 인원수
  final _titleController = TextEditingController(); // 제목 컨트롤러
  final _descriptionController = TextEditingController(); // 설명 컨트롤러

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('게시글 작성', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop(); // 닫기 버튼 눌렀을 때 페이지 닫기
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              // 게시글 저장 기능 구현
            },
            child: Text(
              '만들기',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 입력란
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '채팅방 이름을 입력해주세요.',
                labelStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none, // 하단의 검은선 제거
              ),
            ),
            Divider(color: Colors.red, thickness: 1.0), // 제목과 설명 구분선 추가

            // 소개 입력란
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '채팅방을 소개해주세요',
                labelStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none, // 하단의 검은선 제거
              ),
            ),
            SizedBox(height: 16),

            // 카테고리 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('채팅방 설정', style: TextStyle(fontWeight: FontWeight.bold)),
                Icon(Icons.arrow_drop_down),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                PostCategoryButton(
                  text: "모임",
                  isSelected: selectedCategory == "모임",
                  onPressed: () {
                    setState(() {
                      selectedCategory = "모임";
                    });
                  },
                ),
                PostCategoryButton(
                  text: "배달",
                  isSelected: selectedCategory == "배달",
                  onPressed: () {
                    setState(() {
                      selectedCategory = "배달";
                    });
                  },
                ),
                PostCategoryButton(
                  text: "택시 · 카풀",
                  isSelected: selectedCategory == "택시 · 카풀",
                  onPressed: () {
                    setState(() {
                      selectedCategory = "택시 · 카풀";
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16),

            // 인원수 선택
            Text('인원수', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                PeopleCountButton(
                  text: "1명",
                  isSelected: selectedPeopleCount == "1명",
                  onPressed: () {
                    setState(() {
                      selectedPeopleCount = "1명";
                    });
                  },
                ),
                PeopleCountButton(
                  text: "2명",
                  isSelected: selectedPeopleCount == "2명",
                  onPressed: () {
                    setState(() {
                      selectedPeopleCount = "2명";
                    });
                  },
                ),
                PeopleCountButton(
                  text: "3명",
                  isSelected: selectedPeopleCount == "3명",
                  onPressed: () {
                    setState(() {
                      selectedPeopleCount = "3명";
                    });
                  },
                ),
                PeopleCountButton(
                  text: "제한없음",
                  isSelected: selectedPeopleCount == "제한없음",
                  onPressed: () {
                    setState(() {
                      selectedPeopleCount = "제한없음";
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// PostCategoryButton으로 이름 변경
class PostCategoryButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onPressed;

  PostCategoryButton({required this.text, required this.isSelected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: isSelected ? Colors.white : Colors.red, backgroundColor: isSelected ? Colors.red : Colors.white,
          side: BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}

class PeopleCountButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onPressed;

  PeopleCountButton({required this.text, required this.isSelected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: isSelected ? Colors.white : Colors.black, backgroundColor: isSelected ? Colors.red : Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}
