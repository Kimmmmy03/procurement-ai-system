import 'dart:ui';
import 'package:flutter/material.dart';

/// A single shimmering skeleton block that matches the Glassmorphism design.
///
/// Uses an implicit [AnimationController] to sweep a translucent highlight
/// across a frosted-glass container, giving a modern "content loading" feel.
class GlassSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const GlassSkeleton({
    super.key,
    this.width,
    this.height = 20,
    this.borderRadius = 10,
  });

  @override
  State<GlassSkeleton> createState() => _GlassSkeletonState();
}

class _GlassSkeletonState extends State<GlassSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-0.4 + 2.0 * _controller.value, 0),
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.14),
                Colors.white.withOpacity(0.06),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
        );
      },
    );
  }
}

/// A glass-morphism container with shimmering children.
/// Wraps skeleton blocks in the same frosted-glass card used by [GlassContainer].
class GlassSkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GlassSkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
