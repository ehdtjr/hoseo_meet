class Tag {
  final String name;

  Tag({required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(name: json['name'] as String);
  }
}

class TagState {
  final bool isLoading;
  final List<Tag> tags;
  final String? errorMessage;

  const TagState({
    this.isLoading = false,
    this.tags = const [],
    this.errorMessage,
  });

  TagState copyWith({
    bool? isLoading,
    List<Tag>? tags,
    String? errorMessage,
  }) {
    return TagState(
      isLoading: isLoading ?? this.isLoading,
      tags: tags ?? this.tags,
      errorMessage: errorMessage,
    );
  }
}
