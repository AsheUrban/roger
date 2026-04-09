import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storageKey = 'roger_db_key';

class DatabaseKeyService {
  final FlutterSecureStorage _storage;

  DatabaseKeyService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Returns the existing DB key, or generates and stores a new one on first call.
  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null) return existing;

    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final key = base64Url.encode(bytes);
    await _storage.write(key: _storageKey, value: key);
    return key;
  }
}
