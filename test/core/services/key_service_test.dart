import 'package:flutter_test/flutter_test.dart';

// KeyService (Camera 6b-2) orchestrates secure storage + Supabase — its
// contracts are proven against real Supabase in
// integration_test/security/e2ee_key_test.dart (two authenticated clients).
// The pure crypto underneath is unit-covered in encryption_service_test.dart
// (including derivePublicKey, which ensureOwnKeyPair leans on).

void main() {
  group('KeyService',
      skip: 'Integration test — needs real Supabase + device secure storage '
          '(see integration_test/security/e2ee_key_test.dart)', () {
    group('ensureOwnKeyPair', () {
      test('fresh user: generates, stores private locally, uploads public',
          () {});

      test('idempotent: second call returns the same pair, no new rows', () {});

      test('private key never leaves the device — user_keys holds only the '
          'public key', () {});

      test('new device (no local private key): retires old active rows and '
          'uploads a new public key', () {});
    });

    group('getConversationKey', () {
      test('initiator: generates and distributes one wrapped row per active '
          'member via the distribute_conversation_keys RPC (direct inserts '
          'are RLS-rejected)', () {});

      test('recipient: unwraps own row to the same key the initiator made',
          () {});

      test('server stores only wrapped keys, never the plaintext key', () {});

      test('concurrent initiation: unique index settles the race, loser uses '
          'the established key', () {});

      test('a member with no published key fails the initiation cleanly', () {});

      test('deleted members (user_id null) get no key row', () {});
    });
  });
}
