import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user.dart' as app;

class ContactsService {
  final SupabaseClient _client;

  // In-memory cache — spec says contact data never written to local persistent storage
  List<app.User> _cachedRogerUsers = [];
  List<({String name, String phoneNumber})> _cachedContacts = [];

  ContactsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  Future<bool> hasPermission() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  Future<List<({String name, String phoneNumber})>> getDeviceContacts() async {
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
    );

    final results = <({String name, String phoneNumber})>[];
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = normalizeToE164(phone.number);
        if (normalized.isNotEmpty) {
          results.add((
            name: contact.displayName,
            phoneNumber: normalized,
          ));
        }
      }
    }
    return results;
  }

  /// Best-effort E.164 normalization. Strips formatting, prepends +1 (US default)
  /// if no country code. Not a full international parser.
  String normalizeToE164(String phoneNumber) {
    var digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return '';

    // If starts with +, keep as-is (already has country code)
    if (digits.startsWith('+')) return digits;

    // Strip leading 1 if 11 digits (US with country code but no +)
    if (digits.length == 11 && digits.startsWith('1')) {
      return '+$digits';
    }

    // Assume US +1 for 10-digit numbers
    if (digits.length == 10) {
      return '+1$digits';
    }

    // Can't normalize reliably — return with + prefix as best effort
    return '+$digits';
  }

  String hashPhoneNumber(String e164Number) {
    final bytes = utf8.encode(e164Number);
    return sha256.convert(bytes).toString();
  }

  /// Fetch all roger users, hash their phone numbers locally, match against provided hashes.
  // TODO: Move hashing server-side via Supabase Edge Function for scale
  Future<List<app.User>> batchCheckHashes(List<String> hashes) async {
    if (hashes.isEmpty) return [];

    final hashSet = hashes.toSet();

    // Fetch all roger users (RLS allows reading users table)
    final rows = await _client.from('users').select();

    final matches = <app.User>[];
    for (final row in rows) {
      final phone = row['phone_number'] as String;
      final hash = hashPhoneNumber(phone);
      if (hashSet.contains(hash)) {
        matches.add(_userFromRow(row));
      }
    }

    return matches;
  }

  Future<app.User?> onDemandSearch(String query) async {
    final normalized = normalizeToE164(query);
    if (normalized.isEmpty) return null;

    final hash = hashPhoneNumber(normalized);
    final results = await batchCheckHashes([hash]);
    return results.isEmpty ? null : results.first;
  }

  /// Hashes all device contacts and checks them against roger users.
  /// Results cached in memory only (spec: contact data never persisted locally).
  Future<void> refreshBatchCheck() async {
    final contacts = await getDeviceContacts();
    _cachedContacts = contacts;

    final hashes = contacts.map((c) => hashPhoneNumber(c.phoneNumber)).toList();
    _cachedRogerUsers = await batchCheckHashes(hashes);
  }

  List<app.User> get cachedRogerUsers => _cachedRogerUsers;
  List<({String name, String phoneNumber})> get cachedContacts => _cachedContacts;

  app.User _userFromRow(Map<String, dynamic> row) {
    return app.User(
      id: row['id'] as String,
      phoneNumber: row['phone_number'] as String,
      avatarColor: row['avatar_color'] as String,
      recoveryEmail: row['recovery_email'] as String?,
      lastActiveAt: row['last_active_at'] != null
          ? DateTime.parse(row['last_active_at'] as String)
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
