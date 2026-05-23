import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quote.dart';
import '../providers/auth_provider.dart';
import '../providers/quote_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/quote_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<Quote> _favoriteQuotes = [];
  bool _notificationsEnabled = true;
  bool _loadingFaves = false;

  static const _notifKey = 'notifications_enabled';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
    // Fetch favorite quotes after first frame so ref is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ids = ref.read(favoritesProvider).value ?? [];
      _fetchFavoriteQuotes(ids);
    });
  }

  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled =
            prefs.getBool(_notifKey) ?? true;
      });
    }
  }

  Future<void> _setNotifPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifKey, value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _fetchFavoriteQuotes(List<String> ids) async {
    if (ids.isEmpty) {
      setState(() => _favoriteQuotes = []);
      return;
    }
    setState(() => _loadingFaves = true);
    try {
      final quotes = await ref
          .read(quoteServiceProvider)
          .getQuotesByIds(ids.take(6).toList());
      if (mounted) setState(() => _favoriteQuotes = quotes);
    } catch (_) {
      if (mounted) setState(() => _favoriteQuotes = []);
    } finally {
      if (mounted) setState(() => _loadingFaves = false);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Logout',
            style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                  fontSize: 20,
                )),
        content: Text('Are you sure you want to logout?',
            style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.signOut();
    // Router redirect handles navigation to /auth
  }

  void _shareApp() {
    Share.share(
      'Check out Stauso — beautiful quote cards for WhatsApp & Stories! '
      'Download now and express yourself. 🌟',
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rating feature coming soon!')),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Re-fetch quotes when favorites list changes
    ref.listen<AsyncValue<List<String>>>(favoritesProvider, (_, next) {
      next.whenData(_fetchFavoriteQuotes);
    });

    final user = AuthService.getCurrentUser();
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    final favCount = ref.watch(favoritesProvider).value?.length ?? 0;

    final daysActive = profile != null
        ? DateTime.now().difference(profile.createdAt).inDays + 1
        : 0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Profile header ─────────────────────────────────────────
              _ProfileHeader(
                displayName: profile?.displayName ??
                    user?.displayName ??
                    'Stauso User',
                subtitle: profile?.phoneNumber.isNotEmpty == true
                    ? profile!.phoneNumber
                    : user?.email ?? '',
                photoUrl: profile?.photoUrl ?? user?.photoURL,
                isPremium: profile?.isPremium ?? false,
              ),
              const SizedBox(height: 8),
              // ── Stats ──────────────────────────────────────────────────
              _StatsRow(
                downloads: profile?.downloadCount ?? 0,
                favorites: favCount,
                daysActive: daysActive,
              ),
              const SizedBox(height: 20),
              // ── My Favourites ──────────────────────────────────────────
              _SectionHeader(title: 'My Favourites'),
              if (_loadingFaves)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (_favoriteQuotes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 20),
                  child: Text(
                    'No favourites yet.\nTap ❤️ on any quote to save it here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                _FavoritesGrid(quotes: _favoriteQuotes),
              const SizedBox(height: 20),
              // ── Settings ───────────────────────────────────────────────
              _SectionHeader(title: 'Settings'),
              _SettingTile(
                icon: Icons.language_outlined,
                label: 'Language',
                trailing: const Text('English',
                    style: TextStyle(color: AppColors.textSecondary)),
                onTap: () {},
              ),
              _SettingTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: _setNotifPref,
                  activeColor: AppColors.primary,
                ),
                onTap: null,
              ),
              _SettingTile(
                icon: Icons.star_outline_rounded,
                label: 'Rate Stauso',
                onTap: _rateApp,
              ),
              _SettingTile(
                icon: Icons.share_outlined,
                label: 'Share Stauso',
                onTap: _shareApp,
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              _SettingTile(
                icon: Icons.logout_rounded,
                label: 'Logout',
                iconColor: AppColors.error,
                labelColor: AppColors.error,
                onTap: _logout,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile header ───────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String subtitle;
  final String? photoUrl;
  final bool isPremium;

  const _ProfileHeader({
    required this.displayName,
    required this.subtitle,
    required this.photoUrl,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.surface,
                backgroundImage: photoUrl != null
                    ? CachedNetworkImageProvider(photoUrl!)
                    : null,
                child: photoUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'S',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : null,
              ),
              if (isPremium)
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PRO',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Stats row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int downloads;
  final int favorites;
  final int daysActive;

  const _StatsRow({
    required this.downloads,
    required this.favorites,
    required this.daysActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Stat(value: downloads, label: 'Downloads'),
          _Divider(),
          _Stat(value: favorites, label: 'Favourites'),
          _Divider(),
          _Stat(value: daysActive, label: 'Days Active'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.textSecondary.withValues(alpha: 0.2),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 18,
              ),
        ),
      ),
    );
  }
}

// ─── Favourites grid ──────────────────────────────────────────────────────────

class _FavoritesGrid extends StatelessWidget {
  final List<Quote> quotes;
  const _FavoritesGrid({required this.quotes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: quotes.length,
        itemBuilder: (context, i) {
          return QuoteCardView(
            quote: quotes[i],
            fontSize: 12,
            watermarkName: 'Stauso',
          );
        },
      ),
    );
  }
}

// ─── Settings tile ────────────────────────────────────────────────────────────

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _SettingTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? AppColors.textSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: labelColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 28,
    );
  }
}
