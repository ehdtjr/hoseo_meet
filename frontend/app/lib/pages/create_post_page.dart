import 'package:flutter/material.dart';
import '../api/meet/create_post_service.dart';

class CreatePostPage extends StatefulWidget {
  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  String selectedCategory = "모임"; // 기본 선택된 카테고리
  String selectedPeopleCount = "2명"; // 기본 선택된 인원수
  final _titleController = TextEditingController(); // 제목 컨트롤러
  final _descriptionController = TextEditingController(); // 설명 컨트롤러
  final CreatePostService _createPostService = CreatePostService();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    try {
      await _createPostService.createPost(
        title: _titleController.text,
        type: _mapCategoryToType(selectedCategory),
        content: _descriptionController.text,
        maxPeople: int.parse(selectedPeopleCount.replaceAll("명", "")),
      );
      Navigator.of(context).pop(); // 성공 시 페이지 닫기
    } catch (error) {
      print('게시글 생성 오류: $error');
    }
  }

  String _mapCategoryToType(String category) {
    switch (category) {
      case "모임":
        return "meet";
      case "배달":
        return "delivery";
      case "택시":
        return "taxi";
      case "카풀":
        return "carpool";
      default:
        return "meet";
    }
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
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: _createPost,
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
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '채팅방 이름을 입력해주세요.',
                labelStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
            Divider(color: Colors.red, thickness: 1.0),

            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: '채팅방을 소개해주세요',
                labelStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
            SizedBox(height: 16),

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
                  text: "택시",
                  isSelected: selectedCategory == "택시",
                  onPressed: () {
                    setState(() {
                      selectedCategory = "택시";
                    });
                  },
                ),
                PostCategoryButton(
                  text: "카풀",
                  isSelected: selectedCategory == "카풀",
                  onPressed: () {
                    setState(() {
                      selectedCategory = "카풀";
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16),

            Text('인원수', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: List.generate(19, (index) {
                String peopleCount = "${index + 2}명";
                return PeopleCountButton(
                  text: peopleCount,
                  isSelected: selectedPeopleCount == peopleCount,
                  onPressed: () {
                    setState(() {
                      selectedPeopleCount = peopleCount;
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// 카테고리 버튼 위젯
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
          foregroundColor: isSelected ? Colors.white : Colors.red,
          backgroundColor: isSelected ? Colors.red : Colors.white,
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

// 인원수 버튼 위젯
class PeopleCountButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onPressed;

  PeopleCountButton({required this.text, required this.isSelected, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : Colors.black,
        backgroundColor: isSelected ? Colors.red : Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(text),
    );
  }
}
