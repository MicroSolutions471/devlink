// ignore_for_file: deprecated_member_use

import 'package:devlink/utility/customTheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsScreen extends StatefulWidget {
  final bool fromDrawer;
  const TermsScreen({super.key, this.fromDrawer = false});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _agree = false;
  bool _saving = false;

  Future<void> _accept() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tosAccepted', true);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.fromDrawer,
          title: const Text('Terms of Service'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to DevLink',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'DevLink is a community platform—similar to Stack Overflow—designed to help developers, programmers, and learners collaborate, ask questions, share knowledge, and build teams. Please read these terms carefully before using the app.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withOpacity(0.8),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _h2(context, '1. Using DevLink'),
                      _p(
                        context,
                        'Be respectful and professional. Avoid harassment, hate speech, spam, or illegal content.',
                      ),
                      _p(
                        context,
                        'Share accurate information and cite sources where possible.',
                      ),
                      _p(
                        context,
                        'Do not post code or assets without the right to share them.',
                      ),
                      const SizedBox(height: 12),
                      _h2(context, '2. Content and Ownership'),
                      _p(
                        context,
                        'You retain ownership of your posts. By posting, you grant DevLink a non-exclusive license to display and distribute your content within the platform.',
                      ),
                      _p(
                        context,
                        'Please do not share sensitive personal data or secrets (API keys, passwords).',
                      ),
                      const SizedBox(height: 12),
                      _h2(context, '3. Safety and Moderation'),
                      _p(
                        context,
                        'We may remove content or restrict accounts that violate these terms.',
                      ),
                      _p(
                        context,
                        'Report abuse via the contact options in the About screen.',
                      ),
                      const SizedBox(height: 12),
                      _h2(context, '4. Changes to the Service'),
                      _p(
                        context,
                        'We may update features or policies. We will aim to notify users of significant changes.',
                      ),
                      const SizedBox(height: 12),
                      _h2(context, '5. Disclaimer'),
                      _p(
                        context,
                        'Content is provided by the community. DevLink is not responsible for inaccuracies or damages arising from the use of posted content.',
                      ),
                      const SizedBox(height: 16),
                      if (!widget.fromDrawer)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'By proceeding you agree to follow these guidelines and our terms. You can revisit these terms from Settings/About at any time.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!widget.fromDrawer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            activeColor: primaryColor,
                            value: _agree,
                            onChanged: (v) =>
                                setState(() => _agree = v ?? false),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'I have read and agree to the Terms of Service',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: (!_agree || _saving) ? null : _accept,
                          child: Text(
                            _saving ? 'Saving...' : 'Accept & Continue',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _h2(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _p(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: cs.onSurface.withOpacity(0.85),
          height: 1.45,
        ),
      ),
    );
  }
}
