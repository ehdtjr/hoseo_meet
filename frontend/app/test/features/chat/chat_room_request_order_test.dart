import 'dart:async';
import 'dart:collection';

import 'package:campusmeet/features/chat/data/models/chat_room.dart';
import 'package:campusmeet/features/chat/data/services/chat_room_service.dart';
import 'package:campusmeet/features/chat/providers/chat_room_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

class GatedChatRoomService implements ChatRoomService {
  final Queue<Completer<List<ChatRoom>>> loads = Queue();
  final List<int> unsubscribed = [];

  @override
  final String roomListEndpoint = 'test://rooms';

  @override
  final String unsubscribeEndpoint = 'test://unsubscribe';

  @override
  Future<List<ChatRoom>> loadRoomList() => loads.removeFirst().future;

  @override
  Future<void> unsubscribeRoom(int streamId) async {
    unsubscribed.add(streamId);
  }
}

ChatRoom room(int id) => ChatRoom(
      streamId: id,
      creatorId: 1,
      type: 'random',
      name: 'room-$id',
      isMuted: false,
      subscribers: [1, 2],
      unreadCount: 0,
      lastMessageContent: '',
      time: '',
    );

void main() {
  late GatedChatRoomService service;
  late ChatRoomNotifier notifier;

  setUp(() {
    service = GatedChatRoomService();
    notifier = ChatRoomNotifier(service);
  });

  tearDown(() => notifier.dispose());

  test('a slow older fetch cannot replace a newer room snapshot', () async {
    final older = Completer<List<ChatRoom>>();
    final newer = Completer<List<ChatRoom>>();
    service.loads
      ..add(older)
      ..add(newer);

    final olderRequest = notifier.fetchRooms();
    final newerRequest = notifier.fetchRooms();
    newer.complete([room(2)]);
    await newerRequest;
    expect(notifier.state.map((item) => item.streamId), [2]);

    older.complete([room(1)]);
    await olderRequest;
    expect(notifier.state.map((item) => item.streamId), [2]);
  });

  test('a pre-unsubscribe fetch cannot resurrect the removed room', () async {
    final initial = Completer<List<ChatRoom>>();
    service.loads.add(initial);
    final initialRequest = notifier.fetchRooms();
    initial.complete([room(1)]);
    await initialRequest;

    final stale = Completer<List<ChatRoom>>();
    service.loads.add(stale);
    final staleRequest = notifier.fetchRooms();
    await notifier.unsubscribe(1);
    expect(notifier.state, isEmpty);

    stale.complete([room(1)]);
    await staleRequest;
    expect(notifier.state, isEmpty);
    expect(service.unsubscribed, [1]);
  });

  test('bulk unsubscribe invalidates a pending pre-removal snapshot', () async {
    final initial = Completer<List<ChatRoom>>();
    service.loads.add(initial);
    final initialRequest = notifier.fetchRooms();
    initial.complete([room(1), room(2)]);
    await initialRequest;
    notifier.toggleRoomRemoval(1);
    notifier.toggleRoomRemoval(2);

    final stale = Completer<List<ChatRoom>>();
    service.loads.add(stale);
    final staleRequest = notifier.fetchRooms();
    await notifier.removeSelectedRooms();
    expect(notifier.state, isEmpty);

    stale.complete([room(1), room(2)]);
    await staleRequest;
    expect(notifier.state, isEmpty);
    expect(service.unsubscribed, [1, 2]);
  });
}
