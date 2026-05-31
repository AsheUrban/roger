# roger

Async video messaging for people you want to talk "face-to-face" with.

---

## Contents

- [What it is](#what-it-is)
- [Privacy](#privacy)
- [Stack](#stack)
- [Status](#status)
- [License](#license)

---

Roger is an async video messaging app for staying connected with close friends and family through short videos, photos, and notes. 

The name is a nod to the radio acknowledgment — *roger that*, message received.

---

## Branches

| Branch | Purpose |
|--------|---------|
| `main` | Stable, reviewed code only |
| `dev` | Active development — all work lands here first |

## Status

Active development. Not yet publicly available.

---

## What it is

- **Async video messaging.** Start a back and forth video chat with one person or up to five. They watch it when they get to it, and can record a video response in reply.
- **Photos with optional voice overlay.** Send a photo with a voice note attached.
- **Notes.** Full-screen text with a color background.
- **Video calls.** If you and someone else happen to be in the app at the same time, you can jump to a video call. It auto-records and saves to the thread so the conversation has no gaps.
- **Emoji and video reactions.** React to individual messages with emojis or a video reaction.
- **Contact-based.** Not in your contacts? Then you won't find them on roger and vice versa. This app does not feature social discovery.

---

## Privacy

End-to-end encryption is not a feature, it's the architecture.

All content is encrypted on-device before it leaves the sender and decryption happens on the recipient's device after download.

Roger uses a global rolling message window (100 messages by default, adjustable). Nothing accumulates indefinitely. When a message rolls off, it is deleted from local storage. Remote storage only holds encrypted content until all parties have received it.

Video calls are end-to-end encrypted natively.

---

## Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Database & Auth | Supabase |
| Video/Photo Storage | Cloudflare R2 |
| Live Video | LiveKit (WebRTC, E2EE native) |
| On-Device Compression | `video_compress` |
| Closed Captions | Picovoice Cheetah (on-device) |
| Push Notifications | FCM + APNs via Supabase |
| Content Encryption | `cryptography` (AES-256 + ECDH) |
| Key Storage | iCloud Keychain (iOS) · Android Keystore (Android) |
| State Management | Riverpod 3.x |
| Navigation | `go_router` |
| Local Storage | drift (SQLite, encrypted at rest via sqlite3mc) |
| Deep Linking | Custom URL scheme → App Links / Universal Links |

---

## License

roger is source-available. The code is public for transparency and independent security audit only. You may read and review it. You may not use, modify, or redistribute it.

See [LICENSE](LICENSE.md) for the full terms.

---

*Built by one person, for real use.*
