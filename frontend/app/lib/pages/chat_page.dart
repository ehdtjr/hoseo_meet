// lib/pages/chat_page.dart

import 'package:flutter/material.dart';
import '../widgets/category_button.dart';
import 'chat_detail_page.dart';  // ChatDetailPage 파일을 가져옴

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String selectedCategory = "전체"; // 선택된 카테고리
  final List<Map<String, dynamic>> chatRooms = [
    {
      "id": 1,
      "type": "배달",
      "title": "배달로 때문에 같이 주문 하실 분 구해요",
      "content": "지금 배달로 해서 이 집에서 시키려고 하는데...",
      "unread": 5,
      "time": "오전 10:53",
    },
    {
      "id": 2,
      "type": "배달",
      "title": "배달로 때문에 같이 주문 하실 분 구해요",
      "content": "지금 배달로 해서 이 집에서 시키려고 하는데...",
      "unread": 1,
      "time": "오전 10:53",
    },
    {
      "id": 3,
      "type": "배달",
      "title": "배달로 때문에 같이 주문 하실 분 구해요",
      "content": "지금 배달로 해서 이 집에서 시키려고 하는데...",
      "unread": 3,
      "time": "오전 10:53",
    },
    {
      "id": 4,
      "type": "택시",
      "title": "택시 같이 타실 분 구해요",
      "content": "지금 바로 출발할 수 있는 분...",
      "unread": 0,
      "time": "오전 09:15",
    },
  ];

  // 카테고리 선택
  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea( // SafeArea를 추가해서 상태바 아래에서 바로 시작
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 20, bottom: 5.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CHAT',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 30),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.black),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            SizedBox(height: 5), // 제목과 카테고리 간의 간격 최소화

            // 카테고리 버튼
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  CategoryButton(
                    text: "전체",
                    isSelected: selectedCategory == "전체",
                    onPressed: () => _onCategorySelected("전체"),
                  ),
                  CategoryButton(
                    text: "모임",
                    isSelected: selectedCategory == "모임",
                    onPressed: () => _onCategorySelected("모임"),
                  ),
                  CategoryButton(
                    text: "배달",
                    isSelected: selectedCategory == "배달",
                    onPressed: () => _onCategorySelected("배달"),
                  ),
                  CategoryButton(
                    text: "택시 · 카풀",
                    isSelected: selectedCategory == "택시 · 카풀",
                    onPressed: () => _onCategorySelected("택시 · 카풀"),
                  ),
                  IconButton(
                    icon: Icon(Icons.search, color: Colors.grey),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Divider(color: Colors.red, thickness: 1.0), // 이 Divider가 최상단에 가깝게 위치하게 됨

            // 채팅 목록 (선택된 카테고리에 따른 필터링)
            Expanded(
              child: ListView.builder(
                itemCount: _filteredChatRooms().length,
                itemBuilder: (context, index) {
                  final chatRoom = _filteredChatRooms()[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailPage(chatRoom: chatRoom),
                        ),
                      );
                    },
                    child: _buildChatRoomItem(chatRoom),  // _buildChatRoomItem 메서드 사용
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 채팅방 항목 빌더 메서드 추가
  Widget _buildChatRoomItem(Map<String, dynamic> chatRoom) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 카테고리 라벨
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chatRoom['type'],
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Spacer(),
              // 안 읽은 메시지 개수
              if (chatRoom['unread'] > 0)
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${chatRoom['unread']}',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              SizedBox(width: 8),
              Text(chatRoom['time'],
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          SizedBox(height: 4), // 제목과 설명 사이의 간격을 줄임
          Text(
            chatRoom['title'],
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 2), // 제목과 내용 간의 간격을 줄임
          Text(
            chatRoom['content'],
            style: TextStyle(color: Colors.grey[600]),
          ),
          Divider(color: Colors.red, thickness: 1.0),
        ],
      ),
    );
  }

  // 카테고리에 따라 채팅방 필터링
  List<Map<String, dynamic>> _filteredChatRooms() {
    if (selectedCategory == "전체") {
      return chatRooms; // "전체" 선택 시 모든 채팅방 표시
    } else if (selectedCategory == "택시 · 카풀") {
      return chatRooms.where((chatRoom) => chatRoom['type'] == "택시").toList(); // "택시 · 카풀" 선택 시 "택시" 데이터 필터링
    } else {
      return chatRooms.where((chatRoom) => chatRoom['type'] == selectedCategory).toList(); // 선택된 카테고리에 따른 필터링
    }
  }
}
