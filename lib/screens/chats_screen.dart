// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/screens/coversation_screen.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:devlink/utility/time_helper.dart';
import 'package:devlink/widgets/shimmers.dart';
import 'package:devlink/widgets/user_picker_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatsScreen extends StatefulWidget {
  final bool isSearchActive;
  final String searchQuery;

  const ChatsScreen({
    super.key,
    required this.isSearchActive,
    required this.searchQuery,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String get _searchQuery => widget.searchQuery.toLowerCase().trim();
  bool get _isSearchActive => widget.isSearchActive;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedConversations =
      const [];

  final Map<String, DocumentReference<Map<String, dynamic>>>
  _selectedConversations = {};

  bool get _hasChatSelection => _selectedConversations.isNotEmpty;

  void _toggleConversationSelection(
    String id,
    DocumentReference<Map<String, dynamic>> ref,
  ) {
    setState(() {
      if (_selectedConversations.containsKey(id)) {
        _selectedConversations.remove(id);
      } else {
        _selectedConversations[id] = ref;
      }
    });
  }

  void _clearChatSelection() {
    setState(() => _selectedConversations.clear());
  }

  Future<void> _handleDeleteSelectedChats(String currentUserId) async {
    if (_selectedConversations.isEmpty) return;

    final count = _selectedConversations.length;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(12),
          ),
          title: Text(count == 1 ? 'Delete chat?' : 'Delete $count chats?'),
          content: const Text(
            'This will delete the selected conversation(s) for you only and cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('delete'),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (result != 'delete') return;

    try {
      for (final ref in _selectedConversations.values) {
        await ref.update({
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
          'unreadCounts.$currentUserId': 0,
        });
      }
    } catch (_) {
      // Ignore errors; stream will refresh the list
    }

    if (!mounted) return;
    _clearChatSelection();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Center(child: Text('Sign in to view chats'));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('participants', arrayContains: currentUserId)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          // Avoid shimmer flicker during selection by using cached docs
          List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
          if (snap.connectionState == ConnectionState.waiting &&
              _cachedConversations.isNotEmpty) {
            docs = _cachedConversations;
          } else {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerChatList(count: 8);
            }
            docs = snap.data?.docs ?? [];
            _cachedConversations = docs;
          }

          // Filter out conversations not visible to current user
          final visibleDocs = docs.where((doc) {
            final data = doc.data();
            final participants =
                (data['participants'] as List<dynamic>? ?? []).cast<String>();
            if (!participants.contains(currentUserId)) return false;
            final deletedFor =
                (data['deletedFor'] as List<dynamic>? ?? const <dynamic>[])
                    .cast<String>();
            if (deletedFor.contains(currentUserId)) return false;
            return true;
          }).toList();

          if (visibleDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FluentSystemIcons.ic_fluent_chat_regular,
                    size: 50,

                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text('No chats yet', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              ListView.separated(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: visibleDocs.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 64,
                  color: theme.dividerColor.withOpacity(0.3),
                ),
                itemBuilder: (context, index) {
                  final doc = visibleDocs[index];
                  final data = doc.data();
                  final participants =
                      (data['participants'] as List<dynamic>? ?? [])
                          .cast<String>();
                  final peerId = participants.firstWhere(
                    (id) => id != currentUserId,
                    orElse: () => currentUserId,
                  );

                  final lastMessage =
                      (data['lastMessageText'] as String?) ?? '';
                  final lastMessageAt = data['lastMessageAt'] as Timestamp?;
                  final updatedAt = data['updatedAt'] as Timestamp?;
                  final lastSenderId = data['lastSenderId'] as String?;
                  final isLastMessageFromMe = lastSenderId == currentUserId;

                  final unreadCounts =
                      (data['unreadCounts'] as Map<String, dynamic>? ??
                      const {});
                  final unreadForCurrent =
                      (unreadCounts[currentUserId] as int?) ?? 0;

                  final isSelected = _selectedConversations.containsKey(doc.id);
                  final timestamp = lastMessageAt ?? updatedAt;

                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(peerId)
                        .snapshots(),
                    builder: (context, userSnap) {
                      final u = userSnap.data?.data() ?? {};
                      final name =
                          (u['name'] as String?) ??
                          (u['displayName'] as String?) ??
                          'User';
                      final photo =
                          (u['photoUrl'] as String?) ??
                          (u['avatar'] as String?);
                      final isDeveloper = (u['isDeveloper'] as bool?) ?? false;

                      final q = _searchQuery;
                      if (_isSearchActive && q.isNotEmpty) {
                        final nameLower = name.toLowerCase();
                        final lastLower = lastMessage.toLowerCase();
                        if (!nameLower.contains(q) && !lastLower.contains(q)) {
                          return const SizedBox.shrink();
                        }
                      }

                      return InkWell(
                        onTap: () {
                          if (_hasChatSelection) {
                            _toggleConversationSelection(doc.id, doc.reference);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CoversationScreen(
                                  peerUserId: peerId,
                                  peerName: name,
                                  peerPhoto: photo,
                                ),
                              ),
                            );
                          }
                        },
                        onLongPress: () {
                          _toggleConversationSelection(doc.id, doc.reference);
                        },
                        child: Container(
                          color: isSelected
                              ? theme.colorScheme.primary.withOpacity(
                                  isDark ? 0.18 : 0.08,
                                )
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        UserColors.getBackgroundColorForUser(
                                          peerId,
                                        ),
                                    backgroundImage: photo != null
                                        ? CachedNetworkImageProvider(photo)
                                        : null,
                                    child: photo == null
                                        ? Icon(
                                            FluentSystemIcons
                                                .ic_fluent_person_filled,
                                            size: 20,
                                            color:
                                                UserColors.getIconColorForUser(
                                                  peerId,
                                                ),
                                          )
                                        : null,
                                  ),
                                  if (isDeveloper)
                                    Positioned(
                                      bottom: -2,
                                      right: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(1.5),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.verified,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: unreadForCurrent > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (timestamp != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            TimeHelper.chatListTime(timestamp),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            lastMessage.isNotEmpty
                                                ? (isLastMessageFromMe
                                                      ? 'You: $lastMessage'
                                                      : lastMessage)
                                                : 'Tap to chat',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.7),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (unreadForCurrent > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              unreadForCurrent > 99
                                                  ? '99+'
                                                  : unreadForCurrent.toString(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              if (_hasChatSelection)
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: 'chats_delete_fab',
                        mini: true,
                        backgroundColor: Colors.red,
                        onPressed: () =>
                            _handleDeleteSelectedChats(currentUserId),
                        child: Icon(
                          FluentSystemIcons.ic_fluent_delete_regular,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.grey.shade900
                                  : Colors.grey.shade300,

                              spreadRadius: 2,
                              blurRadius: 7,
                            ),
                          ],
                          color: theme.cardColor,
                        ),
                        child: Row(
                          children: [
                            Text('${_selectedConversations.length} Selected'),
                            FloatingActionButton(
                              heroTag: 'chats_cancel_fab',
                              mini: true,
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              onPressed: _clearChatSelection,
                              child: Icon(
                                Icons.close,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: !_hasChatSelection
          ? FloatingActionButton(
              heroTag: 'chats_main_fab',
              shape: const CircleBorder(),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              child: const Icon(FluentSystemIcons.ic_fluent_chat_regular),
              onPressed: () async {
                final result = await showFollowersFollowingPickerBottomSheet(
                  context,
                  actionIcon: FluentSystemIcons.ic_fluent_chat_regular,
                );
                if (result == null) return;
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CoversationScreen(
                      peerUserId: result.userId,
                      peerName: result.name,
                      peerPhoto: result.photoUrl,
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }
}
