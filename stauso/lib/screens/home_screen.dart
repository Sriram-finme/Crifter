import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_constants.dart';
import '../models/category.dart';
import '../models/quote.dart';
import '../providers/quote_provider.dart';
import '../services/firebase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/quote_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(quotesProvider);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _onFavoriteToggle(String quoteId) {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;
    ref.read(quoteServiceProvider).toggleFavorite(uid, quoteId);
  }

  void _onDownload(Quote quote) {
    // TODO: implement screenshot + save to gallery in editor screen
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final quotes = ref.watch(quotesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final favorites = ref.watch(favoritesProvider).value ?? [];

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              onProfileTap: () => context.go('/profile'),
            ),
            const SizedBox(height: 16),
            _CategoryChips(
              categories: categories,
              selected: selectedCategory,
              onSelect: (id) =>
                  ref.read(selectedCategoryProvider.notifier).state = id,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _onRefresh,
                child: quotes.when(
                  data: (quoteList) {
                    if (quoteList.isEmpty) return const _EmptyState();
                    return _QuoteList(
                      quotes: quoteList,
                      favorites: favorites,
                      onFavoriteToggle: _onFavoriteToggle,
                      onDownload: _onDownload,
                    );
                  },
                  loading: () => const _ShimmerList(),
                  error: (e, _) => _ErrorState(message: e.toString()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onProfileTap;
  const _Header({required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
          ),
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surface,
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category chips ───────────────────────────────────────────────────────────

class _ChipItem {
  final String id;
  final String label;
  const _ChipItem({required this.id, required this.label});
}

class _CategoryChips extends StatelessWidget {
  final AsyncValue<List<Category>> categories;
  final String selected;
  final void Function(String) onSelect;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  List<_ChipItem> _buildItems() {
    final items = <_ChipItem>[const _ChipItem(id: 'all', label: 'All')];
    categories.when(
      data: (cats) =>
          items.addAll(cats.map((c) => _ChipItem(id: c.id, label: c.name))),
      loading: () => items.addAll(
        AppConstants.quoteCategories
            .map((n) => _ChipItem(id: n.toLowerCase(), label: n)),
      ),
      error: (_, __) {},
    );
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final isSelected = item.id == selected;
          return GestureDetector(
            onTap: () => onSelect(item.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Quote list ───────────────────────────────────────────────────────────────

class _QuoteList extends StatelessWidget {
  final List<Quote> quotes;
  final List<String> favorites;
  final void Function(String quoteId) onFavoriteToggle;
  final void Function(Quote quote) onDownload;

  const _QuoteList({
    required this.quotes,
    required this.favorites,
    required this.onFavoriteToggle,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: quotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) => _QuoteListItem(
        quote: quotes[i],
        favorites: favorites,
        onFavoriteToggle: onFavoriteToggle,
        onDownload: onDownload,
      ),
    );
  }
}

class _QuoteListItem extends ConsumerWidget {
  final Quote quote;
  final List<String> favorites;
  final void Function(String quoteId) onFavoriteToggle;
  final void Function(Quote quote) onDownload;

  const _QuoteListItem({
    required this.quote,
    required this.favorites,
    required this.onFavoriteToggle,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl =
        ref.watch(unsplashImageProvider(quote.categoryId)).valueOrNull;
    return QuoteCard(
      quote: quote,
      imageUrl: imageUrl,
      isFavorited: favorites.contains(quote.id),
      onFavoriteToggle: () => onFavoriteToggle(quote.id),
      onDownload: () => onDownload(quote),
    );
  }
}

// ─── Shimmer loading ──────────────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: const Color(0xFF2A2A40),
        child: AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty / Error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.format_quote_rounded,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No quotes yet',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
