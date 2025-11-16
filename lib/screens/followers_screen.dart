// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:devlink/screens/developer_info_screen.dart';
import 'package:devlink/services/follow_service.dart';
import 'package:devlink/widgets/shimmers.dart';
import 'package:flutter/services.dart';

class FollowersScreen extends StatelessWidget {
  const FollowersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view followers')),
      );
    }

    final followersQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('followers')
        .orderBy(FieldPath.documentId);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Followers')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: followersQuery.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerUserList();
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('No followers yet'));
            }
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final followerId = docs[index].id;
                return _UserTile(userId: followerId);
              },
            );
          },
        ),
      ),
    );
  }
}

class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view following')),
      );
    }

    // Instead of using collectionGroup (which causes permission issues),
    // we'll create a following subcollection under the current user.
    final followingQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .orderBy(FieldPath.documentId);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Following')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: followingQuery.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerUserList(showTrailingButton: true);
            }
            if (snap.hasError) {
              debugPrint(snap.error.toString());
              return Center(child: SelectableText('Error: ${snap.error}'));
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('Not following anyone yet'));
            }
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final followingDoc = docs[index];
                final targetUserId = followingDoc.id;
                return _UserTile(
                  userId: targetUserId,
                  showUnfollowButton: true,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class MyPostsScreen extends StatelessWidget {
  const MyPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your posts')),
      );
    }

    final postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Posts')),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: postsQuery.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const ShimmerPostList();
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('No posts yet'));
            }
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final text = data['text'] as String? ?? '';
                final createdAt = data['createdAt'] as Timestamp?;
                final postId = doc.id;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.black12.withOpacity(0.05)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.isNotEmpty ? text : '(No text)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          createdAt?.toDate().toString() ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _editPost(context, doc.reference, text),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text(
                                'Edit',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _deletePost(context, doc.reference, postId),
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _editPost(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String currentText,
  ) async {
    final controller = TextEditingController(text: currentText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit post'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Update your post...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    try {
      await ref.update({'text': result});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating post: $e')));
    }
  }

  Future<void> _deletePost(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
    String postId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'This will remove the post and its replies permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ref.delete();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
    }
  }
}

class _UserTile extends StatelessWidget {
  final String userId;
  final bool showUnfollowButton;

  const _UserTile({required this.userId, this.showUnfollowButton = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final name =
            (data['name'] as String?) ??
            (data['displayName'] as String?) ??
            'User';
        final photo =
            (data['photoUrl'] as String?) ?? (data['avatar'] as String?);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: UserColors.getBackgroundColorForUser(
              userId,
            ).withValues(alpha: 0.1),
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Icon(
                    FluentSystemIcons.ic_fluent_person_filled,
                    color: UserColors.getIconColorForUser(userId),
                  )
                : null,
          ),
          title: Text(name),
          trailing: showUnfollowButton
              ? _UnfollowButton(targetUserId: userId)
              : null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DeveloperInfoScreen(userId: userId),
              ),
            );
          },
        );
      },
    );
  }
}

class _UnfollowButton extends StatefulWidget {
  final String targetUserId;

  const _UnfollowButton({required this.targetUserId});

  @override
  State<_UnfollowButton> createState() => _UnfollowButtonState();
}

class _UnfollowButtonState extends State<_UnfollowButton> {
  bool _loading = false;

  Future<void> _unfollow() async {
    setState(() => _loading = true);
    try {
      await FollowService.instance.toggleFollow(widget.targetUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unfollowed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error unfollowing: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _loading ? null : _unfollow,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Colors.red,
      ),
      child: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Unfollow', style: TextStyle(fontSize: 12)),
    );
  }
}
