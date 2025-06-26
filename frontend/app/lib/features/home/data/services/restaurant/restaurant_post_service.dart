import 'dart:convert';

import '../../../../../commons/network/auth_http_client.dart';
import '../../../../../config.dart';
import '../../models/restaurant/restaurant_post.dart';
import '../../models/restaurant/restaurant_post_detail.dart';
import '../../models/restaurant/restaurant_version.dart';


class RestaurantService {
  final AuthHttpClient _client;

  RestaurantService(this._client);

  Future<List<Restaurant>> loadRestaurants({
    double? userLat,
    double? userLon,
    int skip = 0,
    int limit = 10,
    bool heartedOnly = false,
  }) async {
    final queryParameters = {
      'skip': skip.toString(),
      'limit': limit.toString(),
      'hearted_only': heartedOnly.toString(),
    };

    if (userLat != null) {
      queryParameters['user_lat'] = userLat.toString();
    }
    if (userLon != null) {
      queryParameters['user_lon'] = userLon.toString();
    }

    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/list')
        .replace(queryParameters: queryParameters);

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return jsonData.map((data) => Restaurant.fromJson(data)).toList();
      } else {
        throw Exception('Failed to load restaurants: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading restaurants: $e');
    }
  }

  Future<RestaurantPostDetail> loadRestaurantDetail({
    required int restaurantId,
    double? userLat,
    double? userLon,
  }) async {
    final queryParameters = <String, String>{};

    if (userLat != null) {
      queryParameters['user_lat'] = userLat.toString();
    }
    if (userLon != null) {
      queryParameters['user_lon'] = userLon.toString();
    }

    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/detail/$restaurantId')
        .replace(queryParameters: queryParameters);

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return RestaurantPostDetail.fromJson(jsonData);
      } else {
        throw Exception('Failed to load restaurant detail: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading restaurant detail: $e');
    }
  }

  Future<void> updateRestaurant(RestaurantPostDetail restaurant) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/update');

    try {
      final response = await _client.postRequest(
        url.toString(),
        restaurant.toJson(),
      );

      if (response.statusCode != 200) {
        throw Exception('맛집 수정 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('맛집 수정 중 오류 발생: $e');
    }
  }

  Future<List<RestaurantVersion>> loadRestaurantVersions({
    required int restaurantId,
    int skip = 0,
    int limit = 10,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/$restaurantId/versions')
        .replace(queryParameters: {
      'skip': skip.toString(),
      'limit': limit.toString(),
    });

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return jsonData
            .map((item) => RestaurantVersion.fromJson(item))
            .toList();
      } else {
        throw Exception(
            '버전 목록 조회 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('버전 목록 조회 중 오류 발생: $e');
    }
  }

  Future<void> rollbackRestaurantVersion({
    required int versionId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/rollback')
        .replace(queryParameters: {
      'version_id': versionId.toString(),
    });

    try {
      final response = await _client.postRequest(url.toString(), {});

      if (response.statusCode != 200) {
        throw Exception('맛집 롤백 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('맛집 롤백 중 오류 발생: $e');
    }
  }

}
