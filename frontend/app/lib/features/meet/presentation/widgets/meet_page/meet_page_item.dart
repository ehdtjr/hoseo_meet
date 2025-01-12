import 'package:flutter/material.dart';

class MeetPageItem extends StatelessWidget {
  const MeetPageItem({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        top: 18.0,
        left: 30.0,
        right: 30.0,
      ), // margin을 padding으로 변경
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(width: 1, color: const Color(0xFFE72410)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '매칭',
                  style: TextStyle(
                    color: Color(0xFFE72410),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'zeong153',
                style: TextStyle(
                  color: Color(0xFF707070),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(), // 남은 공간을 채워 햄버거 메뉴를 오른쪽으로 밀어냄
              Container(
                width: 18,
                height: 18,
                child: Icon(
                  Icons.more_vert, // 세로 햄버거 메뉴 아이콘
                  size: 18,
                  color: Color(0xFFBDBDBD),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '운동장 러닝 하실 분들 구해요!',
            style: TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '5시 생각하고 있습니다',
            style: TextStyle(
              color: Color(0xFF707070),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '3시간 전',
                    style: TextStyle(
                      color: Color(0xFF707070),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(width: 6),
                  Container(
                    width: 2, // 점의 너비
                    height: 2, // 점의 높이
                    decoration: BoxDecoration(
                      color: Color(0xFF707070), // 점의 색상
                      shape: BoxShape.circle, // 원형으로 설정
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    '조회수 11',
                    style: TextStyle(
                      color: Color(0xFF707070),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.message_outlined,
                    size: 16,
                    color: Color(0xFF707070),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 13),
          const Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF0B4AD),
          ),
        ],
      ),
    );
  }
}
