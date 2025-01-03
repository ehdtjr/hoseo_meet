import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'CHAT',
            style: TextStyle(
              color: Color(0xFFE72410),
              fontSize: 26,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              height: 1.60,
            ),
          ),

          // 아이콘을 둥근 영역 안에 배치, 터치 시 연한 회색 효과
          Material(
            color: Colors.transparent,
            child: InkWell(
              // (A) 둥근 영역 설정
              customBorder: const CircleBorder(),
              // (B) 터치 효과 색: 연한 회색
              splashColor: Colors.grey[300],
              highlightColor: Colors.grey[200],

              onTap: () {
                // TODO: 동작
              },
              // (C) 아이콘 주위에 약간 패딩을 둬서 터치하기 편하게
              child: const Padding(
                padding: EdgeInsets.all(1.0),
                child: Icon(
                  Icons.more_vert,
                  color: Color(0xFFE72410),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
