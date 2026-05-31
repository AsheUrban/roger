import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageService', skip: 'feature not built — step 11', () {
    group('upload', () {
      test('uploads encrypted blob and returns r2Key', () {});
    });

    group('download', () {
      test('downloads blob by r2Key', () {});
    });

    group('purge', () {
      test('purges blob when all members have downloaded', () {});

      test('does not purge when some members have not downloaded', () {});
    });

    group('expiry', () {
      test('resetExpiry extends the 60-day window', () {});

      test('letExpire purges immediately', () {});
    });
  });
}
