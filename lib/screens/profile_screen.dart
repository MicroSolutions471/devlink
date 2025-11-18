// ignore_for_file: avoid_print, deprecated_member_use

import 'dart:io';
import 'package:carbon_icons/carbon_icons.dart';
import 'package:devlink/auth/auth_service.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/widgets/custom_textfield.dart';
import 'package:enefty_icons/enefty_icons.dart';
import 'package:fluentui_icons/fluentui_icons.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:devlink/services/image_upload_service.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _devEmailController = TextEditingController();
  final _devPhoneController = TextEditingController();
  final _devCodeController = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = false;
  bool _isDeveloper = false;
  bool _wantsDeveloper = false;
  bool _notificationsEnabled = false;
  bool _notifyFromAll = false;
  bool _notifyFromFollowers = false;
  String? _currentPhotoUrl;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _openWhatsAppForDevCode() {
    final msg = Uri.encodeComponent(
      'Salam sir, I am looking for DevCode in DevLink to be registered as a Developer.',
    );
    final uri = Uri.parse('https://wa.me/923479483218?text=$msg');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _devEmailController.dispose();
    _devPhoneController.dispose();
    _devCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? data['displayName'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _devEmailController.text = (data['email'] as String?) ?? '';
          _devPhoneController.text = (data['phone'] as String?) ?? '';
          _isDeveloper = data['isDeveloper'] ?? false;
          _wantsDeveloper = false;
          _notificationsEnabled = data['notificationsEnabled'] ?? false;
          _notifyFromAll = data['notifyFromAll'] ?? false;
          _notifyFromFollowers = data['notifyFromFollowers'] ?? false;
          _currentPhotoUrl = data['photoUrl'] ?? data['avatar'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _pickImage() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),

                // GALLERY
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.photo_library,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  },
                ),

                // CAMERA
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.photo_camera,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      String? photoUrl = _currentPhotoUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        photoUrl = await ImageUploadService.instance.uploadImage(
          _selectedImage!,
        );
      }

      bool newIsDeveloper = _isDeveloper;
      final devCode = _devCodeController.text.trim();

      // If user is not yet a developer but wants to become one, validate DevCode
      if (!newIsDeveloper && _wantsDeveloper) {
        if (devCode.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a DevCode.')),
            );
          }
          return;
        }

        final service = AuthService();
        final ok = await service.validateDevCode(devCode);
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Invalid DevCode. Please contact superadmin.',
                ),
                action: SnackBarAction(
                  label: 'WhatsApp',
                  onPressed: _openWhatsAppForDevCode,
                ),
              ),
            );
          }
          return;
        }

        newIsDeveloper = true;
      }

      final updates = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'isDeveloper': newIsDeveloper,
        'notificationsEnabled': _notificationsEnabled,
        'notifyFromAll': _notifyFromAll,
        'notifyFromFollowers': _notifyFromFollowers,
        if (newIsDeveloper) 'email': _devEmailController.text.trim(),
        if (newIsDeveloper) 'phone': _devPhoneController.text.trim(),
        if (newIsDeveloper && devCode.isNotEmpty) 'devCode': devCode,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updates, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final scheme = isDark ? cs.surface : cs.surfaceContainerHighest;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: isDark ? scheme : Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            TextButton(
              onPressed: _loading ? null : _saveProfile,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Photo
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : _currentPhotoUrl != null
                          ? NetworkImage(_currentPhotoUrl!)
                          : null,
                      child: _selectedImage == null && _currentPhotoUrl == null
                          ? Icon(
                              FluentSystemIcons.ic_fluent_person_filled,
                              size: 60,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isDeveloper)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    'Developer Account',
                    style: TextStyle(color: primaryColor, fontSize: 12),
                  ),
                ),
              if (!_isDeveloper) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).cardColor),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        onTap: () {
                          setState(() {
                            _wantsDeveloper = !_wantsDeveloper;
                          });
                        },
                        title: const Text('Register as Developer'),
                        trailing: Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            activeThumbColor: primaryColor,
                            value: _wantsDeveloper,
                            onChanged: (v) => setState(() {
                              _wantsDeveloper = v;
                            }),
                          ),
                        ),
                      ),
                      if (_wantsDeveloper) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomTextField(
                                controller: _devCodeController,
                                hintText: 'DevCode',
                                prefixIcon: CarbonIcons.code,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    "Don't have a DevCode?",
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _openWhatsAppForDevCode,
                                    icon: const Icon(
                                      LineAwesomeIcons.whatsapp,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              CustomTextField(label: 'Name', controller: _nameController),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Bio',
                maxLines: 3,
                controller: _bioController,
              ),
              const SizedBox(height: 24),
              // Developer contact (only show if developer)
              if (_isDeveloper) ...[
                CustomTextField(
                  prefixIcon: CarbonIcons.email,
                  label: 'Email',
                  maxLines: 1,
                  controller: _devEmailController,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  keyboardType: TextInputType.phone,
                  prefixIcon: CarbonIcons.phone,
                  label: 'Phone',
                  maxLines: 1,
                  controller: _devPhoneController,
                ),
                const SizedBox(height: 24),
              ],

              // Notifications Settings (only show if developer)
              if (_isDeveloper) ...[
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Theme.of(context).colorScheme.surface
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Theme.of(context).dividerColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () {
                          setState(
                            () =>
                                _notificationsEnabled = !_notificationsEnabled,
                          );
                        },
                        leading: Icon(EneftyIcons.notification_bing_outline),
                        title: const Text('Notifications'),
                        subtitle: Text(
                          _notificationsEnabled ? 'Enabled' : 'Disabled',
                        ),
                        trailing: Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            activeThumbColor: primaryColor,
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() => _notificationsEnabled = value);
                            },
                          ),
                        ),
                      ),
                      if (_notificationsEnabled) ...[
                        const Divider(height: 1),
                        CheckboxListTile(
                          activeColor: primaryColor,
                          title: const Text(
                            'Notifications from All',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text(
                            'Receive notifications from all users',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          value: _notifyFromAll,
                          onChanged: (value) {
                            setState(() => _notifyFromAll = value ?? false);
                          },
                        ),
                        CheckboxListTile(
                          activeColor: primaryColor,
                          title: const Text(
                            'Notifications from Followers',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text(
                            'Receive notifications from users who follow you',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          value: _notifyFromFollowers,
                          onChanged: (value) {
                            setState(
                              () => _notifyFromFollowers = value ?? false,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
