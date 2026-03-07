import 'package:flutter/material.dart';
import '../../../models/procurement_models.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/container_fill_bar.dart';
import '../../../widgets/risk_badge_widget.dart';
import 'pr_expanded_detail.dart';

class PRListItem extends StatelessWidget {
  final PurchaseRequest pr;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onToggleSelection;
  final VoidCallback onToggleExpand;
  final VoidCallback onOverride;
  final VoidCallback onSkip;

  const PRListItem({
    super.key,
    required this.pr,
    required this.isSelected,
    required this.isExpanded,
    required this.onToggleSelection,
    required this.onToggleExpand,
    required this.onOverride,
    required this.onSkip,
  });

  Color _getRiskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFEF5350);
      case 'WARNING':
        return const Color(0xFFFFB74D);
      case 'LOW':
        return const Color(0xFF66BB6A);
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL':
        return Icons.error;
      case 'WARNING':
        return Icons.warning;
      case 'LOW':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatPrice(double price) {
    return 'RM ${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _getRiskColor(pr.riskLevel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Main row (always visible)
            InkWell(
              onTap: onToggleExpand,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Checkbox
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelection(),
                      activeColor: const Color(0xFF64B5F6),
                      checkColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    // SKU
                    SizedBox(
                      width: 100,
                      child: Text(
                        pr.sku,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    ),
                    // Product name
                    Expanded(
                      flex: 2,
                      child: Text(
                        pr.productName,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // AI Qty (read-only)
                    SizedBox(
                      width: 80,
                      child: Column(
                        children: [
                          Text(
                            '${pr.aiRecommendedQty}',
                            style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 14, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          if (pr.isOverridden)
                            Text(
                              '→ ${pr.userOverriddenQty}',
                              style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                    // Risk badge
                    SizedBox(
                      width: 100,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: riskColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getRiskIcon(pr.riskLevel), color: riskColor, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              pr.riskLevel.toUpperCase(),
                              style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // AI Insight (truncated)
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          pr.aiInsightText ?? '',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    // Total value
                    SizedBox(
                      width: 110,
                      child: Text(
                        _formatPrice(pr.totalValue),
                        style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    // Override button
                    IconButton(
                      icon: Icon(
                        pr.isOverridden ? Icons.edit_note : Icons.edit,
                        color: pr.isOverridden ? const Color(0xFFFFB74D) : Colors.white54,
                        size: 20,
                      ),
                      onPressed: onOverride,
                      tooltip: 'Override Quantity',
                    ),
                    // Expand toggle
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            // Expanded detail
            if (isExpanded)
              PRExpandedDetail(
                pr: pr,
                onSkip: onSkip,
                onOverride: onOverride,
              ),
          ],
        ),
      ),
    );
  }
}
