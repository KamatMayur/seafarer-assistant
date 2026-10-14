import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/document/document_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/onboarding/profile_setup_screen.dart';
import 'features/onboarding/sign_in_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/sea_time/sea_service_form_screen.dart';
import 'features/sea_time/sea_time_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/privacy_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/wallet/certificate_form_screen.dart';
import 'features/wallet/wallet_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Rebuilds the router's redirect when the session changes.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _SessionListenable(ref);
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/feed',
    refreshListenable: listenable,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (loc == '/privacy') return null; // readable before and after sign-in
      final inOnboarding = loc == '/welcome' || loc == '/sign-in';
      switch (session) {
        case SessionState.loading:
          return loc == '/loading' ? null : '/loading';
        case SessionState.signedOut:
          return inOnboarding ? null : '/welcome';
        case SessionState.needsProfile:
          return loc == '/setup' ? null : '/setup';
        case SessionState.ready:
          return (inOnboarding || loc == '/loading' || loc == '/setup') ? '/feed' : null;
      }
    },
    routes: [
      GoRoute(path: '/loading', builder: (_, _) => const _Loading()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const ProfileSetupScreen()),
      ShellRoute(
        builder: (context, state, child) => _Shell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/feed',
            builder: (_, _) => const FeedScreen(),
            routes: [
              GoRoute(path: 'doc/:id', builder: (_, s) => FeedScreen(selectedId: s.pathParameters['id'])),
            ],
          ),
          GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
          GoRoute(
            path: '/wallet',
            builder: (_, _) => const WalletScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const CertificateFormScreen()),
              GoRoute(path: ':id', builder: (_, s) => CertificateFormScreen(certificateId: s.pathParameters['id'])),
            ],
          ),
          GoRoute(
            path: '/sea',
            builder: (_, _) => const SeaTimeScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const SeaServiceFormScreen()),
              GoRoute(path: ':id', builder: (_, s) => SeaServiceFormScreen(entryId: s.pathParameters['id'])),
            ],
          ),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(
            path: '/settings/profile',
            builder: (_, _) => const ProfileSetupScreen(editing: true),
          ),
        ],
      ),
      GoRoute(
        path: '/document/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => DocumentScreen(documentId: s.pathParameters['id']!),
      ),
    ],
  );
});

class SeafarerApp extends ConsumerWidget {
  const SeafarerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Seafarer Assistant',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1F5FA8), brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard, // 44px+ tap targets
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Shell extends StatelessWidget {
  const _Shell({required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [
    (path: '/feed', icon: Icons.notifications_outlined, active: Icons.notifications, label: 'For you'),
    (path: '/search', icon: Icons.search, active: Icons.search, label: 'Archive'),
    (path: '/wallet', icon: Icons.wallet_outlined, active: Icons.wallet, label: 'Wallet'),
    (path: '/sea', icon: Icons.sailing_outlined, active: Icons.sailing, label: 'Sea time'),
    (path: '/settings', icon: Icons.settings_outlined, active: Icons.settings, label: 'Settings'),
  ];

  int get _index {
    final i = _tabs.indexWhere((t) => location.startsWith(t.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    void go(int i) => context.go(_tabs[i].path);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final t in _tabs)
                NavigationRailDestination(icon: Icon(t.icon), selectedIcon: Icon(t.active), label: Text(t.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ]),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: go,
        destinations: [
          for (final t in _tabs) NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.active), label: t.label),
        ],
      ),
    );
  }
}
