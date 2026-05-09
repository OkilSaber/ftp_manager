import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.enabled = true,
  });

  final Widget child;
  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return child
        .animate(delay: Duration(milliseconds: min(index, 8) * 5))
        .fadeIn(duration: 80.ms, curve: Curves.easeOut)
        .slideX(begin: 0.04, end: 0, duration: 80.ms, curve: Curves.easeOut);
  }
}
