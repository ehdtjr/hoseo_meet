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

  /// ✅ Null-safe fromJson
  factory RestaurantMenu.fromJson(Map<String, dynamic> json) {
    return RestaurantMenu(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? -1,
      editorId: json['editor_id'] is int
          ? json['editor_id'] as int
          : int.tryParse(json['editor_id']?.toString() ?? '') ?? -1,
      postId: json['post_id'] is int
          ? json['post_id'] as int
          : int.tryParse(json['post_id']?.toString() ?? '') ?? -1,
      name: json['name']?.toString() ?? '',
      price: json['price'] is int
          ? json['price'] as int
          : int.tryParse(json['price']?.toString() ?? '') ?? 0,
      image: json['image']?.toString() ?? '',
    );
  }

  /// ✅ toJson
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

  /// ✅ 안전한 copyWith
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

class RestaurantMenuState {
  final List<RestaurantMenu> menus;
  final RestaurantMenu? selectedMenuForEdit;
  final bool editMode;

  RestaurantMenuState({
    required this.menus,
    this.selectedMenuForEdit,
    this.editMode = false,
  });

  RestaurantMenuState copyWith({
    List<RestaurantMenu>? menus,
    RestaurantMenu? selectedMenuForEdit,
    bool? editMode,
  }) {
    return RestaurantMenuState(
      menus: menus ?? this.menus,
      selectedMenuForEdit: selectedMenuForEdit ?? this.selectedMenuForEdit,
      editMode: editMode ?? this.editMode,
    );
  }
}
