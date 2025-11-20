// ignore_for_file: deprecated_member_use, invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:devlink/config/oneSignal_config.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:devlink/utility/time_helper.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:devlink/utility/code_text_formatter.dart';
import 'package:devlink/widgets/code_block.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReplyTile extends StatefulWidget {
  final Map<String, dynamic> data;
  final void Function(String? uid, String? preview, String parentReplyId)?
  onReply;
  final bool isChild;
  final String? quotedUserId;
  final String replyId;
  final DocumentReference replyRef;
  final bool canReply;

  const ReplyTile({
    super.key,
    required this.data,
    this.onReply,
    this.isChild = false,
    this.quotedUserId,
    required this.replyId,
    required this.replyRef,
    this.canReply = true,
  });

  @override
  State<ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends State<ReplyTile> {
  bool _expanded = false;
  bool _exceeds = false;
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;

  @override
  void initState() {
    super.initState();
    final likedBy =
        (widget.data['likedBy'] as List?)?.cast<String>() ?? <String>[];
    final dislikedBy =
        (widget.data['dislikedBy'] as List?)?.cast<String>() ?? <String>[];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _liked = uid != null && likedBy.contains(uid);
    _disliked = uid != null && dislikedBy.contains(uid);
    _likeCount = (widget.data['likes'] as int?) ?? likedBy.length;
    _dislikeCount = (widget.data['dislikes'] as int?) ?? dislikedBy.length;
  }

  bool _willExceedHeight(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty || maxWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout(maxWidth: maxWidth);
    return painter.height > 100.0;
  }

  String? _extractFencedCode(String text) {
    final trimmed = text.trim();
    final regex = RegExp(r'^```(?:[^\n]*\n)?([\s\S]*?)```$');
    final match = regex.firstMatch(trimmed);
    if (match == null) return null;
    final code = match.group(1) ?? '';
    return code.trimRight();
  }

  String? _extractFencedLanguage(String text) {
    final trimmed = text.trimLeft();
    final match = RegExp(r'^```([^\n]*)\n').firstMatch(trimmed);
    final header = match?.group(1)?.trim();
    if (header == null || header.isEmpty) return null;
    return header;
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final uid = widget.data['userId'] as String?;
    final text = (widget.data['text'] as String?) ?? '';
    final ts = widget.data['createdAt'] as Timestamp?;

    return Padding(
      padding: EdgeInsets.only(
        left: widget.isChild ? 28 : 0,
        top: 3,
        bottom: 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReplyAvatar(uid: uid),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: ReplyName(uid: uid)),
                    const SizedBox(width: 4),
                    Text(
                      TimeHelper.replyTimeAgo(ts),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                if (text.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final theme = Theme.of(context);
                      final baseStyle = const TextStyle(fontSize: 13.5);
                      final codeStyle = baseStyle.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      );

                      // If the whole text is a single fenced block, render as a pure CodeBlock
                      final fencedOnly = _extractFencedCode(text);
                      Widget? contentWidget;
                      bool hasCodeBlock = false;

                      if (fencedOnly != null) {
                        final lang = _extractFencedLanguage(text);
                        contentWidget = CodeBlock(
                          code: fencedOnly,
                          language: lang,
                        );
                        hasCodeBlock = true;
                      } else {
                        // Check if there is at least one fenced block
                        final match = RegExp(
                          r"```([\s\S]*?)```",
                        ).firstMatch(text);
                        if (match != null) {
                          final before = text.substring(0, match.start);
                          final inner = match.group(1) ?? '';
                          String? lang;
                          String codeSection = inner;
                          final firstBreak = inner.indexOf('\n');
                          if (firstBreak != -1) {
                            final firstLine = inner
                                .substring(0, firstBreak)
                                .trim();
                            final rest = inner.substring(firstBreak + 1);
                            if (firstLine.isNotEmpty &&
                                !firstLine.contains(' ')) {
                              lang = firstLine;
                              codeSection = rest;
                            }
                          }
                          final code = codeSection.trimRight();
                          final after = text.substring(match.end);

                          final children = <Widget>[];

                          if (before.trim().isNotEmpty) {
                            children.add(
                              RichText(
                                text: TextSpan(
                                  children: CodeTextFormatter.buildSpans(
                                    text: before.trimRight(),
                                    baseStyle: baseStyle,
                                    mentionColor: Colors.green.shade700,
                                    codeStyle: codeStyle.copyWith(
                                      backgroundColor:
                                          theme.colorScheme.surfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          if (code.isNotEmpty) {
                            children.add(CodeBlock(code: code, language: lang));
                            hasCodeBlock = true;
                          }

                          if (after.trim().isNotEmpty) {
                            children.add(
                              RichText(
                                text: TextSpan(
                                  children: CodeTextFormatter.buildSpans(
                                    text: after.trimLeft(),
                                    baseStyle: baseStyle,
                                    mentionColor: Colors.green.shade700,
                                    codeStyle: codeStyle.copyWith(
                                      backgroundColor:
                                          theme.colorScheme.surfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          contentWidget = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: children,
                          );
                        } else {
                          // No fenced blocks: use inline/highlighted text rendering
                          contentWidget = SelectableText.rich(
                            TextSpan(
                              children: CodeTextFormatter.buildSpans(
                                text: text,
                                baseStyle: baseStyle,
                                mentionColor: Colors.green.shade700,
                                codeStyle: codeStyle.copyWith(
                                  backgroundColor:
                                      theme.colorScheme.surfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }
                      }

                      // Only check for exceeds if there's no CodeBlock (CodeBlocks should always be fully visible)
                      final exceeds = hasCodeBlock
                          ? false
                          : _willExceedHeight(
                              text,
                              baseStyle,
                              constraints.maxWidth,
                            );
                      if (exceeds != _exceeds) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _exceeds = exceeds);
                        });
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.topLeft,
                            child: hasCodeBlock
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: contentWidget,
                                  )
                                : ConstrainedBox(
                                    constraints: _expanded
                                        ? const BoxConstraints()
                                        : const BoxConstraints(maxHeight: 100),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: contentWidget,
                                    ),
                                  ),
                          ),
                          if (_exceeds && !hasCodeBlock)
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: TextButton(
                                  onPressed: () =>
                                      setState(() => _expanded = !_expanded),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _expanded ? 'Read less' : 'Read more',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                Row(
                  children: [
                    IconButton(
                      onPressed: FirebaseAuth.instance.currentUser == null
                          ? null
                          : () => _toggleReaction(true),
                      icon: Icon(
                        _liked
                            ? FluentSystemIcons.ic_fluent_thumb_like_filled
                            : FluentSystemIcons.ic_fluent_thumb_like_regular,
                        size: 14,
                      ),
                    ),
                    Text('$_likeCount', style: TextStyle(color: onSurface)),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: FirebaseAuth.instance.currentUser == null
                          ? null
                          : () => _toggleReaction(false),
                      icon: Icon(
                        _disliked
                            ? FluentSystemIcons.ic_fluent_thumb_dislike_filled
                            : FluentSystemIcons.ic_fluent_thumb_dislike_regular,
                        size: 14,
                      ),
                    ),
                    Text('$_dislikeCount', style: TextStyle(color: onSurface)),
                    const SizedBox(width: 8),
                    if (widget.onReply != null && widget.canReply)
                      TextButton(
                        onPressed: () =>
                            widget.onReply?.call(uid, text, widget.replyId),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Reply',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on _ReplyTileState {
  Future<void> _toggleReaction(bool like) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    // optimistic update
    setState(() {
      if (like) {
        if (_liked) {
          _liked = false;
          if (_likeCount > 0) _likeCount--;
        } else {
          _liked = true;
          _likeCount++;
          if (_disliked) {
            _disliked = false;
            if (_dislikeCount > 0) _dislikeCount--;
          }
        }
      } else {
        if (_disliked) {
          _disliked = false;
          if (_dislikeCount > 0) _dislikeCount--;
        } else {
          _disliked = true;
          _dislikeCount++;
          if (_liked) {
            _liked = false;
            if (_likeCount > 0) _likeCount--;
          }
        }
      }
    });

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(widget.replyRef);
        final data = (snap.data() as Map<String, dynamic>?) ?? {};
        final likedBy =
            (data['likedBy'] as List?)?.cast<String>() ?? <String>[];
        final dislikedBy =
            (data['dislikedBy'] as List?)?.cast<String>() ?? <String>[];
        final currentlyLiked = likedBy.contains(currentUid);
        final currentlyDisliked = dislikedBy.contains(currentUid);

        final updates = <String, dynamic>{};
        bool createdNewLike = false;
        bool createdNewDislike = false;

        if (like) {
          if (currentlyLiked) {
            updates['likedBy'] = FieldValue.arrayRemove([currentUid]);
            updates['likes'] = (data['likes'] as int? ?? 0) - 1;
          } else {
            updates['likedBy'] = FieldValue.arrayUnion([currentUid]);
            updates['likes'] = (data['likes'] as int? ?? 0) + 1;
            createdNewLike = true;
            if (currentlyDisliked) {
              updates['dislikedBy'] = FieldValue.arrayRemove([currentUid]);
              updates['dislikes'] = (data['dislikes'] as int? ?? 0) - 1;
            }
          }
        } else {
          if (currentlyDisliked) {
            updates['dislikedBy'] = FieldValue.arrayRemove([currentUid]);
            updates['dislikes'] = (data['dislikes'] as int? ?? 0) - 1;
          } else {
            updates['dislikedBy'] = FieldValue.arrayUnion([currentUid]);
            updates['dislikes'] = (data['dislikes'] as int? ?? 0) + 1;
            createdNewDislike = true;
            if (currentlyLiked) {
              updates['likedBy'] = FieldValue.arrayRemove([currentUid]);
              updates['likes'] = (data['likes'] as int? ?? 0) - 1;
            }
          }
        }

        tx.update(widget.replyRef, updates);

        final ownerId = (data['userId'] as String?);
        if (ownerId != null && ownerId != currentUid) {
          if (createdNewLike) {
            await _notifyOnReaction(ownerId, 'reply_like');
          } else if (createdNewDislike) {
            await _notifyOnReaction(ownerId, 'reply_dislike');
          }
        }
      });
    } catch (_) {
      // Silent failure; optimistic UI remains.
    }
  }

  Future<void> _notifyOnReaction(String toUserId, String type) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    await FirebaseFirestore.instance.collection('notifications').add({
      'toUserId': toUserId,
      'fromUserId': currentUid,
      'replyId': widget.replyId,
      'type': type,
      'title': type == 'reply_like'
          ? 'Someone liked your reply'
          : 'Someone disliked your reply',
      'body': '',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // OneSignal (best effort)
    final uSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(toUserId)
        .get();
    final playerId = (uSnap.data() ?? const {})['playerId'] as String?;
    if (playerId == null || playerId.isEmpty) return;

    final uri = Uri.parse('https://api.onesignal.com/notifications');
    final payload = {
      'app_id': OneSignalConfig.appId,
      'include_player_ids': [playerId],
      'headings': {'en': type == 'reply_like' ? 'New like' : 'New dislike'},
      'contents': {
        'en': type == 'reply_like'
            ? 'Someone liked your reply'
            : 'Someone disliked your reply',
      },
      'data': {'replyId': widget.replyId, 'type': type},
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
}

class ReplyAvatar extends StatelessWidget {
  final String? uid;

  const ReplyAvatar({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return CircleAvatar(
        radius: 10,
        backgroundColor: UserColors.getBackgroundColorForUser(''),
        child: Icon(
          FluentSystemIcons.ic_fluent_person_filled,
          size: 12,
          color: UserColors.getIconColorForUser(''),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final u = snap.data?.data();
        final photo = (u?['photoUrl'] as String?) ?? (u?['avatar'] as String?);
        final isDeveloper = (u?['isDeveloper'] as bool?) ?? false;

        return Stack(
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: UserColors.getBackgroundColorForUser(uid),
              backgroundImage: photo != null
                  ? CachedNetworkImageProvider(photo)
                  : null,
              child: photo == null
                  ? Icon(
                      FluentSystemIcons.ic_fluent_person_filled,
                      size: 12,
                      color: UserColors.getIconColorForUser(uid),
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
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Icon(Icons.verified, color: Colors.green, size: 10),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ReplyName extends StatelessWidget {
  final String? uid;

  const ReplyName({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Text(
        'Someone',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final u = snap.data?.data();
        final name =
            (u?['name'] as String?) ??
            (u?['displayName'] as String?) ??
            'Someone';
        final isDeveloper = (u?['isDeveloper'] as bool?) ?? false;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isDeveloper) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Colors.green, size: 12),
            ],
          ],
        );
      },
    );
  }
}
