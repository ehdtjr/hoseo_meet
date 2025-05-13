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
    String sortBy = 'distance',
    double? userLat,
    double? userLon,
    String? name, // ✅ name 검색 인자 추가
  }) async {
    final queryParameters = {
      'skip': skip.toString(),
      'limit': limit.toString(),
      'place': place ?? '',
      'sort_by': sortBy,
    };

    if (userLat != null) {
      queryParameters['user_lat'] = userLat.toString();
    }
    if (userLon != null) {
      queryParameters['user_lon'] = userLon.toString();
    }
    if (name != null && name.trim().isNotEmpty) {
      queryParameters['name'] = name.trim(); // ✅ name 파라미터 추가
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

  Future<void> heartRoom({required int roomId}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/room_post/rooms/heart/$roomId');

    try {
      final response = await _client.postRequest(url.toString(), {});

      if (response.statusCode == 201 || response.statusCode == 200) {
        // 성공 처리
        return;
      } else if (response.statusCode == 409) {
        throw Exception('이미 하트를 누른 방입니다.');
      } else {
        throw Exception('하트 등록 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('하트 등록 중 오류 발생: $e');
    }
  }

  Future<void> unheartRoom({required int roomId}) async {
    final url = Uri.parse('${AppConfig.baseUrl}/room_post/rooms/heart/$roomId');

    try {
      final response = await _client.deleteRequest(url.toString());

      if (response.statusCode == 204 || response.statusCode == 200) {
        // 성공 처리
        return;
      } else if (response.statusCode == 404) {
        throw Exception('하트 정보가 존재하지 않습니다.');
      } else {
        throw Exception('하트 삭제 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('하트 삭제 중 오류 발생: $e');
    }
  }

}
