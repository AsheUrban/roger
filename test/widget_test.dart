import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:roger/core/providers.dart';
import 'package:roger/main.dart';

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
          authStateChangesProvider.overrideWith(
            (ref) => const Stream<AuthState>.empty(),
          ),
          routerProvider.overrideWithValue(testRouter),
        ],
        child: const RogerApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
