import 'package:cloud_firestore/cloud_firestore.dart';

class Quote {
  final String id;
  final String text;
  final String author;
  final String categoryId;
  final String language;
  final List<String> tags;
  final bool isPremium;
  final String? imageUrl;
  final DateTime createdAt;

  const Quote({
    required this.id,
    required this.text,
    required this.author,
    required this.categoryId,
    required this.language,
    required this.tags,
    required this.isPremium,
    this.imageUrl,
    required this.createdAt,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      text: json['text'] as String,
      author: json['author'] as String,
      categoryId: json['categoryId'] as String,
      language: json['language'] as String,
      tags: List<String>.from(json['tags'] as List),
      isPremium: json['isPremium'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'author': author,
      'categoryId': categoryId,
      'language': language,
      'tags': tags,
      'isPremium': isPremium,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Quote copyWith({
    String? id,
    String? text,
    String? author,
    String? categoryId,
    String? language,
    List<String>? tags,
    bool? isPremium,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return Quote(
      id: id ?? this.id,
      text: text ?? this.text,
      author: author ?? this.author,
      categoryId: categoryId ?? this.categoryId,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      isPremium: isPremium ?? this.isPremium,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
