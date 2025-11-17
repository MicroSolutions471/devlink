// ignore_for_file: avoid_print, deprecated_member_use

import 'package:devlink/utility/customTheme.dart';
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
import 'package:flutter/services.dart';

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
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: _currentUserId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        final data = doc.data();
        final isRead = data['isRead'] as bool?;
        if (isRead == true) continue;
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
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Theme.of(context).colorScheme.surface,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          appBar: AppBar(title: const Text('Notifications')),
          body: const Center(
            child: Text('Please sign in to view notifications'),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Theme.of(context).colorScheme.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
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
                          ad?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bt =
                          bd?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                final at =
                    ad?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bt =
                    bd?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
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

  Timestamp? _extractTimestamp(Map<String, dynamic> notification) {
    // Prefer these keys, but gracefully handle others in the future.
    const keys = ['createdAt', 'timestamp', 'created_at', 'time'];

    for (final key in keys) {
      final value = notification[key];
      if (value == null) continue;

      // Debug which key and type we are using for this notification
      print(
        'Notification ${widget.doc.id}: found timestamp key "$key" with value=$value (type=${value.runtimeType})',
      );

      if (value is Timestamp) return value;

      if (value is int) {
        // Heuristic: treat large ints as milliseconds, smaller as seconds
        final millis = value > 1000000000000 ? value : value * 1000;
        return Timestamp.fromMillisecondsSinceEpoch(millis);
      }

      if (value is double) {
        final millis = value > 1000000000000 ? value : value * 1000;
        return Timestamp.fromMillisecondsSinceEpoch(millis.toInt());
      }

      if (value is String && value.isNotEmpty) {
        // Try parse as ISO date string
        try {
          final dt = DateTime.tryParse(value);
          if (dt != null) {
            return Timestamp.fromDate(dt);
          }
        } catch (_) {}

        // Fallback: numeric string (seconds or millis)
        try {
          final numVal = num.parse(value);
          final millis = numVal > 1000000000000 ? numVal : numVal * 1000;
          return Timestamp.fromMillisecondsSinceEpoch(millis.toInt());
        } catch (_) {}
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notification = widget.doc.data();
    final title = notification['title'] as String? ?? '';
    final body = notification['body'] as String? ?? '';
    final isRead = notification['isRead'] as bool? ?? false;
    final createdAt = _extractTimestamp(notification);
    final timeAgo = TimeHelper.timeAgo(createdAt);
    print(
      'Notification ${widget.doc.id}: createdAt=$createdAt -> timeAgo="$timeAgo"',
    );
    final fromUserId = notification['fromUserId'] as String?;
    final isAdmin = notification['isAdmin'] as bool? ?? false;

    return RepaintBoundary(
      child: InkWell(
        onTap: () {
          if (widget.selectionMode) {
            widget.onToggleSelect();
          } else if (isAdmin) {
            showDialog<void>(
              context: context,
              builder: (ctx) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(title.isEmpty ? 'Notification' : title),
                  content: Text(
                    body.isEmpty
                        ? 'You have a new message from the DevLink team.'
                        : body,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          } else {
            widget.onTap();
          }
        },
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
                if (isAdmin)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 1),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Image.asset('assets/images/logo.png'),
                      ),
                    ),
                  )
                else if (fromUserId != null)
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
                      maxLines: isAdmin ? null : 1,
                      overflow: isAdmin ? null : TextOverflow.ellipsis,
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
                      timeAgo,
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
