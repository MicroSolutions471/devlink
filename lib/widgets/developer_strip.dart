import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:devlink/screens/developer_info_screen.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:devlink/widgets/shimmers.dart';

class DeveloperStrip extends StatelessWidget {
  const DeveloperStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('isDeveloper', isEqualTo: true)
            .limit(20)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ShimmerHorizontalAvatars();
          }
          
          final developers = snap.data?.docs ?? [];
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          final visibleDevelopers = currentUserId == null
              ? developers
              : developers.where((d) => d.id != currentUserId).toList();
          if (visibleDevelopers.isEmpty) return const SizedBox.shrink();
          
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            scrollDirection: Axis.horizontal,
            itemCount: visibleDevelopers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final developerData = visibleDevelopers[index].data();
              final userId = visibleDevelopers[index].id;
              final name =
                  (developerData['name'] as String?) ??
                  (developerData['displayName'] as String?) ??
                  'Dev';
              final photo =
                  (developerData['photoUrl'] as String?) ?? 
                  (developerData['avatar'] as String?);
                  
              return DeveloperAvatar(
                userId: userId,
                name: name,
                photoUrl: photo,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeveloperInfoScreen(
                      userId: userId,
                      initialName: name,
                      initialPhoto: photo,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DeveloperAvatar extends StatelessWidget {
  final String userId;
  final String name;
  final String? photoUrl;
  final VoidCallback onTap;

  const DeveloperAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: 'dev-avatar-$userId',
            child: CircleAvatar(
              radius: 24,
              backgroundColor: UserColors.getBackgroundColorForUser(userId),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
              child: photoUrl == null
                  ? Icon(
                      FluentSystemIcons.ic_fluent_person_filled,
                      size: 22,
                      color: UserColors.getIconColorForUser(userId),
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
  }
}
