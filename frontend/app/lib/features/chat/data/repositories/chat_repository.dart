// features/chat/data/repositories/chat_repository.dart

import '../services/load_message_service.dart';
import '../services/send_message_service.dart';
import '../services/message_read_service.dart';
import '../services/activate_deactivate_service.dart';
import '../services/socket_message_service.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final LoadMessageService _loadService;
  final SendMessageService _sendService;
  final MessageReadService _readService;
  final ActivateDeactivateService _activateService;
  final SocketMessageService _socketService;

  ChatRepository({
    required LoadMessageService loadService,
    required SendMessageService sendService,
    required MessageReadService readService,
    required ActivateDeactivateService activateService,
    required SocketMessageService socketService,
  })  : _loadService = loadService,
        _sendService = sendService,
        _readService = readService,
        _activateService = activateService,
        _socketService = socketService;

  // 메시지 불러오기
  Future<List<ChatMessage>> loadMessages({
    required int streamId,
    String anchor = 'first_unread',
    int numBefore = 10,
    int numAfter = 30,
  }) {
    return _loadService.loadMessages(
      streamId: streamId,
      anchor: anchor,
      numBefore: numBefore,
      numAfter: numAfter,
    );
  }

  // 메시지 전송
  Future<void> sendMessage({
    required int streamId,
    required String content,
  }) {
    return _sendService.sendMessage(
      streamId: streamId,
      messageContent: content,
    );
  }

  // 위치 전송

  Future<void> sendLocation({
    required int streamId,
    required double lat,
    required double lng,
  }) {
    return _sendService.sendLocation(
      streamId: streamId,
      lat: lat,
      lng: lng,
    );
  }

  // 메시지 읽음 처리
  Future<void> markMessagesAsRead({
    required int streamId,
    required int numAfter,
  }) {
    return _readService.markMessagesAsRead(
      streamId: streamId,
      numAfter: numAfter,
    );
  }

  // 가장 최근 메시지 1개만 읽었을 때
  Future<void> markNewestMessageAsRead({
    required int streamId,
  }) {
    return _readService.markNewestMessageAsRead(
      streamId: streamId,
    );
  }

  // 방 활성화 / 비활성화
  Future<void> activateRoom(int streamId) => _activateService.activateRoom(streamId);
  Future<void> deactivateRoom() => _activateService.deactivateRoom();

  // 소켓
  Future<void> connectWebSocket() => _socketService.connectWebSocket();
  Stream<Map<String, dynamic>> get messageStream => _socketService.messageStream;
  void closeWebSocket() => _socketService.closeWebSocket();
  void disposeSocketService() => _socketService.dispose();
}
