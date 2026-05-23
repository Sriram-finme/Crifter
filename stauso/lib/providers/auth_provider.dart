import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/firebase_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.auth.authStateChanges();
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.value;
  if (user == null) return null;

  final doc = await FirebaseService.firestore
      .collection('users')
      .doc(user.uid)
      .get();

  if (!doc.exists || doc.data() == null) return null;
  return UserProfile.fromJson({...doc.data()!, 'id': doc.id});
});
