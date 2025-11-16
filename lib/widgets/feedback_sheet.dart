// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:devlink/utility/customTheme.dart';
import 'package:devlink/utility/font_styles.dart';
import 'package:devlink/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class FeedbackSheet extends StatefulWidget {
  final String name;
  final String email;
  const FeedbackSheet({super.key, required this.name, required this.email});

  static Future<void> show(
    BuildContext context, {
    required String name,
    required String email,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FeedbackSheet(name: name, email: email),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet>
    with TickerProviderStateMixin {
  double _rating = 2.5;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _emojiController;
  late Animation<double> _emojiAnimation;
  late Animation<double> _emojiRotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();

    // Initialize emoji animations
    _emojiController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _emojiAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.5),
            weight: 20.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.5, end: 0.8),
            weight: 20.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.8, end: 1.2),
            weight: 20.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.2, end: 1.0),
            weight: 20.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.0, end: 1.1),
            weight: 10.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.1, end: 1.0),
            weight: 10.0,
          ),
        ]).animate(
          CurvedAnimation(parent: _emojiController, curve: Curves.easeInOut),
        );

    _emojiRotationAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: 0.2),
            weight: 20.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.2, end: -0.2),
            weight: 40.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: -0.2, end: 0.1),
            weight: 20.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.1, end: 0),
            weight: 20.0,
          ),
        ]).animate(
          CurvedAnimation(parent: _emojiController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _animationController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  String _getRatingText() {
    if (_rating == 0) return 'Tap to rate';
    if (_rating <= 1) return 'Poor';
    if (_rating <= 2) return 'Fair';
    if (_rating <= 3) return 'Good';
    if (_rating <= 4) return 'Very Good';
    return 'Excellent!';
  }

  String _getRatingEmoji() {
    if (_rating == 0) return '🤔';
    if (_rating <= 1) return '😢';
    if (_rating <= 2) return '😕';
    if (_rating <= 3) return '😊';
    if (_rating <= 4) return '😃';
    return '🤩';
  }

  Color _getRatingColor() {
    final scheme = Theme.of(context).colorScheme;
    if (_rating == 0) return scheme.onSurface.withOpacity(0.6);
    if (_rating <= 2) return scheme.error;
    if (_rating <= 3) return scheme.tertiary;
    if (_rating <= 4) return scheme.primary;
    return scheme.secondary;
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please give a rating")));
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
      });
      await FirebaseFirestore.instance.collection("feedbacks").add({
        "name": widget.name,
        "email": widget.email,
        "rating": _rating,
        "feedback": _feedbackController.text.trim(),
        "createdAt": DateTime.now(),
      });

      Navigator.pop(context);
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thank you for your feedback!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withOpacity(0.25),
                blurRadius: 10,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: AnimatedBuilder(
                      animation: _emojiController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: const Offset(0, 0),
                          child: Transform.rotate(
                            angle: _emojiRotationAnimation.value,
                            child: Transform.scale(
                              scale: _emojiAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getRatingColor().withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _getRatingEmoji(),
                                  key: ValueKey<String>(_getRatingEmoji()),
                                  style: const TextStyle(fontSize: 48),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rate your experience',
                    style: titleStyle().copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getRatingText(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _getRatingColor(),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RatingBar.builder(
                    initialRating: _rating,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemSize: 32,
                    glow: true,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                    itemBuilder: (context, _) =>
                        Icon(Icons.star_rounded, color: _getRatingColor()),
                    onRatingUpdate: (rating) {
                      setState(() {
                        _rating = rating;
                      });
                      _emojiController
                        ..reset()
                        ..forward();
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _feedbackController,
                    maxLines: null,
                    cursorColor: primaryColor,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tell us about your experience',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceVariant.withOpacity(
                        theme.brightness == Brightness.dark ? 0.35 : 0.9,
                      ),
                      prefixIcon: Icon(
                        Icons.message_outlined,
                        size: 20,
                        color: scheme.onSurface.withOpacity(0.7),
                      ),
                      hintStyle: TextStyle(
                        color: scheme.onSurface.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getRatingColor(),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        child: _isSubmitting
                            ? Loading.medium()
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Stream<double> calculateAverageRatingStream(String providerId) async* {
  try {
    // Listen to the reviews collection for the specific provider
    final Stream<QuerySnapshot> reviewsStream = FirebaseFirestore.instance
        .collection('reviews')
        .where('providerId', isEqualTo: providerId)
        .snapshots();

    await for (final QuerySnapshot reviewsSnapshot in reviewsStream) {
      if (reviewsSnapshot.docs.isEmpty) {
        yield 0.0;
      } else {
        double totalRating = 0.0;
        for (var doc in reviewsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalRating += (data['rating'] as num).toDouble();
        }
        yield totalRating / reviewsSnapshot.docs.length;
      }
    }
  } catch (e) {
    yield 0.0;
  }
}
