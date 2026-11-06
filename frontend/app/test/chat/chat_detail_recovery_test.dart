import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campusmeet/commons/network/auth_http_client.dart';
import 'package:campusmeet/commons/network/auth_http_client_provider.dart';
import 'package:campusmeet/features/auth/data/services/auth_service.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:campusmeet/features/chat/data/models/chat_room.dart';
import 'package:campusmeet/features/chat/data/services/socket_message_service.dart';
import 'package:campusmeet/features/chat/providers/chat_detail_provider.dart';
import 'package:campusmeet/features/chat/providers/socket_message_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'socket_message_service_test.dart' show waitFor;

Map<String, dynamic> message(int id) => {
      'id': id,
      'stream_id': 7,
      'date_sent': '2026-11-06T00:00:00Z',
      'content': '$id',
    };

class TestAuthService extends AuthService {
  final logoutGate = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> loginUser({
    required String username,
    required String password,
  }) async =>
      {
        'statusCode': 200,
        'accessToken': username,
        'refreshToken': 'refresh',
      };
  @override
  Future<Map<String, dynamic>> logout({required String accessToken}) =>
      logoutGate.future;
}

class HistoryClient extends AuthHttpClient {
  HistoryClient(super.ref);
  int newest = 1;
  Completer<void>? pageGate;
  bool failPage = false;
  final anchors = <String>[];
  final unreadCounts = <int, int>{};
  final posts = <({String path, Map<String, dynamic> body})>[];
  final markedIds = <int>{};
  int? activeStream;
  Future<void> Function(String anchor)? afterLoad;
  Future<void> Function(String path, Map<String, dynamic> body)? beforePost;

  Map<String, dynamic> snapshot(int id) => {
        ...message(id),
        'unread_count': unreadCounts[id] ?? 0,
      };
  @override
  Future<http.Response> getRequest(String url) async {
    final query = Uri.parse(url).queryParameters;
    final anchor = query['anchor']!;
    anchors.add(anchor);
    if (anchor == 'first_unread') {
      return http.Response(jsonEncode([snapshot(1)]), 200);
    }
    if (anchor == 'newest') {
      return http.Response(jsonEncode([snapshot(newest)]), 200);
    }
    await pageGate?.future;
    if (failPage) {
      failPage = false;
      return http.Response('offline', 503);
    }
    final from = anchor == 'oldest' ? 1 : int.parse(anchor);
    final after = int.parse(query['num_after']!);
    final before = int.parse(query['num_before']!);
    final ids = [
      for (var id = from - before < 1 ? 1 : from - before;
          id <= newest && id <= from + after;
          id++)
        snapshot(id),
    ];
    await afterLoad?.call(anchor);
    return http.Response(jsonEncode(ids), 200);
  }

  @override
  Future<http.Response> postRequest(
    String url,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final path = Uri.parse(url).path;
    posts.add((path: path, body: Map.of(body)));
    await beforePost?.call(path, body);
    if (path.endsWith('/deactive')) activeStream = null;
    if (path.endsWith('/active')) activeStream = 7;
    if (path.endsWith('/flags/stream')) {
      final anchor = body['anchor'] == 'newest'
          ? newest
          : body['anchor'] == 'first_unread'
              ? 1
              : int.parse(body['anchor'] as String);
      final before = body['num_before'] as int;
      final after = body['num_after'] as int;
      for (var id = anchor - before;
          id <= anchor + after && id <= newest;
          id++) {
        if (id > 0) markedIds.add(id);
      }
    }
    return http.Response('{}', 200);
  }
}

void main() {
  test(
    'notifier recovers a failed gap despite newer live events, then cancels on logout',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final tokens = <String?>[];
      server.listen((request) async {
        tokens.add(request.headers.value('sec-websocket-protocol'));
        final connection = await WebSocketTransformer.upgrade(request);
        connection.listen((_) {}, onError: (Object _) {});
        sockets.add(connection);
      });
      final authService = TestAuthService();
      late HistoryClient client;
      late SocketMessageService socket;
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          authHttpClientProvider.overrideWith(
            (ref) => client = HistoryClient(ref),
          ),
          socketMessageServiceFactoryProvider.overrideWithValue(
            ({required tokenProvider, required onConnected}) =>
                socket = SocketMessageService(
              tokenProvider: tokenProvider,
              onConnected: onConnected,
              socketUrl: 'ws://127.0.0.1:${server.port}',
              initialRetryDelay: const Duration(milliseconds: 20),
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        for (final connection in sockets) {
          unawaited(connection.close());
        }
        await server.close(force: true);
      });
      final auth = container.read(authNotifierProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await auth.loginUser('token-one', 'password');
      final room = ChatRoom(
        streamId: 7,
        creatorId: 1,
        type: 'meet',
        name: 'test',
        isMuted: false,
        subscribers: [],
        unreadCount: 0,
        lastMessageContent: '',
        time: '',
      );
      final provider = chatDetailNotifierProvider(room);
      final listener = container.listen(provider, (_, __) {});
      final notifier = container.read(provider.notifier);
      await notifier.init();
      expect(container.read(provider).messages.map((m) => m.id), [1]);

      client.newest = 351;
      client.failPage = true;
      client.pageGate = Completer<void>();
      await sockets.first.close();
      await waitFor(() => sockets.length == 2 && client.anchors.contains('1'));
      // A live event must not move the HTTP checkpoint past the missing 2..350.
      sockets.last.add(
        jsonEncode({
          'type': 'stream',
          'data': message(351),
          'last_event_id': '351-0',
        }),
      );
      await waitFor(() => container.read(provider).messages.length == 2);
      client.pageGate!.complete();
      await waitFor(() => container.read(provider).messages.length == 351);
      expect(
        container.read(provider).messages.map((m) => m.id),
        List.generate(351, (i) => i + 1),
      );
      expect(client.anchors.where((a) => a == '1'), hasLength(2));
      expect(sockets, hasLength(3));

      await auth.loginUser('token-two', 'password');
      await waitFor(
        () =>
            tokens.last == 'token-two' &&
            socket.connectionState == SocketConnectionState.connected,
      );
      final beforePause = tokens.length;
      final pausing = notifier.pauseConnection();
      expect(socket.connectionState, SocketConnectionState.disconnected);
      await pausing;
      await notifier.resumeConnection();
      expect(tokens.length, beforePause + 1);
      final beforeLogout = tokens.length;
      // The server logout is deliberately blocked: local shutdown must be immediate.
      final loggingOut = auth.logout();
      expect(socket.connectionState, SocketConnectionState.disposed);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(tokens, hasLength(beforeLogout));
      authService.logoutGate.complete({'statusCode': 200});
      await loggingOut;
      listener.close();
      await container.pump();
      expect(notifier.mounted, isFalse);
    },
  );

  test(
    'disposing before init is safe and reopening gets a fresh notifier',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final room = ChatRoom(
        streamId: 7,
        creatorId: 1,
        type: 'meet',
        name: 'test',
        isMuted: false,
        subscribers: [],
        unreadCount: 0,
        lastMessageContent: '',
        time: '',
      );
      final provider = chatDetailNotifierProvider(room);
      var listener = container.listen(provider, (_, __) {});
      final first = container.read(provider.notifier);
      await first.disposeNotifier();
      listener.close();
      await container.pump();
      expect(first.mounted, isFalse);
      listener = container.listen(provider, (_, __) {});
      expect(identical(container.read(provider.notifier), first), isFalse);
      listener.close();
    },
  );
}
