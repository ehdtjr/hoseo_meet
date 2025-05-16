import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../config.dart';
import '../models/auth_state.dart';

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
      final body = jsonDecode(utf8.decode(response.bodyBytes)); // ✅ 여기도
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
        'error': utf8.decode(response.bodyBytes), // ✅ 여기 꼭 수정
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

  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String name,
    required String gender,
    String profile = '',
  }) async {
    const registerUrl = '${AppConfig.baseUrl}/auth/register';

    final body = {
      "email": email,
      "password": password,
      "name": name,
      "gender": gender,
      "profile": profile,
      "is_active": true,
      "is_superuser": false,
      "is_verified": false,
    };

    try {
      final response = await http.post(
        Uri.parse(registerUrl),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'statusCode': response.statusCode,
          'message': '회원가입 성공',
        };
      } else {
        return {
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'statusCode': -1,
        'error': '회원가입 중 오류 발생: $e',
      };
    }
  }

  Future<Map<String, dynamic>> logout({
    required String accessToken,
  }) async {
    const url = '${AppConfig.baseUrl}/auth/logout';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken', // ✅ 핵심
        },
      );

      if (response.statusCode == 200) {
        return {'statusCode': 200};
      } else {
        return {
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e) {
      return {
        'statusCode': -1,
        'error': '로그아웃 중 오류 발생: $e',
      };
    }
  }

  Future<Register> register(RegisterRequest request) async {
    const registerUrl = '${AppConfig.baseUrl}/auth/register';

    try {
      final response = await http.post(
        Uri.parse(registerUrl),
        headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Register.success('회원가입 성공');
      } else {
        final Map<String, dynamic> errorBody = jsonDecode(response.body);
        final errorMessage = errorBody['detail'] ?? '회원가입 실패';
        return Register.failure(errorMessage.toString());
      }
    } catch (e) {
      return Register.failure('회원가입 중 오류 발생: $e');
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    const forgotPasswordUrl = '${AppConfig.baseUrl}/auth/forgot-password';

    try {
      final response = await http.post(
        Uri.parse(forgotPasswordUrl),
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 202) {
        return {
          'statusCode': 202,
          'message': '비밀번호 재설정 메일이 전송되었습니다.',
        };
      } else {
        // body가 비어있지 않은 경우에만 jsonDecode
        String errorMessage = '요청 실패';
        if (response.body.isNotEmpty) {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              errorMessage = decoded['detail'] ?? errorMessage;
            } else {
              errorMessage = response.body;
            }
          } catch (e) {
            errorMessage = '서버 응답 파싱 실패: $e';
          }
        }

        return {
          'statusCode': response.statusCode,
          'error': errorMessage,
        };
      }
    } catch (e) {
      return {
        'statusCode': -1,
        'error': '비밀번호 재설정 요청 중 오류 발생: $e',
      };
    }
  }


  /// 필요 시 리소스 정리
  void dispose() {
    print('[AuthService] dispose() called');
  }
}
