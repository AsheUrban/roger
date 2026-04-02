import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_state.dart';

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  Future<void> loadSettings() async {}
  Future<void> updateDisplayName(String name) async {}
  Future<void> updatePhoneNumber(String newNumber) async {}
  Future<void> updateAvatarColor(String color) async {}
  Future<void> updateMessageLimit(int limit) async {}
  Future<void> toggleDisappearingMessages() async {}
  Future<void> updateNotificationSettings({
    bool? enabled,
    bool? videos,
    bool? photos,
    bool? notes,
    bool? expirations,
  }) async {}
  Future<void> signOut() async {}
  Future<void> deleteAccount() async {}
}
