import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart' as t;
import '../../core/utils/time_format.dart';
import 'search_notifier.dart';
import 'search_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);

    return Scaffold(
      backgroundColor: charcoal,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row — changes in group mode
                  if (state.isGroupMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('New group', style: t.screenTitle),
                        GestureDetector(
                          onTap: notifier.exitGroupMode,
                          child: Text('Cancel', style: t.bodySubdued),
                        ),
                      ],
                    )
                  else
                    Text('Find people', style: t.screenTitle),
                  const SizedBox(height: 14),
                  // Search bar
                  GestureDetector(
                    onTap: !state.hasContactsPermission
                        ? () => notifier.requestContactsPermission()
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: charcoal2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 15,
                            color: warmWhite.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: state.hasContactsPermission
                                ? TextField(
                                    controller: _searchController,
                                    focusNode: _focusNode,
                                    onChanged: notifier.search,
                                    style: const TextStyle(
                                      color: warmWhite,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search contacts',
                                      hintStyle: t.searchHint,
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  )
                                : IgnorePointer(
                                    child: Text(
                                      'Search contacts',
                                      style: t.searchHint,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // "New group" option — visible when search bar is focused,
            // query is empty, not already in group mode
            if (_isFocused &&
                state.query.isEmpty &&
                !state.isGroupMode &&
                state.hasContactsPermission)
              GestureDetector(
                onTap: () {
                  _focusNode.unfocus();
                  notifier.enterGroupMode();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: charcoal2,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.group_add_outlined,
                            color: warmWhite,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text('New group', style: t.rowName),
                    ],
                  ),
                ),
              ),

            // Results list
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
                  : state.results.isEmpty
                      ? _EmptyState(query: state.query)
                      : ListView.separated(
                          itemCount: state.results.length,
                          separatorBuilder: (_, __) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: Divider(
                              height: 0.5,
                              thickness: 0.5,
                              color: t.listDividerColor,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final result = state.results[index];
                            return _SearchResultRow(
                              result: result,
                              isGroupMode: state.isGroupMode,
                              isSelected: result.rogerUser != null &&
                                  state.selectedUserIds
                                      .contains(result.rogerUser!.id),
                              onChat: () async {
                                final convId = await notifier
                                    .startChat(result.rogerUser!.id);
                                if (context.mounted) {
                                  context.go('/camera/$convId');
                                }
                              },
                              onInvite: () {
                                notifier.sendInvite(result.phoneNumber);
                              },
                              onToggleSelect: result.rogerUser != null
                                  ? () => notifier.toggleContactSelection(
                                      result.rogerUser!.id)
                                  : null,
                              onLongPress: result.rogerUser != null &&
                                      !state.isGroupMode
                                  ? () => notifier.enterGroupModeWithContact(
                                      result.rogerUser!.id)
                                  : null,
                            );
                          },
                        ),
            ),

            // Error
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.error!,
                  style: t.errorText,
                  textAlign: TextAlign.center,
                ),
              ),

            // Group mode bottom bar
            if (state.isGroupMode)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: charcoal2,
                  border: Border(
                    top: BorderSide(color: t.listDividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${state.selectedUserIds.length} of 4 selected',
                      style: t.bodyDimmed,
                    ),
                    GestureDetector(
                      onTap: state.selectedUserIds.length >= 2
                          ? () async {
                              final convId =
                                  await notifier.createGroupConversation();
                              if (context.mounted) {
                                context.go('/camera/$convId');
                              }
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: state.selectedUserIds.length >= 2
                              ? warmWhite
                              : warmWhite.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Create',
                          style: TextStyle(
                            color: state.selectedUserIds.length >= 2
                                ? charcoal
                                : warmWhite.withValues(alpha: 0.3),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  final SearchResult result;
  final bool isGroupMode;
  final bool isSelected;
  final VoidCallback onChat;
  final VoidCallback onInvite;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const _SearchResultRow({
    required this.result,
    required this.isGroupMode,
    required this.isSelected,
    required this.onChat,
    required this.onInvite,
    this.onToggleSelect,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
        result.contactName.isNotEmpty ? result.contactName : '?';
    final initials = displayName != '?' ? displayName[0].toUpperCase() : '?';

    final avatarColorName = result.rogerUser?.avatarColor ?? 'Charcoal';
    final colors = avatarColorMap[avatarColorName] ?? (charcoal2, warmWhite);

    return GestureDetector(
      onTap: isGroupMode && onToggleSelect != null ? onToggleSelect : null,
      onLongPress: onLongPress,
      child: Opacity(
        opacity: isGroupMode && !result.isOnRoger
            ? 0.2
            : (result.isOnRoger ? 1.0 : 0.45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Checkbox in group mode
              if (isGroupMode) ...[
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? warmWhite
                      : warmWhite.withValues(alpha: 0.3),
                  size: 22,
                ),
                const SizedBox(width: 12),
              ],

              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.$1,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: t.avatarInitialLarge.copyWith(color: colors.$2),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name + last active
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: t.rowName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.isOnRoger &&
                        result.rogerUser?.lastActiveAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          formatLastActive(result.rogerUser!.lastActiveAt!),
                          style: t.timestamp,
                        ),
                      ),
                  ],
                ),
              ),

              // Action area — different in group mode vs normal
              if (!isGroupMode) ...[
                if (result.isOnRoger)
                  GestureDetector(
                    onTap: onChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: warmWhite, width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Chat', style: t.pillLabel),
                    ),
                  )
                else if (result.hasPendingInvite)
                  Text('Pending', style: t.pendingLabel)
                else
                  GestureDetector(
                    onTap: onInvite,
                    child: Text('Invite \u2192', style: t.inviteArrow),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;

  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    final text = query.isNotEmpty
        ? 'No results for "$query"'
        : 'Your contacts will appear here.';

    return Center(
      child: Text(text, style: t.placeholderText),
    );
  }
}
