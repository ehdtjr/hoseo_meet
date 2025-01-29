import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../config.dart';

class AuthService {
  final String _loginEndpoint = '${AppConfig.baseUrl}/auth/login';
  final String _refreshEndpoint = '${AppConfig.baseUrl}/auth/refresh';

  /// 로그인 로직
  /// - 성공 시 { "statusCode": 200, "accessToken": "...", "refreshToken": "..." }
  /// - 실패 시 { "statusCode": ..., "error": "..." }
  Future<Map<String, dynamic>> loginUser({
    required String username,
    required String password,
  }) async {

    final requestData = {
      'grant_type': 'password',
      'username': username,
      'password': password,
      'scope': '',
      'client_id': 'string',
      'client_secret': 'string',
    };

    final response = await http.post(
      Uri.parse(_loginEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: requestData,
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final accessToken = body['access_token'] as String?;
      final refreshToken = body['refresh_token'] as String?;

      return {
        'statusCode': 200,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
    } else {
      return {
        'statusCode': response.statusCode,
        'error': response.body,
      };
    }
  }

  /// Refresh Token 재발급 (자동로그인)
  /// - 성공 시 { "statusCode": 200, "accessToken": "...", "refreshToken": "..." }
  /// - 실패 시 { "statusCode": ..., "error": "..." }
  Future<Map<String, dynamic>> refreshAccessToken({
    required String refreshToken,
  }) async {
    print('[AuthService] Attempting to refresh token=$refreshToken');

    try {
      final response = await http.post(
        Uri.parse(_refreshEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"refresh_token": refreshToken}),
      );
      print('[AuthService] refresh code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;

        print('[AuthService] Access token refreshed successfully: $newAccess');
        return {
          'statusCode': 200,
          'accessToken': newAccess,
          'refreshToken': newRefresh,
        };
      } else {
        print('[AuthService] refresh failed: ${response.body}');
        return {
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e) {
      print('[AuthService] Exception in refreshAccessToken: $e');
      return {
        'statusCode': -1,
        'error': '$e',
      };
    }
  }

  /// 필요 시 리소스 정리
  void dispose() {
    print('[AuthService] dispose() called');
  }
}
