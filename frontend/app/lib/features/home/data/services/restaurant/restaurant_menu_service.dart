import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../../commons/network/auth_http_client.dart';
import '../../../../../config.dart';
import '../../models/restaurant/restaurant_menmu_version.dart';
import '../../models/restaurant/restaurant_menu.dart';

class RestaurantMenuService {
  final AuthHttpClient _client;

  RestaurantMenuService(this._client);

  Future<List<RestaurantMenu>> loadMenus(int postId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/menu/list/$postId');
    print('메뉴 불러오기 URL: $url');

    try {
      final response = await _client.getRequest(url.toString());

      if (response.statusCode == 200) {
        final List<dynamic> jsonData =
        json.decode(utf8.decode(response.bodyBytes));
        return jsonData
            .map((item) => RestaurantMenu.fromJson(item))
            .toList();
      } else {
        throw Exception('메뉴 불러오기 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('메뉴 불러오는 중 오류 발생: $e');
    }
  }

  Future<void> updateMenu({
    required int menuId,
    required String name,
    required int price,
    File? imageFile,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/menu/$menuId/update');

    final request = http.MultipartRequest('POST', url)
      ..fields['name'] = name
      ..fields['price'] = price.toString();

    if (imageFile != null) {
      final fileName = basename(imageFile.path);
      final mimeType = extension(fileName).replaceAll('.', '');
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', mimeType),
          filename: fileName,
        ),
      );
    }

    try {
      final streamedResponse = await _client.sendStreamRequest(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('메뉴 수정 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('메뉴 수정 중 오류 발생: $e');
    }
  }

  Future<void> createMenu({
    required String name,
    required int price,
    required int postId,
    File? imageFile,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/menu/create');

    final request = http.MultipartRequest('POST', url)
      ..fields['name'] = name
      ..fields['price'] = price.toString()
      ..fields['post_id'] = postId.toString();

    if (imageFile != null) {
      final fileName = basename(imageFile.path);
      final mimeType = extension(fileName).replaceAll('.', '');
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', mimeType),
          filename: fileName,
        ),
      );
    }

    try {
      final streamedResponse = await _client.sendStreamRequest(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('메뉴 생성 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('메뉴 생성 중 오류 발생: $e');
    }
  }

  Future<List<RestaurantMenuVersion>> getMenuVersions({
    required int postId,
    int skip = 0,
    int limit = 10,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/menu/versions/$postId?skip=$skip&limit=$limit');
    print('메뉴 버전 이력 불러오기 URL: $url');

    final response = await _client.getRequest(url.toString());
    if (response.statusCode == 200) {
      final jsonData = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return jsonData.map((e) => RestaurantMenuVersion.fromJson(e)).toList();
    } else {
      throw Exception('메뉴 버전 불러오기 실패: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> rollbackMenu(int menuVersionId) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/menu/rollback/$menuVersionId');
    print('메뉴 롤백 URL: $url');

    try {
      final response = await _client.postRequest(url.toString(), {});

      if (response.statusCode != 200) {
        throw Exception('메뉴 롤백 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('메뉴 롤백 중 오류 발생: $e');
    }
  }

  Future<void> deleteMenu({
    required int menuId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/restaurant/menu/$menuId/delete');

    try {
      final response = await _client.deleteRequest(url.toString());

      if (response.statusCode != 200) {
        throw Exception('메뉴 삭제 실패: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('메뉴 삭제 중 오류 발생: $e');
    }
  }
}