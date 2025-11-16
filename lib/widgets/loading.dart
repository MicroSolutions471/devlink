// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

enum LoadingStyle {
  inkDrop,
  staggeredDotsWave,
  threeRotatingDots,
  fourRotatingDots,
  fallingDot,
  threeArchedCircle,
  horizontalRotatingDots,
  newtonCradle,
  twistingDots,
}

class Loading extends StatelessWidget {
  final double size;
  final Color color;
  final LoadingStyle style;
  final Color? secondaryColor; // used for animations that require two colors

  const Loading({
    super.key,
    this.size = 20,
    this.color = Colors.white,
    this.style = LoadingStyle.inkDrop,
    this.secondaryColor,
  });

  // Small is tuned for icon slots in buttons to avoid overflow (ThreeBounce width ~ size*3 + gaps)
  const Loading.small({
    super.key,
    this.size = 8,
    this.color = Colors.white,
    this.style = LoadingStyle.inkDrop,
    this.secondaryColor,
  });

  const Loading.medium({
    super.key,
    this.size = 20,
    this.color = Colors.white,
    this.style = LoadingStyle.inkDrop,
    this.secondaryColor,
  });

  const Loading.large({
    super.key,
    this.size = 34,
    this.color = Colors.white,
    this.style = LoadingStyle.inkDrop,
    this.secondaryColor,
  });

  Widget _buildAnim() {
    switch (style) {
      case LoadingStyle.inkDrop:
        return LoadingAnimationWidget.inkDrop(color: color, size: size);
      case LoadingStyle.staggeredDotsWave:
        return LoadingAnimationWidget.staggeredDotsWave(
          color: color,
          size: size,
        );
      case LoadingStyle.threeRotatingDots:
        return LoadingAnimationWidget.threeRotatingDots(
          color: color,
          size: size,
        );
      case LoadingStyle.fourRotatingDots:
        return LoadingAnimationWidget.fourRotatingDots(
          color: color,
          size: size,
        );
      case LoadingStyle.fallingDot:
        return LoadingAnimationWidget.fallingDot(color: color, size: size);
      case LoadingStyle.threeArchedCircle:
        return LoadingAnimationWidget.threeArchedCircle(
          color: color,
          size: size,
        );
      case LoadingStyle.horizontalRotatingDots:
        return LoadingAnimationWidget.horizontalRotatingDots(
          color: color,
          size: size,
        );
      case LoadingStyle.newtonCradle:
        return LoadingAnimationWidget.newtonCradle(color: color, size: size);
      case LoadingStyle.twistingDots:
        // needs two colors
        final right = secondaryColor ?? color.withOpacity(0.6);
        return LoadingAnimationWidget.twistingDots(
          leftDotColor: color,
          rightDotColor: right,
          size: size,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: FittedBox(fit: BoxFit.scaleDown, child: _buildAnim()),
    );
  }
}
