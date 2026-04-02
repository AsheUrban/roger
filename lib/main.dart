import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'features/conversations/conversations_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/camera/camera_screen.dart';

final _router = GoRouter(
  initialLocation: '/conversations',
  redirect: (context, state) async {
    final session = Supabase.instance.client.auth.currentSession;
    final isOnboarding = state.uri.path == '/onboarding';

    // Not authenticated → must onboard
    if (session == null) {
      return isOnboarding ? null : '/onboarding';
    }

    // Authenticated — check if account creation completed
    final userRow = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('id', session.user.id)
        .maybeSingle();

    if (userRow == null) {
      // Magic link verified but account creation never finished
      return isOnboarding ? null : '/onboarding';
    }

    // Fully onboarded — don't let them back to onboarding
    if (isOnboarding) {
      return '/conversations';
    }

    return null;
  },
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const ProviderScope(child: RogerApp()));
}

class RogerApp extends StatelessWidget {
  const RogerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'roger',
      routerConfig: _router,
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
