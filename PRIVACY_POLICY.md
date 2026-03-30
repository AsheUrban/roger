# Privacy Policy

**roger**
Last updated: March 2026

---

## Overview

roger is designed so that we cannot read your messages. This is not a policy choice — it is an architectural one. All message content is encrypted on your device before it leaves it. We do not hold encryption keys. We cannot access your videos, photos, notes, or live calls.

This policy explains what information we do collect, why, and how it is handled.

---

## Information We Collect

### Information You Provide

**Account information.** When you create an account, we collect your phone number and display name. Your display name is visible to people you message, your phone number is how people will find you.

**Recovery email.** You may optionally provide an email address for account recovery. This is not required and is never used for marketing.

**Messages.** Videos, photos, notes, and live call recordings are encrypted on your device before transmission. We store and deliver encrypted ciphertext only. We cannot decrypt or access your message content at any point.

### Information Collected Automatically

**Device tokens.** We collect push notification tokens (APNs for iOS, FCM for Android) to deliver message notifications. Notification payloads contain no message content — only the metadata required to display a notification (sender name, message type).

**Presence signals.** When you are active in the app, a presence signal is sent via Supabase Realtime so other users in your conversations can see you are online. This signal is not stored.

**Crash and error logs.** We may collect anonymized crash reports to diagnose and fix technical issues. These logs do not contain message content.

### Contact Discovery

When you grant contacts permission, roger hashes your contacts' phone numbers on your device using a one-way cryptographic function. Only the hashed values are sent to our server to check which of your contacts are on roger. Raw phone numbers never leave your device. We do not store your contact list.

---

## How We Use Information

| Data | Purpose |
|---|---|
| Phone number | Authentication and contact discovery |
| Display name | Shown to conversation members |
| Recovery email | Account recovery only, if provided |
| Encrypted message content | Delivery to recipients via Cloudflare R2 |
| Device tokens | Push notification delivery |
| Hashed contact numbers | Contact discovery — checked against registered users, not stored |

We do not use your information for advertising. We do not sell your data. We do not share your information with third parties except as described in this policy.

---

## Message Storage and Retention

Messages are stored temporarily on Cloudflare R2 until all conversation members have downloaded them, at which point they are purged. A 60-day hard expiry applies as a backstop for undownloaded messages.

On your device, messages are governed by a rolling window you control (10–500 messages, default 100). When a message rolls off the window, it is deleted from your device and purged from R2.

We do not maintain a permanent archive of your messages. Nothing persists on our servers beyond what is needed for delivery.

---

## Encryption

All video, photo, and note content is encrypted on your device before upload using AES-256 with keys derived from per-conversation key pairs. Private keys are generated on your device and never transmitted to our servers in plaintext. Keys are backed up encrypted via iCloud Keychain (iOS) or Android Keystore with Google Play backup (Android).

Live video calls are end-to-end encrypted natively via LiveKit.

Closed captions are generated entirely on-device using Picovoice Cheetah. Audio is never transmitted for transcription.

Because encryption happens on-device and we do not hold keys, we cannot comply with requests to decrypt or produce the content of your messages. We do not have the ability to do so.

---

## Third-Party Services

roger uses the following third-party infrastructure:

| Service | Purpose | Privacy Policy |
|---|---|---|
| Supabase | Authentication, database, presence | supabase.com/privacy |
| Cloudflare R2 | Encrypted message delivery | cloudflare.com/privacypolicy |
| LiveKit | Live video infrastructure | livekit.io/privacy |
| Picovoice | On-device speech recognition | picovoice.ai/privacy |
| Apple APNs | iOS push notifications | apple.com/legal/privacy |
| Google FCM | Android push notifications | policies.google.com/privacy |

---

## Data Sharing

We do not sell, rent, or trade your personal information. We may share information only in the following circumstances:

- **Legal compliance.** If required by law or valid legal process. Because we cannot decrypt your messages, any such request would be limited to account metadata (phone number, display name, account creation date).
- **Safety.** If we have a good-faith belief that disclosure is necessary to prevent imminent physical harm to a specific person — for example, a credible and specific threat of violence. Any disclosure in this circumstance would be limited to account metadata (phone number, display name, account creation date). We cannot provide message content because we cannot decrypt it.
- **Business transfer.** In the event of a merger or acquisition, your information would transfer subject to the same commitments in this policy.

---

## Your Rights

Depending on your location, you may have rights regarding your personal information, including the right to access, correct, or delete it.

**To delete your account:** Go to Settings → Delete account & all data. This removes your account record, purges R2 for any messages not yet downloaded by all recipients, and deletes all local data on your device. Messages already downloaded to other people's devices remain until they naturally roll off the rolling window — roger has no mechanism to reach into other people's devices to remove them on account deletion.

Note: the per-message delete feature (available on your own messages while your account is active) does propagate to all devices immediately via real-time sync. Account deletion and per-message deletion are different operations.

**To request information or exercise other rights:** Contact us at the address below.

---

## Age Requirement

roger is intended for users 18 and older. We do not knowingly collect personal information from anyone under 18. By creating an account, you confirm you are at least 18 years old. If we become aware that a user is under 18, we will delete their account and associated data. If you believe someone under 18 has created an account, please contact us.

---

## Changes to This Policy

We may update this policy from time to time. If changes are material, we will notify you within the app. Continued use of roger after changes take effect constitutes acceptance of the updated policy.

---

## Contact

For privacy questions, requests, or security disclosures:

**roger**
privacy@roger.app

---

*roger is built so that privacy is the default, not the exception.*
