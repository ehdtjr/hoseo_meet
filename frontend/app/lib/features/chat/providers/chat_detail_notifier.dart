import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../data/services/message_recovery_service.dart';
import '../data/services/send_message_service.dart';
import 'socket_message_service_provider.dart';

// Auth
import '../../../../features/auth/providers/auth_notifier_provider.dart';

// 위치 표시
import 'chat_room_provicer.dart';
import 'map_provider.dart';
import 'map_notifier.dart';

class ChatDetailNotifier extends StateNotifier<ChatDetailState> {
  ChatDetailNotifier(this.ref, this.chatRoom, {ChatRepository? repository})
      : _repositoryProvided = repository != null,
        super(ChatDetailState()) {
    if (repository != null) {
      _chatRepository = repository;
      _hasRepository = true;
    }
  }

  final Ref ref;
  final ChatRoom chatRoom;

  final bool _repositoryProvided;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _hasRepository = false;
  Future<void>? _recoveryTask;
  bool _recovering = false;
  Future<void>? _readRefreshTask;
  final Set<int> _pendingReadIds = {};
  Future<void> _presenceTask = Future.value();
  MapNotifier? _mapNotifier;
  bool _foreground = true;
  int _resumeRevision = 0;
  int? _recoveryAnchor;
  bool get _active => !_isDisposed && mounted;
  late final ChatRepository _chatRepository;

  Timer? _locationTimer;
  Timer? _activateTimer;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  final Set<String> _exhaustedAnchors = {}; // ✅ 추가된 anchor 추적

  Future<void> init() async {
    if (_isInitialized || !_active) return;
    final client = ref.read(authHttpClientProvider);
    final token = ref.read(authNotifierProvider).accessToken;
    if (token == null) return;
    _isInitialized = true;

    if (!_repositoryProvided) {
      _chatRepository = ChatRepository(
        loadService: LoadMessageService(client),
        sendService: SendMessageService(client),
        readService: MessageReadService(client),
        activateService: ActivateDeactivateService(client),
        socketService: ref.read(socketMessageServiceFactoryProvider)(
          tokenProvider: () async {
            if (!_active || !_foreground) return null;
            final ready = await ref.read(authNotifierProvider.notifier)
                .ensureValidSession();
            if (!_active || !_foreground || !ready) return null;
            return ref.read(authNotifierProvider).accessToken;
          },
          onConnected: _recoverMessages,
        ),
      );
    }

    _hasRepository = true;
    _mapNotifier = ref.read(mapNotifierProvider.notifier);
    await _loadMessagesAtFirstUnread();
    if (!_active) return;
    _recoveryAnchor = state.messages.isEmpty ? null : state.messages.last.id;
    await _loadParticipants();
    if (!_active) return;
    _activateRoomRegularly();
    await _initWebSocket();
  }

  Future<void> _loadParticipants() async {
    try {
      final userService = ref.read(userServiceProvider);
      final userIds = chatRoom.subscribers;
      if (userIds.isEmpty) return;

      final fetchedUsers = await Future.wait(
        userIds.map((id) => userService.getUser(id)),
      );
      if (_active) state = state.copyWith(participants: fetchedUsers);
    } catch (e) {
      debugPrint('[ChatDetailNotifier] 참여자 정보 실패');
    }
  }

  Future<void> startLocationTracking() async {
    if (!_active || !_hasRepository) return;
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_active || !_foreground || !state.isLocationSharing) return;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (!_active || !_foreground) return;
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

  /// Stop resources synchronously, before any best-effort HTTP cleanup.
  Future<void> disposeNotifier() async {
    if (_isDisposed) return;
    _isDisposed = true;
    stopLocationTracking();
    _activateTimer?.cancel();
    _activateTimer = null;
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    _pendingReadIds.clear();
    if (_mapNotifier?.mounted == true) {
      for (final user in state.participants) {
        _mapNotifier!.removeUser(user.id);
      }
    }
    if (_hasRepository) {
      final closing = _chatRepository.disposeSocketService();
      await Future.wait([closing, _deactivateCurrentChatRoom()]);
    }
  }

  @override
  void dispose() {
    unawaited(disposeNotifier());
    super.dispose();
  }

  Future<void> pauseConnection() async {
    _resumeRevision++;
    _foreground = false;
    if (!_hasRepository || !_active) return;
    final closing = _chatRepository.closeWebSocket();
    await Future.wait([closing, _deactivateCurrentChatRoom()]);
  }

  Future<void> resumeConnection() async {
    if (!_active) return;
    final revision = ++_resumeRevision;
    _foreground = false;
    final ready = await ref.read(authNotifierProvider.notifier)
        .ensureValidSession();
    if (!_active || revision != _resumeRevision || !ready) return;
    _foreground = true;
    if (!_hasRepository || _socketSubscription == null) return;
    await _activateCurrentChatRoom();
    if (_active && _foreground && revision == _resumeRevision) {
      await _chatRepository.reconnectWebSocket();
    }
  }

  void authenticationChanged() {
    if (!_active) return;
    final auth = ref.read(authNotifierProvider);
    if (!auth.isLoggedIn || auth.accessToken == null) {
      unawaited(disposeNotifier());
    } else if (_foreground && _hasRepository && _socketSubscription != null) {
      unawaited(_chatRepository.reconnectWebSocket());
    }
  }

  Future<void> _recoverMessages() {
    final previous = _recoveryTask;
    final task = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          /* Retry the same checkpoint. */
        }
      }
      if (!_active || !_foreground) return;
      // Redis presence may have expired or been lost during a server restart.
      await _activateCurrentChatRoom();
      if (!_active || !_foreground) return;
      await _performRecovery();
    }();
    _recoveryTask = task;
    return task.whenComplete(() {
      if (identical(_recoveryTask, task)) _recoveryTask = null;
    });
  }

  Future<void> _performRecovery() async {
    _recovering = true;
    try {
      // Refresh receipts for the already displayed history as well as the gap.
      // A live event received before the first catch-up must not turn an empty
      // baseline into a later starting point.
      final anchor = _recoveryAnchor == null || state.messages.isEmpty
          ? _recoveryAnchor
          : math.min(_recoveryAnchor!, state.messages.first.id);
      final recovered =
          await MessageRecoveryService(_chatRepository.loadMessages).recover(
        streamId: chatRoom.streamId,
        afterId: anchor,
        isActive: () => _active && _foreground,
      );
      if (!_active || !_foreground || recovered.isEmpty) return;
      state = state.copyWith(
          messages: _mergeMessagesIgnoringDuplicates(
              currentList: state.messages, incomingList: recovered));
      _recoveryAnchor = recovered.last.id;
      ref.read(chatRoomNotifierProvider.notifier).handleIncomingMessage(
          newMessage: state.messages.last, markAsRead: true);
      // Numeric, inclusive upper bound: messages created after the HTTP
      // watermark cannot be marked read by this request.
      await _markMessagesAsRead(recovered);
    } finally {
      _recovering = false;
      _refreshPendingReadStates();
    }
  }

  Future<void> _loadMessagesAtFirstUnread() async {
    try {
      final previousMessages = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: 'first_unread',
        numBefore: 30,
        numAfter: chatRoom.unreadCount,
      );

      if (!_active) return;
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
    if (!_active || !_hasRepository || state.isLoadingMore) return;

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

      if (!_active) return;
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
      if (_active) state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<bool> sendMessage(String content) async {
    if (!_active ||
        !_hasRepository ||
        content.trim().isEmpty ||
        state.isSending) {
      return false;
    }
    // Sending the unchanged failed draft is a retry of the same logical send.
    final matching = state.outgoingMessages.where((m) => m.draft == content);
    final outgoing =
        matching.isEmpty ? OutgoingMessage.create(content) : matching.first;
    return _sendOutgoing(outgoing);
  }

  Future<bool> retryMessage(String clientMessageId) async {
    if (!_active || !_hasRepository || state.isSending) return false;
    final matching = state.outgoingMessages
        .where((m) => m.clientMessageId == clientMessageId);
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
      if (_active) {
        state = state.copyWith(outgoingMessages: [
          for (final message in state.outgoingMessages)
            message.clientMessageId == outgoing.clientMessageId
                ? message.withStatus(MessageSendStatus.failed)
                : message,
        ]);
      }
      return false;
    }

    if (_active) {
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
    if (!_active || !_foreground) return;
    try {
      final latest = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: 'newest',
        numBefore: 30,
        numAfter: 0,
      );
      if (!_active || !_foreground || latest.isEmpty) return;
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
      if (!_active || !_foreground) return;
      // Read acknowledgements are also delivered over the socket that may be
      // unavailable. Fetch authoritative counts instead of assuming zero or
      // decrementing every message (other participants may still be unread).
      final readSnapshot = await _chatRepository.loadMessages(
        streamId: chatRoom.streamId,
        anchor: anchorId.toString(),
        numBefore: latest.length - 1,
        numAfter: 0,
      );
      if (!_active || !_foreground) return;
      _mergeServerSnapshot(readSnapshot);
      _updateRoomPreview();
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 전송 후 메시지 동기화 실패');
    }
  }

  void _mergeServerSnapshot(List<ChatMessage> snapshot) {
    state = state.copyWith(
        messages: _mergeMessagesIgnoringDuplicates(
            currentList: state.messages, incomingList: snapshot));
  }

  void _updateRoomPreview() {
    if (state.messages.isEmpty) return;
    ref.read(chatRoomNotifierProvider.notifier).handleIncomingMessage(
          newMessage: state.messages.last,
          markAsRead: true,
        );
  }

  Future<void> _initWebSocket() async {
    if (!_active) return;
    _socketSubscription = _chatRepository.messageStream.listen((
      incoming,
    ) async {
      if (!_active) return;
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
    if (_foreground) await _chatRepository.connectWebSocket();
  }

  void _handleReadMessage(Map<String, dynamic> msg) {
    final data = msg['data'];
    if (data is! Map || data['read_message'] is! List) return;
    for (final rawId in data['read_message'] as List) {
      final id = rawId is int ? rawId : int.tryParse(rawId.toString());
      if (id != null) _pendingReadIds.add(id);
    }
    _refreshPendingReadStates();
  }

  void _refreshPendingReadStates() {
    if (!_active ||
        !_foreground ||
        _recovering ||
        _readRefreshTask != null ||
        _pendingReadIds.isEmpty) {
      return;
    }
    var failed = false;
    final task = () async {
      while (_active &&
          _foreground &&
          !_recovering &&
          _pendingReadIds.isNotEmpty) {
        final ids = Set<int>.of(_pendingReadIds);
        _pendingReadIds.clear();
        try {
          final refreshed =
              await MessageRecoveryService(_chatRepository.loadMessages)
                  .refreshReadStates(
                      streamId: chatRoom.streamId,
                      cachedMessages: state.messages,
                      messageIds: ids,
                      isActive: () => _active && _foreground);
          if (!_active || !_foreground) return;
          state = state.copyWith(
              messages: _mergeMessagesIgnoringDuplicates(
                  currentList: state.messages, incomingList: refreshed));
        } catch (error) {
          failed = true;
          if (_active) _pendingReadIds.addAll(ids);
          debugPrint('[ChatDetailNotifier] 읽음 상태 동기화 실패');
          break; // A later event or reconnect retries; avoid a hot failure loop.
        }
      }
    }();
    _readRefreshTask = task;
    unawaited(task.whenComplete(() {
      if (identical(_readRefreshTask, task)) _readRefreshTask = null;
      if (!failed) _refreshPendingReadStates();
    }));
  }

  Future<void> _handleStreamMessage(Map<String, dynamic> msg) async {
    final data = msg['data'];
    if (data is! Map<String, dynamic>) return;
    final newMessage = ChatMessage.fromJson(data);
    if (newMessage.streamId == chatRoom.streamId) {
      if (state.messages.any((m) => m.id == newMessage.id)) return;
      if (!_active) return;
      final merged = _mergeMessagesIgnoringDuplicates(
        currentList: state.messages,
        incomingList: [newMessage],
        prepend: false,
      );
      state = state.copyWith(messages: merged);

      // Retries can arrive after newer messages; preview the newest merged ID.
      _updateRoomPreview();

      try {
        await _markMessagesAsRead([newMessage]);
      } catch (error) {
        debugPrint('[ChatDetailNotifier] read 실패');
      }
    }
  }

  void _handleLocationMessage(Map<String, dynamic> msg) {
    final data = msg['data'];
    if (data is! Map<String, dynamic>) return;
    final userId = data['user_id'] as int?;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();

    if (userId != null && lat != null && lng != null) {
      ref
          .read(mapNotifierProvider.notifier)
          .updateUserPosition(userId, lat, lng);
    }
  }

  void _activateRoomRegularly() {
    _activateCurrentChatRoom();
    _activateTimer?.cancel();
    _activateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _activateCurrentChatRoom();
    });
  }

  Future<void> _activateCurrentChatRoom() => _queuePresence(active: true);

  Future<void> _deactivateCurrentChatRoom() => _queuePresence(active: false);

  Future<void> _queuePresence({required bool active}) {
    // A slow background deactivation must finish before a resume activation.
    _presenceTask = _presenceTask.then((_) async {
      if (active && (!_active || !_foreground || chatRoom.streamId == 0)) {
        return;
      }
      try {
        if (active) {
          await _chatRepository
              .activateRoom(chatRoom.streamId)
              .timeout(const Duration(seconds: 15));
        } else {
          await _chatRepository
              .deactivateRoom()
              .timeout(const Duration(seconds: 15));
        }
      } catch (error) {
        debugPrint('[ChatDetailNotifier] 방 활성 상태 변경 실패');
      }
    });
    return _presenceTask;
  }

  Future<void> _markMessagesAsRead(List<ChatMessage> messages) async {
    if (!_active || !_foreground || messages.isEmpty) return;
    try {
      await _chatRepository
          .markLoadedMessagesAsRead(
            streamId: chatRoom.streamId,
            anchorId: messages.last.id,
            numBefore: messages.length - 1,
          )
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      debugPrint('[ChatDetailNotifier] 읽음 처리 실패');
    }
  }

  List<ChatMessage> _mergeMessagesIgnoringDuplicates({
    required List<ChatMessage> currentList,
    required List<ChatMessage> incomingList,
    bool prepend = false,
  }) {
    final byId = {for (final message in currentList) message.id: message};
    for (final incoming in incomingList) {
      final current = byId[incoming.id];
      byId[incoming.id] = current == null
          ? incoming
          : incoming.copyWith(
              unreadCount: math.min(current.unreadCount, incoming.unreadCount));
    }
    final updated = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return updated;
  }
}
