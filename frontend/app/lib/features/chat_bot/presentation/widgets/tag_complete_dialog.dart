import 'package:flutter/material.dart';
import '../../../navigation/presentation/pages/main_tab_page.dart';

class TagCompleteDialog extends StatelessWidget {
  const TagCompleteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white, // 💡 완전한 흰 배경
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.tag, color: Color(0xFFE72410)),
          SizedBox(width: 8),
          Text(
            '태그 생성 완료',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Text(
        '대화를 바탕으로 맞춤 태그를 생성했어요.\n이제 메인 화면으로 이동합니다.',
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainTabPage()),
            );
          },
          child: const Text('확인', style: TextStyle(color: Color(0xFFE72410))),
        ),
      ],
    );
  }
}
