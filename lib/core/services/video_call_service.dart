class VideoCallService {
  Future<void> startCall({required String conversationId}) async {}
  Future<void> joinCall({required String conversationId}) async {}
  Future<void> endCall({required String conversationId}) async {}
  Future<bool> isCallActive({required String conversationId}) async =>
      throw UnimplementedError();
  Stream<bool> watchRemotePresence({required String conversationId}) =>
      throw UnimplementedError();
  Future<void> saveCurrentChunk({required String conversationId}) async {}
}
