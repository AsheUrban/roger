import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/services/encryption_service.dart';

// E2EE crypto contract (spec §7, pulled forward into Camera 6b — key management
// is message-type-agnostic; the same conversation key that encrypts a note will
// encrypt video/photo blobs in 6c).
//
// Primitives (spec tech stack: AES-256 + ECDH via `cryptography`):
//   * user key pair — X25519 (ECDH), keys carried as base64 strings
//   * conversation key — 32 random bytes (AES-256), base64
//   * key wrap — ECIES-style: ephemeral X25519 + HKDF-SHA256 → AES-256-GCM
//   * content — AES-256-GCM, fresh random nonce per encryption
//
// Everything here is pure on-device crypto — no Supabase, no platform channels.

void main() {
  late EncryptionService service;

  setUp(() {
    service = EncryptionService();
  });

  group('EncryptionService', () {
    group('key pair generation', () {
      test('generates a base64 public/private key pair (32 bytes each)',
          () async {
        final pair = await service.generateKeyPair();

        expect(pair.publicKey, isNotEmpty);
        expect(pair.privateKey, isNotEmpty);
        expect(base64Decode(pair.publicKey).length, 32);
        expect(base64Decode(pair.privateKey).length, 32);
      });

      test('each call produces unique keys', () async {
        final a = await service.generateKeyPair();
        final b = await service.generateKeyPair();

        expect(a.publicKey, isNot(equals(b.publicKey)));
        expect(a.privateKey, isNot(equals(b.privateKey)));
      });

      test('derivePublicKey re-derives the same public key from a stored '
          'private key (KeyService needs this after a restart)', () async {
        final pair = await service.generateKeyPair();

        final derived = await service.derivePublicKey(pair.privateKey);

        expect(derived, pair.publicKey);
      });
    });

    group('conversation key', () {
      test('generates a 32-byte (AES-256) key, base64-encoded', () async {
        final key = await service.generateConversationKey();

        expect(key, isNotEmpty);
        expect(base64Decode(key).length, 32);
      });

      test('each call produces a unique key', () async {
        final a = await service.generateConversationKey();
        final b = await service.generateConversationKey();

        expect(a, isNot(equals(b)));
      });

      test('wrap round-trip: encrypt for a recipient, decrypt with their '
          'private key returns the original key', () async {
        final recipient = await service.generateKeyPair();
        final conversationKey = await service.generateConversationKey();

        final wrapped = await service.encryptConversationKey(
          conversationKey: conversationKey,
          recipientPublicKey: recipient.publicKey,
        );
        final unwrapped = await service.decryptConversationKey(
          encryptedConversationKey: wrapped,
          privateKey: recipient.privateKey,
        );

        expect(unwrapped, conversationKey);
        expect(wrapped, isNot(equals(conversationKey)));
      });

      test('wrapping the same key twice produces different ciphertexts '
          '(fresh ephemeral key per wrap)', () async {
        final recipient = await service.generateKeyPair();
        final conversationKey = await service.generateConversationKey();

        final w1 = await service.encryptConversationKey(
          conversationKey: conversationKey,
          recipientPublicKey: recipient.publicKey,
        );
        final w2 = await service.encryptConversationKey(
          conversationKey: conversationKey,
          recipientPublicKey: recipient.publicKey,
        );

        expect(w1, isNot(equals(w2)));
      });

      test('unwrapping with the wrong private key fails', () async {
        final recipient = await service.generateKeyPair();
        final wrongKeys = await service.generateKeyPair();
        final conversationKey = await service.generateConversationKey();

        final wrapped = await service.encryptConversationKey(
          conversationKey: conversationKey,
          recipientPublicKey: recipient.publicKey,
        );

        await expectLater(
          service.decryptConversationKey(
            encryptedConversationKey: wrapped,
            privateKey: wrongKeys.privateKey,
          ),
          throwsA(anything),
          reason: 'AES-GCM authentication must reject a wrong key',
        );
      });
    });

    group('text encryption (notes)', () {
      test('round-trip returns the original text', () async {
        final key = await service.generateConversationKey();

        final ciphertext = await service.encryptText(
          plaintext: 'hello roger',
          conversationKey: key,
        );
        final decrypted = await service.decryptText(
          ciphertext: ciphertext,
          conversationKey: key,
        );

        expect(decrypted, 'hello roger');
      });

      test('ciphertext differs from plaintext and never contains it', () async {
        final key = await service.generateConversationKey();
        const plaintext = 'a perfectly private note';

        final ciphertext = await service.encryptText(
          plaintext: plaintext,
          conversationKey: key,
        );

        expect(ciphertext, isNot(equals(plaintext)));
        expect(ciphertext.contains(plaintext), isFalse);
      });

      test('encrypting the same text twice produces different ciphertexts '
          '(fresh nonce per encryption)', () async {
        final key = await service.generateConversationKey();

        final c1 = await service.encryptText(
            plaintext: 'same note', conversationKey: key);
        final c2 = await service.encryptText(
            plaintext: 'same note', conversationKey: key);

        expect(c1, isNot(equals(c2)));
      });

      test('round-trips emoji and multi-line text (note composer allows the '
          'full system keyboard)', () async {
        final key = await service.generateConversationKey();
        const plaintext = 'line one\nline two 🎥❤️\ntschüß';

        final ciphertext = await service.encryptText(
          plaintext: plaintext,
          conversationKey: key,
        );
        final decrypted = await service.decryptText(
          ciphertext: ciphertext,
          conversationKey: key,
        );

        expect(decrypted, plaintext);
      });

      test('decrypting with the wrong conversation key fails', () async {
        final key = await service.generateConversationKey();
        final wrongKey = await service.generateConversationKey();

        final ciphertext = await service.encryptText(
          plaintext: 'secret',
          conversationKey: key,
        );

        await expectLater(
          service.decryptText(ciphertext: ciphertext, conversationKey: wrongKey),
          throwsA(anything),
        );
      });
    });

    group('blob encryption (video/photo — 6c uses the same path)', () {
      test('round-trip returns the original bytes', () async {
        final key = await service.generateConversationKey();
        final plaintext = Uint8List.fromList(List.generate(1024, (i) => i % 256));

        final ciphertext = await service.encryptBlob(
          plaintext: plaintext,
          conversationKey: key,
        );
        final decrypted = await service.decryptBlob(
          ciphertext: ciphertext,
          conversationKey: key,
        );

        expect(decrypted, plaintext);
      });

      test('ciphertext differs from plaintext', () async {
        final key = await service.generateConversationKey();
        final plaintext = Uint8List.fromList(List.filled(64, 7));

        final ciphertext = await service.encryptBlob(
          plaintext: plaintext,
          conversationKey: key,
        );

        expect(ciphertext, isNot(equals(plaintext)));
      });

      test('decrypting with the wrong conversation key fails', () async {
        final key = await service.generateConversationKey();
        final wrongKey = await service.generateConversationKey();
        final plaintext = Uint8List.fromList([1, 2, 3, 4]);

        final ciphertext = await service.encryptBlob(
          plaintext: plaintext,
          conversationKey: key,
        );

        await expectLater(
          service.decryptBlob(ciphertext: ciphertext, conversationKey: wrongKey),
          throwsA(anything),
        );
      });
    });
  });
}
