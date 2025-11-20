// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/config/oneSignal_config.dart';
import 'package:devlink/services/image_upload_service.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/fullscreen_image_viewer.dart';
import 'package:devlink/widgets/post_image_gallery.dart';
import 'package:devlink/widgets/shimmers.dart';
import 'package:devlink/widgets/user_picker_bottom_sheet.dart';
import 'package:devlink/utility/code_text_formatter.dart';
import 'package:devlink/widgets/code_block.dart';
import 'package:devlink/screens/post_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CoversationScreen extends StatefulWidget {
  final String peerUserId;
  final String? peerName;
  final String? peerPhoto;

  const CoversationScreen({
    super.key,
    required this.peerUserId,
    this.peerName,
    this.peerPhoto,
  });

  @override
  State<CoversationScreen> createState() => _CoversationScreenState();
}

class _CoversationScreenState extends State<CoversationScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  DocumentReference<Map<String, dynamic>>? _conversationRef;
  final List<XFile> _pendingImages = <XFile>[];
  final List<String> _pendingLinks = <String>[];
  bool _inputIsTall = false;
  bool _hasMarkedRead = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedMessages = const [];
  final Map<String, DocumentReference<Map<String, dynamic>>>
  _selectedMessageRefs = {};
  final Map<String, String> _selectedMessageTexts = {};
  final Map<String, bool> _selectedIsMineMap = {};

  String? _editingMessageId;
  DocumentReference<Map<String, dynamic>>? _editingMessageRef;

  bool get _isEditing => _editingMessageId != null;

  bool get _hasSelection => _selectedMessageRefs.isNotEmpty;
  int get _selectedCount => _selectedMessageRefs.length;

  bool get _canDeleteForEveryone {
    if (!_hasSelection || _selectedIsMineMap.isEmpty) return false;
    return _selectedIsMineMap.values.every((v) => v);
  }

  void _insertCodeBlock() {
    const snippet =
        '\n\n```\n// Paste your code snippet here and edit before sending\n```';
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

  String? get _singleSelectedId =>
      _selectedMessageRefs.length == 1 ? _selectedMessageRefs.keys.first : null;

  bool get _canEditSelected {
    final id = _singleSelectedId;
    if (id == null) return false;
    final isMine = _selectedIsMineMap[id] ?? false;
    final text = _selectedMessageTexts[id]?.trim() ?? '';
    return isMine && text.isNotEmpty;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _getOrCreateConversationWith(
    String peerUserId,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return null;

    try {
      final ids = [currentUserId, peerUserId]..sort();
      final pairKey = '${ids[0]}_${ids[1]}';

      final query = await FirebaseFirestore.instance
          .collection('conversations')
          .where('pairKey', isEqualTo: pairKey)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.reference;
      }

      final ref = FirebaseFirestore.instance.collection('conversations').doc();
      await ref.set({
        'pairKey': pairKey,
        'participants': ids,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageText': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': currentUserId,
        'unreadCounts': {currentUserId: 0, peerUserId: 0},
      });
      return ref;
    } catch (e, st) {
      debugPrint('Error in _getOrCreateConversationWith: $e');
      debugPrint('Stack: $st');
      return null;
    }
  }

  Future<void> _forwardMessagesToUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final convRef = await _getOrCreateConversationWith(targetUserId);
    if (convRef == null) return;

    final batch = FirebaseFirestore.instance.batch();

    String lastPreview = '';
    for (final entry in _selectedMessageRefs.entries) {
      final id = entry.key;
      final text = (_selectedMessageTexts[id] ?? '').trim();
      if (text.isEmpty) continue;
      final msgRef = convRef.collection('messages').doc();
      batch.set(msgRef, {
        'text': text,
        'senderId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isForward': true,
      });
      lastPreview = text;
    }

    if (lastPreview.isEmpty) return;

    batch.update(convRef, {
      'lastMessageText': lastPreview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': currentUserId,
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts.$targetUserId': FieldValue.increment(1),
      'unreadCounts.$currentUserId': 0,
    });

    try {
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message forwarded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to forward: $e')));
      }
    } finally {
      _clearSelection();
    }
  }

  Future<void> _showForwardBottomSheet() async {
    final result = await showFollowersFollowingPickerBottomSheet(
      context,
      actionIcon: FluentSystemIcons.ic_fluent_arrow_enter_filled,
    );
    if (result == null) return;
    await _forwardMessagesToUser(result.userId);
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recalcInputLines);
    _initConversation();
  }

  Future<void> _initConversation() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;
    try {
      final ids = [currentUserId, widget.peerUserId]..sort();
      final pairKey = '${ids[0]}_${ids[1]}';

      final query = await FirebaseFirestore.instance
          .collection('conversations')
          .where('pairKey', isEqualTo: pairKey)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        setState(() {
          _conversationRef = query.docs.first.reference;
        });
        return;
      }

      final ref = FirebaseFirestore.instance.collection('conversations').doc();
      await ref.set({
        'pairKey': pairKey,
        'participants': ids,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessageText': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': currentUserId,
        'unreadCounts': {currentUserId: 0, widget.peerUserId: 0},
      });
      setState(() {
        _conversationRef = ref;
      });
    } catch (e, st) {
      debugPrint('🔥 Error in _initConversation: $e');
      debugPrint('Stack: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open chat. Please try again.'),
          ),
        );
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageRefs.clear();
      _selectedMessageTexts.clear();
      _selectedIsMineMap.clear();
    });
  }

  void _onMessageLongPress(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String currentUserId,
  ) {
    final data = doc.data();
    final text = (data['text'] as String?) ?? '';
    final senderId = data['senderId'] as String?;
    final id = doc.id;
    setState(() {
      if (_selectedMessageRefs.containsKey(id)) {
        _selectedMessageRefs.remove(id);
        _selectedMessageTexts.remove(id);
        _selectedIsMineMap.remove(id);
      } else {
        _selectedMessageRefs[id] = doc.reference;
        _selectedMessageTexts[id] = text;
        _selectedIsMineMap[id] = senderId == currentUserId;
      }
    });
  }

  Future<void> _handleCopySelected() async {
    final texts = _selectedMessageTexts.values
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (texts.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texts.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message copied')));
    _clearSelection();
  }

  Future<void> _handleEditSelected() async {
    final id = _singleSelectedId;
    if (id == null) return;
    final ref = _selectedMessageRefs[id];
    if (ref == null) return;

    final oldText = _selectedMessageTexts[id] ?? '';

    setState(() {
      _editingMessageId = id;
      _editingMessageRef = ref;
      _controller.text = oldText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });

    _clearSelection();
  }

  Future<void> _handleForwardSelected() async {
    if (_selectedMessageRefs.isEmpty) return;
    await _showForwardBottomSheet();
  }

  Future<void> _handleDeleteSelected() async {
    if (_selectedMessageRefs.isEmpty) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final bool canDeleteForEveryone = _canDeleteForEveryone;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(12),
          ),
          title: const Text('Delete message?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('me'),
              child: const Text('Delete for me'),
            ),
            if (canDeleteForEveryone)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('everyone'),
                child: const Text(
                  'Delete for everyone',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'me') {
      for (final ref in _selectedMessageRefs.values) {
        try {
          await ref.update({
            'deletedFor': FieldValue.arrayUnion([currentUserId]),
          });
        } catch (_) {}
      }
    } else if (result == 'everyone' && canDeleteForEveryone) {
      _selectedMessageRefs.forEach((id, ref) async {
        final isMine = _selectedIsMineMap[id] ?? false;
        if (!isMine) return;
        try {
          await ref.delete();
        } catch (_) {}
      });
    }

    if (!mounted) return;
    _clearSelection();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingImages.isEmpty && _pendingLinks.isEmpty) ||
        _sending ||
        _conversationRef == null) {
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Editing existing message
    if (_editingMessageRef != null) {
      final ref = _editingMessageRef!;
      try {
        await ref.update({'text': text, 'isEdited': true});
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Message edited')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to edit: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _editingMessageId = null;
            _editingMessageRef = null;
            _controller.clear();
            _pendingImages.clear();
            _pendingLinks.clear();
            _inputIsTall = false;
          });
        }
      }
      return;
    }

    setState(() => _sending = true);

    try {
      final msgRef = _conversationRef!.collection('messages').doc();

      // Upload images (if any)
      final List<String> imageUrls = [];
      for (final x in _pendingImages) {
        final url = await ImageUploadService.instance.uploadImage(File(x.path));
        imageUrls.add(url);
      }

      final messagePreview = text.isNotEmpty
          ? text
          : (imageUrls.isNotEmpty
                ? '[Photo]'
                : (_pendingLinks.isNotEmpty ? _pendingLinks.first : ''));

      await msgRef.set({
        'text': text,
        'senderId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (_pendingLinks.isNotEmpty) 'links': _pendingLinks,
      });

      await _conversationRef!.update({
        'lastMessageText': messagePreview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.${widget.peerUserId}': FieldValue.increment(1),
        'unreadCounts.$currentUserId': 0,
      });

      await _notifyOnMessage(messagePreview);

      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      // ignore errors for now
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _controller.clear();
          _pendingImages.clear();
          _pendingLinks.clear();
          _inputIsTall = false;
        });
      }
    }
  }

  Future<void> _notifyOnMessage(String messageText) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
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

      final uSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.peerUserId)
          .get();
      final playerId = (uSnap.data() ?? const {})['playerId'] as String?;
      if (playerId == null || playerId.isEmpty) return;

      await _sendOneSignal(
        includePlayerIds: [playerId],
        title: '$currentUserName sent you a message',
        body: messageText.isNotEmpty ? messageText : 'New message',
        data: {
          'type': 'chat',
          'conversationId': _conversationRef?.id,
          'fromUserId': uid,
        },
      );
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

  @override
  void dispose() {
    _controller.removeListener(_recalcInputLines);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: isDark ? scheme.surface : Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: _hasSelection
              ? IconButton(icon: Icon(Icons.close), onPressed: _clearSelection)
              : null,
          title: _hasSelection
              ? Text('$_selectedCount selected')
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.peerPhoto == null
                      ? null
                      : () {
                          final heroTag = 'peer_avatar_${widget.peerUserId}';
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FullscreenImageViewer(
                                imageUrl: widget.peerPhoto!,
                                heroTag: heroTag,
                              ),
                            ),
                          );
                        },
                  child: Row(
                    children: [
                      Hero(
                        tag: 'peer_avatar_${widget.peerUserId}',
                        child: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.1),
                          backgroundImage: widget.peerPhoto != null
                              ? CachedNetworkImageProvider(widget.peerPhoto!)
                              : null,
                          child: widget.peerPhoto == null
                              ? Icon(
                                  FluentSystemIcons.ic_fluent_person_filled,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.peerName ?? 'Conversation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          actions: _hasSelection
              ? [
                  IconButton(
                    icon: Icon(
                      FluentSystemIcons.ic_fluent_copy_regular,
                      size: 20,
                    ),
                    onPressed: _handleCopySelected,
                  ),
                  if (_canEditSelected)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: _handleEditSelected,
                    ),
                  IconButton(
                    icon: const Icon(Icons.reply, size: 20),
                    onPressed: _handleForwardSelected,
                  ),
                  IconButton(
                    icon: Icon(
                      FluentSystemIcons.ic_fluent_delete_regular,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: _handleDeleteSelected,
                  ),
                ]
              : null,
        ),
        body: Column(
          children: [
            Expanded(
              child: _conversationRef == null
                  ? const ShimmerConversationList(count: 8)
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _conversationRef!
                          .collection('messages')
                          .orderBy('createdAt', descending: false)
                          .snapshots(),
                      builder: (context, snap) {
                        // Avoid shimmer flicker during selection by using cache
                        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
                        if (snap.connectionState == ConnectionState.waiting &&
                            _cachedMessages.isNotEmpty) {
                          docs = _cachedMessages;
                        } else {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const ShimmerConversationList(count: 8);
                          }
                          docs = snap.data?.docs ?? [];
                          _cachedMessages = docs;
                        }

                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'Say hi 👋',
                              style: TextStyle(fontSize: 16),
                            ),
                          );
                        }
                        if (!_hasMarkedRead) {
                          _markMessagesAsRead(docs);
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data();
                            final senderId = data['senderId'] as String?;
                            final text = (data['text'] as String?) ?? '';
                            final postId = data['postId'] as String?;
                            final imageUrls =
                                (data['imageUrls'] as List<dynamic>?)
                                    ?.cast<String>() ??
                                const <String>[];
                            final links =
                                (data['links'] as List<dynamic>?)
                                    ?.cast<String>() ??
                                const <String>[];
                            final deletedFor =
                                (data['deletedFor'] as List<dynamic>?)
                                    ?.cast<String>() ??
                                const <String>[];
                            if (deletedFor.contains(currentUserId)) {
                              return const SizedBox.shrink();
                            }

                            final createdAtTs = data['createdAt'] as Timestamp?;
                            final createdAt = createdAtTs?.toDate();
                            final isRead = data['isRead'] as bool? ?? false;
                            final isMine = senderId == currentUserId;
                            final isForward =
                                data['isForward'] as bool? ?? false;
                            final isEdited = data['isEdited'] as bool? ?? false;

                            final hasOnlyImages =
                                imageUrls.isNotEmpty &&
                                text.isEmpty &&
                                links.isEmpty;

                            final isSelected = _selectedMessageRefs.containsKey(
                              docs[index].id,
                            );

                            // Determine if we need to show a date header like WhatsApp
                            DateTime? previousDate;
                            if (index > 0) {
                              final prevData = docs[index - 1].data();
                              final prevTs =
                                  prevData['createdAt'] as Timestamp?;
                              previousDate = prevTs?.toDate();
                            }
                            bool showDateHeader = false;
                            if (createdAt != null) {
                              if (previousDate == null) {
                                showDateHeader = true;
                              } else {
                                showDateHeader =
                                    createdAt.year != previousDate.year ||
                                    createdAt.month != previousDate.month ||
                                    createdAt.day != previousDate.day;
                              }
                            }

                            final bubbleRadius = BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMine ? 16 : 4),
                              bottomRight: Radius.circular(isMine ? 4 : 16),
                            );

                            Widget bubble = Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  padding: hasOnlyImages
                                      ? const EdgeInsets.all(2)
                                      : const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? primaryColor
                                        : (isDark
                                              ? theme.colorScheme.surfaceVariant
                                              : Colors.grey.shade200),
                                    borderRadius: bubbleRadius,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isForward) ...[
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              FluentSystemIcons
                                                  .ic_fluent_arrow_forward_regular,
                                              size: 14,
                                              color:
                                                  (isMine
                                                          ? Colors.white
                                                          : theme
                                                                .colorScheme
                                                                .onSurface)
                                                      .withOpacity(0.8),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Forwarded',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color:
                                                    (isMine
                                                            ? Colors.white
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface)
                                                        .withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      if (text.isNotEmpty)
                                        Builder(
                                          builder: (context) {
                                            // Check if this is a shared post
                                            if (postId != null &&
                                                text == '[Shared Post]') {
                                              return InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          PostDetailScreen(
                                                            postId: postId,
                                                          ),
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isMine
                                                        ? Colors.white
                                                              .withOpacity(0.2)
                                                        : theme
                                                              .colorScheme
                                                              .surfaceVariant,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: isMine
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.3,
                                                                )
                                                          : theme
                                                                .colorScheme
                                                                .outlineVariant,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        FluentSystemIcons
                                                            .ic_fluent_document_regular,
                                                        size: 20,
                                                        color: isMine
                                                            ? Colors.white
                                                            : theme
                                                                  .colorScheme
                                                                  .primary,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Shared Post',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: isMine
                                                                    ? Colors
                                                                          .white
                                                                    : theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              'Tap to view',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: isMine
                                                                    ? Colors
                                                                          .white
                                                                          .withOpacity(
                                                                            0.8,
                                                                          )
                                                                    : theme
                                                                          .colorScheme
                                                                          .onSurface
                                                                          .withOpacity(
                                                                            0.7,
                                                                          ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons.arrow_forward_ios,
                                                        size: 16,
                                                        color: isMine
                                                            ? Colors.white
                                                                  .withOpacity(
                                                                    0.7,
                                                                  )
                                                            : theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withOpacity(
                                                                    0.7,
                                                                  ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }

                                            final baseStyle = TextStyle(
                                              color: isMine
                                                  ? Colors.white
                                                  : theme.colorScheme.onSurface,
                                            );
                                            final codeStyle = baseStyle.copyWith(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                              backgroundColor:
                                                  (isMine
                                                          ? Colors.white
                                                          : theme
                                                                .colorScheme
                                                                .surfaceVariant)
                                                      .withOpacity(
                                                        isMine ? 0.08 : 0.4,
                                                      ),
                                            );

                                            // If the whole text is a single fenced block, render as a pure CodeBlock
                                            final fencedOnly =
                                                _extractFencedCode(text);
                                            if (fencedOnly != null) {
                                              final lang =
                                                  _extractFencedLanguage(text);
                                              return CodeBlock(
                                                code: fencedOnly,
                                                language: lang,
                                                backgroundColor:
                                                    isMine && !isDark
                                                    ? Colors.white
                                                    : null,
                                                textColor: isMine && !isDark
                                                    ? Colors.black87
                                                    : null,
                                                borderColor: isMine && !isDark
                                                    ? Colors.grey.shade300
                                                    : null,
                                              );
                                            }

                                            // Otherwise, if there is at least one fenced block, split text into
                                            // before / code / after and render the code part as a CodeBlock.
                                            final match = RegExp(
                                              r"```([\s\S]*?)```",
                                            ).firstMatch(text);
                                            if (match != null) {
                                              final before = text.substring(
                                                0,
                                                match.start,
                                              );
                                              final inner =
                                                  match.group(1) ?? '';
                                              String? lang;
                                              String codeSection = inner;
                                              final firstBreak = inner.indexOf(
                                                '\n',
                                              );
                                              if (firstBreak != -1) {
                                                final firstLine = inner
                                                    .substring(0, firstBreak)
                                                    .trim();
                                                final rest = inner.substring(
                                                  firstBreak + 1,
                                                );
                                                if (firstLine.isNotEmpty &&
                                                    !firstLine.contains(' ')) {
                                                  lang = firstLine;
                                                  codeSection = rest;
                                                }
                                              }
                                              final code = codeSection
                                                  .trimRight();
                                              final after = text.substring(
                                                match.end,
                                              );

                                              final children = <Widget>[];

                                              if (before.trim().isNotEmpty) {
                                                children.add(
                                                  SelectableText.rich(
                                                    TextSpan(
                                                      children:
                                                          CodeTextFormatter.buildSpans(
                                                            text: before
                                                                .trimRight(),
                                                            baseStyle:
                                                                baseStyle,
                                                            codeStyle:
                                                                codeStyle,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              }

                                              if (code.isNotEmpty) {
                                                children.add(
                                                  CodeBlock(
                                                    code: code,
                                                    language: lang,
                                                    backgroundColor:
                                                        isMine && !isDark
                                                        ? Colors.white
                                                        : null,
                                                    textColor: isMine && !isDark
                                                        ? Colors.black87
                                                        : null,
                                                    borderColor:
                                                        isMine && !isDark
                                                        ? Colors.grey.shade300
                                                        : null,
                                                  ),
                                                );
                                              }

                                              if (after.trim().isNotEmpty) {
                                                children.add(
                                                  SelectableText.rich(
                                                    TextSpan(
                                                      children:
                                                          CodeTextFormatter.buildSpans(
                                                            text: after
                                                                .trimLeft(),
                                                            baseStyle:
                                                                baseStyle,
                                                            codeStyle:
                                                                codeStyle,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              }

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: children,
                                              );
                                            }

                                            // No fenced blocks at all: fall back to inline/highlighted text rendering
                                            return SelectableText.rich(
                                              TextSpan(
                                                children:
                                                    CodeTextFormatter.buildSpans(
                                                      text: text,
                                                      baseStyle: baseStyle,
                                                      codeStyle: codeStyle,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      if (imageUrls.isNotEmpty) ...[
                                        if (text.isNotEmpty)
                                          const SizedBox(height: 6),
                                        if (imageUrls.length == 1)
                                          _buildSingleImageBubble(
                                            context,
                                            docs[index].id,
                                            imageUrls.first,
                                          )
                                        else
                                          MultiplePostImages(
                                            imageUrls: imageUrls,
                                            postId:
                                                '${_conversationRef?.id}_${docs[index].id}',
                                            enableTap: !_hasSelection,
                                          ),
                                      ],
                                      if (links.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: links.map((link) {
                                            return InkWell(
                                              onTap: () async {
                                                final uri = Uri.parse(link);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(
                                                    uri,
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                }
                                              },
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isMine
                                                      ? Colors.white
                                                            .withOpacity(0.1)
                                                      : theme
                                                            .colorScheme
                                                            .surfaceVariant,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      FluentSystemIcons
                                                          .ic_fluent_link_filled,
                                                      size: 14,
                                                      color: isMine
                                                          ? Colors.white
                                                          : theme
                                                                .colorScheme
                                                                .primary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        link,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isMine
                                                              ? Colors.white
                                                              : theme
                                                                    .colorScheme
                                                                    .primary,
                                                          decorationColor:
                                                              isMine
                                                              ? Colors.white
                                                              : theme
                                                                    .colorScheme
                                                                    .primary,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );

                            Widget meta = const SizedBox.shrink();
                            if (createdAt != null) {
                              meta = Align(
                                alignment: isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 2,
                                    left: 8,
                                    right: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: isMine
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        TimeOfDay.fromDateTime(
                                          createdAt,
                                        ).format(context),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                      if (isMine) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          isRead ? Icons.done_all : Icons.check,
                                          size: 14,
                                          color: isRead
                                              ? Colors.lightBlueAccent
                                              : theme.colorScheme.onSurface
                                                    .withOpacity(0.7),
                                        ),
                                      ],
                                      if (isEdited) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          'Edited',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontStyle: FontStyle.italic,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (showDateHeader && createdAt != null) {
                              final dateLabel =
                                  '${createdAt.day}/${createdAt.month}/${createdAt.year}';
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceVariant,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        dateLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  ),
                                  bubble,
                                  meta,
                                ],
                              );
                            }

                            return GestureDetector(
                              key: ValueKey(docs[index].id),
                              onLongPress: () {
                                if (currentUserId != null) {
                                  _onMessageLongPress(
                                    docs[index],
                                    currentUserId,
                                  );
                                }
                              },
                              onTap: () {
                                if (_hasSelection && currentUserId != null) {
                                  _onMessageLongPress(
                                    docs[index],
                                    currentUserId,
                                  );
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                color: isSelected
                                    ? theme.colorScheme.primary.withOpacity(
                                        isDark ? 0.18 : 0.08,
                                      )
                                    : Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [bubble, meta],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                vertical: 4,
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
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
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
                            minLines: 1,
                            maxLines: 5,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: _isEditing
                                  ? 'Edit message...'
                                  : 'Write a message...',
                              hintStyle: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: isDark
                                  ? theme.colorScheme.surfaceVariant
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
                                onPressed: _sending ? null : _insertCodeBlock,
                              ),
                            ],
                            IconButton(
                              icon: _sending
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: primaryColor,
                                      ),
                                    )
                                  : Icon(
                                      FluentSystemIcons.ic_fluent_send_filled,
                                      color: primaryColor,
                                    ),
                              onPressed: _sending ? null : _sendMessage,
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
    );
  }

  Future<void> _markMessagesAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_conversationRef == null || _hasMarkedRead) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;
        final isRead = data['isRead'] as bool? ?? false;

        if (senderId != null && senderId != currentUserId && !isRead) {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      batch.update(_conversationRef!, {'unreadCounts.$currentUserId': 0});

      await batch.commit();

      if (mounted) {
        setState(() {
          _hasMarkedRead = true;
        });
      }
    } catch (_) {
      // ignore marking errors
    }
  }

  void _recalcInputLines() {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    const sidePadding = 24.0; // horizontal padding in the composer
    const sendButtonWidth = 48.0;
    const spacing = 12.0;
    final maxWidth = screenWidth - sidePadding - sendButtonWidth - spacing;

    const textStyle = TextStyle(fontSize: 14);
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

  Widget _buildSingleImageBubble(
    BuildContext context,
    String messageId,
    String url,
  ) {
    final heroTag = 'chat_image_${_conversationRef?.id}_$messageId';
    return GestureDetector(
      onTap: _hasSelection
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      FullscreenImageViewer(imageUrl: url, heroTag: heroTag),
                ),
              );
            },
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
        ),
      ),
    );
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
                const Text(
                  'Add Link',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 20),
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
      setState(() => _pendingLinks.add(link));
    }
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
}
