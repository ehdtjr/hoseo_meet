import 'dart:async';

import 'package:campusmeet/features/auth/data/services/auth_service.dart';
import 'package:campusmeet/features/auth/data/services/token_storage_service.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:campusmeet/features/chat/data/models/chat_message.dart';
import 'package:campusmeet/features/chat/data/models/chat_room.dart';
import 'package:campusmeet/features/chat/data/repositories/chat_repository.dart';
import 'package:campusmeet/features/chat/providers/chat_detail_notifier.dart';
import 'package:campusmeet/features/chat/providers/map_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const privateText = 'PRIVATE_CHAT_24 37.123456789 127.987654321 TOKEN_24';

class EmptyStorage extends TokenStorageService {
  @override
  Future<String?> readRefreshToken() async => null;
}

class LoggedInAuth extends AuthNotifier {
  LoggedInAuth() : super(AuthService(), EmptyStorage()) {
    state = state.copyWith(accessToken: 'TOKEN_24', isLoggedIn: true);
  }
}

class SocketRepository implements ChatRepository {
  final events = StreamController<Map<String, dynamic>>();
  @override
  Stream<Map<String, dynamic>> get messageStream => events.stream;
  @override
  Future<void> connectWebSocket() async {}
  @override
  Future<void> markMessagesAsRead(
          {required int streamId, required int numAfter}) async =>
      throw const FormatException(privateText, privateText);
  @override
  Future<List<ChatMessage>> loadMessages(
          {required int streamId,
          String anchor = 'first_unread',
          int numBefore = 10,
          int numAfter = 30}) async =>
      throw const FormatException(privateText, privateText);
  @override
  Future<void> markNewestMessageAsRead({required int streamId}) async =>
      throw const FormatException(privateText, privateText);
  @override
  Future<void> activateRoom(int streamId) async =>
      throw const FormatException(privateText, privateText);
  @override
  Future<void> deactivateRoom() async =>
      throw const FormatException(privateText, privateText);
  @override
  void closeWebSocket() {}
  @override
  void disposeSocketService() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
      'socket consumers sanitize errors and keep processing chat, read and location events',
      () async {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) logs.add(message);
    };
    final repository = SocketRepository();
    final room = ChatRoom(
        streamId: 7,
        creatorId: 1,
        type: 'meet',
        name: 'test',
        isMuted: false,
        subscribers: [],
        unreadCount: 0,
        lastMessageContent: '',
        time: '');
    final provider = StateNotifierProvider<ChatDetailNotifier, ChatDetailState>(
        (ref) => ChatDetailNotifier(ref, room, repository: repository));
    final container = ProviderContainer(overrides: [
      authNotifierProvider.overrideWith((ref) => LoggedInAuth()),
    ]);
    final notifier = container.read(provider.notifier);
    try {
      await notifier.init();
      await notifier.loadMoreMessages();
      final message = {
        'id': 42,
        'sender_id': 1,
        'recipient_id': 7,
        'stream_id': 7,
        'content': privateText,
        'date_sent': '2026-11-06T00:00:00Z',
        'unread_count': 2,
        'type': 1,
      };
      for (final event in <Map<String, dynamic>>[
        {'type': privateText, 'data': privateText},
        {
          'type': 'stream',
          'data': {...message, 'date_sent': privateText}
        },
        {
          'type': 'read',
          'data': {'read_message': privateText}
        },
        {
          'type': 'location',
          'data': {'user_id': 1, 'lat': privateText, 'lng': privateText}
        },
        {'type': 'stream', 'data': message},
        {
          'type': 'read',
          'data': {
            'read_message': [42]
          }
        },
        {
          'type': 'location',
          'data': {'user_id': 1, 'lat': 37.123456789, 'lng': 127.987654321}
        },
      ]) {
        repository.events.add(event);
        await Future<void>.delayed(Duration.zero);
      }
      final state = container.read(provider);
      expect(state.messages.single.content, privateText);
      expect(state.messages.single.unreadCount, 1);
      expect(container.read(mapNotifierProvider)[1]!.latitude, 37.123456789);
      expect(container.read(mapNotifierProvider)[1]!.longitude, 127.987654321);
      expect(logs.where((line) => line.contains('socket_event_failed')),
          hasLength(3));
      expect(logs.any((line) => line.contains('알 수 없는 소켓 타입')), isTrue);
      expect(logs.any((line) => line.contains('read 실패')), isTrue);
    } finally {
      await notifier.disposeNotifier();
      await repository.events.close();
      container.dispose();
      debugPrint = previousDebugPrint;
    }
    final output = logs.join('\n');
    for (final marker in privateText.split(' ')) {
      expect(output, isNot(contains(marker)));
    }
    expect(output, contains('초기 메시지 로드 실패'));
    expect(output, contains('이전 메시지 로드 실패'));
    expect(output, contains('읽음 처리 실패'));
    expect(output, contains('방 활성화 실패'));
    expect(output, contains('방 비활성화 실패'));
  });
}
