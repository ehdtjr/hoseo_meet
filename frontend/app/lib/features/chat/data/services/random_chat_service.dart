import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../commons/network/auth_http_client.dart';
import '../../../../config.dart';
import '../models/random_chat_queue.dart';

abstract class RandomChatQueueApi {
  Future<RandomChatQueueSnapshot> join();
  Future<RandomChatQueueSnapshot> getStatus();
  Future<RandomChatQueueSnapshot> leave();
}

abstract class RandomChatHttpClient {
  Future<http.Response> get(String url);
  Future<http.Response> post(String url, Map<String, dynamic> body);
}

class AuthRandomChatHttpClient implements RandomChatHttpClient {
  final AuthHttpClient _client;

  AuthRandomChatHttpClient(this._client);

  @override
  Future<http.Response> get(String url) => _client.getRequest(url);

  @override
  Future<http.Response> post(String url, Map<String, dynamic> body) =>
      _client.postRequest(url, body);
}

class RandomChatServiceException implements Exception {
  const RandomChatServiceException();
}

class RandomChatService implements RandomChatQueueApi {
  final RandomChatHttpClient _client;
  final String _queueUrl;
  final Duration _requestTimeout;

  RandomChatService(
    this._client, {
    String baseUrl = AppConfig.baseUrl,
    Duration requestTimeout = const Duration(seconds: 10),
  }) : _queueUrl = '$baseUrl/random/match/queue',
       _requestTimeout = requestTimeout;

  @override
  Future<RandomChatQueueSnapshot> join() =>
      _send(() => _client.post('$_queueUrl/join', const {}));

  @override
  Future<RandomChatQueueSnapshot> getStatus() =>
      _send(() => _client.get(_queueUrl));

  @override
  Future<RandomChatQueueSnapshot> leave() =>
      _send(() => _client.post('$_queueUrl/leave', const {}));

  Future<RandomChatQueueSnapshot> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(_requestTimeout);
      if (response.statusCode != 200) {
        throw const RandomChatServiceException();
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const RandomChatServiceException();
      }
      return RandomChatQueueSnapshot.fromJson(decoded);
    } on RandomChatServiceException {
      rethrow;
    } catch (_) {
      throw const RandomChatServiceException();
    }
  }
}
