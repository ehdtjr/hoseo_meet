import 'package:campusmeet/features/home/data/models/restaurant/restaurant_menu.dart';

class RestaurantMenuVersion {
  final int id;
  final int postId;
  final int version;
  final List<RestaurantMenu> menus;
  final int editorId;
  final DateTime createdAt;

  RestaurantMenuVersion({
    required this.id,
    required this.postId,
    required this.version,
    required this.menus,
    required this.editorId,
    required this.createdAt,
  });

  factory RestaurantMenuVersion.fromJson(Map<String, dynamic> json) {
    return RestaurantMenuVersion(
      id: json['id'] ?? -1,
      postId: json['post_id'] ?? -1,
      version: json['version'] ?? 0,
      menus: (json['menus'] as List<dynamic>)
          .map((m) => RestaurantMenu.fromJson(m))
          .toList(),
      editorId: json['editor_id'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

}
