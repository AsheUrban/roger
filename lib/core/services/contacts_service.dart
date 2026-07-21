import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A roger account matched by single-pick discovery. Carries only the
/// non-sensitive fields `discover_user` returns — never a phone or hash.
class DiscoveredUser {
  final String userId;
  final String avatarColor;
  final DateTime? lastActiveAt;

  const DiscoveredUser({
    required this.userId,
    required this.avatarColor,
    this.lastActiveAt,
  });
}

/// Single-pick contact discovery (spec §10). roger never receives the address
/// book: the user picks one contact through the OS picker (no permission), and
/// that one number is checked server-side via the `discover_user` RPC, which
/// peppers + hashes it, matches against stored `phone_hash`, and discards the
/// raw number. The client never reads the `users` table.
class ContactsService {
  final SupabaseClient _client;
  final FlutterNativeContactPicker _picker;

  ContactsService({SupabaseClient? client, FlutterNativeContactPicker? picker})
      : _client = client ?? Supabase.instance.client,
        _picker = picker ?? FlutterNativeContactPicker();

  /// Opens the OS contact picker and returns the single picked contact's name
  /// and number, or null if the user cancelled or the contact has no number.
  /// Requires NO contacts permission: `selectPhoneNumber` reads only the URI
  /// the picker returns (the OS grants scoped access to that one item), never
  /// the contacts provider — that's the load-bearing single-pick property
  /// (spec §10 / invariant 4). Do not swap this for a picker that re-reads the
  /// full contact (e.g. flutter_contacts' getContact), which needs READ_CONTACTS.
  Future<({String name, String phoneNumber})?> pickContact() async {
    final Contact? contact = await _picker.selectPhoneNumber();
    final number = contact?.selectedPhoneNumber;
    if (number == null || number.isEmpty) return null;
    return (name: contact?.fullName ?? '', phoneNumber: number);
  }

  /// Best-effort E.164 normalization. Strips formatting, prepends +1 (US
  /// default) if no country code. The discovery RPC canonicalizes to bare
  /// digits server-side, so formatting differences don't affect the match;
  /// this only needs the correct digits. (International correctness via an
  /// on-device libphonenumber library is tracked separately.)
  String normalizeToE164(String phoneNumber) {
    var digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('+')) return digits;
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    if (digits.length == 10) return '+1$digits';
    return '+$digits';
  }

  /// Checks one picked number against roger via the `discover_user` RPC.
  /// Returns the matching account, or null if the number isn't on roger.
  /// Rate-limited server-side (20/day); throws a [PostgrestException] when the
  /// cap is exceeded, which the caller surfaces gracefully.
  Future<DiscoveredUser?> discover(String phoneNumber) async {
    final normalized = normalizeToE164(phoneNumber);
    if (normalized.isEmpty) return null;

    final res = await _client.rpc('discover_user', params: {
      'p_phone': normalized,
    });
    final rows = res as List;
    if (rows.isEmpty) return null;

    final row = rows.first as Map<String, dynamic>;
    return DiscoveredUser(
      userId: row['user_id'] as String,
      avatarColor: row['avatar_color'] as String,
      lastActiveAt: row['last_active_at'] != null
          ? DateTime.parse(row['last_active_at'] as String)
          : null,
    );
  }
}
