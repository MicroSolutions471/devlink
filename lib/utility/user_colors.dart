import 'package:flutter/material.dart';

class UserColors {
  static const List<Color> _userColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
  ];

  /// Get a consistent color for a user based on their ID
  static Color getColorForUser(String? userId) {
    if (userId == null || userId.isEmpty) {
      return Colors.grey;
    }
    return _userColors[userId.hashCode.abs() % _userColors.length];
  }

  /// Get a light background color for avatars
  static Color getBackgroundColorForUser(String? userId) {
    return getColorForUser(userId).withValues(alpha: 0.2);
  }

  /// Get the icon color for avatars (same as main color)
  static Color getIconColorForUser(String? userId) {
    return getColorForUser(userId);
  }
}
