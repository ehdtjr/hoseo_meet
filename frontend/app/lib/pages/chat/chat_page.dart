import 'package:flutter/material.dart';
import 'package:intl/intl.dart';  // DateFormat을 사용하기 위한 import
import '../../api/chat/load_roomlist_service.dart'; // LoadRoomListService import
import '../../api/chat/socket_message_service.dart'; // SocketMessageService import
import '../../api/login/login_service.dart'; // AuthService import
import '../../widgets/category_button.dart';
import 'chat_detail_page.dart'; // ChatDetailPage 파일을 가져옴

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String selectedCategory = "전체"; // 선택된 카테고리
  late Future<List<dynamic>> _chatRoomsFuture; // 채팅방 목록을 저장할 Future
  final LoadRoomListService loadRoomListService = LoadRoomListService(AuthService());
  late final SocketMessageService socketMessageService;
  List<Map<String, dynamic>> chatRooms = [];

  @override
  void initState() {
    super.initState();
    _chatRoomsFuture = loadRoomListService.loadRoomList(); // API 호출을 통해 채팅방 목록을 로드
    // _connectWebSocket(); // 웹소켓 연결 및 메시지 수신 처리
  }

  // // 웹소켓 연결 및 메시지 수신 처리
  // void _connectWebSocket() {
  //   socketMessageService = SocketMessageService(AuthService().accessToken!);
  //   socketMessageService.connectWebSocket();
  //   socketMessageService.messageStream.listen((message) {
  //     _handleNewMessage(message);
  //   });
  // }

  // 새로운 메시지 수신 시 처리
  void _handleNewMessage(Map<String, dynamic> message) {
    setState(() {
      final streamId = message['stream_id'];
      final updatedChatRooms = chatRooms.map((chatRoom) {
        if (chatRoom['stream_id'] == streamId) {
          chatRoom['unread_message_count'] = (chatRoom['unread_message_count'] ?? 0) + 1;
          chatRoom['last_message'] = message;
          chatRoom['last_message']['date_sent'] = _formatTime(message['date_sent']);
        }
        return chatRoom;
      }).toList();
      chatRooms = updatedChatRooms;
    });
  }

  // 시간을 "오전/오후 h:mm" 형태로 변환
  String _formatTime(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is int) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp).toLocal();
      } else {
        throw Exception('Invalid timestamp format');
      }
      return DateFormat('a h:mm', 'ko_KR').format(dateTime);
    } catch (error) {
      print('타임스탬프 변환 오류: $error');
      return 'Unknown';
    }
  }

  // 카테고리 선택
  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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

            // 채팅 목록 (API 호출로 가져온 데이터)
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _chatRoomsFuture, // 서버에서 가져온 데이터로 FutureBuilder 설정
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator()); // 로딩 중일 때
                  } else if (snapshot.hasError) {
                    return Center(child: Text('데이터를 불러오는데 실패했습니다.'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('채팅방 목록이 없습니다.'));
                  } else {
                    chatRooms = List<Map<String, dynamic>>.from(snapshot.data!);
                    final filteredChatRooms = _filteredChatRooms(chatRooms);
                    return ListView.builder(
                      itemCount: filteredChatRooms.length,
                      itemBuilder: (context, index) {
                        final chatRoom = filteredChatRooms[index];
                        return GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailPage(chatRoom: chatRoom),
                              ),
                            );

                            if (result == 'reload') {
                              setState(() {
                                _chatRoomsFuture = loadRoomListService.loadRoomList();
                              });
                            }
                          },
                          child: _buildChatRoomItem(chatRoom), // _buildChatRoomItem 메서드 사용
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatRoomItem(Map<String, dynamic> chatRoom) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(chatRoom: chatRoom),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    chatRoom['type'] ?? 'Unknown',
                    style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                Spacer(),
                if ((chatRoom['unread_message_count'] ?? 0) > 0)
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${chatRoom['unread_message_count'] ?? 0}',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                SizedBox(width: 8),
                Text(
                  chatRoom['last_message'] is Map ? (chatRoom['last_message']['date_sent'] ?? 'Unknown') : 'Unknown',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              chatRoom['name'] ?? 'No Title',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 2),
            Text(
              chatRoom['last_message'] is Map ? (chatRoom['last_message']['content'] ?? 'No messages') : 'No messages',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Divider(color: Colors.red, thickness: 1.0),
          ],
        ),
      ),
    );
  }

  // 카테고리에 따라 채팅방 필터링
  List<Map<String, dynamic>> _filteredChatRooms(List<Map<String, dynamic>> chatRooms) {
    if (selectedCategory == "전체") {
      return chatRooms; // "전체" 선택 시 모든 채팅방 표시
    } else if (selectedCategory == "택시 · 카풀") {
      return chatRooms.where((chatRoom) => chatRoom['type'] == "택시").toList(); // "택시 · 카풀" 선택 시 "택시" 데이터 필터링
    } else {
      return chatRooms.where((chatRoom) => chatRoom['type'] == selectedCategory).toList(); // 선택된 카테고리에 따른 필터링
    }
  }
}
