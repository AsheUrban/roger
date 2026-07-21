import 'package:share_plus/share_plus.dart';

/// Thin wrapper over the OS share sheet (share_plus). Isolated behind a service
/// so notifiers can be unit-tested with a mock — the real `SharePlus` call is a
/// platform channel and only runs on-device.
class ShareService {
  Future<void> shareText(String text) {
    return SharePlus.instance.share(ShareParams(text: text));
  }
}
