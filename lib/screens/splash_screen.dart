// ignore_for_file: deprecated_member_use

import 'package:devlink/config/config.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Stack(
            children: [
              // Subtle background pattern (soft circles)
              Positioned(
                top: -40,
                left: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 100,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.secondary.withOpacity(0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/logo.png', height: 96),
                          const SizedBox(height: 14),
                          // App name / tagline
                          Text(
                            'DevLink',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Connect • Share • Grow',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onSurface.withOpacity(0.7),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Loading.large(color: primaryColor),
                          const SizedBox(height: 18),
                          Text(
                            'Version ${Config.appVersion}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onSurface.withOpacity(0.7),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer attribution
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'The Product of Innova Solutions',
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
