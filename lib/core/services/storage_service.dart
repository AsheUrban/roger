import 'dart:typed_data';

class StorageService {
  Future<String> uploadBlob({
    required Uint8List encryptedData,
    required String messageId,
  }) async =>
      throw UnimplementedError();
  Future<Uint8List> downloadBlob({required String r2Key}) async =>
      throw UnimplementedError();
  Future<void> purgeBlob({required String r2Key}) async {}
  Future<void> purgeIfAllDownloaded({required String messageId}) async {}
  Future<void> resetExpiry({required String messageId}) async {}
  Future<void> letExpire({required String messageId}) async {}
}
