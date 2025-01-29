import 'dart:convert';
import 'dart:io';
import 'package:hoseomeet/commons/network/auth_http_client.dart';
import 'package:hoseomeet/features/story/data/models/story_post.dart';
import '../../../../config.dart';

class StoryPostService {
  final AuthHttpClient _client;

  StoryPostService(this._client);

  /// ✅ 스토리 리스트 불러오기
  Future<List<StoryPost>> loadListStoryPost() async {
    final url = Uri.parse('${AppConfig.baseUrl}/story_post/list');
    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((data) => StoryPost.fromJson(data)).toList();
      } else {
        throw Exception('Failed to load story posts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading story posts: $e');
    }
  }

  /// ✅ 특정 스토리 게시글 상세 조회
  Future<StoryPost> loadDetailStoryPost(int postId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/story_post/$postId');

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return StoryPost.fromJson(jsonData);
      } else {
        throw Exception(
            'Failed to load story post detail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading story post detail: $e');
    }
  }

  /// ✅ (NEW) 이미지 업로드 (multipart/form-data)
  Future<String> uploadStoryImage(File imageFile) async {
    final url = '${AppConfig.baseUrl}/api/v1/story_post/upload_image';

    try {
      final response = await _client.postMultipartRequest(url, imageFile);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['image_url']; // ✅ 서버에서 반환하는 업로드된 이미지 URL
      } else {
        throw Exception(
            'Failed to upload image: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }
}
