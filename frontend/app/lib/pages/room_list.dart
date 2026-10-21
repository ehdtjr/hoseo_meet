import 'package:flutter/material.dart';

class RoomList extends StatefulWidget {
  @override
  _RoomListState createState() => _RoomListState();
}

class _RoomListState extends State<RoomList> {
  final List<String> _selectOptions = ['거리순', '별점순', '리뷰순'];
  String _selectedOption = '거리순';
  bool _isDropdownOpened = false;

  void _showCustomDropdown(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context)!.context.findRenderObject() as RenderBox;

    // 드롭다운의 위치를 오른쪽에 맞추기 위한 RelativeRect 설정
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(button.size.width, 0), ancestor: overlay), // 버튼의 오른쪽 상단을 기준으로
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    String? selected = await showMenu<String>(
      context: context,
      position: position,
      items: _selectOptions.map((String value) {
        return PopupMenuItem<String>(
          value: value,
          child: Container(
            width: button.size.width * 0.5, // 팝업의 너비를 현재 버튼 크기의 50%로 설정
            child: Text(value),
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      setState(() {
        _selectedOption = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rooms = [
      {
        "name": "퍼스트빌",
        "distance": "150m",
        "reviews": 37,
        "image": "assets/img/info/room1.png",
        "description": "신선한 재료로 만든 건강한 맛, 최고의 맛집!",
        "rating": 4.0
      },
      {
        "name": "궁전빌라",
        "distance": "152m",
        "reviews": 37,
        "image": "assets/img/info/room2.png",
        "description": "신선한 재료로 만든 건강한 맛, 최고의 맛집!",
        "rating": 4.0
      },
      {
        "name": "솔원룸",
        "distance": "151m",
        "reviews": 37,
        "image": "assets/img/info/room3.png",
        "description": "신선한 재료로 만든 건강한 맛, 최고의 맛집!",
        "rating": 4.0
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Center(
          child: Container(
            height: 3,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.red[300],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // 상단 텍스트 및 드롭다운 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '지금 ',
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: '소소',
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                    TextSpan(
                      text: '님 주위에 있는 ',
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: '자취방',
                      style: TextStyle(
                        fontSize: 20,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              // 커스텀 드롭다운 버튼
              GestureDetector(
                onTap: () => _showCustomDropdown(context),
                child: Row(
                  children: [
                    Text(
                      _selectedOption,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 자취방 리스트
        Expanded(
          child: ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];

              return Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 16.0),
                child: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 2,
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 방 이미지
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.asset(
                              room['image'],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: 10),
                          // 방 정보
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room['name'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 5),
                                // 별점 출력 부분
                                Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      Icons.star,
                                      color: (room['rating'] >= starIndex + 1)
                                          ? Colors.red
                                          : Colors.grey,
                                      size: 18,
                                    );
                                  }),
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      room['distance'],
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      '리뷰 ${room['reviews']}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 좋아요 버튼
                          Icon(Icons.favorite_border, color: Colors.red),
                        ],
                      ),
                      SizedBox(height: 10),
                      // 설명 텍스트
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          room['description'],
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
