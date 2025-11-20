// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:carbon_icons/carbon_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/screens/coversation_screen.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:devlink/widgets/fullscreen_image_viewer.dart';
import 'package:devlink/utility/user_colors.dart';
import 'package:devlink/services/follow_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:devlink/utility/number_format.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DeveloperInfoScreen extends StatelessWidget {
  final String userId;
  final String? initialName;
  final String? initialPhoto;
  const DeveloperInfoScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialPhoto,
  });

  String _digits(String input) => input.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _launchEmail(
    BuildContext context,
    String email, {
    String? subject,
  }) async {
    final mailto = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: subject != null && subject.isNotEmpty
          ? {'subject': subject}
          : null,
    );
    try {
      if (await canLaunchUrl(mailto)) {
        await launchUrl(mailto, mode: LaunchMode.externalApplication);
        return;
      }
      final gmailWeb = Uri.parse(
        'https://mail.google.com/mail/?view=cm&to=${Uri.encodeComponent(email)}${subject != null && subject.isNotEmpty ? '&su=${Uri.encodeComponent(subject)}' : ''}',
      );
      if (await canLaunchUrl(gmailWeb)) {
        await launchUrl(gmailWeb, mode: LaunchMode.externalApplication);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No email app found. Copy the address from the profile.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open email: $e')));
    }
  }

  Future<void> _launchWhatsApp(
    BuildContext context,
    String phone, {
    String? text,
  }) async {
    final number = _digits(phone);
    final appUri = Uri.parse(
      'whatsapp://send?phone=$number${text != null && text.isNotEmpty ? '&text=${Uri.encodeComponent(text)}' : ''}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$number${text != null && text.isNotEmpty ? '?text=${Uri.encodeComponent(text)}' : ''}',
    );
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not available on this device.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

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
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text(
            "About",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),

        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, snap) {
            final d = snap.data?.data();
            final name =
                (d?['name'] ?? d?['displayName'] ?? initialName ?? 'Username')
                    as String;
            final photo = (d?['photoUrl'] ?? d?['avatar'] ?? initialPhoto);
            final followers = (d?['followersCount'] ?? 0) as int;
            final bio = (d?['bio'] ?? '') as String;
            final email = (d?['email'] ?? '') as String;
            final phone = (d?['phone'] ?? '') as String;
            final isDeveloper = (d?['isDeveloper'] as bool?) ?? false;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -------- Profile Header --------
                  Row(
                    children: [
                      Hero(
                        tag: 'dev-avatar-$userId',
                        child: Material(
                          type: MaterialType.transparency,
                          child: photo != null
                              ? GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FullscreenImageViewer(
                                          imageUrl: photo,
                                          heroTag: 'dev-avatar-$userId',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 42,
                                        backgroundColor:
                                            UserColors.getBackgroundColorForUser(
                                              userId,
                                            ),
                                        backgroundImage: CachedNetworkImageProvider(photo),
                                      ),
                                      if (isDeveloper)
                                        Positioned(
                                          bottom: -4,
                                          right: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(1),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.verified,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 42,
                                      backgroundColor:
                                          UserColors.getBackgroundColorForUser(
                                            userId,
                                          ),
                                      child: Icon(
                                        FluentSystemIcons
                                            .ic_fluent_person_filled,
                                        size: 48,
                                        color: UserColors.getIconColorForUser(
                                          userId,
                                        ),
                                      ),
                                    ),
                                    if (isDeveloper)
                                      Positioned(
                                        bottom: -4,
                                        right: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(1),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.verified,
                                            color: Colors.green,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  "${formatCount(followers)} followers",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                                const Spacer(),
                                FollowButton(
                                  targetUserId: userId,
                                  initialFollowers: followers,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // -------- Bio --------
                  if (bio.isNotEmpty) ...[
                    Text(
                      bio,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // -------- Contact --------
                  if (email.isNotEmpty || phone.isNotEmpty) ...[
                    const Text(
                      "Contact",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? theme.cardColor : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? theme.dividerColor.withOpacity(0.6)
                              : Colors.grey.shade300,
                          width: 0.6,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (email.isNotEmpty)
                            _contactTile(
                              context,
                              icon: CarbonIcons.email,
                              label: email,
                              onTap: () => _launchEmail(context, email),
                            ),

                          if (email.isNotEmpty && phone.isNotEmpty)
                            Divider(
                              height: 0,
                              color: isDark
                                  ? theme.dividerColor
                                  : Colors.grey.shade300,
                            ),

                          if (phone.isNotEmpty)
                            _contactTile(
                              context,
                              icon: CarbonIcons.phone,
                              label: phone,
                              onTap: () => _launchWhatsApp(context, phone),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return CoversationScreen(
                        peerUserId: userId,
                        peerName: initialName,
                        peerPhoto: initialPhoto,
                      );
                    },
                  ),
                );
              },
              label: const Text('Message'),
              icon: const Icon(FluentSystemIcons.ic_fluent_chat_regular),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface,
        size: 22,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14.5)),

      onTap: onTap,
    );
  }
}

class FollowButton extends StatefulWidget {
  final String targetUserId;
  final int initialFollowers;

  const FollowButton({
    super.key,
    required this.targetUserId,
    required this.initialFollowers,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool? _isFollowing;
  bool _loading = false;
  int? _followers;

  @override
  void initState() {
    super.initState();
    _followers = widget.initialFollowers;
    _loadState();
  }

  Future<void> _loadState() async {
    final currentId = FirebaseAuth.instance.currentUser?.uid;
    if (currentId == null || currentId == widget.targetUserId) {
      setState(() {
        _isFollowing = null;
      });
      return;
    }
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
      final currentlyFollowing = _isFollowing!;
      _isFollowing = !currentlyFollowing;
      if (!currentlyFollowing) {
        _followers = (_followers ?? 0) + 1;
      } else {
        _followers = (_followers ?? 0) > 0 ? (_followers ?? 0) - 1 : 0;
      }
    });

    try {
      await FollowService.instance.toggleFollow(widget.targetUserId);
    } catch (e) {
      if (mounted) {
        setState(() {
          // revert on error
          final currentlyFollowing = !_isFollowing!;
          _isFollowing = currentlyFollowing;
          if (!currentlyFollowing) {
            _followers = (_followers ?? 0) + 1;
          } else {
            _followers = (_followers ?? 0) > 0 ? (_followers ?? 0) - 1 : 0;
          }
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

    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: _loading ? null : _toggle,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        ),
        child: _loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(following ? 'Following' : 'Follow'),
      ),
    );
  }
}
