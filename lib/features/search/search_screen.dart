import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/colors.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
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
                  Text(
                    'Find people',
                    style: GoogleFonts.syne(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: warmWhite,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Search bar — always looks the same.
                  // Without permission: tap triggers permission request.
                  // With permission: normal text input.
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
                                    onChanged: notifier.search,
                                    style: const TextStyle(
                                      color: warmWhite,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search contacts',
                                      hintStyle: TextStyle(
                                        color: warmWhite.withValues(alpha: 0.3),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  )
                                : IgnorePointer(
                                    child: Text(
                                      'Search contacts',
                                      style: TextStyle(
                                        color: warmWhite.withValues(alpha: 0.3),
                                        fontSize: 14,
                                      ),
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
                      ? _EmptyState(
                          query: state.query,
                        )
                      : ListView.separated(
                          itemCount: state.results.length,
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
                            final result = state.results[index];
                            return _SearchResultRow(
                              result: result,
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

class _SearchResultRow extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onChat;
  final VoidCallback onInvite;

  const _SearchResultRow({
    required this.result,
    required this.onChat,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    // Name Resolution: contact name only — '?' if unknown
    final displayName =
        result.contactName.isNotEmpty ? result.contactName : '?';
    final initials = displayName != '?' ? displayName[0].toUpperCase() : '?';

    final avatarColorName = result.rogerUser?.avatarColor ?? 'Charcoal';
    final colors = avatarColorMap[avatarColorName] ?? (charcoal2, warmWhite);

    return Opacity(
      opacity: result.isOnRoger ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
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
                  style: TextStyle(
                    color: colors.$2,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
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
                    style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: warmWhite,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.isOnRoger && result.rogerUser?.lastActiveAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatLastActive(result.rogerUser!.lastActiveAt!),
                        style: TextStyle(
                          fontSize: 12,
                          color: warmWhite.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Action: Chat pill / Invite / Pending
            if (result.isOnRoger)
              GestureDetector(
                onTap: onChat,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: warmWhite, width: 1.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Chat',
                    style: GoogleFonts.syne(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: warmWhite,
                    ),
                  ),
                ),
              )
            else if (result.hasPendingInvite)
              Text(
                'Pending',
                style: TextStyle(
                  fontSize: 12,
                  color: warmWhite.withValues(alpha: 0.4),
                ),
              )
            else
              GestureDetector(
                onTap: onInvite,
                child: Text(
                  'Invite \u2192',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    color: warmWhite.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
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
      child: Text(
        text,
        style: TextStyle(
          color: warmWhite.withValues(alpha: 0.4),
          fontSize: 14,
        ),
      ),
    );
  }
}
