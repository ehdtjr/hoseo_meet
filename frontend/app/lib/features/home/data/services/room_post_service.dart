import 'dart:convert';
import 'package:hoseomeet/commons/network/auth_http_client.dart';
import 'package:hoseomeet/config.dart';
import 'package:hoseomeet/features/home/data/models/room_post.dart';

import '../models/room_post_detail.dart';

class RoomService {
  final AuthHttpClient _client;

  RoomService(this._client);

  Future<List<RoomPost>> loadListRooms({
    int skip = 0,
    int limit = 10,
    String? place,
    String sortBy = 'distance', // 기본값은 그대로 'distance'
    double? userLat,
    double? userLon,
  }) async {
    final queryParameters = {
      'skip': skip.toString(),
      'limit': limit.toString(),
      'place': place ?? '',
      'sort_by': sortBy,
    };

    // user_lat와 user_lon 값이 있으면 쿼리 파라미터에 추가
    if (userLat != null) {
      queryParameters['user_lat'] = userLat.toString();
    }
    if (userLon != null) {
      queryParameters['user_lon'] = userLon.toString();
    }

    final url = Uri.parse('${AppConfig.baseUrl}/room_post/rooms')
        .replace(queryParameters: queryParameters);

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((data) => RoomPost.fromJson(data)).toList();
      } else {
        throw Exception('Failed to load room posts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading room posts: $e');
    }
  }

  /// RoomDetail 서비스: 주어진 roomId의 상세 정보를 가져옵니다.
  Future<RoomDetail> loadRoomDetail({
    required int roomId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/room_post/rooms/$roomId');

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return RoomDetail.fromJson(jsonData);
      } else {
        throw Exception('Failed to load room detail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading room detail: $e');
    }
  }
}
