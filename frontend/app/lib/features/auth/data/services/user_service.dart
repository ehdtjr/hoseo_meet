import 'dart:convert';                     // jsonDecode 등
import 'package:http/http.dart' as http;   // http.Response

import 'package:hoseomeet/commons/network/auth_http_client.dart';
import 'package:hoseomeet/features/auth/data/models/user.dart';
import '../../../../config.dart';

class UserService {
  final AuthHttpClient _client;

  UserService(this._client);

  /// /auth/me 로부터 현재 사용자 프로필(UserProfile)을 가져온다
  Future<UserProfile> getUserProfile() async {
    const uri = '${AppConfig.baseUrl}/auth/me';
    final http.Response response = await _client.getRequest(uri);

    if (response.statusCode == 200) {
      // 1) UTF-8 디코딩 + JSON 파싱
      final decodedBody = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> jsonData = jsonDecode(decodedBody);

      // 2) UserProfile 객체로 변환
      final userProfile = UserProfile.fromJson(jsonData);
      return userProfile;
    } else {
      throw Exception(
        'Failed to fetch user profile. '
            'statusCode: ${response.statusCode}, body: ${response.body}',
      );
    }
  }

  /// 특정 userId에 대한 유저 정보를 가져온다
  Future<User> getUser(int userId) async {
    final uri = '${AppConfig.baseUrl}/users/$userId/profile';
    final http.Response response = await _client.getRequest(uri);

    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> jsonData = jsonDecode(decodedBody);

      // 2) User 객체로 변환
      final user = User.fromJson(jsonData);
      return user;
    } else {
      throw Exception(
        'Failed to fetch user (ID: $userId). '
            'statusCode: ${response.statusCode}, body: ${response.body}',
      );
    }
  }
}
