import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/message.dart';
import '../../core/models/note_payload.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart' as t;
import '../../core/utils/time_format.dart';
import '../../core/widgets/primary_action_pill.dart';
import '../conversations/conversations_notifier.dart';
import '../conversations/conversations_state.dart';
import 'camera_notifier.dart';
import 'camera_state.dart';

/// Camera — 6a shell + 6b notes. Full-bleed surface with the header, control
/// rows, and thumbnail strip per the mockup. The surface swaps by mode:
/// stubbed feed (preview/recording), note composer, or note viewer. Live
/// camera feed, real capture, and video playback land in 6c; the reactions
/// sidebar is step 7; the video call pill is step 9.
class CameraScreen extends ConsumerWidget {
  final String conversationId;

  const CameraScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraProvider(conversationId));
    final notifier = ref.read(cameraProvider(conversationId).notifier);
    final summary = _summaryFor(ref);
    final isRecording = state.mode == CameraMode.recording;
    final isComposing = state.mode == CameraMode.noteComposer;
    final isNotePlayback = state.mode == CameraMode.playback &&
        state.activeMessage?.type == MessageType.note;

    return Scaffold(
      backgroundColor: charcoal,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // ── Main surface, by mode ──────────────────────────────
                  if (isComposing)
                    Positioned.fill(
                      child: _NoteComposer(
                        notifier: notifier,
                        isSending: state.isLoading,
                        error: state.error,
                      ),
                    )
                  else if (isNotePlayback)
                    Positioned.fill(
                      child: _NoteViewer(
                        payload: state.notePayloads[state.activeMessage!.id],
                      ),
                    )
                  else ...[
                    // Stubbed camera feed — the real preview arrives in 6c.
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
                              color: overlayScrim,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              formatElapsed(state.recordingElapsed),
                              style: t.pillLabel,
                            ),
                          ),
                        ),
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

                  // Header overlay — back (left), name + presence (center),
                  // flip (right). Always visible; back is contextual: it
                  // closes the composer/viewer before it leaves the screen.
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: _Header(
                      summary: summary,
                      notifier: notifier,
                      onBack: () {
                        if (isComposing) {
                          notifier.exitNoteComposer();
                        } else if (state.mode == CameraMode.playback) {
                          notifier.closePlayback();
                        } else {
                          context.go('/conversations');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Thumbnail strip — a separate row below the camera.
            _ThumbnailStrip(
              thumbnails: state.thumbnails,
              notePayloads: state.notePayloads,
              onTap: notifier.selectThumbnail,
            ),
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
  final VoidCallback onBack;

  const _Header({
    required this.summary,
    required this.notifier,
    required this.onBack,
  });

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
              onTap: onBack,
            ),
          ),

          // Flip — pinned right. Always visible regardless of state (§18).
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
        decoration: const BoxDecoration(
          color: overlayScrim,
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

/// A bare 26px action icon (the camera Row-2 style). [color] defaults to warm
/// white; the composer's color buttons pass the note's text color instead so
/// they stay legible on any canvas, and [isActive] backs the one whose picker
/// is open with a subtle scrim.
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool isActive;

  const _ActionIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = warmWhite,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}

// ── Note composer (6b) ──────────────────────────────────────────────────────

enum _NotePicker { background, text }

class _NoteComposer extends StatefulWidget {
  final CameraNotifier notifier;
  final bool isSending;
  final String? error;

  const _NoteComposer({
    required this.notifier,
    required this.isSending,
    this.error,
  });

  @override
  State<_NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends State<_NoteComposer> {
  final _controller = TextEditingController();
  // charcoal2, not charcoal: the default note must stay visible as a thumbnail
  // against the charcoal strip (Ashe, 7/25). Full palette still available.
  Color _background = charcoal2;
  Color _textColor = warmWhite;
  // Which palette is open — one at a time; a pick applies and closes it
  // (the same tap-to-expand, select-to-collapse feel as Settings rows).
  _NotePicker? _openPicker;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePicker(_NotePicker picker) {
    setState(() => _openPicker = _openPicker == picker ? null : picker);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('note-canvas'),
      decoration: BoxDecoration(color: _background),
      child: Column(
        children: [
          // The canvas — full keyboard, no formatting controls (spec §5).
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 12),
                child: TextField(
                  key: const Key('note-input'),
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  maxLength: 1000,
                  textAlign: TextAlign.center,
                  cursorColor: _textColor,
                  // One shared token with the viewer (t.noteText) so the note
                  // renders exactly as composed.
                  style: t.noteText.copyWith(color: _textColor),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Say it in writing',
                    hintStyle: t.noteText
                        .copyWith(color: _textColor.withValues(alpha: 0.4)),
                  ),
                  // Subtle counter, only as the 1000-char limit approaches.
                  buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) {
                    if (currentLength < 900) return null;
                    return Text(
                      '$currentLength / $maxLength',
                      key: const Key('note-counter'),
                      style: t.timestamp
                          .copyWith(color: _textColor.withValues(alpha: 0.6)),
                    );
                  },
                ),
              ),
            ),
          ),

          // A failed send surfaces here — never a silent nothing-happened
          // (the notifier keeps the composer open so the text isn't lost).
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                widget.error!,
                key: const Key('note-send-error'),
                style: t.errorText,
                textAlign: TextAlign.center,
              ),
            ),

          // The open palette (if any), then the control row: two camera-style
          // color buttons + Send.
          if (_openPicker == _NotePicker.background)
            _PaletteRow(
              key: const Key('note-bg-palette'),
              swatchKeyPrefix: 'note-bg-swatch',
              selected: _background,
              onSelect: (color) => setState(() {
                _background = color;
                _openPicker = null;
              }),
            )
          else if (_openPicker == _NotePicker.text)
            _PaletteRow(
              key: const Key('note-text-palette'),
              swatchKeyPrefix: 'note-text-swatch',
              selected: _textColor,
              onSelect: (color) => setState(() {
                _textColor = color;
                _openPicker = null;
              }),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
            child: Row(
              children: [
                // Icons ride the note's own text color so they stay legible on
                // any canvas the user picks (no contrast guardrails — §5).
                _ActionIcon(
                  key: const Key('note-bg-button'),
                  icon: Icons.format_color_fill,
                  color: _textColor,
                  isActive: _openPicker == _NotePicker.background,
                  onTap: () => _togglePicker(_NotePicker.background),
                ),
                _ActionIcon(
                  key: const Key('note-text-button'),
                  icon: Icons.text_fields,
                  color: _textColor,
                  isActive: _openPicker == _NotePicker.text,
                  onTap: () => _togglePicker(_NotePicker.text),
                ),
                const Spacer(),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => PrimaryActionPill(
                    key: const Key('note-send'),
                    label: 'Send',
                    enabled:
                        value.text.trim().isNotEmpty && !widget.isSending,
                    onTap: () => widget.notifier.sendNote(
                      text: _controller.text,
                      backgroundColor: _background.toARGB32(),
                      textColor: _textColor.toARGB32(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  final String swatchKeyPrefix;
  final Color selected;
  final ValueChanged<Color> onSelect;

  const _PaletteRow({
    super.key,
    required this.swatchKeyPrefix,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final color in notePalette)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      key: Key('$swatchKeyPrefix-${color.toARGB32()}'),
                      onTap: () => onSelect(color),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.toARGB32() == selected.toARGB32()
                                ? warmWhite
                                : Colors.black.withValues(alpha: 0.25),
                            width:
                                color.toARGB32() == selected.toARGB32() ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Note viewer (6b) ────────────────────────────────────────────────────────

class _NoteViewer extends StatelessWidget {
  final NotePayload? payload;

  const _NoteViewer({required this.payload});

  @override
  Widget build(BuildContext context) {
    final p = payload;
    if (p == null) {
      // Decryption failed — an explicit error state, never a silent blank.
      return Container(
        key: const Key('note-viewer-error'),
        decoration: const BoxDecoration(color: charcoal),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              "This note couldn't be opened on this device.",
              style: t.errorText,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Background and text exactly as composed (spec §5) — like a text story.
    return Container(
      key: const Key('note-viewer'),
      decoration: BoxDecoration(color: Color(p.backgroundColor)),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Text(
            p.text,
            textAlign: TextAlign.center,
            style: t.noteText.copyWith(color: Color(p.textColor)),
          ),
        ),
      ),
    );
  }
}

// ── Thumbnail strip ─────────────────────────────────────────────────────────

class _ThumbnailStrip extends StatelessWidget {
  final List<Message> thumbnails;
  final Map<String, NotePayload> notePayloads;
  final void Function(String messageId) onTap;

  const _ThumbnailStrip({
    required this.thumbnails,
    required this.notePayloads,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Below the camera as a separate strip; newest right (ascending order from
    // the notifier). Empty = no items, no placeholder.
    return Container(
      key: const Key('camera-thumbnails'),
      height: 76,
      color: charcoal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: thumbnails.isEmpty
          ? const SizedBox.shrink()
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: thumbnails.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final message = thumbnails[index];
                final payload = message.type == MessageType.note
                    ? notePayloads[message.id]
                    : null;
                return GestureDetector(
                  onTap: () => onTap(message.id),
                  child: Container(
                    key: const Key('camera-thumbnail-item'),
                    width: 52,
                    decoration: BoxDecoration(
                      color: payload != null
                          ? Color(payload.backgroundColor)
                          : charcoal2,
                      borderRadius: BorderRadius.circular(8),
                      // Hairline edge so a dark note (incl. deliberately
                      // charcoal ones) never disappears into the strip.
                      border: Border.all(
                        color: warmWhite.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Center(
                      child: payload != null
                          // A note reads as its composed colors — "Aa" in the
                          // note's own text color.
                          ? Text(
                              'Aa',
                              style: t.noteThumbLabel
                                  .copyWith(color: Color(payload.textColor)),
                            )
                          : Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: warmWhite.withValues(alpha: 0.4),
                            ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
