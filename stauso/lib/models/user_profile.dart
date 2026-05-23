import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String? photoUrl;
  final bool isPremium;
  final DateTime createdAt;
  final int downloadCount;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.photoUrl,
    required this.isPremium,
    required this.createdAt,
    required this.downloadCount,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      photoUrl: json['photoUrl'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      downloadCount: json['downloadCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'isPremium': isPremium,
      'createdAt': Timestamp.fromDate(createdAt),
      'downloadCount': downloadCount,
    };
  }

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    bool? isPremium,
    DateTime? createdAt,
    int? downloadCount,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      downloadCount: downloadCount ?? this.downloadCount,
    );
  }
}
