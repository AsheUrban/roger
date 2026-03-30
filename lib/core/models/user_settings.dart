class UserSettings {
  final String id;
  final String userId;
  final int messageLimit;
  final bool disappearingMessages;
  final int? preDisappearingLimit;
  final bool notificationsEnabled;
  final bool notifyVideos;
  final bool notifyPhotos;
  final bool notifyNotes;
  final bool notifyExpirations;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSettings({
    required this.id,
    required this.userId,
    this.messageLimit = 100,
    this.disappearingMessages = false,
    this.preDisappearingLimit,
    this.notificationsEnabled = true,
    this.notifyVideos = true,
    this.notifyPhotos = true,
    this.notifyNotes = true,
    this.notifyExpirations = true,
    required this.createdAt,
    required this.updatedAt,
  });
}
