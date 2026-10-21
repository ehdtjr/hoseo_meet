import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../config.dart'; // AppConfig를 import합니다.

class SocketMessageService {
  final String _token;
  final String socketUrl = AppConfig.socketUrl; // AppConfig에서 socketUrl을 가져옵니다.

  WebSocket? _socket;
  StreamController<Map<String, dynamic>> _messageStreamController = StreamController.broadcast();
  late Stream<Map<String, dynamic>> messageStream;

  SocketMessageService(this._token) {
    messageStream = _messageStreamController.stream;
  }

  Future<void> connectWebSocket() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      print("현재 토큰값은 $_token입니다. 웹소켓 시작");
      try {
        _socket = await WebSocket.connect(
          socketUrl,
          headers: {
            'sec-websocket-protocol': _token,
          },
        );
        print('WebSocket 연결 성공');
        _socket!.listen(
          _onMessageReceived,
          onDone: _onSocketDone,
          onError: _onSocketError,
        );
        break;
      } catch (error) {
        retryCount++;
        print('WebSocket 연결 실패: $error. 재시도 중... ($retryCount/$maxRetries)');
        await Future.delayed(Duration(seconds: 2)); // 2초 후에 다시 시도
      }
    }

    if (_socket == null) {
      print('WebSocket 연결 실패: 재시도 한도를 초과했습니다.');
    }
  }

  void _onMessageReceived(dynamic data) {
    try {
      final decodedData = jsonDecode(data);
      print('수신한 메시지: $decodedData');

      if (decodedData['data'] != null && decodedData['data']['type'] == 'stream') {
        _messageStreamController.add(decodedData['data']['data']);
        print('스트림 데이터 추가: ${decodedData['data']['data']}');
      } else {
        print('유효하지 않은 메시지 형식');
      }
    } catch (error) {
      print('메시지 처리 중 오류 발생: $error');
    }
  }


  void _onSocketDone() {
    print('WebSocket 연결이 종료되었습니다.');
  }

  void _onSocketError(error) {
    print('WebSocket 오류 발생: $error');
  }

  // WebSocket 연결 종료 함수
  void closeWebSocket() {
    _socket?.close();
    _socket = null;
    print('WebSocket 연결을 종료했습니다.');
  }

  // 스트림 종료 함수
  void dispose() {
    _messageStreamController.close();
  }
}
