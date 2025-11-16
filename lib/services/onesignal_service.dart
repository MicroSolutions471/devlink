// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/config/oneSignal_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._();
  static final OneSignalService _instance = OneSignalService._();
  factory OneSignalService() => _instance;

  bool _initialized = false;

  Future<void> _initIfNeeded() async {
    if (_initialized) return;
    OneSignal.initialize(OneSignalConfig.appId);
    // Prompt for permission on iOS/Android 13+ (shows OS prompt when applicable)
    await OneSignal.Notifications.requestPermission(true);
    _initialized = true;
  }

  Future<void> onAuthState(User? user) async {
    await _initIfNeeded();
    if (user == null) {
      // Clear external user context on logout
      await OneSignal.logout();
      return;
    }

    // Set external user id to link this device to the signed-in user
    await OneSignal.login(user.uid);

    // Try to read the current push subscription id (playerId)
    final playerId = OneSignal.User.pushSubscription.id;
    if (playerId != null && playerId.isNotEmpty) {
      await _savePlayerId(user.uid, playerId);
    }

    // Also listen for changes to subscription id and keep Firestore in sync
    OneSignal.User.pushSubscription.addObserver((state) async {
      final id = state.current.id;
      if (id != null && id.isNotEmpty) {
        await _savePlayerId(user.uid, id);
      }
    });
  }

  Future<void> _savePlayerId(String uid, String playerId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'playerId': playerId,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silently handle permission errors - OneSignal will still work without storing playerId
      print('OneSignal: Could not save playerId to Firestore: $e');
    }
  }
}
