// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/models/post.dart';
import 'package:devlink/services/image_upload_service.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:devlink/widgets/custom_textfield.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:devlink/config/oneSignal_config.dart';

class PostComposerSheet extends StatefulWidget {
  final DocumentReference? parentRef;
  final Map<String, dynamic>? quoted; // optional quoted reply data
  final DocumentReference? editPostRef; // for editing existing posts
  final String? editText; // initial text for editing
  final List<String>? editImageUrls; // existing image URLs for editing

  const PostComposerSheet({
    super.key,
    this.parentRef,
    this.quoted,
    this.editPostRef,
    this.editText,
    this.editImageUrls,
  });

  const PostComposerSheet.reply({
    super.key,
    required this.parentRef,
    this.quoted,
  }) : editPostRef = null,
       editText = null,
       editImageUrls = null;

  const PostComposerSheet.edit({
    super.key,
    required this.editPostRef,
    required this.editText,
    this.editImageUrls,
  }) : parentRef = null,
       quoted = null;

  @override
  State<PostComposerSheet> createState() => _PostComposerSheetState();
}

class _QuotedReplyBox extends StatelessWidget {
  final Map<String, dynamic> data;
  const _QuotedReplyBox({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = data['userId'] as String?;
    final text = data['text'] as String?;
    final createdAt = data['createdAt'] as Timestamp?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: uid == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
            builder: (context, snap) {
              final u = snap.data?.data();
              final photo =
                  (u?['photoUrl'] as String?) ?? (u?['avatar'] as String?);
              return CircleAvatar(
                radius: 14,
                backgroundImage: photo != null ? CachedNetworkImageProvider(photo) : null,
                child: photo == null
                    ? Icon(
                        FluentSystemIcons.ic_fluent_person_filled,
                        size: 16,
                        color: UserColors.getIconColorForUser(
                          FirebaseAuth.instance.currentUser?.uid ?? '',
                        ),
                      )
                    : null,
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: uid == null
                          ? const Stream.empty()
                          : FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .snapshots(),
                      builder: (context, snap) {
                        final u = snap.data?.data();
                        final name =
                            (u?['name'] as String?) ??
                            (u?['displayName'] as String?) ??
                            'User';
                        return Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _ago(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                if (text != null && text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _ago(Timestamp? ts) {
  if (ts == null) return '';
  final dt = ts.toDate();
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

class _PostComposerSheetState extends State<PostComposerSheet> {
  final _text = TextEditingController();
  final _linkField = TextEditingController();
  final _picker = ImagePicker();

  final List<File> _images = [];
  final List<String> _links = [];
  final List<String> _existingImageUrls =
      []; // For existing images when editing
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Set initial text if editing
    if (widget.editText != null) {
      _text.text = widget.editText!;
    }
    // Load existing images if provided
    if (widget.editImageUrls != null) {
      _existingImageUrls.addAll(widget.editImageUrls!);
    }
    // Load existing post data if editing
    if (widget.editPostRef != null) {
      _loadExistingPostData();
    }
  }

  Future<void> _loadExistingPostData() async {
    try {
      final doc = await widget.editPostRef!.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          // Load existing links
          final existingLinks = data['links'] as List<dynamic>?;
          if (existingLinks != null) {
            _links.addAll(existingLinks.cast<String>());
          }
          // Load existing images if not already loaded from constructor
          if (_existingImageUrls.isEmpty) {
            final existingImages = data['imageUrls'] as List<dynamic>?;
            if (existingImages != null) {
              _existingImageUrls.addAll(existingImages.cast<String>());
            }
          }
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      print('Error loading existing post data: $e');
    }
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

  void _insertCodeBlock() {
    const snippet = '```\n\n\n```';
    final current = _text.text;
    if (current.trim().isEmpty) {
      _text.text = snippet.trimLeft();
    } else {
      _text.text = '$current$snippet';
    }
    _text.selection = TextSelection.fromPosition(
      TextPosition(offset: _text.text.length),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _linkField.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() {
      _images.addAll(files.map((x) => File(x.path)));
    });
  }

  Future<void> _pickFromCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(() => _images.add(File(x.path)));
  }

  Future<void> _addLink() async {
    _linkField.clear();
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste link',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              CustomTextField(controller: _linkField, hintText: 'https://...'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      final v = _linkField.text.trim();
                      if (v.isNotEmpty) {
                        setState(() => _links.add(v));
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _notifyOnReply({
    required DocumentReference parentRef,
    required String replyText,
    Map<String, dynamic>? quoted,
    String? replyId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Get the current user's name from Firestore
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
    final quotedUserId = quoted != null ? quoted['userId'] as String? : null;
    if (quotedUserId != null && quotedUserId != uid) {
      recipients.add(quotedUserId);
    }

    // Add developers who want notifications from all users
    await _addDeveloperRecipients(recipients, uid);

    if (recipients.isEmpty) return;

    for (final toUserId in recipients) {
      final notif = {
        'toUserId': toUserId,
        'fromUserId': uid,
        'postId': parentRef.id,
        if (replyId != null) 'replyId': replyId,
        'type': 'reply',
        'title': '$currentUserName replied to your post',
        'body': replyText.isNotEmpty ? replyText : 'Someone replied',
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
        title: '$currentUserName replied to your post',
        body: replyText.isNotEmpty ? replyText : 'Someone replied',
        data: {'postId': parentRef.id, 'type': 'reply'},
      );
    }
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
    } catch (e) {
      print('Error adding developer recipients: $e');
    }
  }

  Future<void> _notifyOnNewPost({
    required String postId,
    required String postText,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Get the current user's name from Firestore
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

    final recipients = <String>{};

    // Add developers who want notifications from all users
    await _addDeveloperRecipients(recipients, uid);

    if (recipients.isEmpty) return;

    for (final toUserId in recipients) {
      final notif = {
        'toUserId': toUserId,
        'fromUserId': uid,
        'postId': postId,
        'type': 'post',
        'title': 'New post from $currentUserName',
        'body': postText.isNotEmpty ? postText : 'Someone created a new post',
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
        title: '$currentUserName created a new post',
        body: postText.isNotEmpty ? postText : 'Someone created a new post',
        data: {'postId': postId, 'type': 'post'},
      );
    }
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

      final resp = await req.close();

      if (resp.statusCode == 200) {
        print('Notification sent successfully.');
      } else {
        print('Failed to send notification. Status code: ${resp.statusCode}');
        final responseBody = await resp.transform(utf8.decoder).join();
        print('Response: $responseBody');
      }
    } catch (e, stackTrace) {
      print('Error sending OneSignal notification: $e');
      print(stackTrace);
    } finally {
      client.close();
    }
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    // For editing, allow submission even if everything is empty (for deletions)
    // For new posts, require at least some content
    if (widget.editPostRef == null &&
        text.isEmpty &&
        _images.isEmpty &&
        _links.isEmpty &&
        _existingImageUrls.isEmpty) {
      return;
    }
    setState(() => _loading = true);
    try {
      // If editing existing post
      if (widget.editPostRef != null) {
        // Upload new images if any
        final newImageUrls = <String>[];
        for (final f in _images) {
          final url = await ImageUploadService.instance.uploadImage(f);
          newImageUrls.add(url);
        }

        // Combine existing images (that weren't removed) with new images
        final allImageUrls = <String>[];
        allImageUrls.addAll(
          _existingImageUrls,
        ); // Only remaining existing images
        allImageUrls.addAll(newImageUrls); // Plus new images

        // Prepare update data - always update all fields to handle removals
        // Use FieldValue.delete() for empty arrays to properly remove fields
        final updateData = <String, dynamic>{
          'text': text.isEmpty ? FieldValue.delete() : text,
          'imageUrls': allImageUrls.isEmpty
              ? FieldValue.delete()
              : allImageUrls,
          'links': _links.isEmpty ? FieldValue.delete() : _links,
        };

        // Remove null values to clean up empty fields
        updateData.removeWhere((key, value) => value == null);

        await widget.editPostRef!.update(updateData);
        if (mounted) Navigator.pop(context, true);
        return;
      }

      // Upload images
      final urls = <String>[];
      for (final f in _images) {
        final url = await ImageUploadService.instance.uploadImage(f);
        urls.add(url);
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      // If replying, write to replies subcollection and increment parent replyCount
      if (widget.parentRef != null) {
        String? replyId;
        await FirebaseFirestore.instance.runTransaction((tx) async {
          // READ FIRST
          final parentSnap = await tx.get(widget.parentRef!);
          final parentData = parentSnap.data() as Map<String, dynamic>?;
          final current = (parentData?['replyCount'] as int?) ?? 0;

          // THEN WRITE(S)
          final replyRef = widget.parentRef!.collection('replies').doc();
          replyId = replyRef.id; // Store the reply ID
          tx.set(
            replyRef,
            {
              'text': text.isEmpty ? null : text,
              'imageUrls': urls.isEmpty ? null : urls,
              'links': _links.isEmpty ? null : _links,
              'userId': uid,
              'quotedUserId': (widget.quoted != null)
                  ? widget.quoted!['userId'] as String?
                  : null,
              'createdAt': FieldValue.serverTimestamp(),
            }..removeWhere((key, value) => value == null),
          );

          tx.update(widget.parentRef!, {'replyCount': current + 1});
        });

        // Fire-and-forget notifications and push after the transaction
        try {
          await _notifyOnReply(
            parentRef: widget.parentRef!,
            replyText: text,
            quoted: widget.quoted,
            replyId: replyId,
          );
        } catch (_) {}
      } else {
        final user = FirebaseAuth.instance.currentUser;
        final post = Post(
          text: text.isEmpty ? null : text,
          imageUrls: urls,
          links: _links,
          userId: uid,
          authorName: user?.displayName,
          authorPhotoUrl: user?.photoURL,
        );
        final postRef = await FirebaseFirestore.instance
            .collection('posts')
            .add(post.toMap());

        // Notify developers who want notifications from all users
        try {
          await _notifyOnNewPost(postId: postRef.id, postText: text);
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      print(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + viewInsets),
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.parentRef == null ? 'Create Post' : 'Reply',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.parentRef != null) ...[
                  if (widget.quoted != null)
                    _QuotedReplyBox(data: widget.quoted!)
                  else
                    StreamBuilder<DocumentSnapshot>(
                      stream: widget.parentRef!.snapshots(),
                      builder: (context, snap) {
                        final d = snap.data?.data() as Map<String, dynamic>?;
                        if (d == null) return const SizedBox.shrink();
                        final name = (d['authorName'] as String?) ?? 'User';
                        final photo = d['authorPhotoUrl'] as String?;
                        final text = d['text'] as String?;
                        final createdAt = d['createdAt'] as Timestamp?;
                        final images =
                            (d['imageUrls'] as List?)?.cast<String>() ??
                            const [];
                        final String? firstImg = images.isNotEmpty
                            ? images.first
                            : null;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundImage: photo != null
                                        ? CachedNetworkImageProvider(photo)
                                        : null,
                                    child: photo == null
                                        ? Icon(
                                            FluentSystemIcons.ic_fluent_person_filled,
                                            size: 14,
                                            color: UserColors.getIconColorForUser(
                                              (widget.quoted?['userId'] as String?) ?? '',
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$name · ${_timeAgo(createdAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (text != null && text.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (firstImg != null) ...[
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: firstImg,
                                    height: 80,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 4),
                ],
                TextField(
                  controller: _text,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText:
                        'Describe your issue, paste code, or ask a question...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Images preview
                if (_existingImageUrls.isNotEmpty || _images.isNotEmpty) ...[
                  SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _existingImageUrls.length + _images.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        // Show existing images first, then new images
                        if (i < _existingImageUrls.length) {
                          final imageUrl = _existingImageUrls[i];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 160,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: InkWell(
                                  onTap: () => setState(
                                    () => _existingImageUrls.removeAt(i),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.scrim.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onInverseSurface,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          // New images
                          final fileIndex = i - _existingImageUrls.length;
                          final file = _images[fileIndex];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  file,
                                  width: 160,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: InkWell(
                                  onTap: () => setState(
                                    () => _images.removeAt(fileIndex),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Links list
                if (_links.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < _links.length; i++)
                        Chip(
                          label: SizedBox(
                            width: 160,
                            child: Text(
                              _links[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _links.removeAt(i)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                Row(
                  children: [
                    IconButton(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.photo_camera),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addLink,
                      icon: const Icon(Icons.link),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _insertCodeBlock,
                      icon: const Icon(Icons.code),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _loading
                            ? Loading.medium(color: primaryColor)
                            : Text(
                                widget.editPostRef != null
                                    ? 'Save'
                                    : (widget.parentRef == null
                                          ? 'Post'
                                          : 'Reply'),
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
  }
}
