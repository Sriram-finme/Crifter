import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quote.dart';
import '../providers/quote_provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/quote_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<String> _recentSearches = [];
  List<Quote> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  static const _prefsKey = 'recent_searches';
  static const _maxRecent = 8;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Recent searches ────────────────────────────────────────────────────────

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList(_prefsKey) ?? [];
    });
  }

  Future<void> _addRecent(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [query, ..._recentSearches.where((s) => s != query)]
        .take(_maxRecent)
        .toList();
    await prefs.setStringList(_prefsKey, updated);
    setState(() => _recentSearches = updated);
  }

  Future<void> _removeRecent(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = _recentSearches.where((s) => s != query).toList();
    await prefs.setStringList(_prefsKey, updated);
    setState(() => _recentSearches = updated);
  }

  Future<void> _clearAllRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    setState(() => _recentSearches = []);
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<void> _search(String raw) async {
    final query = raw.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    await _addRecent(query);

    try {
      final results =
          await ref.read(quoteServiceProvider).searchQuotes(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _tapRecent(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _search(query);
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
    });
    _focusNode.requestFocus();
  }

  void _onFavoriteToggle(String quoteId) {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;
    ref.read(quoteServiceProvider).toggleFavorite(uid, quoteId);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider).value ?? [];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchBar(
              controller: _controller,
              focusNode: _focusNode,
              onSubmitted: _search,
              onClear: _clear,
            ),
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _hasSearched
                      ? _ResultsView(
                          results: _results,
                          favorites: favorites,
                          query: _controller.text.trim(),
                          onFavoriteToggle: _onFavoriteToggle,
                          onDownload: (id) =>
                              context.push('/editor/$id'),
                        )
                      : _InitialView(
                          recentSearches: _recentSearches,
                          onRecentTap: _tapRecent,
                          onRecentRemove: _removeRecent,
                          onClearAll: _clearAllRecent,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onSubmitted;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search for quotes, shayari, and more',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}

// ─── Initial view (no search yet) ────────────────────────────────────────────

class _InitialView extends StatelessWidget {
  final List<String> recentSearches;
  final void Function(String) onRecentTap;
  final void Function(String) onRecentRemove;
  final VoidCallback onClearAll;

  const _InitialView({
    required this.recentSearches,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (recentSearches.isEmpty) {
      return const _EmptyIllustration(
        icon: Icons.search_rounded,
        title: 'Search for quotes, shayari, and more',
        subtitle: 'Try "Morning motivation" or "Love shayari"',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
              ),
              TextButton(
                onPressed: onClearAll,
                child: const Text('Clear all', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: recentSearches.length,
            itemBuilder: (context, i) {
              final query = recentSearches[i];
              return ListTile(
                leading: const Icon(
                  Icons.history_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                title: Text(
                  query,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => onRecentRemove(query),
                ),
                onTap: () => onRecentTap(query),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8),
                minLeadingWidth: 28,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Results view ─────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final List<Quote> results;
  final List<String> favorites;
  final String query;
  final void Function(String quoteId) onFavoriteToggle;
  final void Function(String quoteId) onDownload;

  const _ResultsView({
    required this.results,
    required this.favorites,
    required this.query,
    required this.onFavoriteToggle,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _EmptyIllustration(
        icon: Icons.sentiment_dissatisfied_outlined,
        title: 'No results for "$query"',
        subtitle: 'Try a different keyword or browse categories',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final quote = results[i];
        return QuoteCard(
          quote: quote,
          isFavorited: favorites.contains(quote.id),
          onFavoriteToggle: () => onFavoriteToggle(quote.id),
          onDownload: () => onDownload(quote.id),
        );
      },
    );
  }
}

// ─── Empty illustration ───────────────────────────────────────────────────────

class _EmptyIllustration extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyIllustration({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
