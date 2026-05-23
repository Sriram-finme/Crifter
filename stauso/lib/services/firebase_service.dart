import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  FirebaseService._();

  static bool _ready = false;
  static bool get isReady => _ready;

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;
  static FirebaseStorage get storage => FirebaseStorage.instance;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (_) {
      // Firebase unavailable in this environment (e.g. Linux desktop / CI).
      // UI will render but live data features won't work.
    }
  }
}
