import 'package:flutter/material.dart';

class ChatHeader extends StatelessWidget {
  final bool isExitMode; // 부모로부터 전달받는 나가기 모드 상태
  final VoidCallback onToggleExitMode; // 나가기 버튼 클릭 시 호출할 콜백 함수

  const ChatHeader({
    super.key,
    required this.isExitMode,
    required this.onToggleExitMode,
  });

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

          // 나가기 버튼
          SizedBox(
            width: 52,
            height: 28,
            child: GestureDetector(
              onTap: onToggleExitMode, // 부모 콜백 호출
              child: Container(
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0xFFE72410)),
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
                  child: isExitMode
                      ? Container(
                    width: 47,
                    height: 23,
                    decoration: ShapeDecoration(
                      color: const Color(0xFFE72410),
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

          // 더보기 아이콘
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
