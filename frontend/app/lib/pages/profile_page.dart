import 'package:flutter/material.dart';
import '../../api/login/login_service.dart'; // AuthService import
import '../../api/chat/create_room_service.dart'; // CreateRoomService import
import '../../api/chat/subcription_room_service.dart'; // JoinRoomService import
import '../../api/chat/load_roomlist_service.dart'; // LoadRoomListService import

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService authService = AuthService(); // 싱글톤으로 AuthService 사용
  late final CreateRoomService createRoomService;
  late final JoinRoomService joinRoomService; // JoinRoomService 추가
  late final LoadRoomListService loadRoomListService; // LoadRoomListService 추가
  final TextEditingController _roomIdController = TextEditingController(); // 텍스트박스 컨트롤러 추가

  @override
  void initState() {
    super.initState();
    createRoomService = CreateRoomService(authService); // CreateRoomService 초기화
    joinRoomService = JoinRoomService(authService); // JoinRoomService 초기화
    loadRoomListService = LoadRoomListService(authService); // LoadRoomListService 초기화
  }

  @override
  void dispose() {
    _roomIdController.dispose(); // 텍스트박스 컨트롤러 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Profile Page'),

          ElevatedButton(
            onPressed: () {
              // 현재 저장된 토큰을 출력
              final token = authService.accessToken;
              if (token != null) {
                print('현재 토큰: $token');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('현재 토큰: $token')),
                );
              } else {
                print('저장된 토큰이 없습니다.');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('저장된 토큰이 없습니다.')),
                );
              }
            },
            child: Text('Button 1 - 토큰 출력'),
          ),

          ElevatedButton(
            onPressed: () async {
              try {
                // CreateRoomService 테스트 (roomName: 'TestRoom')
                final response = await createRoomService.createRoom(roomName: 'TestRoom');
                if (response.statusCode == 200) {
                  print('채팅방 생성 성공: ${response.body}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('채팅방 생성 성공: ${response.body}')),
                  );
                } else {
                  print('채팅방 생성 실패: ${response.statusCode} - ${response.body}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('채팅방 생성 실패: ${response.statusCode} - ${response.body}')),
                  );
                }
              } catch (error) {
                print('오류 발생: $error');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('오류 발생: $error')),
                );
              }
            },
            child: Text('Button 2 - 채팅방 생성'),
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
              keyboardType: TextInputType.number, // 숫자 입력용 키보드
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              try {
                // JoinRoomService 테스트 (streamId: 사용자가 입력한 roomId)
                final streamId = int.tryParse(_roomIdController.text);
                if (streamId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('유효한 Room ID를 입력하세요.')),
                  );
                  return;
                }

                final response = await joinRoomService.joinRoom(streamId: streamId);
                if (response.statusCode == 200) {
                  print('채팅방 입장 성공: ${response.body}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('채팅방 입장 성공: ${response.body}')),
                  );
                } else {
                  print('채팅방 입장 실패: ${response.statusCode} - ${response.body}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('채팅방 입장 실패: ${response.statusCode} - ${response.body}')),
                  );
                }
              } catch (error) {
                print('오류 발생: $error');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('오류 발생: $error')),
                );
              }
            },
            child: Text('Button 3 - 채팅방 입장'),
          ),

          ElevatedButton(
            onPressed: () async {
              try {
                // LoadRoomListService 테스트 (사용자의 채팅방 목록 로드)
                final roomList = await loadRoomListService.loadRoomList();
                print('채팅방 목록: $roomList');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('채팅방 목록: $roomList')),
                );
              } catch (error) {
                print('오류 발생: $error');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('오류 발생: $error')),
                );
              }
            },
            child: Text('Button 4 - 채팅방 목록 로드'),
          ),
        ],
      ),
    );
  }
}
