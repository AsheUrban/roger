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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsState &&
        other.user == user &&
        other.settings == settings &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(user, settings, isLoading, error);
}
