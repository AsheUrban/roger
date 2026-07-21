/// Cached auth-state, owned by `AuthNotifier`/`authProvider` and consumed by
/// the synchronous router redirect. See `LOG_5_29.md` for the full design.
///
/// Two variants today; sealed (not enum/bool) so:
/// - `AuthStateOnboarded(User)` can carry the resolved user in Step 8 (Settings
///   reads it instead of re-fetching) as an additive change, and
/// - a future arm like `SessionExpired` can be added with the compiler walking
///   every `switch` to flag missed handling.
sealed class AuthState {
  const AuthState();
}

final class AuthStateNeedsOnboarding extends AuthState {
  const AuthStateNeedsOnboarding();
}

final class AuthStateOnboarded extends AuthState {
  const AuthStateOnboarded();
}
