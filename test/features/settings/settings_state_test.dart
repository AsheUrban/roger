import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/models/user.dart';
import 'package:roger/core/models/user_settings.dart';
import 'package:roger/features/settings/settings_state.dart';

// SettingsState does not currently expose a copyWith — Step 8 (Settings) is
// unbuilt and the state struct is a placeholder. The copyWith contract from
// the migration doc therefore can't be tested on this class today; the
// other two contracts (equal-when-fields-match, not-equal-when-any-field-
// differs) still apply and are covered below. When Step 8 lands and adds
// copyWith, a third test case should be added here.

void main() {
  group('SettingsState equality', () {
    test('two default instances are equal', () {
      final a = SettingsState();
      final b = SettingsState();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two instances with same field values are equal (shared refs)', () {
      final user = User(
        id: 'u-1',
        phoneNumber: '+15551111111',
        avatarColor: 'Rust',
        createdAt: DateTime(2026, 1, 1),
      );
      final settings = UserSettings(
        id: 'settings-1',
        userId: 'u-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final a = SettingsState(
        user: user,
        settings: settings,
        isLoading: true,
        error: 'oops',
      );
      final b = SettingsState(
        user: user,
        settings: settings,
        isLoading: true,
        error: 'oops',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when user differs (different identity)', () {
      final userA = User(
        id: 'u-1',
        phoneNumber: '+15551111111',
        avatarColor: 'Rust',
        createdAt: DateTime(2026, 1, 1),
      );
      final userB = User(
        id: 'u-2',
        phoneNumber: '+15552222222',
        avatarColor: 'Olive',
        createdAt: DateTime(2026, 1, 1),
      );
      final a = SettingsState(user: userA);
      final b = SettingsState(user: userB);
      expect(a, isNot(equals(b)));
    });

    test('not equal when settings differs (different identity)', () {
      final settingsA = UserSettings(
        id: 's-1',
        userId: 'u-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final settingsB = UserSettings(
        id: 's-2',
        userId: 'u-1',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final a = SettingsState(settings: settingsA);
      final b = SettingsState(settings: settingsB);
      expect(a, isNot(equals(b)));
    });

    test('not equal when isLoading differs', () {
      final a = SettingsState();
      final b = SettingsState(isLoading: true);
      expect(a, isNot(equals(b)));
    });

    test('not equal when error differs', () {
      final a = SettingsState();
      final b = SettingsState(error: 'oops');
      expect(a, isNot(equals(b)));
    });
  });
}
