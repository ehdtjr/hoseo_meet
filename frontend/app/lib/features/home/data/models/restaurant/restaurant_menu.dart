class RestaurantMenu {
  final int id;
  final int editorId;
  final int postId;
  final String name;
  final int price;
  final String image;

  RestaurantMenu({
    required this.id,
    required this.editorId,
    required this.postId,
    required this.name,
    required this.price,
    required this.image,
  });

  factory RestaurantMenu.fromJson(Map<String, dynamic> json) {
    return RestaurantMenu(
      id: json['id'] as int,
      editorId: json['editor_id'] as int,
      postId: json['post_id'] as int,
      name: json['name'] as String,
      price: json['price'] as int,
      image: json['image'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'editor_id': editorId,
      'post_id': postId,
      'name': name,
      'price': price,
      'image': image,
    };
  }

  RestaurantMenu copyWith({
    int? id,
    int? editorId,
    int? postId,
    String? name,
    int? price,
    String? image,
  }) {
    return RestaurantMenu(
      id: id ?? this.id,
      editorId: editorId ?? this.editorId,
      postId: postId ?? this.postId,
      name: name ?? this.name,
      price: price ?? this.price,
      image: image ?? this.image,
    );
  }
}
