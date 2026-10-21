import '../../../../commons/network/auth_http_client.dart';
import '../../../../config.dart';

class ActivateDeactivateService {
  final AuthHttpClient _client;

  ActivateDeactivateService(this._client);

  /// 채팅방 활성화 (POST /stream/{streamId}/active)
  Future<void> activateRoom(int streamId) async {
    final url = '${AppConfig.baseUrl}/stream/$streamId/active?lifetime_seconds=3600';

    // POST 요청 (body가 없으므로 빈 Map 전달)
    final response = await _client.postRequest(url, {});

    if (response.statusCode == 200) {
      print('[Activate] 성공: $streamId');
      print('응답: ${response.body}');
    } else {
      print('[Activate] 실패: ${response.statusCode}');
      print('응답: ${response.body}');
    }
  }

  Future<void> deactivateRoom() async {
    const url = '${AppConfig.baseUrl}/stream/deactive';

    final response = await _client.postRequest(url, {});

    if (response.statusCode == 200) {
      print('[Deactivate] 성공');
      print('응답: ${response.body}');
    } else {
      print('[Deactivate] 실패: ${response.statusCode}');
      print('응답: ${response.body}');
    }
  }
}
