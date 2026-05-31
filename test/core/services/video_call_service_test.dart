import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoCallService', skip: 'feature not built — step 9', () {
    test('startCall initiates LiveKit session', () {});

    test('joinCall connects to existing session', () {});

    test('endCall disconnects and saves final chunk', () {});

    test('auto-chunks at 15-minute intervals', () {});

    test('chunks drop into thread as call_chunk messages silently', () {});

    test('watchRemotePresence streams other user active state', () {});
  });
}
