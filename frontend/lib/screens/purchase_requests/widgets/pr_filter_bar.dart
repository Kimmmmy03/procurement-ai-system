import 'package:flutter/material.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/glass_filter_chip.dart';

class PRFilterBar extends StatelessWidget {
  final String filterRisk;
  final String sortBy;
  final int selectedCount;
  final int totalCount;
  final int criticalCount;
  final int warningCount;
  final int lowRiskCount;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;

  const PRFilterBar({
    super.key,
    required this.filterRisk,
    required this.sortBy,
    required this.selectedCount,
    required this.totalCount,
    required this.criticalCount,
    required this.warningCount,
    required this.lowRiskCount,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.onRefresh,
    required this.onSelectAll,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Filter Chips
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GlassFilterChip(
                      label: 'All (${criticalCount + warningCount + lowRiskCount})',
                      selected: filterRisk == 'ALL',
                      onSelected: (_) => onFilterChanged('ALL'),
                      activeColor: const Color(0xFF64B5F6),
                    ),
                    GlassFilterChip(
                      label: 'Critical ($criticalCount)',
                      selected: filterRisk == 'CRITICAL',
                      onSelected: (_) => onFilterChanged('CRITICAL'),
                      activeColor: const Color(0xFFEF5350),
                    ),
                    GlassFilterChip(
                      label: 'Warning ($warningCount)',
                      selected: filterRisk == 'WARNING',
                      onSelected: (_) => onFilterChanged('WARNING'),
                      activeColor: const Color(0xFFFFB74D),
                    ),
                    GlassFilterChip(
                      label: 'Low ($lowRiskCount)',
                      selected: filterRisk == 'LOW',
                      onSelected: (_) => onFilterChanged('LOW'),
                      activeColor: const Color(0xFF66BB6A),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Sort Dropdown
              GlassDropdown<String>(
                value: sortBy,
                icon: Icons.sort,
                items: const [
                  DropdownMenuItem(value: 'risk', child: Text('Sort: Risk')),
                  DropdownMenuItem(value: 'value', child: Text('Sort: Value')),
                  DropdownMenuItem(value: 'stock', child: Text('Sort: Stock')),
                ],
                onChanged: (v) {
                  if (v != null) onSortChanged(v);
                },
              ),
              const SizedBox(width: 8),
              // Refresh
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54),
                onPressed: onRefresh,
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Selection controls row
          Row(
            children: [
              TextButton.icon(
                onPressed: onSelectAll,
                icon: const Icon(Icons.select_all, size: 16, color: Color(0xFF64B5F6)),
                label: const Text('Select All', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onClearSelection,
                icon: const Icon(Icons.deselect, size: 16, color: Colors.white54),
                label: const Text('Clear', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              const Spacer(),
              // Count badges
              _buildCountBadge('$criticalCount Critical', const Color(0xFFEF5350)),
              const SizedBox(width: 8),
              _buildCountBadge('$warningCount Warning', const Color(0xFFFFB74D)),
              const SizedBox(width: 8),
              _buildCountBadge('$lowRiskCount Low', const Color(0xFF66BB6A)),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF64B5F6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalCount items',
                  style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
