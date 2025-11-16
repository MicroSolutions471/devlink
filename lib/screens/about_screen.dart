// ignore_for_file: deprecated_member_use

import 'package:carbon_icons/carbon_icons.dart';
import 'package:devlink/widgets/fullscreen_image_viewer.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<void> _openEmail(String to) async {
    final uri = Uri.parse('mailto:$to');
    await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/$phone');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: cs.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarIconBrightness: cs.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('About'), centerTitle: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card with avatar and app name
                Card(
                  color: isDark ? theme.cardColor : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? theme.dividerColor.withOpacity(0.12)
                          : theme.dividerColor.withOpacity(0.12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Column(
                      children: [
                        ClipOval(
                          child: Container(
                            width: 80,
                            height: 80,
                            color: cs.surfaceContainerHighest,
                            padding: const EdgeInsets.all(10),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.person,
                                    size: 40,
                                    color: cs.onSurface.withOpacity(0.6),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'DevLink',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A lightweight community to connect, share, and grow with fellow developers. Post updates, discuss ideas, and collaborate in a distraction-free space.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onSurface.withOpacity(0.75),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Features / details
                Card(
                  color: isDark ? theme.cardColor : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? theme.dividerColor.withOpacity(0.12)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What you can do',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _bullet(context, 'Compose posts with images and links'),
                        _bullet(
                          context,
                          'Reply and discuss in focused threads',
                        ),
                        _bullet(
                          context,
                          'Get notified about important updates',
                        ),
                        _bullet(
                          context,
                          'Enjoy light/dark themes with a single toggle',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Contact
                Card(
                  color: isDark ? theme.cardColor : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? theme.dividerColor.withOpacity(0.12)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          LineAwesomeIcons.whatsapp,
                          color: Colors.green,
                        ),
                        title: const Text('WhatsApp'),
                        subtitle: const Text('03479483218'),
                        onTap: () => _openWhatsApp('923479483218'),
                      ),
                      Divider(
                        height: 0,
                        color: isDark
                            ? theme.dividerColor
                            : Colors.grey.shade300,
                      ),
                      ListTile(
                        leading: Icon(CarbonIcons.email, color: Colors.red),
                        title: const Text('Email'),
                        subtitle: const Text('yousafrehman471@gmail.com'),
                        onTap: () => _openEmail('yousafrehman471@gmail.com'),
                      ),
                      Divider(
                        height: 0,
                        color: isDark
                            ? theme.dividerColor
                            : Colors.grey.shade300,
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.language_rounded,
                          color: Colors.blue,
                        ),
                        title: const Text('Website'),
                        subtitle: const Text(
                          'https://innovasolutions.netlify.app/',
                        ),
                        onTap: () =>
                            _openUrl('https://innovasolutions.netlify.app/'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Developer
                Card(
                  color: isDark ? theme.cardColor : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark
                          ? theme.dividerColor.withOpacity(0.12)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'profile-image',
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (BuildContext context) {
                                    return FullscreenImageViewer(
                                      imageUrl: 'assets/images/me.jpg',
                                      heroTag: 'profile-image',
                                    );
                                  },
                                ),
                              );
                            },
                            child: Align(
                              alignment: Alignment.center,
                              child: CircleAvatar(
                                radius: 40,

                                child: ClipRRect(
                                  borderRadius: BorderRadiusGeometry.circular(
                                    100,
                                  ),
                                  child: Image.asset(
                                    'assets/images/me.jpg',
                                    fit: BoxFit.fill,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          FluentSystemIcons
                                              .ic_fluent_person_filled,
                                          size: 40,
                                          color: cs.onSurface.withOpacity(0.6),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        Text(
                          'About the Developer',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Built with passion at Innova Solutions. I focus on crafting fast, clean, and delightful Flutter apps that scale. Reach out for collaboration, freelance, or product ideas.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onSurface.withOpacity(0.75),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'The Product of Innova Solutions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onSurface.withOpacity(0.6),
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

  Widget _bullet(BuildContext context, String text) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: 8),
            decoration: BoxDecoration(
              color: onSurface.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: onSurface.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
