import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageService', () {
    group('upload', () {
      test('uploads encrypted blob and returns r2Key', () {
        fail('not implemented');
      });
    });

    group('download', () {
      test('downloads blob by r2Key', () {
        fail('not implemented');
      });
    });

    group('purge', () {
      test('purges blob when all members have downloaded', () {
        fail('not implemented');
      });

      test('does not purge when some members have not downloaded', () {
        fail('not implemented');
      });
    });

    group('expiry', () {
      test('resetExpiry extends the 60-day window', () {
        fail('not implemented');
      });

      test('letExpire purges immediately', () {
        fail('not implemented');
      });
    });
  });
}
