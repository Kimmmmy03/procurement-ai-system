import 'package:flutter/material.dart';

class ContainerFillBar extends StatelessWidget {
  final int fillPercentage;
  final String strategy;

  const ContainerFillBar({
    super.key,
    required this.fillPercentage,
    required this.strategy,
  });

  @override
  Widget build(BuildContext context) {
    final clampedFill = fillPercentage.clamp(0, 100);
    final Color barColor;
    if (clampedFill >= 85) {
      barColor = Colors.green;
    } else if (clampedFill >= 60) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    final IconData containerIcon;
    if (strategy == 'Full Container Load') {
      containerIcon = Icons.local_shipping;
    } else if (strategy == 'Less than Container Load') {
      containerIcon = Icons.inventory_2;
    } else {
      containerIcon = Icons.warehouse;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(containerIcon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              strategy,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$clampedFill%',
              style: TextStyle(
                color: barColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clampedFill / 100,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
