// ignore_for_file: deprecated_member_use, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/post_composer_sheet.dart';
import 'package:devlink/models/post.dart';
import 'package:devlink/widgets/shimmers.dart';
import 'package:devlink/widgets/post_card.dart';
import 'package:devlink/utility/time_helper.dart';
import 'package:devlink/widgets/post_image_gallery.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:devlink/screens/terms_screen.dart';
import 'package:devlink/utility/code_text_formatter.dart';
import 'package:devlink/widgets/code_block.dart';
import 'package:devlink/widgets/user_picker_bottom_sheet.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'dart:convert';
import 'dart:io';
import 'package:devlink/config/oneSignal_config.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({super.key});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
    });
  }

  Future<void> _openComposerSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PostComposerSheet(),
    );
  }

  Future<void> _openPollComposer() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PostComposerSheet(isPoll: true),
    );
  }

  void _openInactiveInfoSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, color: Colors.red),
                const SizedBox(width: 10),
                Text(
                  'Account Inactive',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your account is currently inactive. You cannot create new posts or replies. Please review our Terms of Service and community guidelines.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withOpacity(0.8),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: (FirebaseAuth.instance.currentUser?.uid == null)
                  ? null
                  : FirebaseFirestore.instance
                      .collection('appeals')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .get(),
              builder: (context, snap) {
                final hasAppeal = (snap.data?.exists ?? false) == true;
                final existingText = snap.data?.data()?['text'] as String?;
                return Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _openAppealSheet(existingText: hasAppeal ? (existingText ?? '') : null);
                      },
                      child: Text(hasAppeal ? 'View Appeal' : 'Appeal'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsScreen(fromDrawer: true),
                          ),
                        );
                      },
                      child: const Text('View Terms'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openAppealSheet({String? existingText}) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        final controller = TextEditingController();
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.report_gmailerrorred, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text(
                    existingText == null ? 'Appeal Inactive Status' : 'Your Appeal',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (existingText == null)
                TextField(
                  controller: controller,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Explain why your account should be reactivated...',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                SelectableText(
                  existingText,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  if (existingText == null)
                    FilledButton(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        Navigator.of(ctx).pop();
                        await _submitAppeal(text);
                      },
                      child: const Text('Submit'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitAppeal(String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = userSnap.data() ?? const {};
    final name = (data['name'] as String?) ?? (data['displayName'] as String?) ?? 'User';
    await FirebaseFirestore.instance.collection('appeals').doc(uid).set({
      'userId': uid,
      'text': text,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      final adminSnap = await FirebaseFirestore.instance
          .collection('appUpdates')
          .doc('adminNotificationID')
          .get();
      final playerId = (adminSnap.data() ?? const {})['oneSignalPlayerID'] as String?;
      if (playerId != null && playerId.isNotEmpty) {
        final uri = Uri.parse('https://api.onesignal.com/notifications');
        final payload = {
          'app_id': OneSignalConfig.appId,
          'include_player_ids': [playerId],
          'headings': {'en': 'New appeal'},
          'contents': {'en': '$name submitted an appeal'},
          'data': {'type': 'appeal', 'userId': uid},
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
        } finally {
          client.close();
        }
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appeal submitted')),
      );
    }
  }

  Widget _buildSearchPlaceholder() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: onSurface.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Search your posts',
            style: TextStyle(fontSize: 18, color: onSurface.withOpacity(0.7)),
          ),
          const SizedBox(height: 8),
          Text(
            'Start typing to see results',
            style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _performSearch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerPostList(count: 3);
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          final onSurface = Theme.of(context).colorScheme.onSurface;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: onSurface.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts found',
                  style: TextStyle(
                    fontSize: 18,
                    color: onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final result = results[index];
            return _buildPostSearchResult(result);
          },
        );
      },
    );
  }

  Widget _buildPostSearchResult(Map<String, dynamic> postData) {
    final post = Post.fromDoc(
      postData['doc'] as DocumentSnapshot<Map<String, dynamic>>,
    );
    final ref =
        (postData['doc'] as DocumentSnapshot<Map<String, dynamic>>).reference;

    return MyPostCard(
      post: post,
      postRef: ref,
      onEdit: () => _editPost(ref, post.text ?? ''),
      onDelete: () => _deletePost(ref),
    );
  }

  Future<List<Map<String, dynamic>>> _performSearch() async {
    if (_searchQuery.isEmpty) return [];

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return [];

    final List<Map<String, dynamic>> results = [];

    try {
      // Search only current user's posts
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        final text = (data['text'] as String? ?? '').toLowerCase();

        if (text.contains(_searchQuery)) {
          results.add({'type': 'post', 'doc': doc});
        }
      }
    } catch (e) {
      print('Search error: $e');
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Posts')),
        body: const Center(child: Text('Please sign in to view your posts')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: _isSearchActive
            ? TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search your posts...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              )
            : const Text('My Posts'),
        actions: [
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .snapshots(),
            builder: (context, snap) {
              final isActive =
                  (snap.data?.data()?['isActive'] as bool?) ?? true;
              if (isActive) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 0,
                ),
                color: Colors.red.withOpacity(0.08),
                child: Row(
                  children: [
                    const Icon(Icons.block, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your account is inactive. Posting is disabled.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: _openInactiveInfoSheet,
                      child: Text(
                        'View',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: _isSearchActive
                ? (_searchQuery.isNotEmpty
                      ? _buildSearchResults()
                      : _buildSearchPlaceholder())
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUserId)
                        .snapshots(),
                    builder: (context, userSnap) {
                      final isActive =
                          (userSnap.data?.data()?['isActive'] as bool?) ?? true;
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .where('userId', isEqualTo: currentUserId)
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const ShimmerPostList(count: 6);
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            final onSurface = Theme.of(
                              context,
                            ).colorScheme.onSurface;
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.post_add,
                                    size: 64,
                                    color: onSurface.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No posts yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create your first post!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final post = Post.fromDoc(docs[i]);
                              final ref = docs[i].reference;
                              return MyPostCard(
                                post: post,
                                postRef: ref,
                                canModify: isActive,
                                onEdit: () => _editPost(ref, post.text ?? ''),
                                onDelete: () => _deletePost(ref),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton:
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .snapshots(),
            builder: (context, snap) {
              final isActive =
                  (snap.data?.data()?['isActive'] as bool?) ?? true;
              if (!isActive) return const SizedBox.shrink();
              return SpeedDial(
                icon: Icons.add,
                activeIcon: Icons.close,
                iconTheme: const IconThemeData(size: 22.0),
                backgroundColor: primaryColor,
                overlayOpacity: 0,
                foregroundColor: Colors.white,
                overlayColor: Colors.transparent,
                elevation: 0,
                direction: SpeedDialDirection.up,
                spacing: 0,
                children: [
                  SpeedDialChild(
                    //   heroTag: 'dashboard_home_fab',
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    onTap: _openComposerSheet,
                    child: Icon(FluentSystemIcons.ic_fluent_edit_regular),

                    label: 'Post',
                    labelBackgroundColor: primaryColor,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                  SpeedDialChild(
                    //   heroTag: 'dashboard_home_fab',
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    onTap: _openPollComposer,
                    child: const Icon(Icons.poll),
                    label: 'Poll',
                    labelBackgroundColor: primaryColor,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _editPost(DocumentReference postRef, String currentText) async {
    // Get the post data to extract existing images
    List<String>? existingImages;
    try {
      final doc = await postRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final imageUrls = data?['imageUrls'] as List<dynamic>?;
        if (imageUrls != null) {
          existingImages = imageUrls.cast<String>();
        }
      }
    } catch (e) {
      print('Error loading post data: $e');
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PostComposerSheet.edit(
        editPostRef: postRef,
        editText: currentText,
        editImageUrls: existingImages,
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated successfully')),
      );
    }
  }

  Future<void> _deletePost(DocumentReference postRef) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(12),
        ),
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await postRef.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting post: $e')));
        }
      }
    }
  }
}

class MyPostCard extends StatelessWidget {
  final Post post;
  final DocumentReference postRef;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool canModify;

  const MyPostCard({
    super.key,
    required this.post,
    required this.postRef,
    required this.onEdit,
    required this.onDelete,
    this.canModify = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withOpacity(0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TimeHelper.timeAgo(post.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canModify)
                      IconButton(
                        onPressed: canModify ? onEdit : null,
                        icon: Icon(
                          FluentSystemIcons.ic_fluent_edit_regular,
                          size: 16,
                        ),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    if (canModify)
                      IconButton(
                        onPressed: canModify ? onDelete : null,
                        icon: Icon(
                          FluentSystemIcons.ic_fluent_delete_regular,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    IconButton(
                      onPressed: () => _sharePost(context, postRef),
                      icon: Icon(
                        FluentSystemIcons.ic_fluent_share_regular,
                        size: 16,
                      ),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Post content
            if (post.text?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final rawText = post.text!;
                  final baseStyle =
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurface,
                      ) ??
                      TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurface,
                      );
                  final codeStyle = baseStyle.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant,
                  );

                  final fencedOnly = _extractFencedCode(rawText);
                  if (fencedOnly != null) {
                    final lang = _extractFencedLanguage(rawText);
                    return CodeBlock(code: fencedOnly, language: lang);
                  }

                  final match = RegExp(r"```([\s\S]*?)```").firstMatch(rawText);
                  if (match != null) {
                    final before = rawText.substring(0, match.start);
                    final inner = match.group(1) ?? '';
                    String? lang;
                    String codeSection = inner;
                    final firstBreak = inner.indexOf('\n');
                    if (firstBreak != -1) {
                      final firstLine = inner.substring(0, firstBreak).trim();
                      final rest = inner.substring(firstBreak + 1);
                      if (firstLine.isNotEmpty && !firstLine.contains(' ')) {
                        lang = firstLine;
                        codeSection = rest;
                      }
                    }
                    final code = codeSection.trimRight();
                    final after = rawText.substring(match.end);

                    final children = <Widget>[];

                    if (before.trim().isNotEmpty) {
                      children.add(
                        SelectableText.rich(
                          TextSpan(
                            children: CodeTextFormatter.buildSpans(
                              text: before.trimRight(),
                              baseStyle: baseStyle,
                              hashtagColor: Colors.blue,
                              codeStyle: codeStyle,
                            ),
                          ),
                        ),
                      );
                    }

                    if (code.isNotEmpty) {
                      children.add(CodeBlock(code: code, language: lang));
                    }

                    if (after.trim().isNotEmpty) {
                      children.add(
                        SelectableText.rich(
                          TextSpan(
                            children: CodeTextFormatter.buildSpans(
                              text: after.trimLeft(),
                              baseStyle: baseStyle,
                              hashtagColor: Colors.blue,
                              codeStyle: codeStyle,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    );
                  }

                  return SelectableText.rich(
                    TextSpan(
                      children: CodeTextFormatter.buildSpans(
                        text: rawText,
                        baseStyle: baseStyle,
                        hashtagColor: Colors.blue,
                        codeStyle: codeStyle,
                      ),
                    ),
                  );
                },
              ),
            ],

            // Post Images
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (post.imageUrls.length == 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: SinglePostImage(
                    imageUrl: post.imageUrls.first,
                    postId: post.id ?? postRef.id,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
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
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                child: PostLinks(links: post.links),
              ),

            // Poll (read-only)
            if (post.isPoll && post.pollOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: PollSection(
                  post: post,
                  postRef: postRef,
                  readOnly: true,
                ),
              ),
          ],
        ),
      ),
    );
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

  Future<void> _sharePost(
    BuildContext context,
    DocumentReference postRef,
  ) async {
    final result = await showFollowersFollowingPickerBottomSheet(
      context,
      actionIcon: FluentSystemIcons.ic_fluent_share_regular,
    );
    if (result == null) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Get or create conversation
      final ids = [currentUserId, result.userId]..sort();
      final pairKey = '${ids[0]}_${ids[1]}';

      final query = await FirebaseFirestore.instance
          .collection('conversations')
          .where('pairKey', isEqualTo: pairKey)
          .limit(1)
          .get();

      DocumentReference<Map<String, dynamic>> convRef;
      if (query.docs.isNotEmpty) {
        convRef = query.docs.first.reference;
      } else {
        convRef = FirebaseFirestore.instance.collection('conversations').doc();
        await convRef.set({
          'pairKey': pairKey,
          'participants': ids,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastMessageText': '[Shared Post]',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': currentUserId,
          'unreadCounts': {currentUserId: 0, result.userId: 0},
        });
      }

      // Send message with post reference
      final msgRef = convRef.collection('messages').doc();
      await msgRef.set({
        'text': '[Shared Post]',
        'senderId': currentUserId,
        'postId': postRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update conversation
      await convRef.update({
        'lastMessageText': '[Shared Post]',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCounts.${result.userId}': FieldValue.increment(1),
        'unreadCounts.$currentUserId': 0,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post shared')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share post: $e')));
      }
    }
  }
}
