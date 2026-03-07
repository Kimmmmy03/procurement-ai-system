import 'dart:ui';
import 'package:flutter/material.dart';

class GlassFilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color activeColor;
  final IconData? icon;

  const GlassFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.activeColor = const Color(0xFF64B5F6),
    this.icon,
  });

  @override
  State<GlassFilterChip> createState() => _GlassFilterChipState();
}

class _GlassFilterChipState extends State<GlassFilterChip>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = widget.activeColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onSelected(!selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: selected ? 12 : 8,
                sigmaY: selected ? 12 : 8,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.35),
                            color.withOpacity(0.15),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(_hovering ? 0.15 : 0.10),
                            Colors.white.withOpacity(_hovering ? 0.08 : 0.05),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? color.withOpacity(0.6)
                        : Colors.white.withOpacity(_hovering ? 0.3 : 0.15),
                    width: selected ? 1.5 : 1.0,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.25),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: color,
                      ),
                      const SizedBox(width: 6),
                    ] else if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: selected ? color : Colors.white.withOpacity(0.85),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;

  const GlassDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.icon = Icons.sort,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              dropdownColor: const Color(0xFF1A2332),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              icon: Icon(icon, color: Colors.white.withOpacity(0.6), size: 18),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final String hintText;
  final TextEditingController? controller;

  const GlassSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Search...',
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5), size: 20),
              filled: false,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }
}
