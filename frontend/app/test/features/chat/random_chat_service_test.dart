import 'dart:async';

import 'package:campusmeet/features/chat/data/models/random_chat_queue.dart';
import 'package:campusmeet/features/chat/data/services/random_chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class FakeRandomChatHttpClient implements RandomChatHttpClient {
  final List<(String, String, Map<String, dynamic>?)> requests = [];
  Future<http.Response> Function(String method, String url)? handler;

  @override
  Future<http.Response> get(String url) {
    requests.add(('GET', url, null));
    return handler!('GET', url);
  }

  @override
  Future<http.Response> post(String url, Map<String, dynamic> body) {
    requests.add(('POST', url, body));
    return handler!('POST', url);
  }
}

void main() {
  late FakeRandomChatHttpClient client;
  late RandomChatService service;

  setUp(() {
    client = FakeRandomChatHttpClient();
    service = RandomChatService(
      client,
      baseUrl: 'https://example.test/api/v1',
      requestTimeout: const Duration(milliseconds: 20),
    );
  });

  test(
    'uses the join, status, and leave contracts and parses each state',
    () async {
      final responses = <http.Response>[
        http.Response('{"status":"waiting","stream_id":null}', 200),
        http.Response('{"status":"matched","stream_id":41}', 200),
        http.Response('{"status":"idle","stream_id":null}', 200),
      ];
      client.handler = (_, __) async => responses.removeAt(0);

      expect((await service.join()).status, RandomChatQueueStatus.waiting);
      expect((await service.getStatus()).streamId, 41);
      expect((await service.leave()).status, RandomChatQueueStatus.idle);
      expect(client.requests, [
        (
          'POST',
          'https://example.test/api/v1/random/match/queue/join',
          const <String, dynamic>{},
        ),
        ('GET', 'https://example.test/api/v1/random/match/queue', null),
        (
          'POST',
          'https://example.test/api/v1/random/match/queue/leave',
          const <String, dynamic>{},
        ),
      ]);
    },
  );

  test(
    'rejects malformed success responses instead of inventing queue state',
    () async {
      client.handler = (_, __) async =>
          http.Response('{"status":"matched","stream_id":null}', 200);

      await expectLater(
        service.getStatus(),
        throwsA(isA<RandomChatServiceException>()),
      );
    },
  );

  test('bounds a request that never completes', () async {
    client.handler = (_, __) => Completer<http.Response>().future;

    await expectLater(
      service.join(),
      throwsA(isA<RandomChatServiceException>()),
    );
  });
}
