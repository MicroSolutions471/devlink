import 'package:devlink/screens/dashbaord.dart';
import 'package:devlink/screens/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:devlink/auth/sign_in_screen.dart';
import 'package:devlink/services/onesignal_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _minSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _minSplash = false);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // idTokenChanges fires on token refresh/revocation and sign-in/out events.
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snapshot) {
        // Keep OneSignal playerId synced with auth state
        OneSignalService().onAuthState(snapshot.data);
        if (snapshot.connectionState == ConnectionState.waiting || _minSplash) {
          return const SplashScreen();
        }
        final user = snapshot.data;
        if (user != null) {
          return const Dashboard();
        }
        return const SignInScreen();
      },
    );
  }
}
