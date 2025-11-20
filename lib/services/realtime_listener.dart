// This will hold the bug/status data for display
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_local_variable

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/utility/font_styles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StatusListener {
  // Cache to store shown status IDs for the current session
  static final Set<String> _shownStatusIds = {};
  static StreamSubscription? _directStatusSubscription;
  static StreamSubscription? _broadcastStatusSubscription;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void _showDialog(
    BuildContext context,
    Map<String, dynamic> statusData,
  ) {
    debugPrint('Creating dialog with status data: $statusData');
    final PageController pageController = PageController();
    bool isAutoScrolling = true;

    // Auto scroll timer
    if ((statusData['images'] as List).length > 1) {
      debugPrint('Setting up auto-scroll for multiple images');
      Future.delayed(const Duration(seconds: 1), () {
        Timer.periodic(const Duration(seconds: 3), (Timer timer) {
          if (isAutoScrolling && pageController.hasClients) {
            if (pageController.page ==
                (statusData['images'] as List).length - 1) {
              pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            } else {
              pageController.nextPage(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          }
        });
      });
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Container();
      },
      transitionBuilder: (context, animation1, animation2, child) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation1, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: animation1,
            child: Dialog(
              backgroundColor: scheme.surface,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Images PageView
                  if (statusData['images'] != null &&
                      (statusData['images'] as List).isNotEmpty)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                            child: PageView.builder(
                              controller: pageController,
                              onPageChanged: (index) {
                                // Optional: Update page indicator
                              },
                              itemCount: (statusData['images'] as List).length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTapDown: (_) => isAutoScrolling = false,
                                  onTapUp: (_) => isAutoScrolling = true,
                                  child: CachedNetworkImage(
                                    imageUrl: statusData['images'][index],
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) {
                                      debugPrint('Error loading image: $error');
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.error_outline,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          // Page indicator dots
                          if ((statusData['images'] as List).length > 1)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  (statusData['images'] as List).length,
                                  (index) => Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (statusData['title']?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              statusData['title'],
                              style: titleStyle().copyWith(
                                color: scheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ),
                        if (statusData['body']?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              statusData['body'],
                              style: TextStyle(
                                fontSize: 16,
                                color: scheme.onSurface.withOpacity(0.8),
                                height: 1.5,
                              ),
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (statusData['link'] != null &&
                                statusData['link'].toString().isNotEmpty)
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    debugPrint(
                                      'Opening link: ${statusData['link']}',
                                    );

                                    try {
                                      launchUrl(Uri.parse(statusData['link']));
                                    } catch (e) {
                                      debugPrint('Error opening link: $e');
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: primaryColor,
                                  ),
                                  child: const Text(
                                    'Visit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  debugPrint('Dismissing dialog');
                                  Navigator.of(context).pop();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onSurface.withOpacity(
                                    0.7,
                                  ),
                                ),
                                child: const Text(
                                  'Dismiss',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showStatusDialog(
    BuildContext context,
    Map<String, dynamic> statusData,
  ) {
    // Check if images exist and are not empty
    if (statusData['images'] != null &&
        statusData['images'] is List &&
        (statusData['images'] as List).isNotEmpty) {
      precacheImage(
            CachedNetworkImageProvider((statusData['images'] as List)[0]),
            context,
          )
          .then((_) {
            _showDialog(context, statusData);
          })
          .catchError((error) {
            debugPrint('Error precaching image: $error');
            _showDialog(context, statusData);
          });
    } else {
      _showDialog(context, statusData);
    }
  }

  static void cancelStatusListeners() {
    _directStatusSubscription?.cancel();
    _broadcastStatusSubscription?.cancel();
    _directStatusSubscription = null;
    _broadcastStatusSubscription = null;
  }

  static void listenForNewStatus(BuildContext context) {
    cancelStatusListeners();

    final String uid = FirebaseAuth.instance.currentUser!.uid;

    // Listen to per-user status subcollection created by admin screen
    _directStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('status')
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) async {
            debugPrint(
              'StatusListener: received ${snapshot.docs.length} unread docs',
            );
            for (var doc in snapshot.docs) {
              final String statusId = doc.id;

              // Skip if already shown in this session
              if (_shownStatusIds.contains(statusId)) {
                continue;
              }

              final data = doc.data();
              final bool isRead = (data['isRead'] as bool?) ?? false;

              if (!isRead) {
                final statusData = {
                  'title': data['title'] ?? 'No Title',
                  'body': data['body'] ?? 'No Message',
                  'images': data['images'] ?? [],
                  'link': data['link'] ?? '',
                };

                // First, mark as read so it won't reappear on app restart
                try {
                  await doc.reference.update({'isRead': true});
                  debugPrint(
                    'Marked user status $statusId as read (pre-display)',
                  );
                } catch (e) {
                  debugPrint('Failed to pre-mark status as read: $e');
                }

                // Add to shown cache and show once per session
                _shownStatusIds.add(statusId);
                if (context.mounted) {
                  debugPrint('StatusListener: showing status $statusId');
                  _showStatusDialog(context, statusData);
                }
              }
            }
          },
          onError: (error) {
            debugPrint('Error in user status listener: $error');
          },
        );
  }

  static Future<bool> hasSeenStatusInFirestore(
    String userId,
    String bugstatusId,
  ) async {
    debugPrint('Checking if status $bugstatusId has been seen by user $userId');
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('seenStatus')
          .doc(bugstatusId)
          .get();

      bool seen = snapshot.exists && (snapshot.data() as Map?)?['seen'] == true;
      debugPrint('Status $bugstatusId seen status in Firestore: $seen');
      return seen;
    } catch (e) {
      debugPrint('Permission or network error reading seenStatus: $e');
      // Gracefully treat as unseen to continue UX; write will be attempted next
      return false;
    }
  }

  static Future<void> markStatusAsSeenInFirestore(
    String userId,
    String bugstatusId,
  ) async {
    debugPrint('Marking status $bugstatusId as seen for user $userId');
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('seenStatus')
          .doc(bugstatusId)
          .set({'seen': true});
      debugPrint('Successfully marked status $bugstatusId as seen');
    } catch (e) {
      debugPrint(
        'Failed to mark status as seen (update your Firestore rules): $e',
      );
    }
  }
}
