class StoryPost {
  final int id;
  final int authorId;
  final TextOverlay textOverlay;
  final String imageUrl;
  final DateTime createdAt;

  StoryPost({
    required this.id,
    required this.authorId,
    required this.textOverlay,
    required this.imageUrl,
    required this.createdAt,
  });

  factory StoryPost.fromJson(Map<String, dynamic> json) {
    return StoryPost(
      id: json['id'],
      authorId: json['author_id'],
      textOverlay: TextOverlay.fromJson(json['text_overlay']),
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'text_overlay': textOverlay.toJson(),
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  StoryPost copyWith({
    int? id,
    int? authorId,
    TextOverlay? textOverlay,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return StoryPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      textOverlay: textOverlay ?? this.textOverlay,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TextOverlay {
  final String text;
  final Position position;
  final FontStyle fontStyle;

  TextOverlay({
    required this.text,
    required this.position,
    required this.fontStyle,
  });

  factory TextOverlay.fromJson(Map<String, dynamic> json) {
    return TextOverlay(
      text: json['text'],
      position: Position.fromJson(json['position']),
      fontStyle: FontStyle.fromJson(json['font_style']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'position': position.toJson(),
      'font_style': fontStyle.toJson(),
    };
  }
}

class Position {
  final double x;
  final double y;

  Position({
    required this.x,
    required this.y,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }
}

class FontStyle {
  final String name;
  final int size;
  final bool bold;
  final String color;

  FontStyle({
    required this.name,
    required this.size,
    required this.bold,
    required this.color,
  });

  factory FontStyle.fromJson(Map<String, dynamic> json) {
    return FontStyle(
      name: json['name'],
      size: json['size'],
      bold: json['bold'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
      'bold': bold,
      'color': color,
    };
  }
}
