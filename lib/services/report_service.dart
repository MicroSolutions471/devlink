import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:devlink/config/oneSignal_config.dart';

class ReportService {
  ReportService._();
  static final instance = ReportService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to report.');
    }
    final reporterId = user.uid;

    final userSnap = await _db.collection('users').doc(reporterId).get();
    final userData = userSnap.data() ?? {};
    final reporterName =
        (userData['name'] as String?) ??
        (userData['displayName'] as String?) ??
        user.displayName ??
        'User';

    final reportRef = _db.collection('reports').doc();
    await reportRef.set({
      'id': reportRef.id,
      'postId': postId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'new',
    });

    final adminDoc = await _db
        .collection('appUpdates')
        .doc('adminNotificationID')
        .get();
    final adminData = adminDoc.data() ?? {};
    final playerId = adminData['oneSignalPlayerID'] as String?;
    final adminUserId = adminData['userId'] as String?;

    if (adminUserId != null && adminUserId.isNotEmpty) {
      await _db.collection('notifications').add({
        'toUserId': adminUserId,
        'fromUserId': reporterId,
        'type': 'report',
        'title': 'New post reported',
        'body': '$reporterName reported a post',
        'data': {'postId': postId, 'type': 'report'},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (playerId != null && playerId.isNotEmpty) {
      await _sendOneSignal(
        includePlayerIds: [playerId],
        title: 'New post reported',
        body: '$reporterName reported a post',
        data: {'type': 'report', 'postId': postId},
      );
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
      await req.close();
    } finally {
      client.close();
    }
  }
}
