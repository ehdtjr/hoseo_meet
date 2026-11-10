import 'dart:async';
import 'dart:convert';

import 'package:campusmeet/commons/network/auth_http_client.dart';
import 'package:campusmeet/features/auth/data/services/auth_service.dart';
import 'package:campusmeet/features/auth/data/services/token_storage_service.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier.dart';
import 'package:campusmeet/features/auth/providers/auth_notifier_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String token(int expiresIn) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn,
        })))}.signature';

class MemoryStorage extends TokenStorageService {
  String? value;
  int deletes = 0;
  Completer<void>? writeGate;
  MemoryStorage([this.value]);
  @override
  Future<String?> readRefreshToken() async => value;
  @override
  Future<void> writeRefreshToken(String token) async {
    await writeGate?.future;
    value = token;
  }

  @override
  Future<void> deleteRefreshToken() async {
    deletes++;
    value = null;
  }
}

class SessionService extends AuthService {
  int refreshes = 0;
  Map<String, dynamic> response = {'statusCode': 503};
  Future<Map<String, dynamic>> Function()? handler;
  String access = token(-60);
  @override
  Future<Map<String, dynamic>> loginUser({
    required String username,
    required String password,
  }) async =>
      {'statusCode': 200, 'accessToken': access, 'refreshToken': username};
  @override
  Future<Map<String, dynamic>> refreshAccessToken(
      {required String refreshToken}) async {
    refreshes++;
    return handler == null ? response : await handler!();
  }

  @override
  Future<Map<String, dynamic>> logout({required String accessToken}) async =>
      {'statusCode': 200};
}

void main() {
  late SessionService service;
  late MemoryStorage storage;
  late AuthNotifier auth;
  Future<void> setup([String? saved, int initialStatus = 503]) async {
    service = SessionService()..response = {'statusCode': initialStatus};
    storage = MemoryStorage(saved);
    auth = AuthNotifier(service, storage);
    await auth.initialization;
    addTearDown(() {
      if (auth.mounted) auth.dispose();
    });
  }

  test(
      'concurrent expired-session recovery shares refresh and persists rotation',
      () async {
    await setup();
    await auth.loginUser('refresh-one', 'password');
    final gate = Completer<Map<String, dynamic>>();
    service.handler = () => gate.future;
    final resumes = List.generate(8, (_) => auth.ensureValidSession());
    await Future<void>.delayed(Duration.zero);
    expect(service.refreshes, 1);
    expect(auth.state.isLoggedIn, isTrue);
    gate.complete({
      'statusCode': 200,
      'accessToken': token(3600),
      'refreshToken': 'rotated'
    });
    expect(await Future.wait(resumes), everyElement(isTrue));
    expect(storage.value, 'rotated');
    expect(auth.state.refreshToken, 'rotated');
  });

  test('concurrent failed foreground refresh is attempted only once', () async {
    await setup();
    await auth.loginUser('saved', 'password');
    final gate = Completer<Map<String, dynamic>>();
    service.handler = () => gate.future;
    final resumes = List.generate(8, (_) => auth.ensureValidSession());
    await Future<void>.delayed(Duration.zero);
    gate.complete({'statusCode': 503});
    expect(await Future.wait(resumes), everyElement(isFalse));
    expect(service.refreshes, 1);
    expect(storage.value, 'saved');
  });

  for (final status in [-1, 429, 500, 503]) {
    test('startup/resume HTTP $status preserves refresh for later recovery',
        () async {
      await setup('saved', status);
      service.response = {'statusCode': status};
      expect(await auth.ensureValidSession(), isFalse);
      expect(storage.value, 'saved');
      expect(storage.deletes, 0);
      service.response = {'statusCode': 200, 'accessToken': token(3600)};
      expect(await auth.ensureValidSession(), isTrue);
      expect(auth.state.refreshToken, 'saved');
    });
  }

  test('thrown transport failure preserves a logged-in session and credential',
      () async {
    await setup();
    await auth.loginUser('saved', 'password');
    final oldAccess = auth.state.accessToken;
    service.handler = () async => throw http.ClientException('offline');
    expect(await auth.ensureValidSession(), isFalse);
    expect(auth.state.isLoggedIn, isTrue);
    expect(auth.state.accessToken, oldAccess);
    expect(storage.value, 'saved');
  });

  for (final status in [400, 401, 403]) {
    test(
        'credential rejection $status clears both tokens and forbids stale retry',
        () async {
      await setup();
      await auth.loginUser('saved', 'password');
      final oldAccess = auth.state.accessToken!;
      service.response = {'statusCode': status};
      expect(await auth.refreshRejectedToken(oldAccess), isFalse);
      expect(auth.state.isLoggedIn, isFalse);
      expect(auth.state.accessToken, isNull);
      expect(auth.state.refreshToken, isNull);
      expect(storage.value, isNull);
    });
  }

  test(
      'late refresh response cannot resurrect logout or replace another account',
      () async {
    await setup();
    await auth.loginUser('first', 'password');
    final gate = Completer<Map<String, dynamic>>();
    service.handler = () => gate.future;
    final refreshing = auth.refreshAccessToken();
    await auth.logout();
    service.access = token(7200);
    await auth.loginUser('second', 'password');
    gate.complete(
        {'statusCode': 200, 'accessToken': 'stale', 'refreshToken': 'stale'});
    await refreshing;
    expect(auth.state.accessToken, service.access);
    expect(auth.state.refreshToken, 'second');
    expect(storage.value, 'second');
  });

  test('logout wins over a persistent token write already in flight', () async {
    await setup();
    await auth.loginUser('first', 'password');
    storage.writeGate = Completer<void>();
    service.response = {
      'statusCode': 200,
      'accessToken': token(3600),
      'refreshToken': 'rotated'
    };
    final refreshing = auth.refreshAccessToken();
    await Future<void>.delayed(Duration.zero);
    final loggingOut = auth.logout();
    storage.writeGate!.complete();
    await Future.wait([refreshing, loggingOut]);
    expect(storage.value, isNull);
    expect(auth.state.accessToken, isNull);
  });

  test(
      'concurrent and delayed 401s share refresh without resending stale credentials',
      () async {
    await setup();
    await auth.loginUser('saved', 'password');
    final oldAccess = auth.state.accessToken!;
    final refreshGate = Completer<Map<String, dynamic>>();
    final delayed401 = Completer<void>();
    service.handler = () => refreshGate.future;
    var oldSends = 0;
    var newSends = 0;
    final transport = MockClient((request) async {
      if (request.headers['Authorization'] == 'Bearer $oldAccess') {
        oldSends++;
        if (request.url.path == '/late') await delayed401.future;
        return http.Response('', 401);
      }
      newSends++;
      return http.Response('', 200);
    });
    final container = ProviderContainer(overrides: [
      authNotifierProvider.overrideWith((ref) => auth),
    ]);
    final client = container
        .read(Provider((ref) => AuthHttpClient(ref, client: transport)));
    addTearDown(container.dispose);
    addTearDown(client.close);
    final requests = [
      for (final path in ['a', 'b', 'late'])
        client.getRequest('https://example.test/$path')
    ];
    await Future<void>.delayed(Duration.zero);
    expect(oldSends, 3);
    expect(service.refreshes, 1);
    refreshGate.complete({'statusCode': 200, 'accessToken': token(3600)});
    await Future.wait(requests.take(2));
    delayed401.complete();
    expect((await Future.wait(requests)).map((r) => r.statusCode),
        everyElement(200));
    expect(service.refreshes, 1);
    expect(newSends, 3);
  });

  test('temporary refresh failure returns original 401 without stale retry',
      () async {
    await setup();
    await auth.loginUser('saved', 'password');
    var sends = 0;
    final container = ProviderContainer(
        overrides: [authNotifierProvider.overrideWith((ref) => auth)]);
    final client = container.read(
        Provider((ref) => AuthHttpClient(ref, client: MockClient((_) async {
              sends++;
              return http.Response('', 401);
            }))));
    addTearDown(container.dispose);
    addTearDown(client.close);
    expect((await client.getRequest('https://example.test/a')).statusCode, 401);
    expect(sends, 1);
    expect(auth.state.isLoggedIn, isTrue);
    expect(storage.value, 'saved');
  });
}
