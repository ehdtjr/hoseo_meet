import '../../../../commons/network/auth_http_client.dart'; // AuthHttpClient import
import '../../../../config.dart';

class MessageSendException implements Exception {
  final int statusCode;
  const MessageSendException(this.statusCode);

  @override
  String toString() => "메시지 전송 실패 (HTTP $statusCode)";
}

class SendMessageService {
  final String _locationEndpoint =
      '${AppConfig.baseUrl}/messages/send/stream/location/';
  final AuthHttpClient _client; // AuthHttpClient 주입

  SendMessageService(this._client);

  /// 1) 텍스트 메시지 전송 (form-urlencoded)
  Future<void> sendMessage({
    required int streamId,
    required String messageContent,
    required String clientMessageId,
  }) async {
    final formBody = <String, String>{
      'message_content': messageContent,
    };

    final url =
        '${AppConfig.baseUrl}/messages/send/stream/$streamId?lifetime_seconds=3600';

    // AuthHttpClient의 postFormUrlEncoded 활용
    final response = await _client.postFormUrlEncoded(url, formBody,
        headers: {'X-Client-Message-ID': clientMessageId});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MessageSendException(response.statusCode);
    }
  }

  /// 2) 위치 전송
  Future<void> sendLocation({
    required int streamId,
    required double lat,
    required double lng,
  }) async {
    final url = '$_locationEndpoint$streamId';

    // JSON 형식의 바디
    final Map<String, dynamic> jsonBody = {
      'lat': lat,
      'lng': lng,
    };
    await _client.postRequest(url, jsonBody);
  }
}
