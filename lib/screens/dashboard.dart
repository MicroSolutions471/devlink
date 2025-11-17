// ignore_for_file: file_names, deprecated_member_use, avoid_print

import 'package:devlink/services/realtime_listener.dart';
import 'package:devlink/services/update_checker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/post_composer_sheet.dart';
import 'package:devlink/models/post.dart';
import 'package:devlink/widgets/shimmers.dart';
import 'package:devlink/widgets/post_card.dart';
import 'package:devlink/widgets/notification_badge.dart';
import 'package:devlink/widgets/dashboard_drawer.dart';
import 'package:devlink/widgets/replies_sheet.dart';
import 'package:devlink/screens/developer_info_screen.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:devlink/services/follow_service.dart';
import 'package:flutter/services.dart';
import 'package:devlink/screens/terms_screen.dart';
import 'dart:async';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

// Thin news strip below AppBar that auto-scrolls through active news
class NewsTickerStrip extends StatefulWidget {
  const NewsTickerStrip({super.key});

  @override
  State<NewsTickerStrip> createState() => _NewsTickerStripState();
}

class _NewsTickerStripState extends State<NewsTickerStrip> {
  final PageController _pageController = PageController(viewportFraction: 1.0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll(int count) {
    _timer?.cancel();
    if (count <= 1) return; // no auto-scroll if single item
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pageController.hasClients) return;
      final page = _pageController.page ?? 0.0;
      final next = (page.round() + 1) % count;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('news')
          .where('isActive', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (!snap.hasData || (snap.data!.docs.isEmpty)) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        // Start auto scroll once we know the length
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startAutoScroll(docs.length);
        });

        return SizedBox(
          width: double.infinity,
          height: 40,
          child: PageView.builder(
            controller: _pageController,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = (data['title'] as String?)?.trim() ?? '';
              final body = (data['body'] as String?)?.trim() ?? '';

              // Use per-news color if available, otherwise fall back to primaryColor
              final colorValue = data['color'] as int?;
              final newsColor = colorValue != null
                  ? Color(colorValue)
                  : primaryColor;

              return Container(
                decoration: BoxDecoration(
                  color: newsColor.withValues(alpha: 0.08),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? '(Untitled)' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: newsColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _openNewsSheet(context, title, body),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 32),
                        foregroundColor: newsColor,
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openNewsSheet(BuildContext context, String title, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title.isEmpty ? '(Untitled)' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                body.isEmpty ? '(No body)' : body,
                style: const TextStyle(fontSize: 14, height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Dashboard now uses custom widgets for cleaner code organization

class _DashboardState extends State<Dashboard> {
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _lastBackPressed;
  bool _canReply = true;

  @override
  void initState() {
    super.initState();
    // Start real-time status listener and perform a one-time update check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StatusListener.listenForNewStatus(context);
      UpdateChecker.checkForUpdate(context);
    });

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
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
    // Stop real-time status listener when dashboard is disposed
    StatusListener.cancelStatusListeners();
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

  // Helper methods moved to utility classes

  Future<void> _openComposerSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PostComposerSheet(),
    );
  }

  void _openRepliesSheet(DocumentReference postRef) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RepliesSheet(postRef: postRef),
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
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TermsScreen(fromDrawer: true),
                    ),
                  );
                },
                child: const Text('Open Terms of Service'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Search for users and posts',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Start typing to see results',
            style: TextStyle(fontSize: 14, color: Colors.grey),
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No results found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
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
            final type = result['type'] as String;

            if (type == 'user') {
              return _buildUserSearchResult(result);
            } else {
              return _buildPostSearchResult(result);
            }
          },
        );
      },
    );
  }

  Widget _buildUserSearchResult(Map<String, dynamic> userData) {
    final userId = userData['id'] as String;
    final name =
        userData['name'] as String? ??
        userData['displayName'] as String? ??
        'User';
    final photo =
        userData['photoUrl'] as String? ?? userData['avatar'] as String?;
    final isDeveloper = userData['isDeveloper'] as bool? ?? false;
    final followersCount = userData['followersCount'] as int? ?? 0;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black12.withOpacity(0.05)),
      ),
      child: ListTile(
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
        title: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (isDeveloper) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Colors.green, size: 16),
            ],
          ],
        ),
        subtitle: isDeveloper && followersCount > 0
            ? Text('$followersCount followers')
            : null,
        trailing: currentUserId != null && userId != currentUserId
            ? _SearchFollowButton(targetUserId: userId)
            : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeveloperInfoScreen(userId: userId),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostSearchResult(Map<String, dynamic> postData) {
    final post = Post.fromDoc(
      postData['doc'] as DocumentSnapshot<Map<String, dynamic>>,
    );
    final ref =
        (postData['doc'] as DocumentSnapshot<Map<String, dynamic>>).reference;

    return PostCard(
      post: post,
      postRef: ref,
      onReplyTap: () => _openRepliesSheet(ref),
      canReply: _canReply,
    );
  }

  Future<List<Map<String, dynamic>>> _performSearch() async {
    if (_searchQuery.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];

    try {
      // Search users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final name =
            (data['name'] as String? ?? data['displayName'] as String? ?? '')
                .toLowerCase();

        if (name.contains(_searchQuery)) {
          results.add({'type': 'user', 'id': doc.id, ...data});
        }
      }

      // Search posts
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        final text = (data['text'] as String? ?? '').toLowerCase();
        final authorName = (data['authorName'] as String? ?? '').toLowerCase();

        if (text.contains(_searchQuery) || authorName.contains(_searchQuery)) {
          results.add({'type': 'post', 'doc': doc});
        }
      }
    } catch (e) {
      print('Search error: $e');
    }

    return results;
  }

  Widget _followingStrip(String currentUserId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final followingDocs = snap.data!.docs;
        if (followingDocs.isEmpty) return const SizedBox.shrink();

        final ids = followingDocs
            .map((d) => (d.data()['targetUserId'] as String?) ?? d.id)
            .where((id) => id != currentUserId)
            .toList();
        if (ids.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 90,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            scrollDirection: Axis.horizontal,
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final userId = ids[index];
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const SizedBox(width: 72);
                  }
                  final data = userSnap.data!.data() ?? {};
                  final name =
                      (data['name'] as String?) ??
                      (data['displayName'] as String?) ??
                      'User';
                  final photo =
                      (data['photoUrl'] as String?) ??
                      (data['avatar'] as String?);
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeveloperInfoScreen(
                          userId: userId,
                          initialName: name,
                          initialPhoto: photo,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'dev-avatar-$userId',
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                UserColors.getBackgroundColorForUser(userId),
                            backgroundImage: photo != null
                                ? NetworkImage(photo)
                                : null,
                            child: photo == null
                                ? Icon(
                                    FluentSystemIcons.ic_fluent_person_filled,
                                    size: 22,
                                    color: UserColors.getIconColorForUser(
                                      userId,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  // Drawer functionality moved to DashboardDrawer widget

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        // If search is open, close it first
        if (_isSearchActive) {
          setState(() {
            _isSearchActive = false;
            _searchController.clear();
            _searchQuery = '';
          });
          return false;
        }
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
          appBar: AppBar(
            centerTitle: false,
            title: _isSearchActive
                ? TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search users and posts...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.black87),
                  )
                : const Text('DevLink'),
            actions: [
              IconButton(
                icon: Icon(_isSearchActive ? Icons.close : Icons.search),
                onPressed: _toggleSearch,
              ),
              if (currentUserId != null && !_isSearchActive)
                NotificationBadge(currentUserId: currentUserId),
            ],
          ),
          drawer: DashboardDrawer(currentUserId: currentUserId),
          body: Column(
            children: [
              NewsTickerStrip(),
              if (currentUserId != null)
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
                        vertical: 10,
                      ),
                      color: Colors.red.withOpacity(0.08),
                      child: Row(
                        children: [
                          const Icon(Icons.block, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your account is inactive. Posting is disabled.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _openInactiveInfoSheet,
                            child: const Text('View'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (!_isSearchActive && currentUserId != null)
                _followingStrip(currentUserId),
              Expanded(
                child: _isSearchActive
                    ? (_searchQuery.isNotEmpty
                          ? _buildSearchResults()
                          : _buildSearchPlaceholder())
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const ShimmerPostList(count: 6);
                          }
                          final docs = snap.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(child: Text('No posts yet'));
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final post = Post.fromDoc(docs[i]);
                              final ref = docs[i].reference;
                              return PostCard(
                                post: post,
                                postRef: ref,
                                onReplyTap: () => _openRepliesSheet(ref),
                                canReply: _canReply,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: currentUserId == null
              ? FloatingActionButton(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  onPressed: _openComposerSheet,
                  child: const Icon(Icons.add),
                )
              : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId)
                      .snapshots(),
                  builder: (context, snap) {
                    final isActive =
                        (snap.data?.data()?['isActive'] as bool?) ?? true;
                    if (!isActive) return const SizedBox.shrink();
                    return FloatingActionButton(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      onPressed: _openComposerSheet,
                      child: const Icon(Icons.add),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _SearchFollowButton extends StatefulWidget {
  final String targetUserId;

  const _SearchFollowButton({required this.targetUserId});

  @override
  State<_SearchFollowButton> createState() => _SearchFollowButtonState();
}

class _SearchFollowButtonState extends State<_SearchFollowButton> {
  bool? _isFollowing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
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
    return TextButton(
      onPressed: _loading ? null : _toggle,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: following ? Colors.grey.shade200 : primaryColor,
        foregroundColor: following ? Colors.black87 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: following ? Colors.black54 : Colors.white,
              ),
            )
          : Text(
              following ? 'Following' : 'Follow',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
    );
  }
}
