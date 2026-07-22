import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// On-device E2EE primitives (spec §7). Pure crypto — no Supabase, no storage;
/// key persistence and distribution live a layer up so this stays unit-testable.
///
/// Primitives (spec tech stack: AES-256 + ECDH via `cryptography`):
///   * user key pair — X25519; public/private carried as base64 strings
///   * conversation key — 32 random bytes (AES-256), base64
///   * key wrap — ECIES-style: a fresh ephemeral X25519 pair per wrap, ECDH
///     against the recipient's public key, HKDF-SHA256 → AES-256-GCM. Wire
///     format: ephemeralPublicKey(32) ‖ nonce(12) ‖ ciphertext ‖ mac(16), base64.
///   * content — AES-256-GCM with the conversation key, fresh nonce per call.
///     Wire format: nonce(12) ‖ ciphertext ‖ mac(16); text variants base64 it.
///
/// The same conversation key encrypts every message type — notes (6b) through
/// [encryptText], video/photo blobs (6c) through [encryptBlob].
class EncryptionService {
  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // Domain-separation label for the key-wrap KDF.
  static final List<int> _wrapInfo = utf8.encode('roger.conversation-key.v1');

  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _publicKeyLength = 32;

  Future<({String publicKey, String privateKey})> generateKeyPair() async {
    final pair = await _x25519.newKeyPair();
    final publicKey = await pair.extractPublicKey();
    final privateBytes = await pair.extractPrivateKeyBytes();
    return (
      publicKey: base64Encode(publicKey.bytes),
      privateKey: base64Encode(privateBytes),
    );
  }

  /// Re-derives the public key from a stored private key — the X25519 public
  /// key is a pure function of the private seed, so only the private key needs
  /// persisting.
  Future<String> derivePublicKey(String privateKey) async {
    final pair = await _x25519.newKeyPairFromSeed(base64Decode(privateKey));
    final publicKey = await pair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  Future<String> generateConversationKey() async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  Future<String> encryptConversationKey({
    required String conversationKey,
    required String recipientPublicKey,
  }) async {
    final ephemeral = await _x25519.newKeyPair();
    final wrapKey = await _deriveWrapKey(
      keyPair: ephemeral,
      remotePublicKeyBytes: base64Decode(recipientPublicKey),
    );
    final box = await _aesGcm.encrypt(
      base64Decode(conversationKey),
      secretKey: wrapKey,
    );
    final ephemeralPublic = await ephemeral.extractPublicKey();
    return base64Encode([...ephemeralPublic.bytes, ...box.concatenation()]);
  }

  Future<String> decryptConversationKey({
    required String encryptedConversationKey,
    required String privateKey,
  }) async {
    final bytes = base64Decode(encryptedConversationKey);
    final ephemeralPublicBytes = bytes.sublist(0, _publicKeyLength);
    final boxBytes = bytes.sublist(_publicKeyLength);
    final keyPair = await _x25519.newKeyPairFromSeed(base64Decode(privateKey));
    final wrapKey = await _deriveWrapKey(
      keyPair: keyPair,
      remotePublicKeyBytes: ephemeralPublicBytes,
    );
    final clear = await _aesGcm.decrypt(
      SecretBox.fromConcatenation(
        boxBytes,
        nonceLength: _nonceLength,
        macLength: _macLength,
      ),
      secretKey: wrapKey,
    );
    return base64Encode(clear);
  }

  Future<Uint8List> encryptBlob({
    required Uint8List plaintext,
    required String conversationKey,
  }) async {
    final box = await _aesGcm.encrypt(
      plaintext,
      secretKey: SecretKey(base64Decode(conversationKey)),
    );
    return Uint8List.fromList(box.concatenation());
  }

  Future<Uint8List> decryptBlob({
    required Uint8List ciphertext,
    required String conversationKey,
  }) async {
    final clear = await _aesGcm.decrypt(
      SecretBox.fromConcatenation(
        ciphertext,
        nonceLength: _nonceLength,
        macLength: _macLength,
      ),
      secretKey: SecretKey(base64Decode(conversationKey)),
    );
    return Uint8List.fromList(clear);
  }

  Future<String> encryptText({
    required String plaintext,
    required String conversationKey,
  }) async {
    final ciphertext = await encryptBlob(
      plaintext: Uint8List.fromList(utf8.encode(plaintext)),
      conversationKey: conversationKey,
    );
    return base64Encode(ciphertext);
  }

  Future<String> decryptText({
    required String ciphertext,
    required String conversationKey,
  }) async {
    final clear = await decryptBlob(
      ciphertext: Uint8List.fromList(base64Decode(ciphertext)),
      conversationKey: conversationKey,
    );
    return utf8.decode(clear);
  }

  Future<SecretKey> _deriveWrapKey({
    required SimpleKeyPair keyPair,
    required List<int> remotePublicKeyBytes,
  }) async {
    final shared = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey:
          SimplePublicKey(remotePublicKeyBytes, type: KeyPairType.x25519),
    );
    return _hkdf.deriveKey(secretKey: shared, info: _wrapInfo);
  }
}
