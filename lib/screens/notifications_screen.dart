// ignore_for_file: avoid_print, deprecated_member_use

import 'package:devlink/utility/time_helper.dart';
import 'package:enefty_icons/enefty_icons.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:devlink/screens/post_detail_screen.dart';
import 'package:devlink/screens/developer_info_screen.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:devlink/widgets/shimmers.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedNotifications =
      const [];

  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    if (_currentUserId == null) return;

    try {
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(docs.map((d) => d.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedIds) {
        final ref = FirebaseFirestore.instance
            .collection('notifications')
            .doc(id);
        batch.delete(ref);
      }
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _selectionMode = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting notifications: $e')),
      );
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final postId = notification['postId'] as String?;
    final replyId = notification['replyId'] as String?;
    final type = notification['type'] as String?;
    final fromUserId = notification['fromUserId'] as String?;

    if (type == 'follow' && fromUserId != null) {
      // Navigate to the follower's profile
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DeveloperInfoScreen(userId: fromUserId),
        ),
      );
    } else if (postId != null) {
      // Navigate to post detail for post/reply notifications
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            postId: postId,
            highlightReplyId: replyId,
            highlightPost:
                (type == 'reply' && replyId == null) || type == 'post',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please sign in to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedIds.length} selected')
            : const Text('Notifications'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              tooltip: 'Select all',
              icon: const Icon(Icons.select_all),
              onPressed: () async {
                final snap = await FirebaseFirestore.instance
                    .collection('notifications')
                    .where('toUserId', isEqualTo: _currentUserId)
                    .limit(500)
                    .get();
                // Sort client-side by date (createdAt or timestamp)
                final sorted = [...snap.docs]
                  ..sort((a, b) {
                    final ad =
                        (a.data()['createdAt'] ?? a.data()['timestamp'])
                            as Timestamp?;
                    final bd =
                        (b.data()['createdAt'] ?? b.data()['timestamp'])
                            as Timestamp?;
                    final at =
                        ad?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bt =
                        bd?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bt.compareTo(at);
                  });
                _selectAll(sorted);
              },
            ),
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(
                FluentSystemIcons.ic_fluent_delete_regular,
                color: Colors.red,
              ),
              onPressed: _deleteSelected,
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: _currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          // If waiting but we have cached data, render cache to avoid flicker
          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedNotifications.isNotEmpty) {
            final notifications = _cachedNotifications;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final doc = notifications[index];
                return _NotificationRow(
                  key: ValueKey(doc.id),
                  doc: doc,
                  selected: _selectedIds.contains(doc.id),
                  selectionMode: _selectionMode,
                  onTap: () {
                    final data = doc.data();
                    _handleNotificationTap(data);
                  },
                  onToggleSelect: () => _toggleSelect(doc.id),
                  onLongPress: () => _enterSelection(doc.id),
                );
              },
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerNotificationList(count: 8);
          }

          if (snapshot.hasError) {
            print('Error fetching notifications: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final raw = snapshot.data?.docs ?? [];
          // Sort by createdAt or timestamp (desc)
          final notifications = [...raw]
            ..sort((a, b) {
              final ad =
                  (a.data()['createdAt'] ?? a.data()['timestamp'])
                      as Timestamp?;
              final bd =
                  (b.data()['createdAt'] ?? b.data()['timestamp'])
                      as Timestamp?;
              final at = ad?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bt = bd?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bt.compareTo(at);
            });
          // Update cache with sorted
          _cachedNotifications = notifications;

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    EneftyIcons.notification_bing_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              return _NotificationRow(
                key: ValueKey(doc.id),
                doc: doc,
                selected: _selectedIds.contains(doc.id),
                selectionMode: _selectionMode,
                onTap: () {
                  final data = doc.data();
                  _handleNotificationTap(data);
                },
                onToggleSelect: () => _toggleSelect(doc.id),
                onLongPress: () => _enterSelection(doc.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationRow extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;
  final VoidCallback onLongPress;

  const _NotificationRow({
    super.key,
    required this.doc,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onToggleSelect,
    required this.onLongPress,
  });

  @override
  State<_NotificationRow> createState() => _NotificationRowState();
}

class _NotificationRowState extends State<_NotificationRow>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notification = widget.doc.data();
    final title = notification['title'] as String? ?? '';
    final body = notification['body'] as String? ?? '';
    final isRead = notification['isRead'] as bool? ?? false;
    final createdAt =
        (notification['createdAt'] ?? notification['timestamp']) as Timestamp?;
    final fromUserId = notification['fromUserId'] as String?;

    return RepaintBoundary(
      child: InkWell(
        onTap: widget.selectionMode ? widget.onToggleSelect : widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: widget.selectionMode
                ? (widget.selected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                      : Colors.transparent)
                : (isRead ? Colors.transparent : Colors.blue.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.selectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Checkbox(
                    activeColor: Colors.red,
                    value: widget.selected,
                    onChanged: (_) => widget.onToggleSelect(),
                  ),
                ),
              if (!widget.selectionMode)
                if (fromUserId != null)
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(fromUserId)
                        .snapshots(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data();
                      final photoUrl =
                          userData?['photoUrl'] as String? ??
                          userData?['avatar'] as String?;
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: UserColors.getBackgroundColorForUser(
                          fromUserId,
                        ),
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? Icon(
                                FluentSystemIcons.ic_fluent_person_filled,
                                size: 16,
                                color: UserColors.getIconColorForUser(
                                  fromUserId,
                                ),
                              )
                            : null,
                      );
                    },
                  )
                else
                  const CircleAvatar(
                    radius: 16,
                    child: Icon(Icons.notifications, size: 16),
                  ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      TimeHelper.timeAgo(createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
              ),

              Column(
                children: [
                  if (!isRead)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
