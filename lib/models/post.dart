import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String? id;
  final String? text;
  final List<String> imageUrls;
  final List<String> links;
  final String? userId;
  final Timestamp? createdAt;
  final int likes;
  final int dislikes;
  final int replyCount;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final String? authorName;
  final String? authorPhotoUrl;

  Post({
    this.id,
    this.text,
    this.imageUrls = const [],
    this.links = const [],
    this.userId,
    this.createdAt,
    this.likes = 0,
    this.dislikes = 0,
    this.replyCount = 0,
    this.likedBy = const [],
    this.dislikedBy = const [],
    this.authorName,
    this.authorPhotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'imageUrls': imageUrls.isEmpty ? null : imageUrls,
      'links': links.isEmpty ? null : links,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      // Keep numeric counts for backward compatibility; arrays are the source of truth.
      'likes': likes,
      'dislikes': dislikes,
      'replyCount': replyCount,
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
    }..removeWhere((key, value) => value == null);
  }

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Post(
      id: doc.id,
      text: d['text'] as String?,
      imageUrls: (d['imageUrls'] as List?)?.cast<String>() ??
          [if (d['imageUrl'] != null) d['imageUrl'] as String],
      links: (d['links'] as List?)?.cast<String>() ??
          [if (d['link'] != null) d['link'] as String],
      userId: d['userId'] as String?,
      createdAt: d['createdAt'] as Timestamp?,
      likes: (d['likes'] as int?) ?? 0,
      dislikes: (d['dislikes'] as int?) ?? 0,
      replyCount: (d['replyCount'] as int?) ?? 0,
      likedBy: (d['likedBy'] as List?)?.cast<String>() ?? const [],
      dislikedBy: (d['dislikedBy'] as List?)?.cast<String>() ?? const [],
      authorName: d['authorName'] as String?,
      authorPhotoUrl: d['authorPhotoUrl'] as String?,
    );
  }
}

