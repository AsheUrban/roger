import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:roger/features/search/search_notifier.dart';
import 'package:roger/features/search/search_state.dart';
import 'package:roger/main.dart';

class _SpySearchNotifier extends SearchNotifier {
  int refreshContactsCalls = 0;
  @override
  SearchState build() => const SearchState();
  @override
  Future<void> refreshContacts() async {
    refreshContactsCalls++;
  }
}

void main() {
  testWidgets('RogerApp renders without crashing', (WidgetTester tester) async {
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(testRouter),
        ],
        child: const RogerApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets(
      'AppLifecycleState.resumed triggers searchProvider.refreshContacts',
      (WidgetTester tester) async {
    final spy = _SpySearchNotifier();
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(testRouter),
          searchProvider.overrideWith(() => spy),
        ],
        child: const RogerApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Simulate the app coming back to the foreground.
    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(spy.refreshContactsCalls, greaterThanOrEqualTo(1));
  });
}
