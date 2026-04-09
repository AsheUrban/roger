import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/database/app_database.dart';
import 'core/providers.dart';
import 'core/services/database_key_service.dart';
import 'features/conversations/conversations_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/camera/camera_screen.dart';

/// Redirect logic extracted for testability.
/// [session] is the current auth session (null if not authenticated).
/// [hasUsersRow] is a function that checks if the public.users row exists.
/// Returns the path to redirect to, or null to stay on current path.
Future<String?> routerRedirect({
  required Session? session,
  required Future<bool> Function(String userId) hasUsersRow,
  required String path,
}) async {
  final isOnboarding = path == '/onboarding';

  // Not authenticated → must onboard
  if (session == null) {
    return isOnboarding ? null : '/onboarding';
  }

  // Authenticated — check if account creation completed
  final exists = await hasUsersRow(session.user.id);

  if (!exists) {
    // Magic link verified but account creation never finished
    return isOnboarding ? null : '/onboarding';
  }

  // Fully onboarded — don't let them back to onboarding
  if (isOnboarding) {
    return '/conversations';
  }

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.read(supabaseClientProvider);

  return GoRouter(
    initialLocation: '/conversations',
    redirect: (context, state) => routerRedirect(
      session: client.auth.currentSession,
      hasUsersRow: (userId) async {
        final row = await client
            .from('users')
            .select('id')
            .eq('id', userId)
            .maybeSingle();
        return row != null;
      },
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
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
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

class RogerApp extends ConsumerWidget {
  const RogerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
