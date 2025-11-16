// ignore_for_file: avoid_print

import 'dart:io';
import 'package:carbon_icons/carbon_icons.dart';
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
  final _picker = ImagePicker();

  bool _loading = false;
  bool _isDeveloper = false;
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

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _devEmailController.dispose();
    _devPhoneController.dispose();
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
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
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
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
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

      final updates = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'isDeveloper': _isDeveloper,
        'notificationsEnabled': _notificationsEnabled,
        'notifyFromAll': _notifyFromAll,
        'notifyFromFollowers': _notifyFromFollowers,
        if (_isDeveloper) 'email': _devEmailController.text.trim(),
        if (_isDeveloper) 'phone': _devPhoneController.text.trim(),
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
        systemNavigationBarColor: scheme,
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
