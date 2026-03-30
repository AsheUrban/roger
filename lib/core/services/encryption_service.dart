import 'dart:typed_data';

class EncryptionService {
  Future<({String publicKey, String privateKey})> generateKeyPair() async =>
      throw UnimplementedError();
  Future<String> generateConversationKey() async =>
      throw UnimplementedError();
  Future<String> encryptConversationKey({
    required String conversationKey,
    required String recipientPublicKey,
  }) async =>
      throw UnimplementedError();
  Future<String> decryptConversationKey({
    required String encryptedConversationKey,
    required String privateKey,
  }) async =>
      throw UnimplementedError();
  Future<Uint8List> encryptBlob({
    required Uint8List plaintext,
    required String conversationKey,
  }) async =>
      throw UnimplementedError();
  Future<Uint8List> decryptBlob({
    required Uint8List ciphertext,
    required String conversationKey,
  }) async =>
      throw UnimplementedError();
  Future<String> encryptText({
    required String plaintext,
    required String conversationKey,
  }) async =>
      throw UnimplementedError();
  Future<String> decryptText({
    required String ciphertext,
    required String conversationKey,
  }) async =>
      throw UnimplementedError();
}
