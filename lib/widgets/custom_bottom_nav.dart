// ignore_for_file: deprecated_member_use

import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final int unreadCount;
  final int pendingCount;
  final Color primaryColor;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.unreadCount = 0,
    this.pendingCount = 0,
    this.primaryColor = Colors.red,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 70,
      decoration: BoxDecoration(color: isDark ? scheme.surface : Colors.white),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              context,
              FluentSystemIcons.ic_fluent_home_regular,
              FluentSystemIcons.ic_fluent_home_filled,
              'Home',
              0,
            ),
            _buildNavItem(
              context,
              FluentSystemIcons.ic_fluent_chat_regular,
              FluentSystemIcons.ic_fluent_chat_filled,
              'Chats',
              1,
              labelColor: isDark ? Colors.white : Colors.white,
              badge: unreadCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    IconData activeIcon,
    String label,
    int index, {
    Color? labelColor,
    int? badge,
  }) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemTapped(index),
          customBorder: const CircleBorder(),
          splashColor: primaryColor.withOpacity(0.1),
          highlightColor: primaryColor.withOpacity(0.1),
          child: SizedBox(
            height: 60,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          isSelected ? activeIcon : icon,
                          color: isSelected
                              ? primaryColor
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                          size: 22,
                        ),
                        if (badge != null && badge > 0)
                          Positioned(
                            right: -8,
                            top: -4,
                            child: CircleAvatar(
                              radius: 8,
                              backgroundColor: Colors.red,
                              child: Text(
                                badge > 99 ? '99+' : badge.toString(),
                                style: TextStyle(
                                  color:
                                      labelColor ??
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? primaryColor
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
