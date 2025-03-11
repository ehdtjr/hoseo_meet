import 'dart:convert';
import 'dart:io';
import 'package:hoseomeet/commons/network/auth_http_client.dart';
import 'package:hoseomeet/config.dart';
import '../models/room_review.dart'; // RoomReview 모델 추가

class RoomReviewService {
  final AuthHttpClient _client;

  RoomReviewService(this._client);

  /// ✅ 특정 방의 리뷰 목록 가져오기
  Future<List<RoomReview>> loadListRoomReviews({
    required int roomId,
    int page = 1,
    int pageSize = 5,
    String sortBy = 'latest',
  }) async {
    final queryParameters = {
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort_by': sortBy,
    };

    final url = Uri.parse('${AppConfig.baseUrl}/room_post/review/$roomId/list')
        .replace(queryParameters: queryParameters);

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((data) => RoomReview.fromJson(data)).toList();
      } else {
        throw Exception(
            'Failed to load room reviews: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading room reviews: $e');
    }
  }

  /// 특정 방의 리뷰 이미지 목록 가져오기
  Future<List<RoomReviewImage>> loadListRoomReviewImages({
    required int roomId,
    int skip = 0,
    int limit = 10,
  }) async {
    final queryParameters = {
      'skip': skip.toString(),
      'limit': limit.toString(),
    };

    final url = Uri.parse('${AppConfig.baseUrl}/room_post/review/$roomId/image_list')
        .replace(queryParameters: queryParameters);

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return jsonData
            .map((data) => RoomReviewImage.fromJson(data))
            .toList();
      } else {
        throw Exception('Failed to load room review images: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading room review images: $e');
    }
  }


  Future<RoomReview?> createRoomReview({
    required int roomId,
    required String content,
    required int rating,
    required List<File> images,
  }) async {
    final url = '${AppConfig.baseUrl}/room_post/review/$roomId/create';

    try {
      final response = await _client.postMultipleMultipartRequest(
        url,
        'images',
        images,
        additionalFields: {
          'content': content,
          'rating': rating.toString(),
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        return RoomReview.fromJson(jsonData);
      } else {
        throw Exception('Failed to create room review: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating room review: $e');
    }
  }

  Future<void> deleteRoomReview(int reviewId) async {
    final url = '${AppConfig.baseUrl}/room_post/review/$reviewId/delete';

    try {
      final response = await _client.deleteRequest(url);
      if (response.statusCode != 200) {
        throw Exception('Failed to delete room review: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting room review: $e');
    }
  }

}
