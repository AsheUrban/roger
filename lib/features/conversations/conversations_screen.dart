import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/user.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/time_format.dart';
import 'conversations_notifier.dart';
import 'conversations_state.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: charcoal,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'roger',
                style: GoogleFonts.youngSerif(
                  fontSize: 28,
                  color: warmWhite,
                ),
              ),
            ),

            // Body
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: warmWhite,
                        ),
                      ),
                    )
                  : state.conversations.isEmpty
                      ? Center(
                          child: Text(
                            'No conversations yet.\nGo to Search to start one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: warmWhite.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: state.conversations.length,
                          separatorBuilder: (_, _) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(
                              height: 0.5,
                              thickness: 0.5,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final summary = state.conversations[index];
                            return _ConversationRow(
                              summary: summary,
                              onTap: () => context.go(
                                '/camera/${summary.conversation.id}',
                              ),
                            );
                          },
                        ),
            ),

            // Error banner
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.error!,
                  style: const TextStyle(color: errorColor, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final ConversationSummary summary;
  final VoidCallback onTap;

  const _ConversationRow({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isGroup = summary.members.length > 1;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // Avatar area
            isGroup
                ? _GroupAvatar(
                    members: summary.members,
                    contactNames: summary.memberContactNames,
                  )
                : _SingleAvatar(
                    member: summary.members.isNotEmpty
                        ? summary.members.first
                        : null,
                    contactName: summary.memberContactNames.isNotEmpty
                        ? summary.memberContactNames.first
                        : '?',
                    isActive: summary.isOtherUserActive,
                  ),

            const SizedBox(width: 14),

            // Name + last-active line
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.displayName,
                          style: GoogleFonts.syne(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: warmWhite,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (summary.lastMessageAt != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            formatShortAge(summary.lastMessageAt!),
                            style: TextStyle(
                              fontSize: 12,
                              color: warmWhite.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  _lastActiveText(summary),
                ],
              ),
            ),

            // Unread dot
            if (summary.hasUnread)
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: warmWhite,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Bottom line: "● active now" (olive) | "active Xm ago" | nothing
  // Falls back to lastMessageAt when otherUserLastActiveAt is absent.
  Widget _lastActiveText(ConversationSummary s) {
    if (s.isOtherUserActive) {
      return Text(
        '● active now',
        style: TextStyle(
          fontSize: 12,
          color: oliveLight,
        ),
      );
    }

    final activeAt = s.otherUserLastActiveAt ?? s.lastMessageAt;
    if (activeAt == null) return const SizedBox.shrink();

    return Text(
      formatLastActive(activeAt),
      style: TextStyle(
        fontSize: 12,
        color: warmWhite.withValues(alpha: 0.4),
      ),
    );
  }
}

class _SingleAvatar extends StatelessWidget {
  final User? member;
  final String contactName;
  final bool isActive;

  const _SingleAvatar({
    this.member,
    required this.contactName,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColorName = member?.avatarColor ?? 'Charcoal';
    final colors = avatarColorMap[avatarColorName] ?? (charcoal2, warmWhite);
    final initial =
        contactName.isNotEmpty ? contactName[0].toUpperCase() : '?';

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.$1,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: colors.$2,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (isActive)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: oliveLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: charcoal, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  final List<User> members;
  final List<String> contactNames;

  const _GroupAvatar({required this.members, required this.contactNames});

  @override
  Widget build(BuildContext context) {
    final capped = members.take(3).toList();

    return SizedBox(
      width: 52,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < capped.length; i++)
            Positioned(
              left: i * 14.0,
              top: i % 2 == 0 ? 0.0 : 8.0,
              child: _MiniAvatar(
                avatarColor: capped[i].avatarColor,
                contactName: i < contactNames.length ? contactNames[i] : '?',
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String avatarColor;
  final String contactName;

  const _MiniAvatar({required this.avatarColor, required this.contactName});

  @override
  Widget build(BuildContext context) {
    final colors = avatarColorMap[avatarColor] ?? (charcoal2, warmWhite);
    final initial =
        contactName.isNotEmpty ? contactName[0].toUpperCase() : '?';

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: colors.$1,
        shape: BoxShape.circle,
        border: Border.all(color: charcoal, width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: colors.$2,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
