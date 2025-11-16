// ignore_for_file: deprecated_member_use

import 'package:devlink/screens/developer_info_screen.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:devlink/models/post.dart';
import 'package:devlink/utility/time_helper.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:devlink/utility/reaction_helper.dart';
import 'package:devlink/widgets/post_image_gallery.dart';
import 'package:devlink/screens/post_detail_screen.dart';
import 'package:devlink/widgets/fullscreen_image_viewer.dart';
import 'package:devlink/services/follow_service.dart';
import 'package:devlink/utility/number_format.dart';
import 'package:devlink/services/report_service.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final DocumentReference postRef;
  final VoidCallback onReplyTap;
  final bool canReply;

  const PostCard({
    super.key,
    required this.post,
    required this.postRef,
    required this.onReplyTap,
    this.canReply = true,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final liked = uid != null && post.likedBy.contains(uid);
    final disliked = uid != null && post.dislikedBy.contains(uid);
    final likeCount = post.likedBy.isNotEmpty
        ? post.likedBy.length
        : post.likes;
    final dislikeCount = post.dislikedBy.isNotEmpty
        ? post.dislikedBy.length
        : post.dislikes;

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    // using theme and colorScheme below
    return Card(
      elevation: 0,
      color: isDarkMode ? theme.cardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  PostDetailScreen(postId: post.id ?? postRef.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: PostHeader(post: post),
            ),

            // Post Text Content
            if (post.text != null && post.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: RichText(
                  text: TextSpan(
                    children: _buildHashtagSpans(
                      post.text!,
                      theme.textTheme.bodyMedium ??
                          const TextStyle(fontSize: 14),
                      Colors.blue,
                    ),
                  ),
                ),
              ),

            // Post Images
            if (post.imageUrls.isNotEmpty) ...[
              if (post.imageUrls.length == 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SinglePostImage(
                    imageUrl: post.imageUrls.first,
                    postId: post.id ?? postRef.id,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MultiplePostImages(
                    imageUrls: post.imageUrls,
                    postId: post.id ?? postRef.id,
                  ),
                ),
              const SizedBox(height: 10),
            ],

            // Post Links
            if (post.links.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: PostLinks(links: post.links),
              ),

            // Post Actions (Like, Dislike, Reply)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: PostReactionsOptimistic(
                enabled: uid != null,
                uid: uid,
                postRef: postRef,
                initialLiked: liked,
                initialDisliked: disliked,
                initialLikeCount: likeCount,
                initialDislikeCount: dislikeCount,
                replyCount: post.replyCount,
                onReply: onReplyTap,
                canReply: canReply,
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

String postRefIdFallback(Post post) => post.id ?? '';

void _showReportSheet(BuildContext context, String postId) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      bool isLoading = false;
      return StatefulBuilder(
        builder: (ctx, setState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
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
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        minLines: 2,
                        maxLines: 5,
                        readOnly: isLoading,
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
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final reason = controller.text.trim();
                                  if (reason.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter a reason'),
                                      ),
                                    );
                                    return;
                                  }
                                  try {
                                    setState(() => isLoading = true);
                                    await ReportService.instance.reportPost(
                                      postId: postId,
                                      reason: reason,
                                    );
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text('Report submitted'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to submit report: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (ctx.mounted) {
                                      setState(() => isLoading = false);
                                    }
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class PostReactionsOptimistic extends StatefulWidget {
  final bool enabled;
  final String? uid;
  final DocumentReference postRef;
  final bool initialLiked;
  final bool initialDisliked;
  final int initialLikeCount;
  final int initialDislikeCount;
  final int replyCount;
  final VoidCallback onReply;
  final bool canReply;

  const PostReactionsOptimistic({
    super.key,
    required this.enabled,
    required this.uid,
    required this.postRef,
    required this.initialLiked,
    required this.initialDisliked,
    required this.initialLikeCount,
    required this.initialDislikeCount,
    required this.replyCount,
    required this.onReply,
    this.canReply = true,
  });

  @override
  State<PostReactionsOptimistic> createState() =>
      _PostReactionsOptimisticState();
}

class _PostReactionsOptimisticState extends State<PostReactionsOptimistic> {
  late bool liked;
  late bool disliked;
  late int likeCount;
  late int dislikeCount;
  bool working = false;

  @override
  void initState() {
    super.initState();
    liked = widget.initialLiked;
    disliked = widget.initialDisliked;
    likeCount = widget.initialLikeCount;
    dislikeCount = widget.initialDislikeCount;
  }

  Future<void> _toggle(bool toLike) async {
    if (!widget.enabled || working || widget.uid == null) return;
    setState(() {
      working = true;
      if (toLike) {
        if (liked) {
          liked = false;
          likeCount = (likeCount > 0) ? likeCount - 1 : 0;
        } else {
          liked = true;
          likeCount += 1;
          if (disliked) {
            disliked = false;
            dislikeCount = (dislikeCount > 0) ? dislikeCount - 1 : 0;
          }
        }
      } else {
        if (disliked) {
          disliked = false;
          dislikeCount = (dislikeCount > 0) ? dislikeCount - 1 : 0;
        } else {
          disliked = true;
          dislikeCount += 1;
          if (liked) {
            liked = false;
            likeCount = (likeCount > 0) ? likeCount - 1 : 0;
          }
        }
      }
    });

    try {
      await ReactionHelper.toggleUserReaction(
        ref: widget.postRef,
        uid: widget.uid!,
        like: toLike,
      );
    } catch (e) {
      // revert on error
      setState(() {
        // flip back
        if (toLike) {
          // undo previous immediate changes
          if (liked) {
            liked = false;
            likeCount = (likeCount > 0) ? likeCount - 1 : 0;
          } else {
            liked = true;
            likeCount += 1;
          }
        } else {
          if (disliked) {
            disliked = false;
            dislikeCount = (dislikeCount > 0) ? dislikeCount - 1 : 0;
          } else {
            disliked = true;
            dislikeCount += 1;
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update reaction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          onPressed: widget.enabled ? () => _toggle(true) : null,
          icon: Icon(
            liked
                ? FluentSystemIcons.ic_fluent_thumb_like_filled
                : FluentSystemIcons.ic_fluent_thumb_like_regular,
            size: 16,
            color: liked ? scheme.primary : scheme.onSurface,
          ),
        ),
        Text(formatCount(likeCount), style: TextStyle(color: scheme.onSurface)),
        const SizedBox(width: 8),
        IconButton(
          onPressed: widget.enabled ? () => _toggle(false) : null,
          icon: Icon(
            disliked
                ? FluentSystemIcons.ic_fluent_thumb_dislike_filled
                : FluentSystemIcons.ic_fluent_thumb_dislike_regular,
            size: 16,
            color: disliked ? scheme.primary : scheme.onSurface,
          ),
        ),
        Text(
          formatCount(dislikeCount),
          style: TextStyle(color: scheme.onSurface),
        ),
        IconButton(
          tooltip: 'Report',
          icon: const Icon(Icons.flag_outlined, size: 18),
          onPressed: () => _showReportSheet(context, widget.postRef.id),
        ),
        const Spacer(),
        if (widget.canReply)
          TextButton.icon(
            onPressed: widget.onReply,
            icon: Icon(
              FluentSystemIcons.ic_fluent_arrow_reply_regular,
              size: 18,
            ),
            label: Text(
              'Reply (${formatCount(widget.replyCount)})',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class PostHeader extends StatelessWidget {
  final Post post;

  const PostHeader({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: post.userId == null
          ? const Stream.empty()
          : FirebaseFirestore.instance
                .collection('users')
                .doc(post.userId)
                .snapshots(),
      builder: (context, userSnap) {
        final baseName = post.authorName ?? 'User';
        final basePhoto = post.authorPhotoUrl;
        final userData = userSnap.data?.data();
        final name =
            (userData?['name'] as String?) ??
            (userData?['displayName'] as String?) ??
            baseName;
        final photo =
            (userData?['photoUrl'] as String?) ??
            (userData?['avatar'] as String?) ??
            basePhoto;
        final isDeveloper = (userData?['isDeveloper'] as bool?) ?? false;
        final followers = (userData?['followersCount'] as int?) ?? 0;
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          minVerticalPadding: 0,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          leading: GestureDetector(
            onTap: photo != null
                ? () {
                    final heroTag = 'profile_${post.userId}_${post.id}';
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FullscreenImageViewer(
                          imageUrl: photo,
                          heroTag: heroTag,
                        ),
                      ),
                    );
                  }
                : null,
            child: Stack(
              children: [
                Hero(
                  tag: 'profile_${post.userId}_${post.id}',
                  child: GestureDetector(
                    onTap: photo != null
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DeveloperInfoScreen(userId: post.userId!),
                              ),
                            );
                          }
                        : null,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: UserColors.getBackgroundColorForUser(
                        post.userId,
                      ),
                      backgroundImage: photo != null
                          ? NetworkImage(photo)
                          : null,
                      child: photo == null
                          ? Icon(
                              FluentSystemIcons.ic_fluent_person_filled,
                              size: 20,
                              color: UserColors.getIconColorForUser(
                                post.userId,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                if (isDeveloper)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,

                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified,
                        color: Colors.green,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          title: Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (post.userId != null && post.userId != currentUserId)
                PostFollowButton(targetUserId: post.userId!),
            ],
          ),
          subtitle: Text(
            followers > 0
                ? '${formatCount(followers)} followers · ${TimeHelper.timeAgo(post.createdAt)}'
                : TimeHelper.timeAgo(post.createdAt),
            style: TextStyle(fontSize: 12, color: onSurface.withOpacity(0.6)),
          ),
        );
      },
    );
  }
}

class PostFollowButton extends StatefulWidget {
  final String targetUserId;

  const PostFollowButton({super.key, required this.targetUserId});

  @override
  State<PostFollowButton> createState() => _PostFollowButtonState();
}

class _PostFollowButtonState extends State<PostFollowButton> {
  bool? _isFollowing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isFollowing = await FollowService.instance.isFollowing(
      widget.targetUserId,
    );
    if (mounted) {
      setState(() {
        _isFollowing = isFollowing;
      });
    }
  }

  Future<void> _toggle() async {
    if (_isFollowing == null || _loading) return;
    setState(() {
      _loading = true;
      _isFollowing = !_isFollowing!;
    });
    try {
      await FollowService.instance.toggleFollow(widget.targetUserId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update follow status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFollowing == null) {
      return const SizedBox.shrink();
    }
    final following = _isFollowing!;
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: _loading ? null : _toggle,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),

        foregroundColor: primaryColor,
      ),
      child: _loading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: scheme.primary,
                strokeWidth: 2,
              ),
            )
          : Text(following ? 'Following' : 'Follow'),
    );
  }
}

class PostLinks extends StatelessWidget {
  final List<String> links;

  const PostLinks({super.key, required this.links});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final link in links)
          InkWell(
            onTap: () => launchUrl(Uri.parse(link)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FluentSystemIcons.ic_fluent_link_filled,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.primary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class PostActions extends StatelessWidget {
  final bool liked;
  final bool disliked;
  final int likeCount;
  final int dislikeCount;
  final int replyCount;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback onReply;
  final String postId;
  final bool canReply;

  const PostActions({
    super.key,
    required this.liked,
    required this.disliked,
    required this.likeCount,
    required this.dislikeCount,
    required this.replyCount,
    this.onLike,
    this.onDislike,
    required this.onReply,
    required this.postId,
    this.canReply = true,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        IconButton(
          onPressed: onLike,
          icon: Icon(
            size: 16,
            liked
                ? FluentSystemIcons.ic_fluent_thumb_like_filled
                : FluentSystemIcons.ic_fluent_thumb_like_regular,
          ),
        ),
        Text('$likeCount', style: TextStyle(color: onSurface)),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onDislike,
          icon: Icon(
            size: 16,
            disliked
                ? FluentSystemIcons.ic_fluent_thumb_dislike_filled
                : FluentSystemIcons.ic_fluent_thumb_dislike_regular,
          ),
        ),
        Text('$dislikeCount', style: TextStyle(color: onSurface)),
        IconButton(
          tooltip: 'Report',
          icon: const Icon(Icons.flag_outlined, size: 18),
          onPressed: () => _showReportSheet(context, postId),
        ),
        const Spacer(),
        if (canReply)
          TextButton.icon(
            onPressed: onReply,
            icon: Icon(
              FluentSystemIcons.ic_fluent_arrow_reply_regular,
              size: 18,
            ),
            label: Text('Reply ($replyCount)', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
