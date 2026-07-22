import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart' as t;
import '../../core/utils/time_format.dart';
import '../conversations/conversations_notifier.dart';
import '../conversations/conversations_state.dart';
import 'camera_notifier.dart';
import 'camera_state.dart';

/// Camera 6a — the shell. Full-bleed (stubbed) feed with the header, control
/// rows, and thumbnail strip overlaid/arranged per the mockup. The live camera
/// feed, real capture, note composer, sidebar, and inline playback land in
/// later slices (6b/6c/step 7).
class CameraScreen extends ConsumerWidget {
  final String conversationId;

  const CameraScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraProvider(conversationId));
    final notifier = ref.read(cameraProvider(conversationId).notifier);
    final summary = _summaryFor(ref);
    final isRecording = state.mode == CameraMode.recording;

    return Scaffold(
      backgroundColor: charcoal,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Stubbed camera feed — full-bleed background the overlays
                  // sit on top of. The real preview arrives in 6c.
                  const Positioned.fill(child: _FeedStub()),

                  // Recording timer — just below the header (which stays
                  // visible mid-record), so it never sits over the name.
                  if (isRecording)
                    Positioned(
                      top: 56,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          key: const Key('camera-timer'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatElapsed(state.recordingElapsed),
                            style: t.pillLabel,
                          ),
                        ),
                      ),
                    ),

                  // Header overlay — back (left), name + presence (center),
                  // flip (right). Back and flip are twin circular controls.
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: _Header(summary: summary, notifier: notifier),
                  ),

                  // Controls overlay — bottom.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: _Controls(
                      isRecording: isRecording,
                      notifier: notifier,
                    ),
                  ),
                ],
              ),
            ),

            // Thumbnail strip — a separate row below the camera.
            _ThumbnailStrip(count: state.thumbnails.length),
          ],
        ),
      ),
    );
  }

  ConversationSummary? _summaryFor(WidgetRef ref) {
    // Name + presence resolve from the conversation summary (§10) — the single
    // source of truth, shared with the Conversations screen.
    final conversations = ref.watch(conversationsProvider).conversations;
    for (final s in conversations) {
      if (s.conversation.id == conversationId) return s;
    }
    return null;
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _FeedStub extends StatelessWidget {
  const _FeedStub();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('camera-feed'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2820), Color(0xFF1A1A14)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          size: 40,
          color: warmWhite.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ConversationSummary? summary;
  final CameraNotifier notifier;

  const _Header({required this.summary, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center — name + presence, always truly centered.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  summary?.displayName ?? '',
                  style: t.rowName,
                  overflow: TextOverflow.ellipsis,
                ),
                if (summary != null) _presenceLine(summary!),
              ],
            ),
          ),

          // Back — pinned left.
          Align(
            alignment: Alignment.centerLeft,
            child: _CircleButton(
              key: const Key('camera-back'),
              icon: Icons.arrow_back,
              onTap: () => context.go('/conversations'),
            ),
          ),

          // Flip — pinned right.
          Align(
            alignment: Alignment.centerRight,
            child: _CircleButton(
              key: const Key('camera-flip'),
              icon: Icons.cameraswitch_outlined,
              onTap: notifier.flipCamera,
            ),
          ),
        ],
      ),
    );
  }

  Widget _presenceLine(ConversationSummary s) {
    if (s.isOtherUserActive) {
      return const Text('● active now', style: t.activeNow);
    }
    // Fall back to the last message time when there's no last-active, matching
    // the Conversations list row so both screens render the same conversation
    // consistently.
    final activeAt = s.otherUserLastActiveAt ?? s.lastMessageAt;
    if (activeAt == null) return const SizedBox.shrink();
    return Text(formatLastActive(activeAt), style: t.timestamp);
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: warmWhite, size: 18),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final bool isRecording;
  final CameraNotifier notifier;

  const _Controls({required this.isRecording, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1 — record button, centered.
        _RecordButton(
          isRecording: isRecording,
          onTap: isRecording ? notifier.stopRecording : notifier.startRecording,
        ),

        // Row 2 — photo / note / settings. Hidden entirely while recording.
        if (!isRecording) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionIcon(
                key: const Key('camera-photo'),
                icon: Icons.photo_outlined,
                onTap: notifier.takePhoto,
              ),
              _ActionIcon(
                key: const Key('camera-note'),
                icon: Icons.edit_outlined,
                onTap: notifier.enterNoteComposer,
              ),
              _ActionIcon(
                key: const Key('camera-settings'),
                icon: Icons.settings_outlined,
                onTap: () {}, // per-conversation menu — step 8
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const _RecordButton({required this.isRecording, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('camera-record'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isRecording ? salmon : warmWhite,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: isRecording
              // Recording: salmon circle + warm-white center indicator.
              ? Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: warmWhite,
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              // Idle: warm-white circle + charcoal video-camera icon.
              : const Icon(Icons.videocam, color: charcoal, size: 30),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIcon({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(icon, color: warmWhite, size: 26),
      ),
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  final int count;

  const _ThumbnailStrip({required this.count});

  @override
  Widget build(BuildContext context) {
    // Below the camera as a separate strip. Empty = no items, no placeholder.
    return Container(
      key: const Key('camera-thumbnails'),
      height: 76,
      color: charcoal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: count == 0
          ? const SizedBox.shrink()
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, _) => Container(
                key: const Key('camera-thumbnail-item'),
                width: 52,
                decoration: BoxDecoration(
                  color: charcoal2,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }
}
