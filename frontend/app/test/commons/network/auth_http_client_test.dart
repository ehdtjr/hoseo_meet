import 'dart:convert';
import 'dart:io';
import 'package:campusmeet/commons/network/auth_http_client.dart';
import 'package:campusmeet/features/auth/data/services/auth_service.dart';
import 'package:campusmeet/features/auth/data/services/token_storage_service.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryStorage extends TokenStorageService {
  @override
  Future<String?> readRefreshToken() async => null;
}

class TestAuthNotifier extends AuthNotifier {
  int refreshes = 0;
  bool refreshSucceeds = true;
  TestAuthNotifier() : super(AuthService(), MemoryStorage()) {
    state = state.copyWith(isLoggedIn: true, accessToken: 'old-token');
  }
  @override
  Future<void> refreshAccessToken() async {
    refreshes++;
    state = state.copyWith(
      isLoggedIn: refreshSucceeds,
      accessToken: refreshSucceeds ? 'new-token' : null,
    );
  }
}

void main() {
  late ProviderContainer container;
  late TestAuthNotifier auth;
  late List<http.Request> requests;
  late AuthHttpClient client;
  late Directory snapshotRoot;
  int secondStatus = 200;
  void setupClient({http.Client? transport}) {
    auth = TestAuthNotifier();
    requests = [];
    container = ProviderContainer(overrides: [
      authNotifierProvider.overrideWith((ref) => auth),
    ]);
    final provider = Provider((ref) => AuthHttpClient(
          ref,
          temporaryDirectory: snapshotRoot,
          client: transport ??
              MockClient((request) async {
                requests.add(request);
                return http.Response(
                    '', requests.length == 1 ? 401 : secondStatus);
              }),
        ));
    client = container.read(provider);
  }

  setUp(() async {
    secondStatus = 200;
    snapshotRoot =
        await Directory.systemTemp.createTemp('hoseo-snapshot-test-');
    setupClient();
  });
  tearDown(() async {
    client.close();
    container.dispose();
    try {
      expect(await snapshotRoot.list().toList(), isEmpty,
          reason: 'Upload snapshots must be cleaned on every exit path');
    } finally {
      await snapshotRoot.delete(recursive: true);
    }
  });

  void replaceTransport(http.Client transport) {
    client.close();
    container.dispose();
    setupClient(transport: transport);
  }

  void expectPreserved() {
    expect(requests, hasLength(2));
    expect(auth.refreshes, 1);
    expect(requests[0].headers['Authorization'], 'Bearer old-token');
    expect(requests[1].headers['Authorization'], 'Bearer new-token');
    expect(requests[1].bodyBytes, requests[0].bodyBytes);
    expect(requests[1].headers['content-type'],
        requests[0].headers['content-type']);
    expect(requests[1].url, requests[0].url);
    expect(requests[1].method, requests[0].method);
  }

  test('401 retry preserves form encoding, Korean text and custom headers',
      () async {
    final result = await client.postFormUrlEncoded(
        'https://example.test/send', {'message_content': '한글 & + = ?\n다음 줄'},
        headers: {'X-Client-Message-ID': 'draft-id'});
    expect(result.statusCode, 200);
    expectPreserved();
    expect(requests.last.bodyFields, {'message_content': '한글 & + = ?\n다음 줄'});
    expect(requests.last.headers['content-type'],
        startsWith('application/x-www-form-urlencoded'));
    expect(requests.last.headers['X-Client-Message-ID'], 'draft-id');
  });

  test('401 retry preserves JSON bytes and headers', () async {
    await client.postRequest('https://example.test/json', {
      'text': '한글',
      'ids': [1, 2]
    }, headers: {
      'X-Trace': 'trace'
    });
    expectPreserved();
    expect(requests.last.headers['X-Trace'], 'trace');
    expect(
        requests.last.headers['content-type'], startsWith('application/json'));
  });

  for (final multiple in [false, true]) {
    test(
        '401 retry preserves ${multiple ? 'multiple' : 'single'} multipart body and boundary',
        () async {
      final dir = await Directory.systemTemp.createTemp('hoseo-upload-');
      try {
        final first =
            await File('${dir.path}/first.png').writeAsBytes([0, 1, 2, 255]);
        final second =
            await File('${dir.path}/second.png').writeAsBytes([3, 4, 5]);
        final result = multiple
            ? await client.postMultipleMultipartRequest(
                'https://example.test/upload', 'files', [first, second],
                additionalFields: {'caption': '원문'})
            : await client.postSingleMultipartRequest(
                'https://example.test/upload', 'file', first);
        expect(result.statusCode, 200);
        expectPreserved();
        expect(requests.last.headers['content-type'],
            startsWith('multipart/form-data; boundary='));
        expect(latin1.decode(requests.last.bodyBytes),
            contains('filename="first.png"'));
        if (multiple) {
          expect(latin1.decode(requests.last.bodyBytes),
              contains('filename="second.png"'));
          expect(latin1.decode(requests.last.bodyBytes),
              contains('name="caption"'));
        }
      } finally {
        await dir.delete(recursive: true);
      }
    });
  }

  test('a second 401 terminates after one refresh', () async {
    secondStatus = 401;
    expect(
        (await client.getRequest('https://example.test/unauthorized'))
            .statusCode,
        401);
    expect(requests, hasLength(2));
    expect(auth.refreshes, 1);
  });

  test('failed refresh does not resend with a stale token', () async {
    auth.refreshSucceeds = false;
    expect(
        (await client.getRequest('https://example.test/unauthorized'))
            .statusCode,
        401);
    expect(requests, hasLength(1));
    expect(auth.refreshes, 1);
  });
  test(
      'large multipart retry streams bounded chunks from disk after source deletion',
      () async {
    final sourceRoot =
        await Directory.systemTemp.createTemp('hoseo-large-upload-');
    try {
      final source = File('${sourceRoot.path}/large.png');
      final handle = await source.open(mode: FileMode.write);
      const fileSize = 64 * 1024 * 1024;
      await handle.truncate(fileSize);
      await handle.close();
      var sends = 0;
      final lengths = <int>[];
      final contentTypes = <String?>[];
      var largestChunk = 0;
      replaceTransport(MockClient.streaming((request, stream) async {
        expect(request, isNot(isA<http.Request>()),
            reason:
                'Multipart attempts must not hold an aggregate byte buffer');
        contentTypes.add(request.headers['content-type']);
        var length = 0;
        await for (final chunk in stream) {
          length += chunk.length;
          if (chunk.length > largestChunk) largestChunk = chunk.length;
        }
        expect(length, request.contentLength);
        expect(length, greaterThan(fileSize));
        lengths.add(length);
        sends++;
        if (sends == 1) await source.delete();
        return http.StreamedResponse(
            const Stream<List<int>>.empty(), sends == 1 ? 401 : 200);
      }));
      final result = await client.postSingleMultipartRequest(
          'https://example.test/upload', 'file', source);
      expect(result.statusCode, 200);
      expect(sends, 2);
      expect(auth.refreshes, 1);
      expect(lengths[1], lengths[0]);
      expect(contentTypes[1], contentTypes[0]);
      expect(largestChunk, lessThanOrEqualTo(64 * 1024));
      expect(await source.exists(), isFalse);
    } finally {
      await sourceRoot.delete(recursive: true);
    }
  });

  for (final terminalStatus in [401, 503]) {
    test('multipart HTTP $terminalStatus cleans the disk snapshot after retry',
        () async {
      secondStatus = terminalStatus;
      final sourceRoot =
          await Directory.systemTemp.createTemp('hoseo-small-upload-');
      try {
        final source =
            await File('${sourceRoot.path}/small.png').writeAsBytes([0, 255]);
        final result = await client.postSingleMultipartRequest(
            'https://example.test/upload', 'file', source);
        expect(result.statusCode, terminalStatus);
        expect(requests, hasLength(2));
      } finally {
        await sourceRoot.delete(recursive: true);
      }
    });
  }

  test('multipart transport failure cleans its snapshot without retrying',
      () async {
    final sourceRoot =
        await Directory.systemTemp.createTemp('hoseo-failed-upload-');
    try {
      final source =
          await File('${sourceRoot.path}/small.png').writeAsBytes([0, 255]);
      var sends = 0;
      replaceTransport(MockClient.streaming((request, stream) async {
        await stream.drain<void>();
        sends++;
        throw http.ClientException('offline');
      }));
      expect(
          (await client.postSingleMultipartRequest(
                  'https://example.test/upload', 'file', source))
              .statusCode,
          500);
      expect(sends, 1);
      expect(auth.refreshes, 0);
    } finally {
      await sourceRoot.delete(recursive: true);
    }
  });

  test('multipart failed refresh cleans its snapshot without a second send',
      () async {
    auth.refreshSucceeds = false;
    final sourceRoot =
        await Directory.systemTemp.createTemp('hoseo-refresh-failed-upload-');
    try {
      final source =
          await File('${sourceRoot.path}/small.png').writeAsBytes([0, 255]);
      expect(
          (await client.postSingleMultipartRequest(
                  'https://example.test/upload', 'file', source))
              .statusCode,
          401);
      expect(requests, hasLength(1));
    } finally {
      await sourceRoot.delete(recursive: true);
    }
  });

  test('multipart missing source fails before sending or refreshing', () async {
    expect(
        (await client.postSingleMultipartRequest('https://example.test/upload',
                'file', File('${snapshotRoot.path}/missing.png')))
            .statusCode,
        500);
    expect(requests, isEmpty);
    expect(auth.refreshes, 0);
  });
}
