import 'package:flutter/material.dart';

class NeumorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurRadius;
  final double offset;
  final bool isPressed;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxShape shape;
  final Color? color;
  final Duration animationDuration;

  const NeumorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurRadius = 10.0,
    this.offset = 5.0,
    this.isPressed = false,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.shape = BoxShape.rectangle,
    this.color,
    this.animationDuration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = color ?? Theme.of(context).scaffoldBackgroundColor;
    
    // Shadows
    final lightShadow = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final darkShadow = isDark ? Colors.black.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.15);

    return AnimatedContainer(
      duration: animationDuration,
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
        boxShadow: isPressed
            ? [
                // Inner shadow effect simulated by smaller shadows or just no shadow
                BoxShadow(color: darkShadow, offset: const Offset(1, 1), blurRadius: 2, spreadRadius: -1),
                BoxShadow(color: lightShadow, offset: const Offset(-1, -1), blurRadius: 2, spreadRadius: -1),
              ]
            : [
                BoxShadow(color: darkShadow, offset: Offset(offset, offset), blurRadius: blurRadius),
                BoxShadow(color: lightShadow, offset: Offset(-offset, -offset), blurRadius: blurRadius),
              ],
      ),
      child: child,
    );
  }
}
