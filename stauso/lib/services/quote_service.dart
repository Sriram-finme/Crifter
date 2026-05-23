import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../models/quote.dart';
import 'firebase_service.dart';

class QuoteService {
  FirebaseFirestore get _db => FirebaseService.firestore;

  Stream<List<Category>> getCategories() {
    return _db
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Category.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<Quote>> getQuotesByCategory(
    String categoryId, {
    int limit = 20,
  }) {
    return _db
        .collection('quotes')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Quote.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<Quote>> getFeaturedQuotes({int limit = 20}) {
    return _db
        .collection('quotes')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Quote.fromJson({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<List<Quote>> searchQuotes(String query) async {
    final snap = await _db
        .collection('quotes')
        .where('text', isGreaterThanOrEqualTo: query)
        .where('text', isLessThanOrEqualTo: '$query')
        .limit(20)
        .get();
    return snap.docs
        .map((d) => Quote.fromJson({...d.data(), 'id': d.id}))
        .toList();
  }

  Future<void> toggleFavorite(String userId, String quoteId) async {
    final ref = _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(quoteId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({'addedAt': FieldValue.serverTimestamp()});
    }
  }

  Stream<List<String>> getUserFavorites(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  Future<List<Quote>> getQuotesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final docs = await Future.wait(
      ids.map((id) => _db.collection('quotes').doc(id).get()),
    );
    return docs
        .where((d) => d.exists && d.data() != null)
        .map((d) => Quote.fromJson({...d.data()!, 'id': d.id}))
        .toList();
  }
}
