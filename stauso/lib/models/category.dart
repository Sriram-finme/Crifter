class Category {
  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
  final int sortOrder;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    required this.sortOrder,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconUrl: json['iconUrl'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'iconUrl': iconUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? slug,
    String? iconUrl,
    int? sortOrder,
    bool? isActive,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      iconUrl: iconUrl ?? this.iconUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }
}
