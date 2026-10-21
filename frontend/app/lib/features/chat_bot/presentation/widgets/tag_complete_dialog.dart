import 'package:flutter/material.dart';

class TagCompleteDialog extends StatelessWidget {
  final VoidCallback onComplete;

  const TagCompleteDialog({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),

      title: const Row(
        children: [
          Icon(Icons.sell_outlined, color: Color(0xFFE72410), size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '맞춤 태그를 준비할게요',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),

      content: const Text(
        '대화를 바탕으로 태그를 생성해드릴게요.',
        style: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: Colors.black87,
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onComplete();
          },
          child: const Text(
            '확인',
            style: TextStyle(
              color: Color(0xFFE72410),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
