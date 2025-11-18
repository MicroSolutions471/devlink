// ignore_for_file: deprecated_member_use

import 'package:devlink/screens/dashbaord.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:devlink/auth/auth_service.dart';
import 'package:devlink/auth/sign_in_screen.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/custom_textfield.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _devCodeController = TextEditingController();
  final _service = AuthService();
  bool _loading = false;
  bool _googleLoading = false;
  bool _isDeveloper = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _devCodeController.dispose();
    super.dispose();
  }

  Future<void> _signInGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _service.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Dashboard()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyAuthMessage(e))));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      bool isDev = _isDeveloper;
      String devCode = _devCodeController.text.trim();
      if (isDev) {
        final ok = await _service.validateDevCode(devCode);
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Invalid DevCode. Please contact superadmin.',
                ),
                action: SnackBarAction(
                  label: 'WhatsApp',
                  onPressed: _openWhatsApp,
                ),
              ),
            );
          }
          return;
        }
      }

      await _service.signUpWithEmail(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        isDeveloper: isDev,
        devCode: isDev ? devCode : null,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Dashboard()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyAuthMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openWhatsApp() {
    final msg = Uri.encodeComponent(
      'Salam sir i am looking for DevCode in DevLink to be register as a Devleopers',
    );
    final uri = Uri.parse('https://wa.me/923479483218?text=$msg');
    launchUrl(uri, mode: LaunchMode.externalApplication);
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

    final anyLoading = _loading || _googleLoading;
    final isFormFilled =
        _nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        (!_isDeveloper || _devCodeController.text.isNotEmpty);

    return Scaffold(
      backgroundColor: isDark ? scheme.surface : Colors.white,
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
                          "Create an Account 🚀",
                          style:
                              Theme.of(
                                context,
                              ).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ) ??
                              TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Join DevLink and start learning, asking, and sharing knowledge.",
                          style: TextStyle(
                            color: scheme.onSurface.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name
                        CustomTextField(
                          controller: _nameController,
                          hintText: "Full name",
                          prefixIcon: CarbonIcons.user,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),

                        // Email
                        CustomTextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          hintText: "Email address",
                          prefixIcon: CarbonIcons.email,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 20),

                        // Password
                        CustomTextField(
                          isPassword: true,
                          controller: _passwordController,
                          hintText: "Password",
                          prefixIcon: CarbonIcons.password,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () {
                            setState(() {
                              _isDeveloper = !_isDeveloper;
                            });
                          },
                          title: Text('Register as Developer'),
                          trailing: Transform.scale(
                            scale: 0.7,
                            child: Switch(
                              activeColor: primaryColor,
                              value: _isDeveloper,
                              onChanged: (v) =>
                                  setState(() => _isDeveloper = v),
                            ),
                          ),
                        ),

                        if (_isDeveloper) ...[
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _devCodeController,
                            hintText: "DevCode",
                            prefixIcon: CarbonIcons.code,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Don\'t have a DevCode?',
                                style: TextStyle(
                                  color: scheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              IconButton(
                                onPressed: _openWhatsApp,
                                icon: Icon(
                                  LineAwesomeIcons.whatsapp,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],

                        const SizedBox(height: 14),

                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (anyLoading || !isFormFilled)
                                ? null
                                : _signUp,
                            child: _loading
                                ? Loading.medium(color: primaryColor)
                                : const Text("Sign Up"),
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
                                  color: scheme.onSurface.withOpacity(0.6),
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

                        // Google Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed:
                                anyLoading ||
                                    (_isDeveloper &&
                                        _devCodeController.text.isEmpty)
                                ? null
                                : _signInGoogle,
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

                        // Already have account?
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account?",
                              style: TextStyle(
                                color: scheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            TextButton(
                              onPressed: anyLoading
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SignInScreen(),
                                      ),
                                    ),
                              child: Text(
                                "Sign In",
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
