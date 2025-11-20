// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'dart:convert';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/custom_textfield.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:devlink/widgets/reply_tile.dart';
import 'package:devlink/services/image_upload_service.dart';
import 'package:devlink/config/oneSignal_config.dart';

class RepliesSheet extends StatefulWidget {
  final DocumentReference postRef;
  final String? initialQuotedUserId;
  final String? initialQuotedPreview;

  const RepliesSheet({
    super.key,
    required this.postRef,
    this.initialQuotedUserId,
    this.initialQuotedPreview,
  });

  @override
  State<RepliesSheet> createState() => _RepliesSheetState();
}

class _RepliesSheetState extends State<RepliesSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  final List<XFile> _pendingImages = <XFile>[];
  final List<String> _pendingLinks = <String>[];
  bool _inputIsTall = false;
  String? _replyingToUserId;
  String? _replyingToName;
  String? _replyingToPreview;
  String? _replyingToReplyId;
  bool _canReply = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recalcInputLines);
    // If opened with a target user to reply to, prefill mention and banner.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuotedUserId != null) {
        _replyTo(widget.initialQuotedUserId, widget.initialQuotedPreview);
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

  void _insertCodeBlock() {
    const snippet = '\n```\n\n```';
    final current = _controller.text;
    if (current.trim().isEmpty) {
      _controller.text = snippet.trimLeft();
    } else {
      _controller.text = '$current$snippet';
    }
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  List<Map<String, dynamic>> _threadReplies(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final items = <Map<String, dynamic>>[];
    final all = docs.map((d) => {'data': d.data(), 'id': d.id}).toList()
      ..sort((a, b) {
        final ta =
            (a['data'] as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
        final tb =
            (b['data'] as Map<String, dynamic>?)?['createdAt'] as Timestamp?;
        final da = ta?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = tb?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });

    // top-level replies have no quotedReplyId
    final topLevel = all
        .where(
          (e) => (e['data'] as Map<String, dynamic>?)?['quotedReplyId'] == null,
        )
        .toList();
    for (final parent in topLevel) {
      items.add({
        'data': parent['data'] as Map<String, dynamic>,
        'isChild': false,
        'id': parent['id'],
      });
      final parentId = parent['id'] as String;
      final children =
          all
              .where(
                (e) =>
                    (e['data'] as Map<String, dynamic>?)?['quotedReplyId'] ==
                    parentId,
              )
              .toList()
            ..sort((a, b) {
              final ta =
                  (a['data'] as Map<String, dynamic>?)?['createdAt']
                      as Timestamp?;
              final tb =
                  (b['data'] as Map<String, dynamic>?)?['createdAt']
                      as Timestamp?;
              final da = ta?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              final db = tb?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
              return da.compareTo(db);
            });
      for (final child in children) {
        items.add({
          'data': child['data'] as Map<String, dynamic>,
          'isChild': true,
          'id': child['id'],
        });
      }
    }

    // Orphans (children whose parent wasn't found among top-level) go at the end
    final usedIds = items
        .map((e) => e['id'] as String?)
        .whereType<String>()
        .toSet();
    for (final e in all) {
      final id = e['id'] as String;
      if (!usedIds.contains(id)) {
        items.add({
          'data': e['data'] as Map<String, dynamic>,
          'isChild': false,
          'id': id,
        });
      }
    }
    return items;
  }

  Future<void> _notifyOnReply({
    required DocumentReference parentRef,
    required String replyText,
    String? quotedUserId,
    String? replyId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final currentUserData = currentUserDoc.data() ?? {};
    final currentUserName =
        currentUserData['name'] ??
        currentUserData['displayName'] ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'Someone';

    final parentSnap = await parentRef.get();
    final parent = parentSnap.data() as Map<String, dynamic>? ?? {};
    final postOwnerId = parent['userId'] as String?;

    final recipients = <String>{};
    if (postOwnerId != null && postOwnerId != uid) recipients.add(postOwnerId);
    if (quotedUserId != null && quotedUserId != uid) {
      recipients.add(quotedUserId);
    }
    await _addDeveloperRecipients(recipients, uid);
    if (recipients.isEmpty) return;

    for (final toUserId in recipients) {
      final notif = {
        'toUserId': toUserId,
        'fromUserId': uid,
        'postId': parentRef.id,
        if (replyId != null) 'replyId': replyId,
        'type': 'reply',
        'title': toUserId == quotedUserId
            ? '$currentUserName replied to your comment'
            : '$currentUserName replied to your post',
        'body': _stripLeadingMention(replyText).isNotEmpty
            ? _stripLeadingMention(replyText)
            : 'Someone replied',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('notifications').add(notif);

      final uSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(toUserId)
          .get();
      final playerId = (uSnap.data() ?? const {})['playerId'] as String?;
      if (playerId == null || playerId.isEmpty) continue;

      await _sendOneSignal(
        includePlayerIds: [playerId],
        title: toUserId == quotedUserId
            ? '$currentUserName replied to your comment'
            : '$currentUserName replied to your post',
        body: _stripLeadingMention(replyText).isNotEmpty
            ? _stripLeadingMention(replyText)
            : 'Someone replied',
        data: {'postId': parentRef.id, 'type': 'reply'},
      );
    }
  }

  String _stripLeadingMention(String text) {
    // Remove a leading @Name or @First Last plus trailing space
    return text.replaceFirst(RegExp(r'^@[A-Za-z]+(?:\s+[A-Za-z]+)?\s*'), '');
  }

  Future<void> _addDeveloperRecipients(
    Set<String> recipients,
    String currentUserId,
  ) async {
    try {
      final developersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('isDeveloper', isEqualTo: true)
          .where('notificationsEnabled', isEqualTo: true)
          .where('notifyFromAll', isEqualTo: true)
          .get();

      for (final doc in developersQuery.docs) {
        final developerId = doc.id;
        if (developerId != currentUserId) {
          recipients.add(developerId);
        }
      }
    } catch (_) {}
  }

  Future<void> _sendOneSignal({
    required List<String> includePlayerIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final uri = Uri.parse('https://api.onesignal.com/notifications');
    final payload = {
      'app_id': OneSignalConfig.appId,
      'include_player_ids': includePlayerIds,
      'headings': {'en': title},
      'contents': {'en': body},
      if (data != null) 'data': data,
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

  Future<void> _replyTo(
    String? uid, [
    String? preview,
    String? parentReplyId,
  ]) async {
    _focusNode.requestFocus();
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final u = snap.data() ?? {};
      final name =
          (u['name'] as String?) ?? (u['displayName'] as String?) ?? 'user';
      final mention = '@$name ';
      final t = _controller.text;
      if (!t.startsWith(mention)) {
        _controller.text = '$mention$t';
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
      setState(() {
        _replyingToUserId = uid;
        _replyingToName = name;
        _replyingToPreview = preview;
        _replyingToReplyId = parentReplyId;
      });
    } catch (_) {
      // best-effort; ignore failures
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        widthFactor: 1.0,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surface
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: AnimatedPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Replies',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: widget.postRef
                        .collection('replies')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return SizedBox.shrink();
                      }

                      final replies = snap.data?.docs ?? [];
                      if (replies.isEmpty) {
                        return const Center(child: Text('No replies yet'));
                      }

                      final threaded = _threadReplies(replies);
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                        itemCount: threaded.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = threaded[i];
                          final data = item['data'] as Map<String, dynamic>;
                          final isChild = item['isChild'] as bool;
                          final quotedUserId = data['quotedUserId'] as String?;
                          final replyId = item['id'] as String;
                          return ReplyTile(
                            data: data,
                            isChild: isChild,
                            quotedUserId: quotedUserId,
                            replyId: replyId,
                            replyRef: widget.postRef
                                .collection('replies')
                                .doc(replyId),
                            onReply: (uid, preview, parentReplyId) =>
                                _replyTo(uid, preview, parentReplyId),
                            canReply: _canReply,
                          );
                        },
                      );
                    },
                  ),
                ),
                // Inline composer
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyingToUserId != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '@${_replyingToName ?? 'user'}',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if ((_replyingToPreview ?? '').isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            _replyingToPreview!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                                  .withOpacity(0.9),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _replyingToUserId = null;
                                      _replyingToName = null;
                                      _replyingToPreview = null;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                        if (_pendingImages.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              height: 76,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _pendingImages.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  final f = _pendingImages[i];
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(f.path),
                                          width: 76,
                                          height: 76,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: -2,
                                        right: -1,
                                        child: Material(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: () => setState(
                                              () => _pendingImages.removeAt(i),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(2),
                                              child: Icon(
                                                Icons.close,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onError,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        if (_pendingLinks.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _pendingLinks.asMap().entries.map((e) {
                                final i = e.key;
                                final link = e.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.link,
                                        size: 18,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          link,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                        onPressed: () => setState(
                                          () => _pendingLinks.removeAt(i),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: _inputIsTall ? 0 : 144,
                              child: _inputIsTall
                                  ? const SizedBox.shrink()
                                  : Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.image),
                                          onPressed: _sending
                                              ? null
                                              : () => _pickImageSource(),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.link),
                                          onPressed: _sending
                                              ? null
                                              : () => _promptForLink(),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.code),
                                          onPressed: _sending
                                              ? null
                                              : _insertCodeBlock,
                                        ),
                                      ],
                                    ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                minLines: 1,
                                maxLines: 5,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Write a reply...',
                                  hintStyle: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.surfaceVariant
                                      : Colors.grey.shade200,
                                  border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_inputIsTall) ...[
                                  IconButton(
                                    icon: const Icon(Icons.image),
                                    onPressed: _sending
                                        ? null
                                        : () => _pickImageSource(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.link),
                                    onPressed: _sending
                                        ? null
                                        : () => _promptForLink(),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.code),
                                    onPressed: _sending
                                        ? null
                                        : _insertCodeBlock,
                                  ),
                                ],
                                IconButton(
                                  icon: _sending
                                      ? Loading.medium(color: primaryColor)
                                      : Icon(
                                          FluentSystemIcons
                                              .ic_fluent_send_filled,
                                          color: primaryColor,
                                        ),
                                  onPressed: _sending ? null : _sendReply,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _recalcInputLines() {
    if (!mounted) return;
    // Approximate available width for the TextField content.
    final screenWidth = MediaQuery.of(context).size.width;
    // Account for horizontal padding (12 + 12) and send button width + spacing.
    const sidePadding = 24.0;
    const sendButtonWidth = 48.0;
    const spacing = 12.0;
    final maxWidth = screenWidth - sidePadding - sendButtonWidth - spacing;

    final textStyle = const TextStyle(fontSize: 14);
    final tp = TextPainter(
      text: TextSpan(text: _controller.text, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 5,
    );
    tp.layout(maxWidth: maxWidth);
    final lineCount = tp.computeLineMetrics().length;
    final tall = lineCount > 2;
    if (tall != _inputIsTall) {
      setState(() => _inputIsTall = tall);
    }
  }

  Future<void> _pickImageSource() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant,
                    child: Icon(
                      Icons.photo_library,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant,
                    child: Icon(
                      Icons.photo_camera,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      if (!mounted) return;
      setState(() => _pendingImages.add(file));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  Future<void> _promptForLink() async {
    final controller = TextEditingController();

    final link = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Add Link',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: controller,
                  hintText: 'https://...',
                  prefixIcon: Icons.link,
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a link';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),

                    TextButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      child: const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.w600),
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

    if (link != null && link.isNotEmpty) {
      setState(
        () => _pendingLinks.add(link),
      ); // or handle your link however needed
    }
  }

  Future<void> _sendReply() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to reply.')),
      );
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    setState(() => _sending = true);
    try {
      // Upload images (if any)
      List<String> imageUrls = [];
      for (final x in _pendingImages) {
        final url = await ImageUploadService.instance.uploadImage(File(x.path));
        imageUrls.add(url);
      }
      final replyRef = await widget.postRef.collection('replies').add({
        'userId': uid,
        'text': text,
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (_pendingLinks.isNotEmpty) 'links': _pendingLinks,
        if (_replyingToUserId != null) 'quotedUserId': _replyingToUserId,
        if (_replyingToReplyId != null) 'quotedReplyId': _replyingToReplyId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // increment replyCount
      await widget.postRef.update({'replyCount': FieldValue.increment(1)});
      try {
        await _notifyOnReply(
          parentRef: widget.postRef,
          replyText: text,
          quotedUserId: _replyingToUserId,
          replyId: replyRef.id,
        );
      } catch (_) {}
      _controller.clear();
      setState(() {
        _pendingImages.clear();
        _pendingLinks.clear();
        _replyingToUserId = null;
        _replyingToName = null;
        _replyingToPreview = null;
        _replyingToReplyId = null;
      });
      _focusNode.requestFocus();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
