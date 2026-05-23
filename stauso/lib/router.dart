import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/home_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/splash_screen.dart';
import 'services/firebase_service.dart';

// ─── Router provider ──────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier();

  ref.listen<AsyncValue>(
    authStateProvider,
    (_, __) => notifier.refresh(),
  );
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = notifier.isLoggedIn;
      final loc = state.matchedLocation;

      // Splash and onboarding are always public
      if (loc == '/' || loc == '/onboarding') return null;

      // Unauthenticated users go to /auth
      if (!isLoggedIn && loc != '/auth') return '/auth';

      // Authenticated users bounce off /auth
      if (isLoggedIn && loc == '/auth') return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const CategoriesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/editor/:quoteId',
        builder: (context, state) => EditorScreen(
          quoteId: state.pathParameters['quoteId']!,
        ),
      ),
    ],
  );
});

// ─── Notifier that wakes the router when auth state changes ───────────────────

class _RouterNotifier extends ChangeNotifier {
  bool get isLoggedIn => FirebaseService.auth.currentUser != null;

  void refresh() => notifyListeners();
}
