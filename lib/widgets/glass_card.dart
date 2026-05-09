import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
    this.blur = 12,
    this.isSelected = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final double blur;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    Color overlayColor;
    if (isSelected) {
      overlayColor = isDark
          ? AppColors.mintAccent.withValues(alpha: 0.12)
          : AppColors.forestGreen.withValues(alpha: 0.10);
    } else {
      overlayColor = isDark ? AppColors.glassOverlayDark : AppColors.glassOverlayLight;
    }

    final gradientColors = isDark
        ? [const Color(0x26FFFFFF), const Color(0x0DFFFFFF)]
        : [const Color(0xB3FFFFFF), const Color(0x66FFFFFF)];

    final borderColor = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;

    Widget card = Container(
      decoration: BoxDecoration(
        color: overlayColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (blur > 0) {
      card = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: card,
        ),
      );
    } else {
      card = ClipRRect(borderRadius: radius, child: card);
    }

    if (margin != null) {
      return Padding(padding: margin!, child: card);
    }
    return card;
  }
}
