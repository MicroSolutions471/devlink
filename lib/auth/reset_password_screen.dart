// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:carbon_icons/carbon_icons.dart';
import 'package:devlink/auth/auth_service.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/custom_textfield.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _service = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    setState(() => _loading = true);
    try {
      await _service.resetPassword(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyAuthMessage(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final isFormFilled = _emailController.text.trim().isNotEmpty;

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
                        Text(
                          "Reset Password",
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
                          "Enter your email and we’ll send you a reset link.",
                          style: TextStyle(
                            color: scheme.onSurface.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 22),
                        CustomTextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          hintText: "Email address",
                          prefixIcon: CarbonIcons.email,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_loading || !isFormFilled)
                                ? null
                                : _reset,
                            child: _loading
                                ? Loading.medium(color: primaryColor)
                                : const Text("Send Reset Link"),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.arrow_back,
                              color: scheme.onSurface.withOpacity(0.6),
                            ),
                            label: Text(
                              "Back to Login",
                              style: TextStyle(
                                color: scheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ),
                        ),
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
