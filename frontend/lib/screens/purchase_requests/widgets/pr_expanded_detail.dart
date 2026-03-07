import 'package:flutter/material.dart';
import '../../../models/procurement_models.dart';
import '../../../widgets/container_fill_bar.dart';

class PRExpandedDetail extends StatelessWidget {
  final PurchaseRequest pr;
  final VoidCallback onSkip;
  final VoidCallback onOverride;

  const PRExpandedDetail({
    super.key,
    required this.pr,
    required this.onSkip,
    required this.onOverride,
  });

  String _formatPrice(double price) => 'RM ${price.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final avgDaily = pr.avgDailySales;
    final safetyStock = (avgDaily * pr.supplierLeadTime * 0.2).ceil();
    final reorderPoint = (avgDaily * pr.supplierLeadTime).ceil() + safetyStock;

    return Container(
      padding: const EdgeInsets.fromLTRB(48, 0, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Three-column detail layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Historical Sales
              Expanded(
                child: _buildDetailSection(
                  'Historical Sales Data',
                  Icons.trending_up,
                  const Color(0xFF64B5F6),
                  [
                    _DetailRow('Last 30 Days', '${pr.last30DaysSales} units'),
                    _DetailRow('Last 60 Days', '${pr.last60DaysSales} units'),
                    _DetailRow('Avg Daily Sales', '${avgDaily.toStringAsFixed(1)} units'),
                    _DetailRow('Trend', pr.last30DaysSales > (pr.last60DaysSales / 2) ? 'Increasing' : 'Decreasing'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Column 2: Current Inventory
              Expanded(
                child: _buildDetailSection(
                  'Current Inventory Status',
                  Icons.inventory_2,
                  const Color(0xFFFFB74D),
                  [
                    _DetailRow('Current Stock', '${pr.currentStock} units'),
                    _DetailRow('Lead Time', '${pr.supplierLeadTime} days'),
                    _DetailRow('Stock Coverage', '${pr.stockCoverageDays} days'),
                    _DetailRow('Reorder Point', '$reorderPoint units'),
                    _DetailRow('Safety Stock', '$safetyStock units'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Column 3: AI Risk Analysis
              Expanded(
                child: _buildDetailSection(
                  'AI Risk Analysis',
                  Icons.psychology,
                  const Color(0xFF66BB6A),
                  [
                    _DetailRow('Risk Level', pr.riskLevel.toUpperCase()),
                    _DetailRow('AI Insight', pr.aiInsightText ?? 'N/A'),
                    _DetailRow('Unit Price', _formatPrice(pr.unitPrice)),
                    _DetailRow('Total Value', _formatPrice(pr.totalValue)),
                    _DetailRow('Min Order Qty', '${pr.minOrderQty} units'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Supplier Information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF9C27B0), size: 18),
                const SizedBox(width: 12),
                Text(
                  'Supplier: ${pr.supplierName ?? "N/A"}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 24),
                Text(
                  'MOQ: ${pr.minOrderQty} units',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
                const Spacer(),
                if (pr.isOverridden)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Overridden: ${pr.userOverriddenQty} units (${pr.overrideReason})',
                      style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          // Shipping & Logistics Row
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Container Recommendation
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_boat, color: Color(0xFF42A5F5), size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Container / Shipping',
                            style: TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              pr.containerStrategy,
                              style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Container size & count
                      if (pr.containerSize.isNotEmpty && pr.containerSize != 'None')
                        _buildLogisticsChip(
                          Icons.inventory_2,
                          '${pr.containerCount}x ${pr.containerSize}',
                          const Color(0xFF42A5F5),
                        ),
                      if (pr.containerSize.isEmpty || pr.containerSize == 'None')
                        _buildLogisticsChip(
                          Icons.warehouse,
                          'Local Bulk / No container needed',
                          Colors.white54,
                        ),
                      const SizedBox(height: 8),
                      // Volume & Weight utilization bars
                      ContainerFillBar(
                        fillPercentage: pr.containerFillRate,
                        strategy: 'Volume',
                      ),
                      const SizedBox(height: 4),
                      ContainerFillBar(
                        fillPercentage: pr.weightUtilizationPct,
                        strategy: 'Weight',
                      ),
                      const SizedBox(height: 8),
                      // CBM / Weight / Transit stats
                      Row(
                        children: [
                          if (pr.totalCbm > 0)
                            Text(
                              '${pr.totalCbm.toStringAsFixed(1)} CBM',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                            ),
                          if (pr.totalCbm > 0 && pr.totalWeightKg > 0)
                            Text(' | ', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10)),
                          if (pr.totalWeightKg > 0)
                            Text(
                              '${pr.totalWeightKg.toStringAsFixed(0)} kg',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                            ),
                          const Spacer(),
                          if (pr.estimatedTransitDays > 0)
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 10, color: Colors.white.withValues(alpha: 0.4)),
                                const SizedBox(width: 3),
                                Text(
                                  '${pr.estimatedTransitDays}d transit',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                                ),
                              ],
                            ),
                        ],
                      ),
                      // Spare capacity / fill-up suggestion
                      if (pr.fillUpSuggestion.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline, color: Color(0xFFFF9800), size: 13),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  pr.fillUpSuggestion,
                                  style: const TextStyle(color: Color(0xFFFF9800), fontSize: 10, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Lorry Recommendation + AI Reasoning
              Expanded(
                child: Column(
                  children: [
                    // Lorry recommendation
                    if (pr.recommendedLorry.isNotEmpty && pr.recommendedLorry != 'None')
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF66BB6A).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.local_shipping, color: Color(0xFF66BB6A), size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Local Delivery',
                                  style: TextStyle(color: Color(0xFF66BB6A), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildLogisticsChip(
                              Icons.fire_truck,
                              '${pr.lorryCount}x ${pr.recommendedLorry}',
                              const Color(0xFF66BB6A),
                            ),
                          ],
                        ),
                      ),
                    // AI Reasoning
                    if (pr.aiReasoning != null && pr.aiReasoning!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9C27B0).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.psychology, color: Color(0xFF9C27B0), size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'AI Reasoning',
                                  style: TextStyle(color: Color(0xFF9C27B0), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pr.aiReasoning!,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, height: 1.4),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onSkip,
                icon: const Icon(Icons.skip_next, size: 16),
                label: const Text('Skip This Item'),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onOverride,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Override Quantity'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB74D),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, Color color, List<_DetailRow> rows) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(row.label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                Flexible(
                  child: Text(
                    row.value,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
