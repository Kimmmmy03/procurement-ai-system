import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final String riskLevel;
  final double fontSize;

  const RiskBadge({
    super.key,
    required this.riskLevel,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = riskLevel.toUpperCase();
    final Color bgColor;
    final Color textColor;
    final IconData icon;

    if (normalized == 'HIGH' || normalized == 'CRITICAL') {
      bgColor = Colors.red.withValues(alpha: 0.15);
      textColor = Colors.red;
      icon = Icons.error_outline;
    } else if (normalized == 'MEDIUM' || normalized == 'WARNING') {
      bgColor = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
    } else {
      bgColor = Colors.green.withValues(alpha: 0.15);
      textColor = Colors.green;
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2, color: textColor),
          const SizedBox(width: 4),
          Text(
            riskLevel.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
