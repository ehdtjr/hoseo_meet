import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';

class MeetSearchService {
  final String searchMeetEndpoint = '${AppConfig.baseUrl}/meet_post/search';

  Future<List<Map<String, dynamic>>> fetchPosts({String? type, int skip = 0, int limit = 10}) async {
    final url = Uri.parse('$searchMeetEndpoint?skip=$skip&limit=$limit${type != null ? '&type=$type' : ''}');

    final response = await http.get(
      url,
      headers: {
        'accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      // UTF-8로 디코딩하여 JSON 데이터를 파싱합니다.
      List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map<Map<String, dynamic>>((post) {
        return {
          ...post as Map<String, dynamic>,
          "join_people": post["current_people"] ?? null,
        };
      }).toList();
    } else {
      throw Exception('Failed to load posts');
    }
  }
}
