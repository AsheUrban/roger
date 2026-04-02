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

    group('hashing', () {
      test('hashes phone number deterministically', () {
        final hash1 = service.hashPhoneNumber('+15551234567');
        final hash2 = service.hashPhoneNumber('+15551234567');
        expect(hash1, hash2);
      });

      test('different numbers produce different hashes', () {
        final hash1 = service.hashPhoneNumber('+15551234567');
        final hash2 = service.hashPhoneNumber('+15559999999');
        expect(hash1, isNot(equals(hash2)));
      });

      test('produces valid SHA-256 hex string (64 characters)', () {
        final hash = service.hashPhoneNumber('+15551234567');
        expect(hash.length, 64);
        expect(RegExp(r'^[a-f0-9]+$').hasMatch(hash), true);
      });
    });

    group('permissions', () {
      test('requestPermission returns grant status',
          skip: true, () {});

      test('hasPermission checks current state',
          skip: true, () {});
    });

    group('batch check', () {
      test('sends hashes to server, returns matching roger users',
          skip: true, () {});

      test('raw numbers never leave device — only hashes sent',
          skip: true, () {});
    });

    group('on-demand search', () {
      test('normalizes query before hashing', () {
        final normalized = service.normalizeToE164('(555) 123-4567');
        final hash = service.hashPhoneNumber(normalized);
        final directHash = service.hashPhoneNumber('+15551234567');
        expect(hash, directHash);
      });
    });

    group('cached data', () {
      test('cachedRogerUsers starts empty', () {
        expect(service.cachedRogerUsers, isEmpty);
      });

      test('cachedContacts starts empty', () {
        expect(service.cachedContacts, isEmpty);
      });
    });
  });
}
