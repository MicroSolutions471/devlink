// ignore_for_file: deprecated_member_use

import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:devlink/models/post.dart';
import 'package:devlink/widgets/replies_sheet.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:devlink/widgets/fullscreen_image_viewer.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:devlink/widgets/shimmers.dart';
import 'package:devlink/widgets/reply_tile.dart';
import 'package:devlink/utility/number_format.dart';
import 'package:devlink/services/report_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:devlink/config/oneSignal_config.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String? highlightReplyId;
  final bool highlightPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.highlightReplyId,
    this.highlightPost = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class ReportPostSheet extends StatefulWidget {
  final String postId;
  const ReportPostSheet({super.key, required this.postId});

  @override
  State<ReportPostSheet> createState() => _ReportPostSheetState();
}

class _ReportPostSheetState extends State<ReportPostSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Report Post',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _loading ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 5,
                  readOnly: _loading,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Describe the issue...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? Loading.medium(color: primaryColor)
                        : const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a reason')));
      return;
    }
    try {
      setState(() => _loading = true);
      await ReportService.instance.reportPost(
        postId: widget.postId,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit report: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

void _showReportSheet(BuildContext context, String postId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ReportPostSheet(postId: postId),
  );
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<Color?> _highlightAnimation;
  String? _highlightedItemId;
  bool _canReply = true;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _highlightAnimation =
        ColorTween(
          begin: Colors.amber.withOpacity(0.25),
          end: Colors.transparent,
        ).animate(
          CurvedAnimation(parent: _highlightController, curve: Curves.easeOut),
        );

    // Start highlighting after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.highlightPost) {
        _highlightedItemId = widget.postId;
        _highlightController.forward();
      } else if (widget.highlightReplyId != null) {
        _highlightedItemId = widget.highlightReplyId;
        _highlightController.forward();
      }
    });

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get()
          .then((snap) {
            final isActive = (snap.data()?['isActive'] as bool?) ?? true;
            if (mounted) {
              setState(() {
                _canReply = isActive;
              });
            }
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleUserReaction({
    required DocumentReference ref,
    required String uid,
    required bool like,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final likedBy = (data['likedBy'] as List?)?.cast<String>() ?? <String>[];
      final dislikedBy =
          (data['dislikedBy'] as List?)?.cast<String>() ?? <String>[];
      final currentlyLiked = likedBy.contains(uid);
      final currentlyDisliked = dislikedBy.contains(uid);

      final updates = <String, dynamic>{};
      bool createdNewLike = false;
      bool createdNewDislike = false;

      if (like) {
        if (currentlyLiked) {
          updates['likedBy'] = FieldValue.arrayRemove([uid]);
          updates['likes'] = (data['likes'] as int? ?? 0) - 1;
        } else {
          updates['likedBy'] = FieldValue.arrayUnion([uid]);
          updates['likes'] = (data['likes'] as int? ?? 0) + 1;
          createdNewLike = true;
          if (currentlyDisliked) {
            updates['dislikedBy'] = FieldValue.arrayRemove([uid]);
            updates['dislikes'] = (data['dislikes'] as int? ?? 0) - 1;
          }
        }
      } else {
        if (currentlyDisliked) {
          updates['dislikedBy'] = FieldValue.arrayRemove([uid]);
          updates['dislikes'] = (data['dislikes'] as int? ?? 0) - 1;
        } else {
          updates['dislikedBy'] = FieldValue.arrayUnion([uid]);
          updates['dislikes'] = (data['dislikes'] as int? ?? 0) + 1;
          createdNewDislike = true;
          if (currentlyLiked) {
            updates['likedBy'] = FieldValue.arrayRemove([uid]);
            updates['likes'] = (data['likes'] as int? ?? 0) - 1;
          }
        }
      }

      tx.update(ref, updates);
      // After updating, send notification if a new reaction was created
      final ownerId = (data['userId'] as String?);
      if (ownerId != null && ownerId != uid) {
        if (createdNewLike) {
          await _notifyOnReaction(
            toUserId: ownerId,
            postId: ref.id,
            type: 'like',
          );
        } else if (createdNewDislike) {
          await _notifyOnReaction(
            toUserId: ownerId,
            postId: ref.id,
            type: 'dislike',
          );
        }
      }
    });
  }

  Future<void> _notifyOnReaction({
    required String toUserId,
    required String postId,
    required String type, // 'like' | 'dislike'
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final fromSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final from = fromSnap.data() ?? {};
    final fromName = from['name'] ?? from['displayName'] ?? 'Someone';

    final notif = {
      'toUserId': toUserId,
      'fromUserId': uid,
      'postId': postId,
      'type': type,
      'title': type == 'like'
          ? '$fromName liked your post'
          : '$fromName disliked your post',
      'body': '',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance.collection('notifications').add(notif);

    // OneSignal push (best effort)
    final toSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(toUserId)
        .get();
    final playerId = (toSnap.data() ?? const {})['playerId'] as String?;
    if (playerId == null || playerId.isEmpty) return;

    final uri = Uri.parse('https://api.onesignal.com/notifications');
    final payload = {
      'app_id': OneSignalConfig.appId,
      'include_player_ids': [playerId],
      'headings': {'en': type == 'like' ? 'New like' : 'New dislike'},
      'contents': {
        'en': type == 'like'
            ? '$fromName liked your post'
            : '$fromName disliked your post',
      },
      'data': {'postId': postId, 'type': type},
    };
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${OneSignalConfig.appKey}',
      );
      req.add(utf8.encode(jsonEncode(payload)));
      await req.close();
    } catch (_) {
    } finally {
      client.close();
    }
  }

  void _openRepliesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepliesSheet(
        postRef: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId),
      ),
    );
  }

  void _openRepliesSheetTo(String? uid, String? preview) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RepliesSheet(
        postRef: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId),
        initialQuotedUserId: uid,
        initialQuotedPreview: preview,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerPostDetailCard();
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Post not found'));
          }

          final post = Post.fromDoc(snapshot.data!);
          final postRef = snapshot.data!.reference;
          final uid = FirebaseAuth.instance.currentUser?.uid;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Main Post
                AnimatedBuilder(
                  animation: _highlightAnimation,
                  builder: (context, child) {
                    return Container(
                      color: _highlightedItemId == widget.postId
                          ? _highlightAnimation.value
                          : Colors.transparent,
                      child: _buildPostCard(post, postRef, uid),
                    );
                  },
                ),

                Divider(
                  thickness: 8,
                  color: Theme.of(context).dividerColor.withOpacity(0.06),
                ),

                // Replies Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Replies',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_canReply)
                        TextButton.icon(
                          onPressed: () => _openRepliesSheet(),
                          icon: const Icon(Icons.reply, size: 18),
                          label: const Text('Reply'),
                        ),
                    ],
                  ),
                ),

                // Replies List
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: postRef
                      .collection('replies')
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, repliesSnapshot) {
                    if (repliesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const ShimmerRepliesList(count: 4);
                    }

                    final replies = repliesSnapshot.data?.docs ?? [];

                    if (replies.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No replies yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: replies.length,
                      itemBuilder: (context, index) {
                        final reply = replies[index];
                        final data = reply.data();
                        final quotedUserId = data['quotedUserId'] as String?;
                        final quotedReplyId = data['quotedReplyId'] as String?;
                        return AnimatedBuilder(
                          animation: _highlightAnimation,
                          builder: (context, child) {
                            return Container(
                              color: _highlightedItemId == reply.id
                                  ? _highlightAnimation.value
                                  : Colors.transparent,
                              child: ReplyTile(
                                data: data,
                                isChild: quotedReplyId != null,
                                quotedUserId: quotedUserId,
                                replyId: reply.id,
                                replyRef: postRef
                                    .collection('replies')
                                    .doc(reply.id),
                                onReply: (uid, preview, parentReplyId) =>
                                    _openRepliesSheetTo(uid, preview),
                                canReply: _canReply,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(Post post, DocumentReference postRef, String? uid) {
    final liked = uid != null && post.likedBy.contains(uid);
    final disliked = uid != null && post.dislikedBy.contains(uid);
    final likeCount = post.likedBy.isNotEmpty
        ? post.likedBy.length
        : post.likes;
    final dislikeCount = post.dislikedBy.isNotEmpty
        ? post.dislikedBy.length
        : post.dislikes;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDarkMode ? theme.cardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
      ),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author info
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: post.userId == null
                  ? const Stream.empty()
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(post.userId)
                        .snapshots(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data();
                final name =
                    userData?['name'] ??
                    userData?['displayName'] ??
                    post.authorName ??
                    'User';
                final photoUrl =
                    userData?['photoUrl'] ??
                    userData?['avatar'] ??
                    post.authorPhotoUrl;
                final isDeveloper = userData?['isDeveloper'] ?? false;
                final autherfollowers =
                    (userData?['followersCount'] as int?) ?? 0;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: UserColors.getBackgroundColorForUser(
                          post.userId,
                        ),
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? Icon(
                                FluentSystemIcons.ic_fluent_person_filled,
                                size: 22,
                                color: UserColors.getIconColorForUser(
                                  post.userId,
                                ),
                              )
                            : null,
                      ),
                      if (isDeveloper)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (isDeveloper) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    autherfollowers > 0
                        ? '${formatCount(autherfollowers)} followers · ${_timeAgo(post.createdAt)}'
                        : _timeAgo(post.createdAt),
                  ),
                  trailing: IconButton(
                    tooltip: 'Report',
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    onPressed: () => _showReportSheet(context, widget.postId),
                  ),
                );
              },
            ),

            // Post content
            if (post.text != null && post.text!.isNotEmpty) ...[
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: _buildHashtagSpans(
                    post.text!,
                    theme.textTheme.bodyMedium?.copyWith(fontSize: 16) ??
                        const TextStyle(fontSize: 16),
                    Colors.blue,
                  ),
                ),
              ),
            ],

            // Images
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (post.imageUrls.length == 1)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FullscreenImageViewer(
                            imageUrl: post.imageUrls.first,
                            heroTag: 'post_${post.id}_img',
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: 'post_${post.id}_img',
                      child: Image.network(
                        post.imageUrls.first,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: post.imageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, j) {
                      final imgUrl = post.imageUrls[j];
                      final heroTag = 'post_${post.id}_img_$j';
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FullscreenImageViewer(
                                  imageUrl: imgUrl,
                                  heroTag: heroTag,
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: heroTag,
                            child: Image.network(
                              imgUrl,
                              width: 240,
                              height: 160,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],

            // Links
            if (post.links.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final link in post.links)
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(link)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FluentSystemIcons.ic_fluent_link_regular,
                              size: 16,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                link,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: scheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: uid == null
                        ? null
                        : () => _toggleUserReaction(
                            ref: postRef,
                            uid: uid,
                            like: true,
                          ),
                    icon: Icon(
                      size: 16,
                      liked
                          ? FluentSystemIcons.ic_fluent_thumb_like_filled
                          : FluentSystemIcons.ic_fluent_thumb_like_regular,
                    ),
                  ),
                  Text(
                    formatCount(likeCount),
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: uid == null
                        ? null
                        : () => _toggleUserReaction(
                            ref: postRef,
                            uid: uid,
                            like: false,
                          ),
                    icon: Icon(
                      size: 16,
                      disliked
                          ? FluentSystemIcons.ic_fluent_thumb_dislike_filled
                          : FluentSystemIcons.ic_fluent_thumb_dislike_regular,
                    ),
                  ),
                  Text(
                    formatCount(dislikeCount),
                    style: TextStyle(color: scheme.onSurface),
                  ),
                  IconButton(
                    tooltip: 'Report',
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    onPressed: () => _showReportSheet(context, widget.postId),
                  ),
                  const Spacer(),
                  if (_canReply)
                    TextButton.icon(
                      onPressed: () => _openRepliesSheet(),
                      icon: const Icon(Icons.reply, size: 18),
                      label: Text('Reply (${formatCount(post.replyCount)})'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _buildHashtagSpans(
    String text,
    TextStyle baseStyle,
    Color hashtagColor,
  ) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(#[\w]+)');

    text.splitMapJoin(
      regex,
      onMatch: (match) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: baseStyle.copyWith(color: hashtagColor),
          ),
        );
        return '';
      },
      onNonMatch: (nonMatch) {
        if (nonMatch.isNotEmpty) {
          spans.add(TextSpan(text: nonMatch, style: baseStyle));
        }
        return '';
      },
    );

    return spans;
  }
}
