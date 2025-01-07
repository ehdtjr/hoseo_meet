import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:geolocator/geolocator.dart';

// Services
import '../../../commons/network/auth_http_client_provider.dart';
import '../data/models/chat_message.dart';
import '../data/models/chat_room.dart';
import '../data/repositories/chat_repository.dart';
import '../data/services/activate_deactivate_service.dart';
import '../data/services/load_message_service.dart';
import '../data/services/message_read_service.dart';
import '../data/services/send_message_service.dart';
import '../data/services/socket_message_service.dart';

// Auth
import '../../../../features/auth/providers/auth_notifier_provider.dart';
// 맵 관련 (위치 표시)
import 'chat_room_provicer.dart';
import 'map_provider.dart';

class ChatDetailNotifier extends StateNotifier<ChatDetailState> {
  ChatDetailNotifier(this.ref, this.chatRoom) : super(ChatDetailState());

  final Ref ref;
  final ChatRoom chatRoom;

  bool _isInitialized = false;
  late final ChatRepository _chatRepository;

  // 5초마다 위치 전송 (Timer)
  Timer? _locationTimer;

  // WebSocket listen
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  // 방 활성화 타이머
  Timer? _activateTimer;

  // ---------------------------
  // init() : 한 번만 실행
  // ---------------------------
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('[ChatDetailNotifier] init() called again, ignoring...');
      return;
    }
    _isInitialized = true;

    // (1) AuthHttpClient
    final client = ref.read(authHttpClientProvider);

    // (2) 전역 토큰
    final token = ref.read(authNotifierProvider).accessToken;
    if (token == null) {
      debugPrint('[ChatDetailNotifier] init() 실패: 토큰이 없습니다.');
      return;
    }

    // (3) 필요한 Service들
    _chatRepository = ChatRepository(
      loadService: LoadMessageService(client),
      sendService: SendMessageService(client),
      readService: MessageReadService(client),
      activateService: ActivateDeactivateService(client),
      socketService: SocketMessageService(token),
    );

    // 기본 작업
    await _fetchUserId();        // 내 userId 세팅 (예: 0)
    await _loadMessagesAtFirstUnread();
    await _markMessagesAsRead();
    await _initWebSocket();
    _activateRoomRegularly();
  }

  // ---------------------------
  // 내 위치 추적 -> 서버로 전송 (5초마다)
  // ---------------------------
  Future<void> startLocationTracking() async {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final lat = position.latitude;
        final lng = position.longitude;
        // 위치 전송
        await _chatRepository.sendLocation(
          streamId: chatRoom.streamId,
          lat: lat,
          lng: lng,
        );
      } catch (e) {
        debugPrint('[ChatDetailNotifier] 내 위치 서버 전송 실패: $e');
      }
    });
  }

  void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // disposeNotifier
  Future<void> disposeNotifier() async {
    stopLocationTracking();
    _activateTimer?.cancel();
    _activateTimer = null;

    await _deactivateCurrentChatRoom();
    await _socketSubscription?.cancel();
    _chatRepository.closeWebSocket();
    _chatRepository.disposeSocketService();
  }

  // 사용자 ID
  Future<void> _fetchUserId() async {
    try {
      // 임시로 userId = 0
      state = state.copyWith(userId: 0);
    } catch (e) {
      debugPrint('[ChatDetailNotifier] _fetchUserId 실패: $e');
    }
  }

  // ---------------------------
  // 메시지 로드 (처음 진입 시)
  // ---------------------------
  Future<void> _loadMessagesAtFirstUnread() async {
    try {
      final previousMessages = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: 'first_unread',
        numBefore: 10,
        numAfter: chatRoom.unreadCount,
      );

      // 기존 messages와 합치면서 중복(ID) 제거
      // (처음 로딩이므로 그냥 덮어써도 되지만, 혹시 모를 중복 제거)
      final merged = _mergeMessagesIgnoringDuplicates(
        currentList: state.messages,
        incomingList: previousMessages,
        prepend: false, // 뒤쪽(append)으로 합치기
      );

      state = state.copyWith(messages: merged);
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 초기 메시지 로드 실패: $error');
    }
  }

  // ---------------------------
  // 이전 메시지 더 불러오기 (위로 스크롤 페이징)
  // ---------------------------
  Future<void> loadMoreMessages() async {
    if (state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final oldestId = state.messages.isNotEmpty ? state.messages.first.id : null;
      final moreMessages = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: oldestId?.toString() ?? 'first_unread',
        numBefore: 30,
        numAfter: 0,
      );

      if (moreMessages.isNotEmpty) {
        final merged = _mergeMessagesIgnoringDuplicates(
          currentList: state.messages,
          incomingList: moreMessages,
          prepend: true,
        );
        state = state.copyWith(messages: merged);
      } else {
        debugPrint('[ChatDetailNotifier] 더 이상 불러올 이전 메시지가 없습니다');
      }
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 더 이전 메시지 로드 실패: $error');
    }

    state = state.copyWith(isLoadingMore: false);
  }

  // ---------------------------
  // 메시지 전송
  // ---------------------------
  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || state.userId == null) return;

    try {
      // 서버에 전송하면, 소켓(WebSocket)으로 다시 돌아올 때
      // _handleStreamMessage 에서 목록에 반영됨
      await _chatRepository.sendMessage(
        streamId: chatRoom.streamId,
        content: trimmed,
      );
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 메시지 전송 실패: $error');
    }
  }

  // ---------------------------
  // WebSocket 연결 및 이벤트 처리
  // ---------------------------
  Future<void> _initWebSocket() async {
    await _chatRepository.connectWebSocket();
    _socketSubscription = _chatRepository.messageStream.listen((incoming) async {
      final type = incoming['type'];
      switch (type) {
        case 'read':
          _handleReadMessage(incoming);
          break;
        case 'stream':
          await _handleStreamMessage(incoming);
          break;
        case 'location':
          _handleLocationMessage(incoming);
          break;
        default:
          debugPrint('[ChatDetailNotifier] 다룰 필요 없는 타입: $type');
          break;
      }
    });
  }

  void _handleReadMessage(Map<String, dynamic> msg) {
    final readIds = msg['data']?['read_message'] as List<dynamic>? ?? [];
    final updated = state.messages.map((m) {
      if (readIds.contains(m.id)) {
        final newCount = (m.unreadCount > 0) ? (m.unreadCount - 1) : 0;
        return m.copyWith(unreadCount: newCount);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  /// 소켓으로 들어온 새 메시지(stream) 처리
  Future<void> _handleStreamMessage(Map<String, dynamic> msg) async {
    final data = msg['data'];
    if (data['stream_id'] == chatRoom.streamId) {
      final newMessage = ChatMessage.fromJson(data);

      // 기존 메시지와 합치되, 중복 ID가 있으면 무시
      final merged = _mergeMessagesIgnoringDuplicates(
        currentList: state.messages,
        incomingList: [newMessage],
        prepend: false, // 새 메시지는 뒤쪽에 추가
      );
      state = state.copyWith(messages: merged);

      // 채팅방 목록 갱신 등
      ref
          .read(chatRoomNotifierProvider.notifier)
          .handleIncomingMessageOnOpen(newMessage: newMessage);

      try {
        await _chatRepository.markNewestMessageAsRead(
          streamId: chatRoom.streamId,
        );
      } catch (error) {
        debugPrint('[ChatDetailNotifier] newest message read fail: $error');
      }
    } else {
      debugPrint('[ChatDetailNotifier] 다른 방 메시지');
    }
  }

  void _handleLocationMessage(Map<String, dynamic> msg) {
    final data = msg['data'];
    final userId = data['user_id'] as int?;
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;

    if (userId != null && lat != null && lng != null) {
      ref.read(mapNotifierProvider.notifier).updateUserCircle(userId, lat, lng);
    }
  }

  // ---------------------------
  // 방 활성화 타이머
  // ---------------------------
  void _activateRoomRegularly() {
    debugPrint('ChatDetailNotifier: _activateRoomRegularly');
    _activateCurrentChatRoom();
    _activateTimer?.cancel();
    _activateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _activateCurrentChatRoom();
    });
  }

  Future<void> _activateCurrentChatRoom() async {
    try {
      final streamId = chatRoom.streamId;
      if (streamId != 0) {
        await _chatRepository.activateRoom(streamId);
      }
    } catch (e) {
      debugPrint('[ChatDetailNotifier] activateRoom 오류: $e');
    }
  }

  Future<void> _deactivateCurrentChatRoom() async {
    try {
      await _chatRepository.deactivateRoom();
    } catch (e) {
      debugPrint('[ChatDetailNotifier] deactivateRoom 오류: $e');
    }
  }

  // ---------------------------
  // 메시지 읽음 처리
  // ---------------------------
  Future<void> _markMessagesAsRead() async {
    try {
      await _chatRepository.markMessagesAsRead(
        streamId: chatRoom.streamId,
        numAfter: chatRoom.unreadCount,
      );
    } catch (error) {
      debugPrint('[ChatDetailNotifier] markMessagesAsRead 오류: $error');
    }
  }

  // ---------------------------
  // [중복 메시지 제거] 헬퍼 함수
  // ---------------------------
  List<ChatMessage> _mergeMessagesIgnoringDuplicates({
    required List<ChatMessage> currentList,
    required List<ChatMessage> incomingList,
    bool prepend = false,
  }) {
    // 복사본
    final updated = [...currentList];

    for (final incoming in incomingList) {
      // 같은 id의 메시지가 있는지 확인
      final idx = updated.indexWhere((m) => m.id == incoming.id);

      if (idx == -1) {
        // 중복 아님 -> 새로 추가
        if (prepend) {
          updated.insert(0, incoming);
        } else {
          updated.add(incoming);
        }
      }
    }

    return updated;
  }
}
