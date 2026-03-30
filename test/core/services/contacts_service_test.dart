import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContactsService', () {
    group('permissions', () {
      test('requestPermission returns grant status', () {
        fail('not implemented');
      });

      test('hasPermission checks current state', () {
        fail('not implemented');
      });
    });

    group('phone number normalization', () {
      test('normalizes to E.164 format', () {
        fail('not implemented');
      });

      test('handles spaces, dashes, and country codes', () {
        fail('not implemented');
      });
    });

    group('hashing', () {
      test('hashes phone number deterministically', () {
        fail('not implemented');
      });

      test('different numbers produce different hashes', () {
        fail('not implemented');
      });
    });

    group('batch check', () {
      test('sends hashes to server, returns matching roger users', () {
        fail('not implemented');
      });

      test('raw numbers never leave device', () {
        fail('not implemented');
      });

      test('runs on background isolate for large contact lists', () {
        fail('not implemented');
      });
    });

    group('on-demand search', () {
      test('checks specific query against server', () {
        fail('not implemented');
      });

      test('returns null for no match', () {
        fail('not implemented');
      });
    });
  });
}
