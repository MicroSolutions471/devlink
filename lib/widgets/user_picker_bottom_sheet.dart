import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PickUserResult {
  final String userId;
  final String name;
  final String? photoUrl;

  PickUserResult({required this.userId, required this.name, this.photoUrl});
}

Future<PickUserResult?> showFollowersFollowingPickerBottomSheet(
  BuildContext context, {
  required IconData actionIcon,
}) async {
  return showModalBottomSheet<PickUserResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) =>
        SafeArea(child: _FollowersFollowingPickerSheet(actionIcon: actionIcon)),
  );
}

class _FollowersFollowingPickerSheet extends StatefulWidget {
  final IconData actionIcon;

  const _FollowersFollowingPickerSheet({required this.actionIcon});

  @override
  State<_FollowersFollowingPickerSheet> createState() =>
      _FollowersFollowingPickerSheetState();
}

class _FollowersFollowingPickerSheetState
    extends State<_FollowersFollowingPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final List<_PickerUser> _allUsers = [];
  List<_PickerUser> _visibleUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final db = FirebaseFirestore.instance;

      final followersSnap = await db
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();

      final followingSnap = await db
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();

      // --- Build user relation map ---
      final Map<String, String> relations = {};

      for (final d in followersSnap.docs) {
        relations[d.id] = "Follower";
      }

      for (final d in followingSnap.docs) {
        if (relations.containsKey(d.id)) {
          relations[d.id] = "Follower • Following";
        } else {
          relations[d.id] = "Following";
        }
      }

      final ids = relations.keys;

      final List<_PickerUser> users = [];
      for (final id in ids) {
        final snap = await db.collection('users').doc(id).get();
        final data = snap.data() ?? {};
        final name =
            (data['name'] as String?) ??
            (data['displayName'] as String?) ??
            'User';
        final photo =
            (data['photoUrl'] as String?) ?? (data['avatar'] as String?);

        users.add(
          _PickerUser(
            id: id,
            name: name,
            photoUrl: photo,
            relation: relations[id] ?? "",
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _allUsers.clear();
        _allUsers.addAll(users);
        _visibleUsers = List<_PickerUser>.from(_allUsers);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _visibleUsers = List<_PickerUser>.from(_allUsers);
      } else {
        _visibleUsers = _allUsers
            .where((u) => u.name.toLowerCase().contains(q))
            .toList();
      }
    });
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select user',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search users...',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              Expanded(
                child: Center(child: Loading.medium(color: primaryColor)),
              )
            else if (_visibleUsers.isEmpty)
              const Expanded(child: Center(child: Text('No users found')))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _visibleUsers.length,
                  itemBuilder: (context, index) {
                    final u = _visibleUsers[index];
                    return _PickerUserTile(
                      user: u,
                      actionIcon: widget.actionIcon,
                      onSelected: (user) {
                        Navigator.of(context).pop(
                          PickUserResult(
                            userId: user.id,
                            name: user.name,
                            photoUrl: user.photoUrl,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------ USER MODEL ------------------

class _PickerUser {
  final String id;
  final String name;
  final String? photoUrl;
  final String relation; // NEW FIELD

  _PickerUser({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.relation,
  });
}

// ------------------ USER TILE ------------------

class _PickerUserTile extends StatelessWidget {
  final _PickerUser user;
  final IconData actionIcon;
  final ValueChanged<_PickerUser> onSelected;

  const _PickerUserTile({
    required this.user,
    required this.actionIcon,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: UserColors.getBackgroundColorForUser(
          user.id,
        ).withValues(alpha: 0.1),
        backgroundImage: user.photoUrl != null
            ? CachedNetworkImageProvider(user.photoUrl!)
            : null,
        child: user.photoUrl == null
            ? Icon(
                FluentSystemIcons.ic_fluent_person_filled,
                color: UserColors.getIconColorForUser(user.id),
              )
            : null,
      ),

      // TITLE WITH SMALL TEXT UNDER NAME
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (user.relation.isNotEmpty)
            Text(
              user.relation,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),

      trailing: TextButton(
        onPressed: () => onSelected(user),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Icon(actionIcon),
      ),
      onTap: () => onSelected(user),
    );
  }
}
