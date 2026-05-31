import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'auth_state.dart';
import 'providers.dart';
import 'services/auth_service.dart';

/// Cached auth state — replaces the per-navigation `public.users` query that
/// used to run inside `routerRedirect`. See `LOG_5_29.md` for the full design.
///
/// Seed strategy: `build()` reads `AuthService.currentSession` synchronously
/// so the state is resolved before the first frame. A session present
/// optimistically seeds `Onboarded` (no flash for the returning-user common
/// case); an async correction in a microtask bounces only the stale-session-
/// no-row edge case. The correction is error-resilient — only a definitive
/// `null` from `getCurrentUser()` downgrades to `NeedsOnboarding`; thrown
/// errors leave the optimistic state in place so a transient 401 / network
/// blip never bounces a real returning user.
///
/// The notifier also subscribes to `AuthService.authEvents` and acts on
/// `signedOut` only — `signedIn` / `tokenRefreshed` / `initialSession` fire
/// on startup and would otherwise clobber the seed/correction.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;
  StreamSubscription<AuthChangeEvent>? _eventsSub;

  @override
  AuthState build() {
    _authService = ref.read(authServiceProvider);

    _eventsSub = _authService.authEvents.listen((event) {
      if (event == AuthChangeEvent.signedOut) {
        if (!ref.mounted) return;
        state = const AuthStateNeedsOnboarding();
      }
      // signedIn / tokenRefreshed / initialSession ignored on purpose:
      // Supabase fires those during startup and reacting would undo the seed
      // and async correction.
    });
    ref.onDispose(() {
      _eventsSub?.cancel();
    });

    final session = _authService.currentSession;
    if (session == null) {
      return const AuthStateNeedsOnboarding();
    }

    // Optimistic seed + async correction. Microtask defers the call until
    // after build() returns so the seed lands first.
    Future.microtask(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (!ref.mounted) return;
        if (user == null) {
          // Definitive null — authenticated but no public.users row. The
          // residual edge-case flash is paid here.
          state = const AuthStateNeedsOnboarding();
        }
        // Non-null: stay Onboarded (already the seed).
      } catch (_) {
        // Error-resilient: a thrown error is inconclusive (transient 401
        // mid-token-refresh, network failure). Leaving the optimistic
        // Onboarded prevents bouncing a real returning user over a blip;
        // a genuine logout is still caught by the signedOut subscription.
      }
    });

    return const AuthStateOnboarded();
  }

  /// Called by `OnboardingNotifier` on account-creation success (and the
  /// existing-user branch of `verifyOtp`) before the screen's imperative
  /// navigation. Flips state to `Onboarded` so the redirect won't bounce.
  void markOnboarded() {
    state = const AuthStateOnboarded();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
