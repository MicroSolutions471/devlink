// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:devlink/auth/auth_service.dart';
import 'package:devlink/auth/reset_password_screen.dart';
import 'package:devlink/auth/sign_up_screen.dart';
import 'package:devlink/screens/dashboard.dart';
import 'package:devlink/widgets/custom_textfield.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:devlink/utility/customTheme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _service = AuthService();
  bool _emailLoading = false;
  bool _googleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInEmail() async {
    setState(() => _emailLoading = true);
    try {
      await _service.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard()),
        (route) => false,
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _service.signInWithGoogle();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Dashboard()),
        (route) => false,
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(friendlyAuthMessage(e))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    final anyLoading = _emailLoading || _googleLoading;
    final isFormFilled =
        _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.surface
          : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isDark ? scheme.surface : Colors.white,
              scheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.25 : 0.4,
              ),
            ],
          ),
        ),
        child: Center(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  color: isDark ? scheme.surface : Colors.white,
                  elevation: isDark ? 0 : 2,
                  shadowColor: scheme.shadow.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Image.asset(
                                width: 80,
                                'assets/images/logo.png',
                                package: null,
                                fit: BoxFit.contain,
                              ),

                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                        // Header
                        Text(
                          "Welcome Back 👋",
                          style:
                              Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ) ??
                              TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Sign in to continue learning and sharing knowledge",
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 22),
                        // Email
                        CustomTextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          hintText: "Email address",
                          prefixIcon: CarbonIcons.email,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        // Password
                        CustomTextField(
                          controller: _passwordController,
                          isPassword: true,
                          hintText: "Password",
                          prefixIcon: CarbonIcons.password,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _emailLoading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ResetPasswordScreen(),
                                    ),
                                  ),
                            child: Text(
                              "Forgot password?",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (anyLoading || !isFormFilled)
                                ? null
                                : _signInEmail,

                            child: _emailLoading
                                ? Loading.medium(color: primaryColor)
                                : const Text("Sign In"),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Theme.of(context).dividerColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: anyLoading ? null : _signInGoogle,

                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_googleLoading)
                                  Loading.medium(color: primaryColor)
                                else
                                  Image.asset(
                                    'assets/images/google-logo.png',
                                    height: 20,
                                    width: 20,
                                  ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _googleLoading
                                        ? "Signing in..."
                                        : "Continue with Google",
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Sign Up link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don’t have an account?",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            TextButton(
                              onPressed: anyLoading
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SignUpScreen(),
                                      ),
                                    ),
                              child: Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
