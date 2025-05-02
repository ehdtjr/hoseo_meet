// features/chat/data/services/chat_stream_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../commons/network/auth_http_client.dart';
import '../../../../config.dart';
import '../models/chat_bot_message.dart';

/// AuthHttpClient.sendStreamRequest을 활용한
/// application/x-www-form-urlencoded 스트림 수신 서비스
class ChatStreamService {
  final AuthHttpClient _client;
  final String _streamEndpoint = '${AppConfig.baseUrl}/chat_bot/chat/';

  ChatStreamService(this._client);

  /// [prompt]를 form-urlencoded 로 보내고,
  /// 서버가 줄 단위(\n) JSON으로 흘려주는 청크를 ChatBotChunk로 스트리밍 반환
  Stream<ChatBotChunk> streamMessages({ required String prompt }) async* {
    final uri = Uri.parse(_streamEndpoint);
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
      ..bodyFields = {'prompt': prompt};

    final streamedResponse = await _client.sendStreamRequest(request);
    if (streamedResponse.statusCode != 200) {
      throw Exception('채팅 스트림 요청 실패: HTTP ${streamedResponse.statusCode}');
    }

    // utf8 디코딩 + 라인 단위 분리
    final lines = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final Map<String, dynamic> jsonMap = json.decode(line);
      yield ChatBotChunk.fromJson(jsonMap);
    }
  }
}
