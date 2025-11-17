// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'package:devlink/auth/auth_gate.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/screens/about_screen.dart';
import 'package:devlink/screens/terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:devlink/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:devlink/config/oneSignal_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _loadOneSignalKeyFromRemote();
  await _loadPrimaryColorFromRemote();
  final savedMode = await ThemeProvider.readSaved();
  final prefs = await SharedPreferences.getInstance();
  final accepted = prefs.getBool('tosAccepted') ?? false;
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider.preset(savedMode),
      child: MyApp(showTermsOnStart: !accepted),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showTermsOnStart;
  const MyApp({super.key, required this.showTermsOnStart});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DevLink',
        theme: customTheme(),
        darkTheme: customDarkTheme(),
        themeMode: context.watch<ThemeProvider>().themeMode,
        initialRoute: showTermsOnStart ? '/terms' : '/',
        routes: {
          '/': (context) => const AuthGate(),
          '/about': (context) => const AboutScreen(),
          '/terms': (context) => const TermsScreen(),
        },
      ),
    );
  }
}

Future<void> _loadOneSignalKeyFromRemote() async {
  debugPrint("🔄 Starting OneSignal key fetch from Firestore...");

  try {
    final doc = await FirebaseFirestore.instance
        .collection('appUpdates')
        .doc('keys')
        .get();

    if (!doc.exists) {
      debugPrint("❌ Firestore document 'appUpdates/keys' does NOT exist.");
      return;
    }

    final data = doc.data();
    if (data == null) {
      debugPrint("❌ Firestore returned NULL data for 'appUpdates/keys'.");
      return;
    }

    debugPrint("📄 Raw Firestore data: $data");

    final value = data['apiKey'];

    if (value == null) {
      debugPrint("❌ 'apiKey' field is missing in Firestore document.");
      return;
    }

    if (value is! String) {
      debugPrint(
        "❌ 'apiKey' is not a String. Found type: ${value.runtimeType}",
      );
      return;
    }

    if (value.isEmpty) {
      debugPrint("❌ 'apiKey' is an empty string.");
      return;
    }

    OneSignalConfig.appKey = value;
    debugPrint("✅ OneSignal API key loaded successfully: $value");
  } catch (e, stack) {
    debugPrint("🔥 Error loading OneSignal key: $e");
    debugPrint("📌 Stack trace: $stack");
  }
}

Future<void> _loadPrimaryColorFromRemote() async {
  try {
    print('[main] Loading primary color from remote...');
    final doc = await FirebaseFirestore.instance
        .collection('appUpdates')
        .doc('colors')
        .get();
    final data = doc.data();
    print('[main] appUpdates/colors data: $data');
    if (data == null) return;
    final value = data['primaryColor'];
    print('[main] remote primaryColor raw value: $value');
    if (value is int) {
      primaryColor = Color(value);
      print('[main] primaryColor set from int before runApp: $primaryColor');
    } else if (value is String && value.isNotEmpty) {
      final parsed = _parseHexColor(value);
      if (parsed != null) {
        primaryColor = parsed;
        print('[main] primaryColor set from string before runApp: $parsed');
      } else {
        print(
          '[main] Failed to parse string primaryColor in main, keeping default blue',
        );
      }
    } else {
      print(
        '[main] primaryColor missing or empty in main, keeping default blue',
      );
    }
  } catch (_) {
    print('[main] Failed to load primary color from remote');
  }
}

Color? _parseHexColor(String input) {
  var hex = input.trim();
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  if (hex.length == 8) {
    final value = int.tryParse(hex, radix: 16);
    if (value != null) {
      return Color(value);
    }
  }
  return null;
}
