import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../providers/quote_provider.dart';
import '../widgets/quote_card.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static const Map<String, String> _emojiMap = {
    'morning': '🌅',
    'love': '❤️',
    'motivation': '🔥',
    'friendship': '🤝',
    'festivals': '🎉',
    'shayari': '✍️',
    'spiritual': '🕉️',
    'success': '🏆',
  };

  String _emoji(String name) =>
      _emojiMap[name.toLowerCase()] ?? '💬';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    // Build a flat list of (id, name) pairs — Firestore data if available,
    // else AppConstants fallback while loading / on error.
    final items = <_Item>[];
    categoriesAsync.when(
      data: (cats) {
        if (cats.isNotEmpty) {
          items.addAll(cats.map((c) => _Item(id: c.id, name: c.name)));
        } else {
          items.addAll(_fallbackItems());
        }
      },
      loading: () => items.addAll(_fallbackItems()),
      error: (_, __) => items.addAll(_fallbackItems()),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Text(
                'Categories',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.05,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final gradient =
                      kGradientPresets[i % kGradientPresets.length];
                  return _CategoryCard(
                    name: item.name,
                    emoji: _emoji(item.name),
                    gradient: gradient,
                    onTap: () {
                      ref.read(selectedCategoryProvider.notifier).state =
                          item.id;
                      context.go('/home');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Item> _fallbackItems() => AppConstants.quoteCategories
      .map((name) => _Item(id: name.toLowerCase(), name: name))
      .toList();
}

class _Item {
  final String id;
  final String name;
  const _Item({required this.id, required this.name});
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final String emoji;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.name,
    required this.emoji,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 42)),
            const SizedBox(height: 10),
            Text(
              name,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 15,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
