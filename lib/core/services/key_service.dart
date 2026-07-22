import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'encryption_service.dart';

/// Key management (spec §7, pulled forward into Camera 6b): owns where keys
/// live and how they reach other members. Crypto itself lives in
/// [EncryptionService]; this layer talks to secure storage and Supabase.
///
/// * Own key pair — the private key is stored ONLY in platform secure storage
///   (Keychain / Keystore via flutter_secure_storage), keyed per user id so a
///   different account signing in on the same device never reuses it. Only the
///   public key is uploaded (`user_keys`). The public key is re-derived from
///   the stored private key, so the private key is the single secret at rest.
/// * Conversation key — fetched as the caller's own wrapped `conversation_keys`
///   row and unwrapped locally; if the conversation has no key yet, this device
///   initiates: generates the key and writes one wrapped row per active member
///   (each encrypted to that member's public key). The server only ever sees
///   wrapped keys.
class KeyService {
  final SupabaseClient _client;
  final EncryptionService _encryption;
  final FlutterSecureStorage _storage;

  // Unwrapped conversation keys for this session. In-memory only — never
  // persisted. NOTE (Gap 2, step 8): like currentUserIdProvider, this cache
  // assumes one identity per session; sign-out/account-switch must clear it
  // when those flows land.
  final Map<String, String> _conversationKeyCache = {};

  KeyService({
    SupabaseClient? client,
    EncryptionService? encryption,
    FlutterSecureStorage? storage,
  })  : _client = client ?? Supabase.instance.client,
        _encryption = encryption ?? EncryptionService(),
        _storage = storage ?? const FlutterSecureStorage();

  String _privateKeyStorageKey(String userId) => 'roger_private_key_$userId';

  /// Idempotently guarantees this user has a usable key pair: a private key in
  /// secure storage and a matching ACTIVE `user_keys` row server-side.
  ///
  /// Handles all three states with one rule — the local private key is the
  /// source of truth:
  ///   * fresh user: generate, store private, upload public
  ///   * restart: private key present, active server row matches → no-op
  ///   * new device / drift: no private key (or server row doesn't match the
  ///     derived public) → retire the old active rows, upload the new public.
  ///     Historical messages wrapped to the lost key are unreadable on this
  ///     device (spec §18 edge case); conversations continue from the new key.
  Future<({String publicKey, String privateKey})> ensureOwnKeyPair() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated.');
    }

    var privateKey = await _storage.read(key: _privateKeyStorageKey(uid));
    if (privateKey == null) {
      final pair = await _encryption.generateKeyPair();
      await _storage.write(
        key: _privateKeyStorageKey(uid),
        value: pair.privateKey,
      );
      privateKey = pair.privateKey;
    }
    final publicKey = await _encryption.derivePublicKey(privateKey);

    final active = await _client
        .from('user_keys')
        .select('public_key')
        .eq('user_id', uid)
        .isFilter('retired_at', null) as List;
    final hasMatch = active.any((r) => r['public_key'] == publicKey);

    if (!hasMatch) {
      if (active.isNotEmpty) {
        await _client
            .from('user_keys')
            .update({'retired_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', uid)
            .isFilter('retired_at', null);
      }
      await _client
          .from('user_keys')
          .insert({'user_id': uid, 'public_key': publicKey});
    }

    return (publicKey: publicKey, privateKey: privateKey);
  }

  /// Returns the conversation's shared key (base64), unwrapped for local use.
  ///
  /// Reads the caller's own active `conversation_keys` row and unwraps it with
  /// the private key. If the conversation has no key yet, this device is the
  /// initiator (spec §7: whichever member sends first): it generates the key
  /// and inserts one wrapped row per active member. A concurrent initiation
  /// race is settled by the one-active-key-per-member unique index — the loser
  /// gets a unique-violation, refetches, and uses the established key.
  Future<String> getConversationKey(String conversationId) async {
    final cached = _conversationKeyCache[conversationId];
    if (cached != null) return cached;

    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not authenticated.');
    }

    final own = await ensureOwnKeyPair();

    final row = await _client
        .from('conversation_keys')
        .select('encrypted_conversation_key')
        .eq('conversation_id', conversationId)
        .eq('user_id', uid)
        .isFilter('retired_at', null)
        .maybeSingle();

    if (row != null) {
      final key = await _encryption.decryptConversationKey(
        encryptedConversationKey: row['encrypted_conversation_key'] as String,
        privateKey: own.privateKey,
      );
      _conversationKeyCache[conversationId] = key;
      return key;
    }

    return _initiateConversationKey(
      conversationId: conversationId,
      ownUserId: uid,
      own: own,
    );
  }

  Future<String> _initiateConversationKey({
    required String conversationId,
    required String ownUserId,
    required ({String publicKey, String privateKey}) own,
  }) async {
    final memberRows = await _client
        .from('conversation_members')
        .select('user_id')
        .eq('conversation_id', conversationId)
        .isFilter('left_at', null) as List;
    // Deleted members (user_id nulled) get no key row — no account, no keys,
    // nothing to encrypt for.
    final memberIds =
        memberRows.map((r) => r['user_id'] as String?).whereType<String>();

    final conversationKey = await _encryption.generateConversationKey();

    final wrappedKeys = <Map<String, dynamic>>[];
    for (final memberId in memberIds) {
      final String publicKey;
      if (memberId == ownUserId) {
        publicKey = own.publicKey;
      } else {
        final keys = await _client
            .from('user_keys')
            .select('public_key')
            .eq('user_id', memberId)
            .isFilter('retired_at', null) as List;
        if (keys.isEmpty) {
          // Spec §18 edge: a member's public key is unavailable — the message
          // cannot be encrypted for them; the send fails cleanly. (A local
          // send-queue with retry is future work — tracked with the
          // upload-retry open question.)
          throw StateError(
            "This conversation can't be encrypted yet — a member hasn't "
            'opened roger since encryption was added.',
          );
        }
        publicKey = keys.first['public_key'] as String;
      }
      wrappedKeys.add({
        'user_id': memberId,
        'encrypted_conversation_key': await _encryption.encryptConversationKey(
          conversationKey: conversationKey,
          recipientPublicKey: publicKey,
        ),
      });
    }

    try {
      // Key rows are written ONLY through this SECURITY DEFINER RPC — there is
      // no client INSERT policy on conversation_keys. The RPC refuses if any
      // active key row already exists (no first-write poisoning: a member
      // can't pre-plant a garbage row) and requires the set to cover exactly
      // the active members (no partial distribution locking anyone out).
      await _client.rpc('distribute_conversation_keys', params: {
        'p_conversation_id': conversationId,
        'p_keys': wrappedKeys,
      });
    } on PostgrestException catch (e) {
      // Already keyed: another device initiated concurrently and won (spec
      // §18: "one wins, other receives established key"). Use theirs.
      if (e.code == '23505') {
        final established = await _client
            .from('conversation_keys')
            .select('encrypted_conversation_key')
            .eq('conversation_id', conversationId)
            .eq('user_id', ownUserId)
            .isFilter('retired_at', null)
            .maybeSingle();
        if (established != null) {
          final key = await _encryption.decryptConversationKey(
            encryptedConversationKey:
                established['encrypted_conversation_key'] as String,
            privateKey: own.privateKey,
          );
          _conversationKeyCache[conversationId] = key;
          return key;
        }
      }
      rethrow;
    }

    _conversationKeyCache[conversationId] = conversationKey;
    return conversationKey;
  }
}
