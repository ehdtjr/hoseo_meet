import 'dart:convert';
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
        throw Exception('Failed to load meet post detail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading meet post detail: $e');
    }
  }
}
