class NotificationService {
  Future<void> registerDeviceToken() async {}
  Future<void> removeDeviceToken() async {}
  Future<void> sendNewMessageNotification({
    required String conversationId,
    required String senderName,
    required String messageType,
  }) async {}
  Future<void> sendNudgeNotification({
    required String recipientId,
    required String senderName,
  }) async {}
  Future<void> sendExpiredNotification({
    required String senderId,
    required String recipientName,
  }) async {}
  Future<bool> areNotificationsEnabled() async => throw UnimplementedError();
}
