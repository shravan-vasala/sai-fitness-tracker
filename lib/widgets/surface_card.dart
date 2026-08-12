import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/layout_insets.dart';

enum SurfaceCardElevation { home, nested }

/// Standard app surface card — Home cockpit chrome by default.
class SurfaceCard extends StatefulWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.border,
    this.color,
    this.elevation = SurfaceCardElevation.home,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final Color? color;
  final SurfaceCardElevation elevation;
  final double? borderRadius;

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
      widget.onTap!();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? kCardRadius;
    final List<BoxShadow> shadows;
    switch (widget.elevation) {
      case SurfaceCardElevation.home:
        shadows = [
          BoxShadow(
            color: context.colors.textLight.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ];
      case SurfaceCardElevation.nested:
        shadows = [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ];
    }

    final card = Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? context.colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: widget.border,
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: card,
      ),
    );
  }
}
