# roger

Async video messaging for people you actually talk to.

---

## Contents

- [What it is](#what-it-is)
- [What it is not](#what-it-is-not)
- [Privacy](#privacy)
- [Stack](#stack)
- [Status](#status)
- [License](#license)

---

Roger is an async video messaging app for staying connected with close friends and family through short videos, photos, and notes. It is not a social network. There are no profiles, no follower counts, no algorithmic feeds, no strangers. Just the people already in your phone.

The name is a nod to the radio acknowledgment — *roger that*, message received.

---

## What it is

- **Async video messaging.** Record a video, it goes to your people. They watch it when they get to it. No pressure, no coordination, no live call required.
- **Photos with optional voice overlay.** Send a photo with a short voice note attached. No filters, no markup.
- **Notes.** Full-screen text with a color background. Simple.
- **Video calls** If you and someone else happen to be in the app at the same time, you can jump to a video call. It auto-records and saves to the thread so the conversation has no gaps.
- **Emoji and video reactions.** React to individual messages with emoji (animated, no counts) or a short video reaction.
- **Contact-based.** You find people because they're in your phone. No usernames, no handles, no search for strangers.

---

## Privacy

End-to-end encryption is not a feature — it's the architecture.

All content is encrypted on-device before it leaves the sender. Cloudflare R2 stores and delivers encrypted blobs only. The server never holds plaintext. Decryption happens on the recipient's device after download.

Roger uses a global rolling message window (100 messages by default, adjustable). Nothing accumulates indefinitely. When a message rolls off, it is deleted from local storage and purged from R2. The framing: *your last 100 messages are always here* — not a permanent archive of your life on someone else's server.

Live video calls via LiveKit are end-to-end encrypted natively. Closed captions are generated on-device via Picovoice Cheetah — no audio ever leaves the device.

---

## Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Database & Auth | Supabase |
| Video/Photo Storage | Cloudflare R2 |
| Live Video | LiveKit (WebRTC, E2EE native) |
| Closed Captions | Picovoice Cheetah (on-device) |
| Encryption | `cryptography` / `libsodium_dart` |
| Key Storage | iCloud Keychain (iOS) · Android Keystore (Android) |
| State Management | Riverpod |
| Local Storage | drift / sqflite |

---

## Status

Active development. Not yet publicly available.

---

## License

roger is source-available. The code is public for transparency and independent security audit only. You may read and review it. You may not use, modify, or redistribute it.

See [LICENSE](LICENSE.md) for the full terms.

---

*Built by one person, for real use.*
