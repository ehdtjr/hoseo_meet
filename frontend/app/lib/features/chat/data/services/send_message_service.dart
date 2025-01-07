import 'package:http/http.dart' as http;
import '../../../../commons/network/auth_http_client.dart'; // AuthHttpClient import
import '../../../../config.dart';

class SendMessageService {
  final String _locationEndpoint = '${AppConfig.baseUrl}/messages/send/stream/location/';
  final AuthHttpClient _client; // AuthHttpClient 주입

  SendMessageService(this._client);

  /// 1) 텍스트 메시지 전송 (form-urlencoded)
  Future<void> sendMessage({
    required int streamId,
    required String messageContent,
  }) async {
    final formBody = <String, String>{
      'message_content': messageContent,
    };

    final url = '${AppConfig.baseUrl}/messages/send/stream/$streamId?lifetime_seconds=3600';

    // AuthHttpClient의 postFormUrlEncoded 활용
    await _client.postFormUrlEncoded(url, formBody);
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
