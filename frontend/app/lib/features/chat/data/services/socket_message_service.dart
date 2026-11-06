import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../config.dart';

class SocketMessageService {
  final String _token;
  final String socketUrl;

  WebSocket? _socket;
  // 여러 구독자에게 메시지를 전달하기 위해 broadcast StreamController 사용
  final StreamController<Map<String, dynamic>> _messageStreamController = StreamController.broadcast();
  late final Stream<Map<String, dynamic>> messageStream;

  SocketMessageService(this._token, {String? socketUrl})
      : socketUrl = socketUrl ?? AppConfig.socketUrl {
    // 컨트롤러의 stream을 외부로 노출
    messageStream = _messageStreamController.stream;
  }

  /// WebSocket 연결 시도
  Future<void> connectWebSocket() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        _socket = await WebSocket.connect(
          socketUrl,
          headers: {
            'sec-websocket-protocol': _token,
          },
        );
        print('[WebSocket] connected');

        // 정상 연결 후 메시지 수신, 종료, 오류 콜백 등록
        _socket?.listen(
          _onMessageReceived,
          onDone: _onSocketDone,
          onError: _onSocketError,
        );
        break;
      } catch (_) {
        retryCount++;
        // Exception strings can contain URLs, headers or credentials.
        print('[WebSocket] connect_failed retry=$retryCount/$maxRetries');
        await Future.delayed(const Duration(seconds: 2)); // 2초 후에 다시 시도
      }
    }

    if (_socket == null) {
      print('[WebSocket] retries_exhausted');
    }
  }

  /// 메시지 수신 콜백
  void _onMessageReceived(dynamic data) {
    try {
      final decodedData = jsonDecode(data);
      if (decodedData is Map<String, dynamic>) {
        // Only these protocol constants may enter logs; unknown values can be PII.
        final type = decodedData['type'];
        final safeType = type is String &&
                const {'stream', 'user', 'location', 'read'}.contains(type)
            ? type
            : 'unknown';
        print('[WebSocket] received type=$safeType');
        _messageStreamController.add(decodedData);
      } else {
        print('[WebSocket] invalid_message_shape');
      }
    } catch (_) {
      // FormatException includes the offending source text. Never print it.
      print('[WebSocket] decode_failed');
    }
  }

  /// 소켓 정상 종료 시
  void _onSocketDone() {
    print('[WebSocket] disconnected');
  }

  /// 소켓 오류 발생 시
  void _onSocketError(error) {
    print('[WebSocket] transport_failed');
  }

  /// WebSocket 연결 종료 함수
  void closeWebSocket() {
    _socket?.close();
    _socket = null;
    print('[WebSocket] closed');
  }

  /// 스트림 및 컨트롤러 종료 함수
  void dispose() {
    _messageStreamController.close();
  }
}
