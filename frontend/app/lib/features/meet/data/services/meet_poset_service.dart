import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint를 사용하기 위해 추가
import 'package:hoseomeet/commons/network/auth_http_client.dart';
import 'package:hoseomeet/features/meet/data/models/meet_post.dart';
import 'package:hoseomeet/features/meet/data/models/meet_post_detail.dart';
import '../../../../config.dart';

class MeePostService {
  final AuthHttpClient _client;

  MeePostService(this._client);

  Future<List<MeetPost>> loadListMeetPost({
    String type = '',
    String title = '',
    String content = '',
    int skip = 0,
    int limit = 10,
  }) async {
    final queryParameters = {
      'type': type,
      'title': title,
      'content': content,
      'skip': skip.toString(),
      'limit': limit.toString(),
    };

    final url = Uri.parse('${AppConfig.baseUrl}/meet_post/search')
        .replace(queryParameters: queryParameters);

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((data) => MeetPost.fromJson(data)).toList();
      } else {
        throw Exception('Failed to load meet posts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading meet posts: $e');
    }
  }

  /// 특정 게시글의 상세 정보를 가져오는 함수
  Future<MeetDetail> loadDetailMeetPost(int postId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/meet_post/detail/$postId');

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        // UTF-8 디코딩 처리
        final Map<String, dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return MeetDetail.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to load meet post detail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading meet post detail: $e');
    }
  }

  Future<void> createMeetPost({
    required String title,
    required String type,
    required String content,
    required int maxPeople,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/meet_post/create');

    final body = {
      'title': title,
      'type': type,
      'content': content,
      'max_people': maxPeople,
    };

    try {
      // postRequest 호출: headers 제거, body만 전달
      final response = await _client.postRequest(url.toString(), body);

      if (response.statusCode == 201) {
        debugPrint('Meet post created successfully');
      } else {
        throw Exception('Failed to create meet post: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating meet post: $e');
    }
  }

  Future<void> subscribeMeetPost(int postId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/meet_post/subscribe/$postId');

    try {
      final response = await _client.postRequest(url.toString(), {});

      if (response.statusCode == 200) {
        debugPrint('Subscribed to meet post successfully');
      } else {
        throw Exception(
            'Failed to subscribe to meet post: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error subscribing to meet post: $e');
    }
  }
}
