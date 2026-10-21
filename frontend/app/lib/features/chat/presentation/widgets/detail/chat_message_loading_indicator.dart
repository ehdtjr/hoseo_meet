import 'package:flutter/material.dart';

class ChatMessageLoadingIndicator extends StatelessWidget {
  const ChatMessageLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.all(8.0),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(width: 10),
          Text(
            '이전 메시지를 불러오는 중...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
