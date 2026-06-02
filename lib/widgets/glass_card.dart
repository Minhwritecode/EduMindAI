import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable glass‑morphism card.
///
/// It applies a blur backdrop with a semi‑transparent background.
/// The `[child]` is displayed inside the card. Optional `[borderRadius]`
/// and `[blurSigma]` allow customization.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.blurSigma = 12.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)),
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: borderRadius,
              border: Border.all(
                width: 1.0,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
