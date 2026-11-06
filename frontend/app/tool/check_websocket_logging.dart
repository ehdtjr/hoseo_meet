// Run with Dart JIT and as an AOT executable: checks must not depend on asserts.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campusmeet/features/chat/data/services/socket_message_service.dart';

const markers = [
  'PRIVATE_CHAT_24',
  '37.123456789',
  '127.987654321',
  'TOKEN_24'
];

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final logs = <String>[];
  await runZoned(() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peerReady = Completer<WebSocket>();
    final requests = server.listen((request) async {
      if (request.uri.path == '/reject') {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write(markers.join(' '));
        await request.response.close();
        return;
      }
      final peer = await WebSocketTransformer.upgrade(request,
          protocolSelector: (_) => markers.last);
      peer.listen((_) {});
      peerReady.complete(peer);
    });
    final service = SocketMessageService(
        tokenProvider: () => markers.last,
        socketUrl: 'ws://127.0.0.1:${server.port}/events');
    final delivered = <Map<String, dynamic>>[];
    final allDelivered = Completer<void>();
    final subscription = service.messageStream.listen((event) {
      delivered.add(event);
      if (delivered.length == 6) allDelivered.complete();
    });
    try {
      await service.connectWebSocket();
      final peer = await peerReady.future.timeout(const Duration(seconds: 5));
      final frames = [
        for (final type in ['stream', 'location', 'read', 'user'])
          {
            'type': type,
            'data': {
              'content': markers.first,
              'lat': double.parse(markers[1]),
              'lng': double.parse(markers[2]),
              'token': markers.last,
            },
          },
        {'type': markers.first, 'data': markers.last},
        {'type': markers, 'data': markers.last},
      ];
      // FormatException.toString() quotes its source; test both syntax and shape.
      peer.add('${markers.join(' ')} {');
      peer.add(jsonEncode(markers));
      peer.add(utf8.encode(markers.join(' ')));
      for (final frame in frames) {
        peer.add(jsonEncode(frame));
      }
      await allDelivered.future.timeout(const Duration(seconds: 5));
      check(jsonEncode(delivered) == jsonEncode(frames),
          'Events must reach subscribers unchanged after malformed input');
      await peer.close(WebSocketStatus.normalClosure, markers.last);
      // Wait for the close callback so its diagnostic is captured as well.
      for (var i = 0;
          i < 100 && !logs.contains('[WebSocket] disconnected');
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      check(logs.contains('[WebSocket] disconnected'), 'Missing close status');

      await service.closeWebSocket();

      final rejected = SocketMessageService(
          tokenProvider: () => markers.last,
          initialRetryDelay: const Duration(milliseconds: 10),
          maxRetryDelay: const Duration(milliseconds: 20),
          socketUrl:
              'ws://127.0.0.1:${server.port}/reject?token=${markers.last}');
      await rejected.connectWebSocket();
      for (var i = 0;
          i < 500 && !logs.contains('[WebSocket] retry_scheduled attempt=3');
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await rejected.dispose();
    } finally {
      await service.dispose();
      await subscription.cancel();
      await requests.cancel();
      await server.close(force: true);
    }
  }, zoneSpecification: ZoneSpecification(print: (_, __, ___, line) {
    logs.add(line);
  }));

  final output = logs.join('\n');
  for (final marker in markers) {
    check(!output.contains(marker), 'Private marker leaked into socket logs');
  }
  for (final status in [
    'state=connected',
    'received type=stream',
    'received type=location',
    'received type=read',
    'received type=user',
    'received type=unknown',
    'decode_failed',
    'invalid_message_shape',
    'disconnected',
    'connect_failed',
    'retry_scheduled attempt=3',
    'state=disconnected',
    'state=disposed',
    'invalid_frame',
  ]) {
    check(
        output.contains('[WebSocket] $status'), 'Missing diagnostic: $status');
  }
  // Print the checked capture for a reviewable, synthetic-only evidence log.
  stdout.writeln(output);
  stdout.writeln('PASS: 6 events preserved; private markers absent from logs.');
}
