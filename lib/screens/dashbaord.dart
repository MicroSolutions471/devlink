// ignore_for_file: file_names, deprecated_member_use, avoid_print

import 'package:devlink/screens/chats_screen.dart';
import 'package:devlink/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/dashboard_drawer.dart';
import 'package:flutter/services.dart';
import 'package:devlink/widgets/custom_bottom_nav.dart';
import 'package:devlink/widgets/notification_badge.dart';
import 'package:devlink/widgets/post_composer_sheet.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

// Dashboard now uses custom widgets for cleaner code organization

class _DashboardState extends State<Dashboard> {
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _lastBackPressed;
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _searchController.clear();
      _searchQuery = '';
      _isSearchActive = false;
    });
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

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openComposerSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PostComposerSheet(),
    );
  }

  // Drawer functionality moved to DashboardDrawer widget

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Ensure the selected index is always within the range of available pages.
    // This guards against cases where the number of tabs changes while
    // _selectedIndex still holds an old value (e.g. after hot reload).
    final pages = [
      HomeScreen(
        isSearchActive: _isSearchActive && _selectedIndex == 0,
        searchQuery: _selectedIndex == 0 ? _searchQuery : '',
      ),
      ChatsScreen(
        isSearchActive: _isSearchActive && _selectedIndex == 1,
        searchQuery: _selectedIndex == 1 ? _searchQuery : '',
      ),
    ];
    final int safeIndex = _selectedIndex.clamp(0, pages.length - 1);

    return WillPopScope(
      onWillPop: () async {
        // If search is open, close it first
        if (_isSearchActive) {
          setState(() {
            _isSearchActive = false;
            _searchController.clear();
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
                    decoration: InputDecoration(
                      hintText: _selectedIndex == 1
                          ? 'Search chats...'
                          : 'Search users and posts...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintStyle: const TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(color: Colors.black87),
                  )
                : Text(_selectedIndex == 0 ? 'DevLink' : 'Chats'),
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
          body: IndexedStack(index: safeIndex, children: pages),
          bottomNavigationBar: currentUserId == null
              ? SafeArea(
                  child: CustomBottomNavBar(
                    selectedIndex: _selectedIndex,
                    onItemTapped: _onItemTapped,
                    primaryColor: primaryColor,
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .where('participants', arrayContains: currentUserId)
                      .snapshots(),
                  builder: (context, snap) {
                    int unreadTotal = 0;
                    if (snap.hasData) {
                      for (final doc in snap.data!.docs) {
                        final data = doc.data();
                        final unreadMap =
                            (data['unreadCounts'] as Map<String, dynamic>? ??
                            const {});
                        final value = unreadMap[currentUserId] as int? ?? 0;
                        unreadTotal += value;
                      }
                    }
                    return SafeArea(
                      child: CustomBottomNavBar(
                        selectedIndex: _selectedIndex,
                        onItemTapped: _onItemTapped,
                        primaryColor: primaryColor,
                        unreadCount: unreadTotal,
                      ),
                    );
                  },
                ),
          floatingActionButton: safeIndex == 0
              ? (currentUserId == null
                    ? FloatingActionButton(
                        heroTag: 'dashboard_home_fab',
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
                            heroTag: 'dashboard_home_fab',
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            onPressed: _openComposerSheet,
                            child: const Icon(Icons.add),
                          );
                        },
                      ))
              : null,
        ),
      ),
    );
  }
}
