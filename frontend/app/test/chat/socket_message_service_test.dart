import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campusmeet/features/chat/data/services/socket_message_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late HttpServer server;
  late List<WebSocket> sockets;
  late List<String?> tokens;
  late SocketMessageService service;
  var token = 'old-token';

  setUp(() async {
    sockets = [];
    tokens = [];
    token = 'old-token';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      tokens.add(request.headers.value('sec-websocket-protocol'));
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((_) {}, onError: (Object _) {});
      sockets.add(socket);
    });
    service = SocketMessageService(
      tokenProvider: () => token,
      socketUrl: 'ws://127.0.0.1:${server.port}',
      initialRetryDelay: const Duration(milliseconds: 15),
      maxRetryDelay: const Duration(milliseconds: 40),
    );
  });

  tearDown(() async {
    service.dispose();
    for (final socket in sockets) {
      unawaited(socket.close());
    }
    await server.close(force: true);
  });

  test(
    'coalesces connects, reconnects after success, and reads the latest token',
    () async {
      final received = <Map<String, dynamic>>[];
      final subscription = service.messageStream.listen(received.add);
      await Future.wait(List.generate(12, (_) => service.connectWebSocket()));
      expect(sockets, hasLength(1));
      expect(service.connectionState, SocketConnectionState.connected);
      sockets.first.add(jsonEncode({'type': 'stream', 'last_event_id': '1-0'}));
      await waitFor(() => received.length == 1);
      token = 'new-token';
      await sockets.first.close();
      await waitFor(
        () =>
            tokens.length == 2 &&
            service.connectionState == SocketConnectionState.connected,
      );
      expect(tokens, ['old-token', 'new-token']);
      sockets.last.add(jsonEncode({'type': 'stream', 'last_event_id': '1-0'}));
      sockets.last.add('broken json');
      sockets.last.add('[1, 2]');
      sockets.last.add(jsonEncode({'type': 'stream', 'last_event_id': '2-0'}));
      await waitFor(() => received.length == 2);
      expect(received.map((e) => e['last_event_id']), ['1-0', '2-0']);
      await subscription.cancel();
    },
  );

  test(
    'retries failures with capped exponential backoff until network returns',
    () async {
      service.dispose();
      var attempts = 0;
      final times = <DateTime>[];
      service = SocketMessageService(
        tokenProvider: () => token,
        connector: (url, token) async {
          times.add(DateTime.now());
          if (++attempts < 5) throw const SocketException('network down');
          return WebSocket.connect('ws://127.0.0.1:${server.port}');
        },
        initialRetryDelay: const Duration(milliseconds: 20),
        maxRetryDelay: const Duration(milliseconds: 60),
      );
      await service.connectWebSocket();
      await waitFor(
        () => service.connectionState == SocketConnectionState.connected,
      );
      expect(attempts, 5); // Keeps trying beyond the old three-attempt limit.
      final gaps = List.generate(
        4,
        (i) => times[i + 1].difference(times[i]).inMilliseconds,
      );
      expect(gaps[0], greaterThanOrEqualTo(18));
      expect(gaps[1], greaterThanOrEqualTo(38));
      expect(gaps[2], greaterThanOrEqualTo(58));
      expect(gaps[3], greaterThanOrEqualTo(58));
    },
  );

  test('stream errors reconnect after an established connection', () async {
    service.dispose();
    final controller = StreamController<dynamic>();
    var attempts = 0;
    service = SocketMessageService(
      tokenProvider: () => token,
      initialRetryDelay: const Duration(milliseconds: 10),
      connector: (_, __) async {
        if (++attempts == 1) return ErrorSocket(controller.stream);
        return WebSocket.connect('ws://127.0.0.1:${server.port}');
      },
    );
    await service.connectWebSocket();
    controller.addError(const SocketException('connection reset'));
    await waitFor(
      () =>
          attempts == 2 &&
          service.connectionState == SocketConnectionState.connected,
    );
    await controller.close();
  });

  test('dispose cancels a pending retry and completes all listeners', () async {
    await service.connectWebSocket();
    final messagesDone = service.messageStream.drain<void>();
    final statesDone = service.connectionStates.drain<void>();
    await sockets.first.close();
    await waitFor(
      () => service.connectionState == SocketConnectionState.reconnecting,
    );
    service.dispose();
    service.dispose();
    await Future.wait([messagesDone, statesDone]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(tokens, hasLength(1));
    expect(service.connectionState, SocketConnectionState.disposed);
    await service.connectWebSocket();
    expect(tokens, hasLength(1));
  });

  test(
    'late handshake is closed after dispose without attaching a listener',
    () async {
      service.dispose();
      final handshake = Completer<WebSocket>();
      service = SocketMessageService(
        tokenProvider: () => token,
        connector: (_, __) => handshake.future,
      );
      final connecting = service.connectWebSocket();
      await Future<void>.delayed(Duration.zero);
      service.dispose();
      final lateSocket = await WebSocket.connect(
        'ws://127.0.0.1:${server.port}',
      );
      handshake.complete(lateSocket);
      await connecting;
      await waitFor(() => lateSocket.readyState == WebSocket.closed);
      expect(service.connectionState, SocketConnectionState.disposed);
    },
  );

  test('handshake timeout retries and closes the late socket', () async {
    service.dispose();
    final handshake = Completer<WebSocket>();
    var attempts = 0;
    service = SocketMessageService(
      tokenProvider: () => token,
      connectTimeout: const Duration(milliseconds: 30),
      initialRetryDelay: const Duration(milliseconds: 10),
      connector: (_, __) {
        if (++attempts == 1) return handshake.future;
        return WebSocket.connect('ws://127.0.0.1:${server.port}');
      },
    );
    await service.connectWebSocket();
    await waitFor(
      () => service.connectionState == SocketConnectionState.connected,
    );
    final lateSocket = await WebSocket.connect('ws://127.0.0.1:${server.port}');
    handshake.complete(lateSocket);
    await waitFor(() => lateSocket.readyState == WebSocket.closed);
    expect(attempts, 2);
  });

  test('established socket disposal clears heartbeat and protocol-close timers',
      () async {
    final timers = <Timer, Duration>{};
    await runZoned(() async {
      await service.connectWebSocket();
      await service.dispose();
    }, zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        final timer = parent.createTimer(zone, duration, callback);
        timers[timer] = duration;
        return timer;
      },
    ));
    expect(
        timers.entries.where((entry) => entry.key.isActive).toList(), isEmpty,
        reason:
            'No heartbeat, close-handshake, or retry timers may survive awaited disposal');
  });

  test('explicit close and absent authentication stop reconnecting', () async {
    await service.connectWebSocket();
    service.closeWebSocket();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(tokens, hasLength(1));
    token = '';
    await service.connectWebSocket();
    expect(service.connectionState, SocketConnectionState.disconnected);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(tokens, hasLength(1));
  });

  test('failed catch-up retries even after the handshake succeeded', () async {
    service.dispose();
    var recoveries = 0;
    service = SocketMessageService(
      tokenProvider: () => token,
      socketUrl: 'ws://127.0.0.1:${server.port}',
      initialRetryDelay: const Duration(milliseconds: 10),
      onConnected: () async {
        if (++recoveries == 1) throw const HttpException('offline');
      },
    );
    await service.connectWebSocket();
    await waitFor(
      () => service.connectionState == SocketConnectionState.connected,
    );
    expect(recoveries, 2);
    expect(tokens, hasLength(2));
  });
}

class ErrorSocket extends Stream<dynamic> implements WebSocket {
  ErrorSocket(this.source);
  final Stream<dynamic> source;
  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      source.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );
  @override
  Future<void> close([int? code, String? reason]) async {}
  @override
  set pingInterval(Duration? value) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
