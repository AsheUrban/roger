import 'package:flutter_test/flutter_test.dart';
import 'package:roger/core/utils/time_format.dart';

void main() {
  group('formatElapsed', () {
    test('zero-pads seconds under a minute', () {
      expect(formatElapsed(Duration.zero), '0:00');
      expect(formatElapsed(const Duration(seconds: 7)), '0:07');
      expect(formatElapsed(const Duration(seconds: 59)), '0:59');
    });

    test('rolls minutes without padding them', () {
      expect(formatElapsed(const Duration(minutes: 1, seconds: 5)), '1:05');
      expect(formatElapsed(const Duration(minutes: 14, seconds: 59)), '14:59');
    });
  });
}
