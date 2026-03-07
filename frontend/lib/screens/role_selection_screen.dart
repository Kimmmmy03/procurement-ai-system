// lib/screens/role_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;
import 'dart:ui' as ui;

import 'approver/approver_main_navigator.dart';
import 'officer_main_navigator.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            js.context.callMethod('initFloatingLines', []);
          } catch (e) {
            debugPrint('FloatingLines init error: $e');
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    if (kIsWeb) {
      try {
        js.context.callMethod('destroyFloatingLines', []);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020208),
      body: Stack(
        children: [
          // Dark gradient background tint
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.3),
                radius: 1.2,
                colors: [
                  Color(0xFF080c1a),
                  Color(0xFF020208),
                ],
              ),
            ),
          ),

          // Dark overlay for extra tint
          Container(color: Colors.black.withOpacity(0.35)),

          // Vignette overlay for depth
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),

          // Main Content
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo icon — white, AI-themed
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.08),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.08),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title — split text animation
                    const _SplitText(
                      text: 'Procurement AI',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        height: 1.1,
                      ),
                      delay: Duration(milliseconds: 300),
                      staggerDuration: Duration(milliseconds: 50),
                      animationDuration: Duration(milliseconds: 500),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Select your interface to continue',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.45),
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 56),

                    // Role Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _HoverRoleCard(
                            title: 'Procurement Officer',
                            name: 'John Lance',
                            description: 'Manage daily operations, generate purchase requests & track orders',
                            icon: Icons.inventory_2_rounded,
                            accentColor: const Color(0xFF00BCD4),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => const OfficerMainNavigator(),
                                  transitionsBuilder: (_, a, __, c) =>
                                      FadeTransition(opacity: a, child: c),
                                  transitionDuration: const Duration(milliseconds: 300),
                                ),
                              );
                            },
                          ),
                          _HoverRoleCard(
                            title: 'Executive Approver',
                            name: 'Sarah Lee (GM)',
                            description: 'Review AI forecasts, batch approvals & procurement analytics',
                            icon: Icons.verified_user_rounded,
                            accentColor: const Color(0xFFFF9800),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => ApproverMainNavigator(),
                                  transitionsBuilder: (_, a, __, c) =>
                                      FadeTransition(opacity: a, child: c),
                                  transitionDuration: const Duration(milliseconds: 300),
                                ),
                              );
                            },
                          ),
                        ];

                        if (constraints.maxWidth > 800) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              cards[0],
                              const SizedBox(width: 32),
                              cards[1],
                            ],
                          );
                        }
                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 20),
                            cards[1],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 48),
                    Text(
                      'Powered by Azure AI Foundry',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.2),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Role card with hover lift + glow animation
class _HoverRoleCard extends StatefulWidget {
  final String title;
  final String name;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _HoverRoleCard({
    required this.title,
    required this.name,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_HoverRoleCard> createState() => _HoverRoleCardState();
}

class _HoverRoleCardState extends State<_HoverRoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            final t = _hoverAnimation.value;
            return Transform.translate(
              offset: Offset(0, -6 * t),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 42 + 12 * t,
                    sigmaY: 42 + 12 * t,
                  ),
                  child: Container(
                    width: 300,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.21 + 0.08 * t),
                          Colors.white.withOpacity(0.12 + 0.06 * t),
                        ],
                      ),
                      border: Border.all(
                        color: Color.lerp(
                          Colors.white.withOpacity(0.20),
                          widget.accentColor.withOpacity(0.45),
                          t,
                        )!,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withOpacity(0.05 + 0.15 * t),
                          blurRadius: 40 + 20 * t,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3 + 0.1 * t),
                          blurRadius: 24,
                          offset: Offset(0, 8 + 4 * t),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: _buildCardContent(),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return AnimatedBuilder(
      animation: _hoverAnimation,
      builder: (context, _) {
        final t = _hoverAnimation.value;
        final btnColor = Color.lerp(
          Colors.white,
          widget.accentColor,
          t,
        )!;
        final btnTextColor = Color.lerp(
          const Color(0xFF0a0a14),
          Colors.white,
          t,
        )!;
        final btnShadowOpacity = 0.05 + 0.25 * t;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon circle
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor.withOpacity(0.1),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(widget.icon, size: 28, color: widget.accentColor),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Name badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: widget.accentColor.withOpacity(0.1),
              ),
              child: Text(
                widget.name,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.accentColor.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              widget.description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Button — white by default, accent color on hover
            Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: btnColor,
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(btnShadowOpacity),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Access Portal',
                      style: TextStyle(
                        color: btnTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: btnTextColor, size: 18),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Glass Container Widget (kept for use by other screens)
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double blur;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.opacity = 0.5,
    this.blur = 15,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 20,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.6),
              width: 1.5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(opacity + 0.2),
                Colors.white.withOpacity(opacity),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(10, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// Liquid Button Widget (kept for use by other screens)
class LiquidButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const LiquidButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isPrimary
            ? const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFEF5350)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? const Color(0xFF1E88E5).withOpacity(0.4)
                : const Color(0xFFE53935).withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Split-text animation: each character slides up and fades in with a stagger.
class _SplitText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration delay;
  final Duration staggerDuration;
  final Duration animationDuration;

  const _SplitText({
    required this.text,
    required this.style,
    this.delay = const Duration(milliseconds: 200),
    this.staggerDuration = const Duration(milliseconds: 50),
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  State<_SplitText> createState() => _SplitTextState();
}

class _SplitTextState extends State<_SplitText> with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _fadeAnimations = [];
  final List<Animation<Offset>> _slideAnimations = [];

  @override
  void initState() {
    super.initState();

    final totalChars = widget.text.length;
    final totalStagger =
        widget.staggerDuration.inMilliseconds * (totalChars - 1);
    final totalDuration =
        widget.animationDuration.inMilliseconds + totalStagger;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalDuration),
    );

    for (int i = 0; i < totalChars; i++) {
      final startRatio =
          (widget.staggerDuration.inMilliseconds * i) / totalDuration;
      final endRatio =
          (widget.staggerDuration.inMilliseconds * i +
              widget.animationDuration.inMilliseconds) /
          totalDuration;

      _fadeAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(startRatio, endRatio.clamp(0.0, 1.0),
                curve: Curves.easeOut),
          ),
        ),
      );

      _slideAnimations.add(
        Tween<Offset>(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(startRatio, endRatio.clamp(0.0, 1.0),
                curve: Curves.easeOutCubic),
          ),
        ),
      );
    }

    Future.delayed(widget.delay, () {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB0BEC5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.text.length, (i) {
              final char = widget.text[i];
              return SlideTransition(
                position: _slideAnimations[i],
                child: Opacity(
                  opacity: _fadeAnimations[i].value,
                  child: Text(
                    char == ' ' ? '\u00A0' : char,
                    style: widget.style,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
