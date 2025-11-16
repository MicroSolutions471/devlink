import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/screens/about_screen.dart';
import 'package:devlink/screens/terms_screen.dart';
import 'package:devlink/services/update_checker.dart';
import 'package:devlink/widgets/feedback_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:devlink/screens/profile_screen.dart';
import 'package:devlink/screens/followers_screen.dart';
import 'package:devlink/screens/my_posts_screen.dart' as new_my_posts;
import 'package:flutter/services.dart';
// removed unused imports
import 'package:provider/provider.dart';
import 'package:devlink/providers/theme_provider.dart';

class DashboardDrawer extends StatelessWidget {
  final String? currentUserId;

  const DashboardDrawer({super.key, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Drawer(
      width: 220,
      shape: const RoundedRectangleBorder(),
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: currentUserId == null
          ? _guestDrawer(context)
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                final user = snapshot.data?.data() ?? {};
                final name = user["name"] ?? "User";
                final email = FirebaseAuth.instance.currentUser?.email ?? "";
                final photoUrl = user["photoUrl"];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(context, name, email, photoUrl),
                    const Divider(height: 1, thickness: 0.4),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _tile(
                            context,
                            icon: FluentSystemIcons.ic_fluent_person_regular,
                            text: "Profile",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            },
                          ),
                          _tile(
                            context,
                            icon: FluentSystemIcons.ic_fluent_people_regular,
                            text: "Followers",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FollowersScreen(),
                                ),
                              );
                            },
                          ),
                          _tile(
                            context,
                            icon:
                                FluentSystemIcons.ic_fluent_people_team_regular,
                            text: "Following",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FollowingScreen(),
                                ),
                              );
                            },
                          ),
                          _tile(
                            context,
                            icon: FluentSystemIcons
                                .ic_fluent_text_bullet_list_square_regular,
                            text: "My Posts",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const new_my_posts.MyPostsScreen(),
                                ),
                              );
                            },
                          ),
                          _tile(
                            context,
                            icon: FluentSystemIcons.ic_fluent_info_regular,
                            text: "About DevLink",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AboutScreen(),
                                ),
                              );
                            },
                          ),
                          _tile(
                            context,
                            icon: Icons.description_outlined,
                            text: "Terms of Service",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TermsScreen(fromDrawer: true),
                                ),
                              );
                            },
                          ),
                          _tile(
                            context,
                            icon:
                                FluentSystemIcons.ic_fluent_duo_update_regular,
                            text: "Check for Update",
                            onTap: () {
                              UpdateChecker.checkForUpdateFromButton(context);
                            },
                          ),
                          _tile(
                            context,
                            icon: FluentSystemIcons
                                .ic_fluent_person_feedback_regular,
                            text: "Feedback",
                            onTap: () {
                              Navigator.pop(context);
                              FeedbackSheet.show(
                                context,
                                name: name,
                                email: email,
                              );
                            },
                          ),
                          ListTile(
                            dense: true,
                            horizontalTitleGap: 10,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            minLeadingWidth: 20,
                            leading: Icon(
                              (Theme.of(context).brightness == Brightness.dark)
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                              size: 20,
                              color: onSurface,
                            ),
                            title: Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontSize: 14,
                                color: onSurface,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            trailing: Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: context.watch<ThemeProvider>().isDark,
                                onChanged: (_) => context
                                    .read<ThemeProvider>()
                                    .toggleDarkLight(),
                              ),
                            ),
                            onTap: () {
                              context.read<ThemeProvider>().toggleDarkLight();

                              final isDark = context
                                  .read<ThemeProvider>()
                                  .isDark;

                              SystemChrome.setSystemUIOverlayStyle(
                                SystemUiOverlayStyle(
                                  statusBarColor: Colors.transparent,
                                  systemNavigationBarColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                  systemNavigationBarDividerColor:
                                      Colors.transparent,
                                  statusBarIconBrightness: isDark
                                      ? Brightness.light
                                      : Brightness.dark,
                                  systemNavigationBarIconBrightness: isDark
                                      ? Brightness.light
                                      : Brightness.dark,
                                  systemNavigationBarContrastEnforced: false,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 18, thickness: 0.4),
                    _tile(
                      context,
                      icon: FluentSystemIcons.ic_fluent_sign_out_regular,
                      text: "Sign Out",
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: () async {
                        Navigator.pop(context);
                        final nav = Navigator.of(context);
                        await FirebaseAuth.instance.signOut();
                        nav.pushNamedAndRemoveUntil('/', (route) => false);
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }

  // --------------------------
  // Minimal Header
  // --------------------------
  Widget _header(
    BuildContext context,
    String name,
    String email,
    String? photoUrl,
  ) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.surface,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Icon(
                    FluentSystemIcons.ic_fluent_person_filled,
                    size: 24,
                    color: onSurface.withValues(alpha: 0.6),
                  )
                : null,
          ),

          const SizedBox(height: 14),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            email,
            style: TextStyle(
              fontSize: 11,
              color: onSurface.withValues(alpha: 0.6),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --------------------------
  // Single Ultra-Minimal Tile
  // --------------------------
  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return ListTile(
      dense: true,
      horizontalTitleGap: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 20,
      leading: Icon(icon, size: 20, color: iconColor ?? onSurface),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: textColor ?? onSurface,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
    );
  }

  // --------------------------
  // Guest Drawer
  // --------------------------
  Widget _guestDrawer(BuildContext context) {
    return Column(
      children: [
        _header(context, "DevLink", "Welcome", null),
        const Divider(height: 1, thickness: 0.4),
        _tile(
          context,
          icon: Icons.login,
          text: "Sign In",
          onTap: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
