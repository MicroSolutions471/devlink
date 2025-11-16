// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class BeautifulEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final double? iconSize;

  const BeautifulEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon Container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (iconColor ?? scheme.onSurface).withOpacity(0.1),
                    (iconColor ?? scheme.onSurface).withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: (iconColor ?? scheme.onSurface).withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: iconSize ?? 60,
                color: iconColor ?? scheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: scheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
