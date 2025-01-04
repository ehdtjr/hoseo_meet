import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../config.dart';

class SocketMessageService {
  final String _token;
  final String socketUrl = AppConfig.socketUrl; // AppConfig에서 socketUrl을 가져옵니다.

  WebSocket? _socket;
  // 여러 구독자에게 메시지를 전달하기 위해 broadcast StreamController 사용
  final StreamController<Map<String, dynamic>> _messageStreamController = StreamController.broadcast();
  late final Stream<Map<String, dynamic>> messageStream;

  SocketMessageService(this._token) {
    // 컨트롤러의 stream을 외부로 노출
    messageStream = _messageStreamController.stream;
  }

  /// WebSocket 연결 시도
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

        // 정상 연결 후 메시지 수신, 종료, 오류 콜백 등록
        _socket?.listen(
          _onMessageReceived,
          onDone: _onSocketDone,
          onError: _onSocketError,
        );
        break;
      } catch (error) {
        retryCount++;
        print('WebSocket 연결 실패: $error. 재시도 중... ($retryCount/$maxRetries)');
        await Future.delayed(const Duration(seconds: 2)); // 2초 후에 다시 시도
      }
    }

    if (_socket == null) {
      print('WebSocket 연결 실패: 재시도 한도를 초과했습니다.');
    }
  }

  /// 메시지 수신 콜백
  void _onMessageReceived(dynamic data) {
    try {
      final decodedData = jsonDecode(data);
      print('수신한 메시지: $decodedData');

      // (A) 기존처럼 'type'이 'stream'인지 여부만 확인하는 것이 아니라,
      // 메시지가 Map 형태인지(키-값 형태인지) 확인한 뒤 전체를 스트림으로 보내도록 수정
      if (decodedData is Map<String, dynamic>) {
        _messageStreamController.add(decodedData);
      } else {
        print('유효하지 않은 메시지 형식 (Map 형태가 아님)');
      }
    } catch (error) {
      print('메시지 처리 중 오류 발생: $error');
    }
  }

  /// 소켓 정상 종료 시
  void _onSocketDone() {
    print('WebSocket 연결이 종료되었습니다.');
  }

  /// 소켓 오류 발생 시
  void _onSocketError(error) {
    print('WebSocket 오류 발생: $error');
  }

  /// WebSocket 연결 종료 함수
  void closeWebSocket() {
    _socket?.close();
    _socket = null;
    print('WebSocket 연결을 종료했습니다.');
  }

  /// 스트림 및 컨트롤러 종료 함수
  void dispose() {
    _messageStreamController.close();
  }
}
