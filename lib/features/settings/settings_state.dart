import '../../core/models/user.dart';
import '../../core/models/user_settings.dart';

class SettingsState {
  final User? user;
  final UserSettings? settings;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.user,
    this.settings,
    this.isLoading = false,
    this.error,
  });
}
