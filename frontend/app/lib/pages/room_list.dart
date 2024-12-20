import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class RoomList extends StatefulWidget {
  final String categoryName; // 카테고리 이름 전달 받기

  RoomList({required this.categoryName});

  @override
  _RoomListState createState() => _RoomListState();
}

class _RoomListState extends State<RoomList> {
  final List<String> _selectOptions = ['거리순', '별점순', '리뷰순'];
  String _selectedOption = '거리순';
  bool _isDropdownOpened = false;
  List<dynamic> items = [];
  String userName = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadName();
  }

  Future<void> _loadData() async {
    // 카테고리에 따라 다른 JSON 파일 로드
    String fileName = widget.categoryName == '음식점'
        ? 'assets/data/food_list.json'
        : 'assets/data/room_list.json';

    final String response = await rootBundle.loadString(fileName);
    final data = json.decode(response);
    setState(() {
      items = data;
    });
  }

  Future<void> _loadName() async {
    final String response = await rootBundle.loadString('assets/data/name.json');
    final data = json.decode(response);
    setState(() {
      userName = data['name'];
    });
  }

  void _sortItems(String criteria) {
    setState(() {
      if (criteria == '거리순') {
        items.sort((a, b) => int.parse(a['distance'].replaceAll('m', '')).compareTo(
            int.parse(b['distance'].replaceAll('m', ''))));
      } else if (criteria == '별점순') {
        items.sort((a, b) => b['rating'].compareTo(a['rating']));
      } else if (criteria == '리뷰순') {
        items.sort((a, b) => b['reviews'].compareTo(a['reviews']));
      }
    });
  }

  void _showCustomDropdown(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context)!.context.findRenderObject() as RenderBox;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(button.size.width, 0), ancestor: overlay),
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
            width: button.size.width * 0.5,
            child: Text(value),
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      setState(() {
        _selectedOption = selected;
        _sortItems(selected); // 정렬 실행
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      text: userName,
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
                      text: widget.categoryName, // 전달받은 카테고리 이름 사용
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
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.asset(
                              item['image'],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      Icons.star,
                                      color: (item['rating'] >= starIndex + 1) ? Colors.red : Colors.grey,
                                      size: 18,
                                    );
                                  }),
                                ),
                                SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      item['distance'],
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      '리뷰 ${item['reviews']}',
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
                          Icon(Icons.favorite_border, color: Colors.red),
                        ],
                      ),
                      SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['description'],
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
