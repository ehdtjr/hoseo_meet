import 'dart:convert';                     // jsonDecode 등
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;   // http.Response

import 'package:hoseomeet/commons/network/auth_http_client.dart';
import 'package:hoseomeet/features/auth/data/models/user.dart';
import '../../../../config.dart';

class UserService {
  final AuthHttpClient _client;

  UserService(this._client);

  Future<UserProfile> uploadProfileImage(File imageFile) async {
    const url = '${AppConfig.baseUrl}/users/me/profile';

    try {
      final response = await _client.postSingleMultipartRequest(
        url,
        'file',
        imageFile,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(utf8.decode(response.bodyBytes));
        return UserProfile.fromJson(jsonData);
      } else {
        throw Exception(
          '이미지 업로드 실패: ${response.statusCode}, body: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('프로필 이미지 업로드 중 오류: $e');
    }
  }


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

  Future<void> reportUser({
    required int reported_user_id,
    required String reason,
  }) async {
    const url = '${AppConfig.baseUrl}/users/report';

    // ✅ 1. 인자 유효성 검사
    if (reported_user_id <= 0) {
      throw ArgumentError('신고 대상 ID가 유효하지 않습니다: $reported_user_id');
    }

    if (reason.trim().isEmpty) {
      throw ArgumentError('신고 사유가 비어 있습니다.');
    }

    // ✅ 2. 콘솔 로그 (디버깅용)
    debugPrint('[신고 요청] ID: $reported_user_id, 사유: $reason');

    try {
      final response = await _client.postRequest(url, {
        'reported_user_id': reported_user_id,
        'reason': reason,
      });

      if (response.statusCode != 201) {
        final body = utf8.decode(response.bodyBytes);
        throw Exception('신고 실패: ${response.statusCode}, body: $body');
      }
    } catch (e) {
      throw Exception('신고 중 오류 발생: $e');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    const url = '${AppConfig.baseUrl}/users/change-password';

    try {
      final response = await _client.postRequest(url, {
        'current_password': currentPassword,
        'new_password': newPassword,
      });

      if (response.statusCode != 200) {
        final body = utf8.decode(response.bodyBytes);
        final decoded = jsonDecode(body);

        String extractMessage(dynamic rawMsg) {
          // 영어 서버 메시지를 한글로 변환
          if (rawMsg is String) {
            if (rawMsg.contains('at least 6 characters')) {
              return '비밀번호는 최소 6자 이상이어야 합니다';
            }
            if (rawMsg.contains('Incorrect password') ||
                rawMsg.contains('올바르지 않은')) {
              return '현재 비밀번호가 올바르지 않습니다';
            }
            if (rawMsg.contains('must not be empty')) {
              return '비밀번호를 입력해주세요';
            }
            return rawMsg; // fallback
          }
          return '알 수 없는 오류가 발생했습니다';
        }

        // 문자열 형태 detail
        if (decoded is Map && decoded['detail'] is String) {
          throw Exception(extractMessage(decoded['detail']));
        }

        // 리스트 형태 detail (ex: 유효성 오류)
        if (decoded is Map && decoded['detail'] is List) {
          final details = decoded['detail'];
          if (details.isNotEmpty && details[0]['msg'] != null) {
            throw Exception(extractMessage(details[0]['msg']));
          }
        }

        throw Exception('알 수 없는 오류가 발생했습니다');
      }
    } catch (e) {
      // 최종적으로 UI에 넘길 메시지를 깔끔히 정리
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}