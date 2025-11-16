// ignore_for_file: deprecated_member_use

import 'package:enefty_icons/enefty_icons.dart';
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
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
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
              FluentSystemIcons.ic_fluent_search_regular,
              FluentSystemIcons.ic_fluent_search_filled,
              'Search',
              1,
            ),
            _buildNavItem(
              context,
              EneftyIcons.shopping_cart_outline,
              EneftyIcons.shopping_cart_bold,
              'Carts',
              2,
              badge: pendingCount,
            ),
            _buildNavItem(
              context,
              EneftyIcons.receipt_2_2_outline,
              EneftyIcons.receipt_2_2_bold,
              'Orders',
              3,
              badge: unreadCount,
            ),
            _buildNavItem(
              context,
              FluentSystemIcons.ic_fluent_person_regular,
              FluentSystemIcons.ic_fluent_person_filled,
              'Profile',
              4,
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
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                if (badge != null && badge > 0)
                  Positioned(
                    right: 20,
                    top: 8,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: primaryColor,
                      child: Text(
                        badge > 99 ? '99+' : badge.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
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
}
