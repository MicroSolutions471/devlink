// ignore_for_file: avoid_print, duplicate_ignore

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:devlink/config/oneSignal_config.dart';

class FollowService {
  FollowService._();
  static final instance = FollowService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<bool> isFollowing(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUserId) return false;

    // Check the current user's following subcollection instead of target's followers
    // This is more reliable with the bidirectional system
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUserId)
        .get();
    return doc.exists;
  }

  Future<void> toggleFollow(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUserId) {
      return;
    }
    final targetRef = _db.collection('users').doc(targetUserId);
    final currentRef = _db.collection('users').doc(uid);
    final followerRef = targetRef.collection('followers').doc(uid);
    final followingRef = currentRef.collection('following').doc(targetUserId);

    final didFollow = await _db.runTransaction<bool>((tx) async {
      final followingSnap = await tx.get(followingRef);
      final targetSnap = await tx.get(targetRef);
      final currentSnap = await tx.get(currentRef);

      final isCurrentlyFollowing = followingSnap.exists;
      final targetFollowers =
          (targetSnap.data()?['followersCount'] as int?) ?? 0;
      final currentFollowing =
          (currentSnap.data()?['followingCount'] as int?) ?? 0;

      if (isCurrentlyFollowing) {
        // Unfollow
        tx.delete(followerRef);

        // Also delete the following doc for the current user
        tx.delete(followingRef);

        tx.update(targetRef, {
          'followersCount': targetFollowers > 0 ? targetFollowers - 1 : 0,
        });
        tx.update(currentRef, {
          'followingCount': currentFollowing > 0 ? currentFollowing - 1 : 0,
        });
        return false;
      }

      // Follow
      tx.set(followerRef, {
        'createdAt': FieldValue.serverTimestamp(),
        'followerId': uid,
      });

      // Also create a following doc for the current user
      tx.set(followingRef, {
        'createdAt': FieldValue.serverTimestamp(),
        'targetUserId': targetUserId,
      });

      tx.update(targetRef, {'followersCount': targetFollowers + 1});
      tx.update(currentRef, {'followingCount': currentFollowing + 1});

      final fromData = currentSnap.data();
      final fromName =
          (fromData?['name'] as String?) ??
          (fromData?['displayName'] as String?) ??
          'Someone';

      final notificationRef = _db.collection('notifications').doc();
      tx.set(notificationRef, {
        'id': notificationRef.id,
        'type': 'follow',
        'toUserId': targetUserId,
        'fromUserId': uid,
        'title': '$fromName started following you',
        'body': '',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      return true;
    });

    // Send push notification only on new follow (not on unfollow)
    if (didFollow) {
      try {
        final targetSnap = await _db
            .collection('users')
            .doc(targetUserId)
            .get();
        final targetData = targetSnap.data() ?? {};
        final playerId = targetData['playerId'] as String?;
        final notificationsEnabled =
            (targetData['notificationsEnabled'] as bool?) ?? false;
        final notifyFromFollowers =
            (targetData['notifyFromFollowers'] as bool?) ?? false;
        final notifyFromAll = (targetData['notifyFromAll'] as bool?) ?? false;

        if (playerId == null || playerId.isEmpty) return;
        if (!notificationsEnabled) return;
        if (!notifyFromFollowers && !notifyFromAll) return;

        final currentSnap = await _db.collection('users').doc(uid).get();
        final fromData = currentSnap.data() ?? {};
        final fromName =
            (fromData['name'] as String?) ??
            (fromData['displayName'] as String?) ??
            'Someone';

        await _sendOneSignal(
          includePlayerIds: [playerId],
          title: '$fromName started following you',
          body: 'Tap to view their profile',
          data: {'type': 'follow', 'fromUserId': uid},
        );
      } catch (e, stack) {
        // Don't break app flow on push error
        // ignore: avoid_print
        print('Error sending follow push: $e');
        print(stack);
      }
    }
  }

  Future<void> _sendOneSignal({
    required List<String> includePlayerIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final uri = Uri.parse('https://api.onesignal.com/notifications');
    final payload = {
      'app_id': OneSignalConfig.appId,
      'include_player_ids': includePlayerIds,
      'headings': {'en': title},
      'contents': {'en': body},
      if (data != null) 'data': data,
    };

    final client = HttpClient();

    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${OneSignalConfig.appKey}',
      );
      req.add(utf8.encode(jsonEncode(payload)));

      final resp = await req.close();

      if (resp.statusCode != 200) {
        final responseBody = await resp.transform(utf8.decoder).join();
        // ignore: avoid_print
        print(
          'Failed to send follow notification. Status: ${resp.statusCode}, body: $responseBody',
        );
      }
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('Error sending OneSignal follow notification: $e');
      print(stackTrace);
    } finally {
      client.close();
    }
  }
}
