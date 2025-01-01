// features/chat/providers/chat_detail_notifier.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hoseomeet/features/chat/providers/map_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:hoseomeet/features/chat/data/models/chat_message.dart';
import 'package:hoseomeet/features/chat/data/repositories/chat_repository.dart';

// Auth
import '../../../../api/login/authme_service.dart';
import '../../../../api/login/login_service.dart';

// Services
import '../data/services/activate_deactivate_service.dart';
import '../data/services/load_message_service.dart';
import '../data/services/message_read_service.dart';
import '../data/services/send_message_service.dart';
import '../data/services/socket_message_service.dart';

// ---------------------------
// 상태 모델
// ---------------------------
class ChatDetailState {
  final int? userId;
  final bool isLoadingMore;
  final List<ChatMessage> messages;

  ChatDetailState({
    this.userId,
    this.isLoadingMore = false,
    this.messages = const [],
  });

  ChatDetailState copyWith({
    int? userId,
    bool? isLoadingMore,
    List<ChatMessage>? messages,
  }) {
    return ChatDetailState(
      userId: userId ?? this.userId,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      messages: messages ?? this.messages,
    );
  }
}

// ---------------------------
// Notifier
// ---------------------------
class ChatDetailNotifier extends StateNotifier<ChatDetailState> {
  ChatDetailNotifier(
      this.ref,
      this.chatRoom,
      ) : super(ChatDetailState());

  final Ref ref;                        // Riverpod 2.x: ref 주입
  final Map<String, dynamic> chatRoom;

  bool _isInitialized = false;
  late final ChatRepository _chatRepository;

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  Timer? _activateTimer;
  StreamSubscription<Position>? _positionSubscription; // 위치 추적

  // ---------------------------
  // init() : 한 번만 실행
  // ---------------------------
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('[ChatDetailNotifier] init() called again, ignoring...');
      return;
    }
    _isInitialized = true;

    // 1) AuthService 준비
    final authService = AuthService();

    // 2) 필요한 Service들을 생성해 Repository에 주입
    _chatRepository = ChatRepository(
      loadService: LoadMessageService(authService),
      sendService: SendMessageService(authService),
      readService: MessageReadService(authService),
      activateService: ActivateDeactivateService(authService),
      socketService: SocketMessageService(authService.accessToken!),
    );

    // 기본 작업
    await _fetchUserId();
    await _loadMessagesAtFirstUnread();
    await _markMessagesAsRead();
    await _initWebSocket();      // 웹소켓 연결
    _activateRoomRegularly();    // 타이머로 방 활성화
  }

  // ---------------------------
  // 내 위치 추적 -> 서버로 전송
  // ---------------------------
  Future<void> startLocationTracking() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) async {
      final lat = position.latitude;
      final lng = position.longitude;
      debugPrint('[ChatDetailNotifier] 내 위치 변경: lat=$lat, lng=$lng');

      try {
        await _chatRepository.sendLocation(
          streamId: chatRoom['stream_id'],
          lat: lat,
          lng: lng,
        );
        debugPrint('[ChatDetailNotifier] 내 위치 서버 전송 완료');
      } catch (e) {
        debugPrint('[ChatDetailNotifier] 내 위치 서버 전송 실패: $e');
      }
    });
  }

  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  // disposeNotifier: 타이머, 스트림 해제
  Future<void> disposeNotifier() async {
    stopLocationTracking();
    _activateTimer?.cancel();
    _activateTimer = null;

    await _deactivateCurrentChatRoom();
    await _socketSubscription?.cancel();
    _chatRepository.closeWebSocket();
    _chatRepository.disposeSocketService();
  }

  // ---------------------------
  // 사용자 ID
  // ---------------------------
  Future<void> _fetchUserId() async {
    try {
      final authMeService = AuthMeService(AuthService().accessToken!);
      await authMeService.fetchAndStoreUserId();
      state = state.copyWith(userId: authMeService.userId);
    } catch (e) {
      debugPrint('[ChatDetailNotifier] _fetchUserId 실패: $e');
    }
  }

  // ---------------------------
  // 메시지 로드
  // ---------------------------
  Future<void> _loadMessagesAtFirstUnread() async {
    try {
      final previousMessages = await _chatRepository.loadMessages(
        streamId: chatRoom['stream_id'],
        anchor: 'first_unread',
        numBefore: 30,
        numAfter: 30,
      );
      state = state.copyWith(
        messages: [...state.messages, ...previousMessages],
      );
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 초기 메시지 로드 실패: $error');
    }
  }

  Future<void> loadMoreMessages() async {
    if (state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final oldestId = state.messages.isNotEmpty ? state.messages.first.id : null;
      final moreMessages = await _chatRepository.loadMessages(
        streamId: chatRoom['stream_id'],
        anchor: oldestId?.toString() ?? 'first_unread',
        numBefore: 30,
        numAfter: 0,
      );
      if (moreMessages.isNotEmpty) {
        state = state.copyWith(
          messages: [...moreMessages, ...state.messages],
        );
      } else {
        debugPrint('[ChatDetailNotifier] 더 이상 불러올 이전 메시지가 없습니다');
      }
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 더 이전 메시지 로드 실패: $error');
    }

    state = state.copyWith(isLoadingMore: false);
  }

  // ---------------------------
  // 메시지 보내기
  // ---------------------------
  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || state.userId == null) return;

    try {
      await _chatRepository.sendMessage(
        streamId: chatRoom['stream_id'],
        content: trimmed,
      );
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 메시지 전송 실패: $error');
    }
  }

  // ---------------------------
  // WebSocket 연결
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
          _handleLocationMessage(incoming); // 위치 메시지 처리
          break;
        default:
          debugPrint('[ChatDetailNotifier] 다룰 필요 없는 타입: $type');
          break;
      }
    });
  }

  // 읽음 처리
  void _handleReadMessage(Map<String, dynamic> msg) {
    final List<dynamic> readIds = msg['data']?['read_message'] ?? [];
    final updated = state.messages.map((m) {
      if (readIds.contains(m.id)) {
        final newCount = (m.unreadCount > 0) ? (m.unreadCount - 1) : 0;
        return m.copyWith(unreadCount: newCount);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  // 일반 메시지(stream) 처리
  Future<void> _handleStreamMessage(Map<String, dynamic> msg) async {
    final data = msg['data'];
    if (data['stream_id'] == chatRoom['stream_id']) {
      final newMessage = ChatMessage.fromJson(data);
      state = state.copyWith(messages: [...state.messages, newMessage]);

      // newest message read
      try {
        await _chatRepository.markNewestMessageAsRead(
          streamId: chatRoom['stream_id'],
        );
      } catch (error) {
        debugPrint('[ChatDetailNotifier] newest message read fail: $error');
      }
    } else {
      debugPrint('[ChatDetailNotifier] 다른 방 메시지');
    }
  }

  // 위치 메시지 처리 (서버 -> 클라이언트)
  void _handleLocationMessage(Map<String, dynamic> msg) {
    final data = msg['data'];
    final userId = data['user_id'] as int?;
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;

    if (userId != null && lat != null && lng != null) {
      debugPrint('[ChatDetailNotifier] location => user:$userId ($lat,$lng)');
       ref.read(mapNotifierProvider.notifier).updateUserCircle(userId, lat, lng);
    }
  }

  // ---------------------------
  // 채팅방 활성 / 비활성
  // ---------------------------
  void _activateRoomRegularly() {
    _activateCurrentChatRoom();
    _activateTimer?.cancel();
    _activateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _activateCurrentChatRoom();
    });
  }

  Future<void> _activateCurrentChatRoom() async {
    try {
      final streamId = chatRoom['stream_id'];
      if (streamId != null) {
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

  // 메시지 읽음 처리
  Future<void> _markMessagesAsRead() async {
    try {
      final unreadCount = chatRoom['unread_message_count'] ?? 0;
      await _chatRepository.markMessagesAsRead(
        streamId: chatRoom['stream_id'],
        numAfter: unreadCount,
      );
    } catch (error) {
      debugPrint('[ChatDetailNotifier] markMessagesAsRead 오류: $error');
    }
  }
}
