import 'package:cloud_firestore/cloud_firestore.dart';

class ReactionHelper {
  /// Toggles user reaction (like/dislike) on a post or reply
  static Future<void> toggleUserReaction({
    required DocumentReference ref,
    required String uid,
    required bool like,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final likedBy = (data['likedBy'] as List?)?.cast<String>() ?? <String>[];
      final dislikedBy =
          (data['dislikedBy'] as List?)?.cast<String>() ?? <String>[];
      final currentlyLiked = likedBy.contains(uid);
      final currentlyDisliked = dislikedBy.contains(uid);

      final updates = <String, dynamic>{};

      if (like) {
        if (currentlyLiked) {
          updates['likedBy'] = FieldValue.arrayRemove([uid]);
          updates['likes'] = (data['likes'] as int? ?? 0) - 1;
        } else {
          updates['likedBy'] = FieldValue.arrayUnion([uid]);
          updates['likes'] = (data['likes'] as int? ?? 0) + 1;
          if (currentlyDisliked) {
            updates['dislikedBy'] = FieldValue.arrayRemove([uid]);
            updates['dislikes'] = (data['dislikes'] as int? ?? 0) - 1;
          }
        }
      } else {
        if (currentlyDisliked) {
          updates['dislikedBy'] = FieldValue.arrayRemove([uid]);
          updates['dislikes'] = (data['dislikes'] as int? ?? 0) - 1;
        } else {
          updates['dislikedBy'] = FieldValue.arrayUnion([uid]);
          updates['dislikes'] = (data['dislikes'] as int? ?? 0) + 1;
          if (currentlyLiked) {
            updates['likedBy'] = FieldValue.arrayRemove([uid]);
            updates['likes'] = (data['likes'] as int? ?? 0) - 1;
          }
        }
      }

      tx.update(ref, updates);
    });
  }
}
