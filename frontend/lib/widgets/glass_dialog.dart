import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

/// A glassmorphism-styled dialog that replaces AlertDialog.
/// Provides frosted glass background with blur, gradient, and subtle borders.
class GlassAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final double? width;
  final BoxConstraints? constraints;

  const GlassAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.width,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: width,
            constraints: constraints,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xCC1A2332),
                  Color(0xDD0F1923),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    DefaultTextStyle(
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      child: title!,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (content != null)
                    DefaultTextStyle(
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      child: content!,
                    ),
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: actions!
                          .expand((w) => [w, const SizedBox(width: 8)])
                          .toList()
                        ..removeLast(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A larger glassmorphism dialog for complex content (PO details, emails, etc).
class GlassDialog extends StatelessWidget {
  final Widget child;
  final double? width;
  final BoxConstraints? constraints;

  const GlassDialog({
    super.key,
    required this.child,
    this.width,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: width,
            constraints: constraints,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xCC1A2332),
                  Color(0xDD0F1923),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism overlay notification — replaces SnackBar system-wide.
/// Usage: GlassNotification.show(context, 'Message', isError: false)
class GlassNotification {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
    IconData? icon,
  }) {
    // Remove any existing notification
    _current?.remove();
    _current = null;

    final accentColor = isError ? const Color(0xFFEF5350) : const Color(0xFF66BB6A);
    final toastIcon = icon ?? (isError ? Icons.error_outline : Icons.check_circle_outline);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _GlassNotificationWidget(
        message: message,
        accentColor: accentColor,
        icon: toastIcon,
        onDismiss: () {
          entry.remove();
          _current = null;
        },
        duration: duration,
      ),
    );

    _current = entry;
    Overlay.of(context).insert(entry);
  }
}

class _GlassNotificationWidget extends StatefulWidget {
  final String message;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onDismiss;
  final Duration duration;

  const _GlassNotificationWidget({
    required this.message,
    required this.accentColor,
    required this.icon,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_GlassNotificationWidget> createState() => _GlassNotificationWidgetState();
}

class _GlassNotificationWidgetState extends State<_GlassNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    _timer?.cancel();
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      right: 24,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380, minWidth: 260),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xCC1A2332),
                        const Color(0xDD0F1923),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.accentColor.withOpacity(0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withOpacity(0.15),
                        blurRadius: 24,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 32,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(widget.icon, color: widget.accentColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.4),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
