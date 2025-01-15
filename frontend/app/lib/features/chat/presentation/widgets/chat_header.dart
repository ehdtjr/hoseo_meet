import 'package:flutter/material.dart';

class ChatHeader extends StatefulWidget {
  const ChatHeader({super.key});

  @override
  _ChatHeaderState createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  bool _isExitToggled = false; // 나가기 버튼 토글 상태

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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

          const Spacer(),

          // 나가기 버튼 (배경색만 토글)
          SizedBox(
            width: 52,
            height: 28,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isExitToggled = !_isExitToggled; // 토글 상태 변경
                });
              },
              child: Container(
                decoration: ShapeDecoration(
                  color: Colors.white, // 큰 컨테이너의 배경색
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0xFFE72410)), // 테두리 고정
                    borderRadius: BorderRadius.circular(13),
                  ),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 4,
                      offset: Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: _isExitToggled
                      ? Container(
                    width: 47,
                    height: 23,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFE72410), // 작은 컨테이너 배경 빨간색
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '나가기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  )
                      : const Text(
                    '나가기',
                    style: TextStyle(
                      color: Color(0xFFE72410),
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 아이콘을 둥근 영역 안에 배치, 터치 시 연한 회색 효과
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              splashColor: Colors.grey[300],
              highlightColor: Colors.grey[200],
              onTap: () {
                // TODO: 동작
              },
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
