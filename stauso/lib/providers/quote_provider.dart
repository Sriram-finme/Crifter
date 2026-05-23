import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../models/quote.dart';
import '../services/firebase_service.dart';
import '../services/quote_service.dart';

final quoteServiceProvider = Provider<QuoteService>((ref) => QuoteService());

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(quoteServiceProvider).getCategories();
});

final selectedCategoryProvider = StateProvider<String>((ref) => 'all');

final quotesProvider = StreamProvider<List<Quote>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final service = ref.watch(quoteServiceProvider);
  if (category == 'all') {
    return service.getFeaturedQuotes();
  }
  return service.getQuotesByCategory(category);
});

final favoritesProvider = StreamProvider<List<String>>((ref) {
  final uid = FirebaseService.auth.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(quoteServiceProvider).getUserFavorites(uid);
});
