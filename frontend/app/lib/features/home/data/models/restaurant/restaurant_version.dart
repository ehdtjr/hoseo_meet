class RestaurantVersion {
  final int id;
  final int editorId;
  final int postId;
  final int version;
  final String name;
  final String address;
  final String? contact;
  final String? businessHours;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  RestaurantVersion({
    required this.id,
    required this.editorId,
    required this.postId,
    required this.version,
    required this.name,
    required this.address,
    required this.contact,
    required this.businessHours,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory RestaurantVersion.fromJson(Map<String, dynamic> json) {
    return RestaurantVersion(
      id: json['id'],
      editorId: json['editor_id'],
      postId: json['post_id'],
      version: json['version'],
      name: json['name'],
      address: json['address'],
      contact: json['contact'],
      businessHours: json['business_hours'],
      latitude: json['location']['latitude'],
      longitude: json['location']['longitude'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
