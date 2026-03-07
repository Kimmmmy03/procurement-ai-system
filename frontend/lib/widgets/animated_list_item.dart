import 'dart:math' as math;
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// SlideDirection enum
// ---------------------------------------------------------------------------

enum SlideDirection { up, down, left, right }

// ---------------------------------------------------------------------------
// 1. AnimatedListItem
//    Wraps any child with a staggered fade + slide entrance animation.
// ---------------------------------------------------------------------------

class AnimatedListItem extends StatefulWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.direction = SlideDirection.up,
    this.duration = const Duration(milliseconds: 400),
    this.staggerDelay = const Duration(milliseconds: 50),
  });

  final int index;
  final Widget child;
  final SlideDirection direction;
  final Duration duration;
  final Duration staggerDelay;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  bool get wantKeepAlive => true;

  Offset _directionOffset() {
    switch (widget.direction) {
      case SlideDirection.up:
        return const Offset(0, 1);
      case SlideDirection.down:
        return const Offset(0, -1);
      case SlideDirection.left:
        return const Offset(1, 0);
      case SlideDirection.right:
        return const Offset(-1, 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);

    final offset = _directionOffset();
    _slide = Tween<Offset>(
      begin: Offset(offset.dx * 30, offset.dy * 30),
      end: Offset.zero,
    ).animate(curved);

    final stagger = widget.staggerDelay * widget.index;
    Future.delayed(stagger, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: _slide.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. AnimatedCounter
//    Animates a number counting up from 0 to the target value.
// ---------------------------------------------------------------------------

class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 800),
    this.prefix,
    this.suffix,
    this.decimalPlaces = 0,
    this.style,
  });

  final num value;
  final Duration duration;
  final String? prefix;
  final String? suffix;
  final int decimalPlaces;
  final TextStyle? style;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _buildAnimation(0, widget.value.toDouble());
    _controller.forward();
  }

  void _buildAnimation(double from, double to) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    );
    _animation = Tween<double>(begin: from, end: to).animate(curved);
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value.toDouble();
      _controller.reset();
      _buildAnimation(_previousValue, widget.value.toDouble());
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final formatted = _animation.value.toStringAsFixed(widget.decimalPlaces);
        final text =
            '${widget.prefix ?? ''}$formatted${widget.suffix ?? ''}';
        return Text(text, style: widget.style);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. FadeSlideIn
//    Simple fade + slide wrapper with configurable offset and delay.
// ---------------------------------------------------------------------------

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0, 20),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(curved);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
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
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: _slide.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// 4. AnimatedGradientBorder
//    Container with a slowly rotating sweep-gradient border.
// ---------------------------------------------------------------------------

class AnimatedGradientBorder extends StatefulWidget {
  const AnimatedGradientBorder({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.borderWidth = 1.5,
    this.colors = const [
      Color(0xFF1E88E5),
      Color(0xFF26A69A),
      Color(0xFF1E88E5),
    ],
    this.duration = const Duration(seconds: 3),
  });

  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final List<Color> colors;
  final Duration duration;

  @override
  State<AnimatedGradientBorder> createState() => _AnimatedGradientBorderState();
}

class _AnimatedGradientBorderState extends State<AnimatedGradientBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
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
        return CustomPaint(
          painter: _GradientBorderPainter(
            progress: _controller.value,
            borderRadius: widget.borderRadius,
            borderWidth: widget.borderWidth,
            colors: widget.colors,
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.borderWidth),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  _GradientBorderPainter({
    required this.progress,
    required this.borderRadius,
    required this.borderWidth,
    required this.colors,
  });

  final double progress;
  final double borderRadius;
  final double borderWidth;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(borderRadius),
    );

    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: colors,
      transform: GradientRotation(progress * math.pi * 2),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ---------------------------------------------------------------------------
// 5. StaggeredColumn / StaggeredRow
//    Automatically wraps children with AnimatedListItem stagger.
// ---------------------------------------------------------------------------

class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  final List<Widget> children;
  final Duration staggerDelay;
  final Duration itemDuration;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (int i = 0; i < children.length; i++)
          AnimatedListItem(
            index: i,
            staggerDelay: staggerDelay,
            duration: itemDuration,
            child: children[i],
          ),
      ],
    );
  }
}

class StaggeredRow extends StatelessWidget {
  const StaggeredRow({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.itemDuration = const Duration(milliseconds: 400),
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  final List<Widget> children;
  final Duration staggerDelay;
  final Duration itemDuration;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (int i = 0; i < children.length; i++)
          AnimatedListItem(
            index: i,
            staggerDelay: staggerDelay,
            duration: itemDuration,
            direction: SlideDirection.left,
            child: children[i],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. PulseWidget
//    Subtle repeating pulse with glow shadow effect.
// ---------------------------------------------------------------------------

class PulseWidget extends StatefulWidget {
  const PulseWidget({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF1E88E5),
    this.duration = const Duration(seconds: 2),
  });

  final Widget child;
  final Color glowColor;
  final Duration duration;

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scale = Tween<double>(begin: 0.97, end: 1.0).animate(curved);
    _glowOpacity = Tween<double>(begin: 0.0, end: 0.45).animate(curved);
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
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withOpacity(_glowOpacity.value),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
