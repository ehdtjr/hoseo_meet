import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MeetSearchBarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 382,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6.4,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0), // 전체 좌우 20pt 패딩
        child: Row(
          children: [
            Expanded(
              child: TextField(
                style: TextStyle(
                  color: Color(0xFF707070),
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                ),
                decoration: InputDecoration(
                  hintText: '찾으시는 채팅방이 있나요?',
                  hintStyle: TextStyle(
                    color: Color(0xFF707070),
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 13.0),
                ),
              ),
            ),
            SvgPicture.asset(
              'assets/icons/fi-rr-search.svg',
              width: 20,
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
