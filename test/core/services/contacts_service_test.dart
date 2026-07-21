import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roger/core/services/contacts_service.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late ContactsService service;
  late MockSupabaseClient mockClient;

  setUp(() {
    mockClient = MockSupabaseClient();
    service = ContactsService(client: mockClient);
  });

  group('ContactsService', () {
    // Single-pick discovery (spec §10): the client sends one picked number to
    // the discover_user RPC and gets back a match or nothing. The number is
    // hashed + matched server-side (peppered), never on the client — so there
    // is no client-side hashing to test anymore. normalizeToE164 is the one
    // remaining pure function; discover() and pickContact() are integration
    // (real Supabase / the OS picker).

    group('phone number normalization', () {
      test('strips spaces, dashes, and parentheses', () {
        expect(service.normalizeToE164('(555) 123-4567'), '+15551234567');
        expect(service.normalizeToE164('555 123 4567'), '+15551234567');
        expect(service.normalizeToE164('555-123-4567'), '+15551234567');
      });

      test('prepends +1 for 10-digit numbers without country code', () {
        expect(service.normalizeToE164('5551234567'), '+15551234567');
      });

      test('keeps + prefix if already present', () {
        expect(service.normalizeToE164('+15551234567'), '+15551234567');
        expect(service.normalizeToE164('+445551234567'), '+445551234567');
      });

      test('handles 11-digit US number starting with 1', () {
        expect(service.normalizeToE164('15551234567'), '+15551234567');
      });

      test('returns empty string for empty input', () {
        expect(service.normalizeToE164(''), '');
      });

      test('returns empty string for non-digit input', () {
        expect(service.normalizeToE164('abc'), '');
      });
    });

    group('discovery', () {
      test('single-number match against the discover_user RPC',
          skip: 'Integration test — needs real Supabase', () {});

      test('the picked number is never hashed or stored client-side',
          skip: 'Integration test — needs real Supabase', () {});
    });

    group('pickContact', () {
      test('opens the OS picker and returns one contact, no permission',
          skip: 'Integration test — needs the device contact picker', () {});
    });
  });
}
