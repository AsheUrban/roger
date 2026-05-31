import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'core/auth_notifier.dart';
import 'core/auth_state.dart';
import 'core/config/env.dart';
import 'core/database/app_database.dart';
import 'core/providers.dart';
import 'core/services/database_key_service.dart';
import 'core/theme/colors.dart';
import 'features/conversations/conversations_screen.dart';
import 'features/search/search_notifier.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/camera/camera_screen.dart';

/// Synchronous router redirect — reads the cached `AuthState` instead of
/// querying `public.users` on every navigation. See `LOG_5_29.md`.
///
/// Pure function: exhaustive switch over `AuthState`; idempotent on its own
/// target (the redirect won't loop). Re-evaluated whenever the
/// `refreshListenable` bridge in `routerProvider` fires.
String? routerRedirect({
  required AuthState authState,
  required String path,
}) {
  final isOnboarding = path == '/onboarding';
  return switch (authState) {
    AuthStateNeedsOnboarding() => isOnboarding ? null : '/onboarding',
    AuthStateOnboarded() => isOnboarding ? '/conversations' : null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  // `ValueNotifier` bridge poked by `ref.listen(authProvider, ...)`. Passed to
  // `GoRouter` as `refreshListenable` so the redirect re-runs whenever
  // `AuthState` changes (seed → async correction, signedOut, markOnboarded).
  // Closure-local — never exposed as provider state — so no `Raw<…>` needed.
  final bridge = ValueNotifier<int>(0);
  ref.listen<AuthState>(authProvider, (_, _) {
    bridge.value++;
  });
  ref.onDispose(bridge.dispose);

  return GoRouter(
    initialLocation: '/conversations',
    refreshListenable: bridge,
    redirect: (context, state) => routerRedirect(
      authState: ref.read(authProvider),
      path: state.uri.path,
    ),
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _RogerShell(child: child),
        routes: [
          GoRoute(
            path: '/conversations',
            builder: (context, state) => const ConversationsScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/camera/:conversationId',
        builder: (context, state) => CameraScreen(
          conversationId: state.pathParameters['conversationId']!,
        ),
      ),
    ],
  );
});

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  final dbKey = await DatabaseKeyService().getOrCreateKey();
  final db = await openAppDatabase(dbKey);

  runApp(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ],
    child: const RogerApp(),
  ));
}

class RogerApp extends ConsumerStatefulWidget {
  const RogerApp({super.key});

  @override
  ConsumerState<RogerApp> createState() => _RogerAppState();
}

class _RogerAppState extends ConsumerState<RogerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Fire-and-forget — refreshContacts has its own in-flight guard.
      ref.read(searchProvider.notifier).refreshContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'roger',
      routerConfig: router,
    );
  }
}

class _RogerShell extends StatelessWidget {
  final Widget child;

  const _RogerShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = switch (location) {
      '/conversations' => 0,
      '/search' => 1,
      '/settings' => 2,
      _ => 0,
    };

    return Scaffold(
      backgroundColor: charcoal,
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) {
          final path = switch (i) {
            0 => '/conversations',
            1 => '/search',
            2 => '/settings',
            _ => '/conversations',
          };
          context.go(path);
        },
        // Spec §4: warm white for active nav state. Labels never shown.
        backgroundColor: charcoal,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedItemColor: warmWhite,
        unselectedItemColor: warmWhite.withValues(alpha: 0.4),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: '',
          ),
        ],
      ),
    );
  }
}
