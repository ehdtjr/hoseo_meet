import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../commons/network/auth_http_client_provider.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../data/models/chat_message.dart';
import '../data/models/outgoing_message.dart';
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
  ChatDetailNotifier(this.ref, this.chatRoom, {ChatRepository? repository})
      : _repositoryProvided = repository != null, super(ChatDetailState()) {
    if (repository != null) _chatRepository = repository;
  }

  final Ref ref;
  final ChatRoom chatRoom;

  bool _isInitialized = false;
  bool _isRoomClosed = false;
  final bool _repositoryProvided;
  late final ChatRepository _chatRepository;

  Timer? _locationTimer;
  Timer? _activateTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  final Set<String> _exhaustedAnchors = {}; // ✅ 추가된 anchor 추적

  Future<void> init() async {
    _isRoomClosed = false;
    if (_isInitialized) return;
    _isInitialized = true;

    final client = ref.read(authHttpClientProvider);
    final token = ref.read(authNotifierProvider).accessToken;
    if (token == null) return;

    if (!_repositoryProvided) {
      _chatRepository = ChatRepository(
        loadService: LoadMessageService(client),
        sendService: SendMessageService(client),
        readService: MessageReadService(client),
        activateService: ActivateDeactivateService(client),
        socketService: SocketMessageService(token),
      );
    }

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
      debugPrint('[ChatDetailNotifier] 참여자 정보 실패');
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
        debugPrint('[ChatDetailNotifier] 위치 전송 실패');
      }
    });
  }

  void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> disposeNotifier() async {
    _isRoomClosed = true;
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
      debugPrint('[ChatDetailNotifier] 초기 메시지 로드 실패');
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
      debugPrint('[ChatDetailNotifier] 이전 메시지 로드 실패');
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }


  Future<bool> sendMessage(String content) async {
    if (content.trim().isEmpty || state.isSending) return false;
    // Sending the unchanged failed draft is a retry of the same logical send.
    final matching = state.outgoingMessages.where((m) => m.draft == content);
    final outgoing = matching.isEmpty
        ? OutgoingMessage.create(content)
        : matching.first;
    return _sendOutgoing(outgoing);
  }

  Future<bool> retryMessage(String clientMessageId) async {
    if (state.isSending) return false;
    final matching = state.outgoingMessages.where(
        (m) => m.clientMessageId == clientMessageId);
    if (matching.isEmpty) return false;
    return _sendOutgoing(matching.first);
  }

  Future<bool> _sendOutgoing(OutgoingMessage outgoing) async {
    state = state.copyWith(outgoingMessages: [
      for (final message in state.outgoingMessages)
        if (message.clientMessageId != outgoing.clientMessageId) message,
      outgoing.withStatus(MessageSendStatus.sending),
    ]);
    try {
      await _chatRepository.sendMessage(
        streamId: chatRoom.streamId,
        content: outgoing.draft.trim(),
        clientMessageId: outgoing.clientMessageId,
      );
    } catch (error) {
      if (mounted) {
        state = state.copyWith(outgoingMessages: [
          for (final message in state.outgoingMessages)
            message.clientMessageId == outgoing.clientMessageId
                ? message.withStatus(MessageSendStatus.failed) : message,
        ]);
      }
      return false;
    }

    if (mounted) {
      state = state.copyWith(outgoingMessages: [
        for (final message in state.outgoingMessages)
          if (message.clientMessageId != outgoing.clientMessageId) message,
      ]);
      unawaited(_syncLatestMessages());
    }
    return true;
  }

  // Recover missed WebSocket events without delaying the acknowledged send or
  // offering to resend it when a read/history request fails.
  Future<void> _syncLatestMessages() async {
    try {
      final latest = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: 'newest',
        numBefore: 30,
        numAfter: 0,
      );
      if (!mounted || _isRoomClosed || latest.isEmpty) return;
      final knownIds = state.messages.map((m) => m.id).toSet();
      final hasRecoveredMessages = latest.any((m) => !knownIds.contains(m.id));
      _mergeServerSnapshot(latest);
      _updateRoomPreview();
      if (!hasRecoveredMessages) return;

      final anchorId = latest.map((m) => m.id).reduce((a, b) => a > b ? a : b);
      await _chatRepository.markLoadedMessagesAsRead(
        streamId: chatRoom.streamId,
        anchorId: anchorId,
        numBefore: latest.length - 1,
      );
      if (!mounted || _isRoomClosed) return;
      // Read acknowledgements are also delivered over the socket that may be
      // unavailable. Fetch authoritative counts instead of assuming zero or
      // decrementing every message (other participants may still be unread).
      final readSnapshot = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: anchorId.toString(),
        numBefore: latest.length - 1,
        numAfter: 0,
      );
      if (!mounted || _isRoomClosed) return;
      _mergeServerSnapshot(readSnapshot);
      _updateRoomPreview();
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 전송 후 메시지 동기화 실패');
    }
  }

  void _mergeServerSnapshot(List<ChatMessage> snapshot) {
    final byId = {for (final message in state.messages) message.id: message};
    for (final message in snapshot) {
      final existing = byId[message.id];
      // A delayed history response must not undo newer socket read updates.
      byId[message.id] = existing != null &&
              existing.unreadCount < message.unreadCount
          ? message.copyWith(unreadCount: existing.unreadCount)
          : message;
    }
    final messages = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    state = state.copyWith(messages: messages);
  }

  void _updateRoomPreview() {
    if (state.messages.isEmpty) return;
    ref.read(chatRoomNotifierProvider.notifier).handleIncomingMessage(
      newMessage: state.messages.last,
      markAsRead: true,
    );
  }

  Future<void> _initWebSocket() async {
    await _chatRepository.connectWebSocket();
    _socketSubscription = _chatRepository.messageStream.listen((incoming) async {
      try {
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
            debugPrint('[ChatDetailNotifier] 알 수 없는 소켓 타입');
            break;
        }
      } catch (_) {
        // Parsing exceptions can quote message fields or coordinates.
        debugPrint('[ChatDetailNotifier] socket_event_failed');
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
        debugPrint('[ChatDetailNotifier] read 실패');
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
      debugPrint('[ChatDetailNotifier] 방 활성화 실패');
    }
  }

  Future<void> _deactivateCurrentChatRoom() async {
    try {
      await _chatRepository.deactivateRoom();
    } catch (e) {
      debugPrint('[ChatDetailNotifier] 방 비활성화 실패');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatRepository.markMessagesAsRead(
        streamId: chatRoom.streamId,
        numAfter: chatRoom.unreadCount,
      );
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 읽음 처리 실패');
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
