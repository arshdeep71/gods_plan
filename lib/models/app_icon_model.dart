class AppIconModel {
  final String id;
  final String name;
  final String assetPath;
  final String thumbnailPath;
  final String? category;
  final bool favorite;
  final DateTime addedAt;
  final String? author;
  final List<String> tags;
  final int sortOrder;

  AppIconModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.thumbnailPath,
    this.category,
    this.favorite = false,
    required this.addedAt,
    this.author,
    required this.tags,
    required this.sortOrder,
  });

  AppIconModel copyWith({
    bool? favorite,
  }) {
    return AppIconModel(
      id: id,
      name: name,
      assetPath: assetPath,
      thumbnailPath: thumbnailPath,
      category: category,
      favorite: favorite ?? this.favorite,
      addedAt: addedAt,
      author: author,
      tags: tags,
      sortOrder: sortOrder,
    );
  }

  factory AppIconModel.fromJson(Map<String, dynamic> json, {bool favorite = false}) {
    return AppIconModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Icon',
      assetPath: json['assetPath'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String? ?? '',
      category: json['category'] as String?,
      favorite: favorite,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      author: json['author'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      sortOrder: json['sortOrder'] as int? ?? 999,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'assetPath': assetPath,
      'thumbnailPath': thumbnailPath,
      'category': category,
      'addedAt': addedAt.toIsoFormat(),
      'author': author,
      'tags': tags,
      'sortOrder': sortOrder,
    };
  }
}
