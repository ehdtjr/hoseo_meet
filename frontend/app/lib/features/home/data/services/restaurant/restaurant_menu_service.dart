import 'dart:convert';

import '../../../../../commons/network/auth_http_client.dart';
import '../../../../../config.dart';
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


}