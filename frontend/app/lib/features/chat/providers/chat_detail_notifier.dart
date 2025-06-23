import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../commons/network/auth_http_client_provider.dart';
import '../../auth/providers/user_profile_provider.dart';
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

// 위치 표시
import 'chat_room_provicer.dart';
import 'map_provider.dart';

class ChatDetailNotifier extends StateNotifier<ChatDetailState> {
  ChatDetailNotifier(this.ref, this.chatRoom) : super(ChatDetailState());

  final Ref ref;
  final ChatRoom chatRoom;

  bool _isInitialized = false;
  late final ChatRepository _chatRepository;

  Timer? _locationTimer;
  Timer? _activateTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  final Set<String> _exhaustedAnchors = {}; // ✅ 추가된 anchor 추적

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final client = ref.read(authHttpClientProvider);
    final token = ref.read(authNotifierProvider).accessToken;
    if (token == null) return;

    _chatRepository = ChatRepository(
      loadService: LoadMessageService(client),
      sendService: SendMessageService(client),
      readService: MessageReadService(client),
      activateService: ActivateDeactivateService(client),
      socketService: SocketMessageService(token),
    );

    await _markMessagesAsRead();
    await _loadMessagesAtFirstUnread();
    await _loadParticipants();
    await _initWebSocket();
    _activateRoomRegularly();
  }

  Future<void> _loadParticipants() async {
    try {
      final userService = ref.read(userServiceProvider);
      final userIds = chatRoom.subscribers;
      if (userIds.isEmpty) return;

      final fetchedUsers = await Future.wait(
        userIds.map((id) => userService.getUser(id)),
      );
      state = state.copyWith(participants: fetchedUsers);
    } catch (e) {
      debugPrint('[ChatDetailNotifier] 참여자 정보 실패: $e');
    }
  }

  Future<void> startLocationTracking() async {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!state.isLocationSharing) return;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _chatRepository.sendLocation(
          streamId: chatRoom.streamId,
          lat: position.latitude,
          lng: position.longitude,
        );
      } catch (e) {
        debugPrint('[ChatDetailNotifier] 위치 전송 실패: $e');
      }
    });
  }

  void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> disposeNotifier() async {
    stopLocationTracking();
    _activateTimer?.cancel();
    _activateTimer = null;

    final mapNotifier = ref.read(mapNotifierProvider.notifier);
    for (final user in state.participants) {
      mapNotifier.removeUser(user.id);
    }

    await _deactivateCurrentChatRoom();
    await _socketSubscription?.cancel();
    _chatRepository.closeWebSocket();
    _chatRepository.disposeSocketService();
  }

  Future<void> _loadMessagesAtFirstUnread() async {
    try {
      final previousMessages = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: 'first_unread',
        numBefore: 30,
        numAfter: chatRoom.unreadCount,
      );

      final merged = _mergeMessagesIgnoringDuplicates(
        currentList: state.messages,
        incomingList: previousMessages,
        prepend: false,
      );

      state = state.copyWith(messages: merged);
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 초기 메시지 로드 실패: $error');
    }
  }

  // ✅ 최종 수정된 loadMoreMessages()
  Future<void> loadMoreMessages() async {
    if (state.isLoadingMore) return;

    final oldestId = state.messages.isNotEmpty
        ? state.messages.first.id.toString()
        : 'first_unread';

    state = state.copyWith(isLoadingMore: true);

    try {
      final moreMessages = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: oldestId,
        numBefore: 30,
        numAfter: 0,
      );

      final merged = _mergeMessagesIgnoringDuplicates(
        currentList: state.messages,
        incomingList: moreMessages,
        prepend: true,
      );

      if (merged.length != state.messages.length) {
        state = state.copyWith(messages: merged, hasMore: true); // ✅ 메시지 추가됨
      } else {
        debugPrint('[ChatDetailNotifier] 병합 결과 동일 → 상태 갱신 생략');
        debugPrint('[ChatDetailNotifier] 더 이상 불러올 메시지가 없음 → anchor 등록');
        _exhaustedAnchors.add(oldestId);
        state = state.copyWith(hasMore: false); // ✅ 더 이상 없음
      }
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 이전 메시지 로드 실패: $error');
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }


  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    try {
      await _chatRepository.sendMessage(
        streamId: chatRoom.streamId,
        content: trimmed,
      );
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 메시지 전송 실패: $error');
    }
  }

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
          debugPrint('[ChatDetailNotifier] 알 수 없는 소켓 타입: $type');
          break;
      }
    });
  }

  void _handleReadMessage(Map<String, dynamic> msg) {
    final readIds = msg['data']?['read_message'] as List<dynamic>? ?? [];
    final updated = state.messages.map((m) {
      if (readIds.contains(m.id)) {
        final newCount = m.unreadCount > 0 ? m.unreadCount - 1 : 0;
        return m.copyWith(unreadCount: newCount);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  Future<void> _handleStreamMessage(Map<String, dynamic> msg) async {
    final data = msg['data'];
    if (data['stream_id'] == chatRoom.streamId) {
      final newMessage = ChatMessage.fromJson(data);
      final merged = _mergeMessagesIgnoringDuplicates(
        currentList: state.messages,
        incomingList: [newMessage],
        prepend: false,
      );
      state = state.copyWith(messages: merged);

      ref.read(chatRoomNotifierProvider.notifier).handleIncomingMessage(
        newMessage: newMessage,
        markAsRead: true,
      );

      try {
        await _chatRepository.markNewestMessageAsRead(
          streamId: chatRoom.streamId,
        );
      } catch (error) {
        debugPrint('[ChatDetailNotifier] read 실패: $error');
      }
    }
  }

  void _handleLocationMessage(Map<String, dynamic> msg) {
    final data = msg['data'];
    final userId = data['user_id'] as int?;
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;

    if (userId != null && lat != null && lng != null) {
      ref.read(mapNotifierProvider.notifier).updateUserPosition(userId, lat, lng);
    }
  }

  void _activateRoomRegularly() {
    _activateCurrentChatRoom();
    _activateTimer?.cancel();
    _activateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _activateCurrentChatRoom();
    });
  }

  Future<void> _activateCurrentChatRoom() async {
    try {
      if (chatRoom.streamId != 0) {
        await _chatRepository.activateRoom(chatRoom.streamId);
      }
    } catch (e) {
      debugPrint('[ChatDetailNotifier] 방 활성화 실패: $e');
    }
  }

  Future<void> _deactivateCurrentChatRoom() async {
    try {
      await _chatRepository.deactivateRoom();
    } catch (e) {
      debugPrint('[ChatDetailNotifier] 방 비활성화 실패: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatRepository.markMessagesAsRead(
        streamId: chatRoom.streamId,
        numAfter: chatRoom.unreadCount,
      );
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 읽음 처리 실패: $error');
    }
  }

  List<ChatMessage> _mergeMessagesIgnoringDuplicates({
    required List<ChatMessage> currentList,
    required List<ChatMessage> incomingList,
    bool prepend = false,
  }) {
    final existingIds = currentList.map((m) => m.id).toSet();
    final updated = [...currentList];

    for (final incoming in incomingList) {
      if (!existingIds.contains(incoming.id)) {
        if (prepend) {
          updated.insert(0, incoming);
        } else {
          updated.add(incoming);
        }
        existingIds.add(incoming.id);
        debugPrint('메시지 추가됨: ${incoming.id}');
      } else {
        debugPrint('중복 메시지 생략: ${incoming.id}');
      }
    }

    return updated;
  }
}
