import 'package:cloud_firestore/cloud_firestore.dart';

class TimeHelper {
  /// Converts a Firestore timestamp to a human-readable "time ago" format
  static String timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final dateTime = timestamp.toDate();
    Duration difference = DateTime.now().difference(dateTime);
    if (difference.isNegative) {
      difference = difference * -1; // clamp future timestamps
    }
    if (difference.inSeconds < 5) return 'just now';

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  /// Converts a Firestore timestamp to a human-readable "time ago" format for replies
  static String replyTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final dateTime = timestamp.toDate();
    Duration difference = DateTime.now().difference(dateTime);
    if (difference.isNegative) {
      difference = difference * -1; // clamp future timestamps
    }
    if (difference.inSeconds < 5) return 'just now';

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  /// Formats timestamp for chat list (Yesterday, Monday, or date format)
  static String chatListTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      // Today - show time
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      // Check if within last 7 days for day name
      final daysDiff = today.difference(date).inDays;
      if (daysDiff < 7) {
        const weekdays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        return weekdays[dateTime.weekday - 1];
      } else {
        // Show date in format DD/MM
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
      }
    }
  }
}
