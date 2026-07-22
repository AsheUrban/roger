import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart' as t;
import '../../core/utils/time_format.dart';
import '../search/search_notifier.dart';
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
            // Header — wordmark, plus a select toggle for bulk-leave. In
            // selection mode it becomes "N selected" + Cancel.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.isSelectionMode
                        ? '${state.selectedIds.length} selected'
                        : 'roger',
                    style: state.isSelectionMode
                        ? t.screenTitle
                        : t.wordmarkHeader,
                  ),
                  if (state.isSelectionMode)
                    GestureDetector(
                      onTap: ref
                          .read(conversationsProvider.notifier)
                          .exitSelectionMode,
                      child: Text('Cancel', style: t.bodySubdued),
                    )
                  else if (state.conversations.isNotEmpty)
                    IconButton(
                      key: const Key('select-mode-toggle'),
                      onPressed: ref
                          .read(conversationsProvider.notifier)
                          .enterSelectionMode,
                      icon: Icon(Icons.checklist,
                          color: warmWhite.withValues(alpha: 0.6), size: 22),
                    ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: t.loadingSpinner,
                    )
                  : state.conversations.isEmpty
                      ? Center(
                          child: Text(
                            'No conversations yet.\nGo to Search to start one.',
                            textAlign: TextAlign.center,
                            style: t.placeholderText,
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
                              color: t.listDividerColor,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final summary = state.conversations[index];
                            final id = summary.conversation.id;
                            final notifier =
                                ref.read(conversationsProvider.notifier);
                            return _ConversationRow(
                              summary: summary,
                              selectionMode: state.isSelectionMode,
                              selected: state.selectedIds.contains(id),
                              onTap: state.isSelectionMode
                                  ? () => notifier.toggleSelected(id)
                                  : () => context.go('/camera/$id'),
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
                  style: t.errorText,
                  textAlign: TextAlign.center,
                ),
              ),

            // Bulk-leave bar (selection mode).
            if (state.isSelectionMode)
              _LeaveSelectedBar(
                count: state.selectedIds.length,
                onLeave: () => _confirmLeave(context, ref, state.selectedIds.length),
              ),
          ],
        ),
      ),
      floatingActionButton: state.isSelectionMode
          ? null
          : FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: charcoal2,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Icon(Icons.chat_bubble_outline,
                          color: warmWhite.withValues(alpha: 0.6), size: 22),
                      title: Text('New chat', style: t.rowName),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/search');
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.group_add_outlined,
                          color: warmWhite.withValues(alpha: 0.6), size: 22),
                      title: Text('New group', style: t.rowName),
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(searchProvider.notifier).enterGroupMode();
                        context.go('/search');
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        backgroundColor: charcoal2,
        child: const Icon(Icons.add, color: warmWhite),
      ),
    );
  }
}

/// Confirmation before a bulk leave (spec §9 requires a confirm step), then
/// leaves the selected conversations.
Future<void> _confirmLeave(BuildContext context, WidgetRef ref, int count) async {
  final title =
      count == 1 ? 'Leave this conversation?' : 'Leave $count conversations?';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: charcoal2,
      title: Text(title, style: t.rowName),
      content: Text(
        // Spec §9 leave copy.
        "You'll lose access and won't receive new messages. To rejoin, "
        'someone would need to add you to a new group.',
        style: t.bodySubdued,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancel', style: t.bodySubdued),
        ),
        TextButton(
          key: const Key('confirm-leave'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Leave', style: t.bodyText.copyWith(color: destructive)),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(conversationsProvider.notifier).leaveSelected();
  }
}

class _LeaveSelectedBar extends StatelessWidget {
  final int count;
  final VoidCallback onLeave;

  const _LeaveSelectedBar({required this.count, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('leave-selected-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: charcoal2,
        border: Border(top: BorderSide(color: t.listDividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$count selected', style: t.bodyDimmed),
          TextButton(
            key: const Key('leave-selected-button'),
            onPressed: count > 0 ? onLeave : null,
            child: Text(
              'Leave',
              style: t.rowName.copyWith(
                color: count > 0 ? destructive : destructive.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final ConversationSummary summary;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;

  const _ConversationRow({
    required this.summary,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    // Deleted members aren't in `members`; count both toward group-vs-1:1.
    final otherSlots = summary.members.length + summary.deletedMemberCount;
    final isGroup = otherSlots > 1;
    final isDeleted1to1 =
        !isGroup && summary.members.isEmpty && summary.deletedMemberCount > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? warmWhite : warmWhite.withValues(alpha: 0.3),
                size: 22,
              ),
              const SizedBox(width: 12),
            ],
            // Avatar area
            if (isGroup)
              _GroupAvatar(
                members: summary.members,
                contactNames: summary.memberContactNames,
                deletedMemberCount: summary.deletedMemberCount,
              )
            else if (isDeleted1to1)
              const _DeletedAvatar(size: 46)
            else
              _SingleAvatar(
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
                          style: t.rowName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (summary.lastMessageAt != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            formatShortAge(summary.lastMessageAt!),
                            style: t.timestamp,
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

  Widget _lastActiveText(ConversationSummary s) {
    if (s.isOtherUserActive) {
      return const Text('● active now', style: t.activeNow);
    }

    final activeAt = s.otherUserLastActiveAt ?? s.lastMessageAt;
    if (activeAt == null) return const SizedBox.shrink();

    return Text(formatLastActive(activeAt), style: t.timestamp);
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
                style: t.avatarInitialLarge.copyWith(color: colors.$2),
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
  final int deletedMemberCount;

  const _GroupAvatar({
    required this.members,
    required this.contactNames,
    this.deletedMemberCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Cluster of up to 3 faces: active members first, then a deleted-user
    // treatment (spec §4) for each deleted slot. Order in the cluster carries
    // no meaning, so a count is enough to place the deleted faces.
    final minis = <Widget>[];
    for (var i = 0; i < members.length && minis.length < 3; i++) {
      minis.add(_MiniAvatar(
        avatarColor: members[i].avatarColor,
        contactName: i < contactNames.length ? contactNames[i] : '?',
      ));
    }
    for (var i = 0; i < deletedMemberCount && minis.length < 3; i++) {
      minis.add(const _DeletedAvatar(size: 28, bordered: true));
    }

    return SizedBox(
      width: 52,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < minis.length; i++)
            Positioned(
              left: i * 14.0,
              top: i % 2 == 0 ? 0.0 : 8.0,
              child: minis[i],
            ),
        ],
      ),
    );
  }
}

class _DeletedAvatar extends StatelessWidget {
  final double size;
  final bool bordered;

  const _DeletedAvatar({required this.size, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    // Spec §4 Deleted-User Avatar: a solid warm-white (#FAFAF5) circle with a
    // charcoal (#1E1D18) dash — no initial, no personal color. A deliberate
    // "this changed" signal. The border matches _MiniAvatar so a deleted face
    // reads as part of a group cluster.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: warmWhite,
        shape: BoxShape.circle,
        border: bordered ? Border.all(color: charcoal, width: 1.5) : null,
      ),
      child: Center(
        child: Icon(Icons.remove, color: charcoal, size: size * 0.5),
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
          style: t.avatarInitialMini.copyWith(color: colors.$2),
        ),
      ),
    );
  }
}
