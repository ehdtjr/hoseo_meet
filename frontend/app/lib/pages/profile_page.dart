import 'package:flutter/material.dart';
import '../../api/login/login_service.dart'; // AuthService import
import '../../api/chat/create_room_service.dart'; // CreateRoomService import
import '../../api/chat/subcription_room_service.dart'; // JoinRoomService import
import '../../api/chat/load_roomlist_service.dart'; // LoadRoomListService import
import '../../api/chat/send_message_service.dart'; // SendMessageService import
import '../../api/chat/message_read_service.dart'; // MessageReadService import
import '../../kakao/kakao_auto_login_service.dart'; // KakaoAutoLoginService import

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService authService = AuthService(); // 싱글톤으로 AuthService 사용
  final KakaoAutoLoginService _kakaoAutoLoginService = KakaoAutoLoginService(); // KakaoAutoLoginService 추가
  late final CreateRoomService createRoomService;
  late final JoinRoomService joinRoomService; // JoinRoomService 추가
  late final LoadRoomListService loadRoomListService; // LoadRoomListService 추가
  late final SendMessageService sendMessageService; // SendMessageService 추가
  late final MessageReadService messageReadService; // MessageReadService 추가

  final TextEditingController _roomNameController = TextEditingController(); // 방 이름 입력용
  final TextEditingController _roomTypeController = TextEditingController(); // 방 타입 입력용
  final TextEditingController _roomIdController = TextEditingController(); // Room ID 입력용
  final TextEditingController _streamIdController = TextEditingController(); // Stream ID 입력용
  final TextEditingController _messageController = TextEditingController(); // 메시지 입력용
  final TextEditingController _numAfterController = TextEditingController(); // num_after 입력용

  @override
  void initState() {
    super.initState();
    createRoomService = CreateRoomService(authService); // CreateRoomService 초기화
    joinRoomService = JoinRoomService(authService); // JoinRoomService 초기화
    loadRoomListService = LoadRoomListService(authService); // LoadRoomListService 초기화
    sendMessageService = SendMessageService(authService); // SendMessageService 초기화
    messageReadService = MessageReadService(authService); // MessageReadService 초기화
  }

  @override
  void dispose() {
    _roomNameController.dispose(); // 컨트롤러 해제
    _roomTypeController.dispose(); // 컨트롤러 해제
    _roomIdController.dispose(); // 컨트롤러 해제
    _streamIdController.dispose(); // 컨트롤러 해제
    _messageController.dispose(); // 컨트롤러 해제
    _numAfterController.dispose(); // 컨트롤러 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Profile Page'),
            // Room Name 입력 텍스트박스
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _roomNameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Room Name 입력',
                ),
              ),
            ),

            // Room Type 입력 텍스트박스
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _roomTypeController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Room Type 입력',
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                try {
                  final response = await createRoomService.createRoom(
                    roomName: _roomNameController.text,
                    roomType: _roomTypeController.text,
                  );
                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('채팅방 생성 성공: ${response.body}')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('채팅방 생성 실패: ${response.statusCode} - ${response.body}')),
                    );
                  }
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류 발생: $error')),
                  );
                }
              },
              child: Text('채팅방 생성'),
            ),

            // Room ID 입력 텍스트박스
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _roomIdController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Room ID 입력',
                ),
                keyboardType: TextInputType.number,
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                try {
                  final streamId = int.tryParse(_roomIdController.text);
                  if (streamId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('유효한 Room ID를 입력하세요.')),
                    );
                    return;
                  }

                  final response = await joinRoomService.joinRoom(streamId: streamId);
                  if (response.statusCode == 200) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('채팅방 입장 성공: ${response.body}')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('채팅방 입장 실패: ${response.statusCode} - ${response.body}')),
                    );
                  }
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류 발생: $error')),
                  );
                }
              },
              child: Text('채팅방 입장'),
            ),

            ElevatedButton(
              onPressed: () async {
                try {
                  final roomList = await loadRoomListService.loadRoomList();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('채팅방 목록: $roomList')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류 발생: $error')),
                  );
                }
              },
              child: Text('채팅방 목록 로드'),
            ),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _streamIdController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Stream ID 입력',
                ),
                keyboardType: TextInputType.number,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '메시지 입력',
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                try {
                  final streamId = int.tryParse(_streamIdController.text);
                  final messageContent = _messageController.text;

                  if (streamId == null || messageContent.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('유효한 Stream ID와 메시지를 입력하세요.')),
                    );
                    return;
                  }

                  await sendMessageService.sendMessage(
                    streamId: streamId,
                    messageContent: messageContent,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('메시지 전송 성공')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('메시지 전송 실패: $error')),
                  );
                }
              },
              child: Text('메시지 전송'),
            ),

            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _numAfterController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'num_after 입력',
                ),
                keyboardType: TextInputType.number,
              ),
            ),

            ElevatedButton(
              onPressed: () async {
                try {
                  final streamId = int.tryParse(_streamIdController.text);
                  final numAfter = int.tryParse(_numAfterController.text) ?? 0;

                  if (streamId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('유효한 Stream ID를 입력하세요.')),
                    );
                    return;
                  }

                  await messageReadService.markMessagesAsRead(
                    streamId: streamId,
                    numAfter: numAfter,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('메시지 읽음 처리 성공')),
                  );
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류 발생: $error')),
                  );
                }
              },
              child: Text('메시지 읽음 처리'),
            ),

            // 카카오톡 토큰 삭제 버튼 추가
            ElevatedButton(
              onPressed: () async {
                await _kakaoAutoLoginService.deleteTokens();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('카카오톡 토큰이 삭제되었습니다.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: Text(
                '카카오톡 토큰 삭제',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
