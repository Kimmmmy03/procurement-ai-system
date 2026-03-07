// screens/approver/approval_history_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/glass_filter_chip.dart';
import '../../widgets/skeleton_layouts.dart';

class ApprovalHistoryScreen extends StatefulWidget {
  const ApprovalHistoryScreen({super.key});

  @override
  State<ApprovalHistoryScreen> createState() => _ApprovalHistoryScreenState();
}

class _ApprovalHistoryScreenState extends State<ApprovalHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  String _filterAction = 'ALL';
  String _searchQuery = '';
  int _expandedIndex = -1;

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final history = await apiService.getApprovalHistory();

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading history: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        GlassNotification.show(context, 'Failed to load approval history', isError: true);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    var filtered = _history;

    // Filter by action
    if (_filterAction != 'ALL') {
      filtered = filtered.where((h) => h['action'] == _filterAction).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((h) {
        final q = _searchQuery.toLowerCase();
        final batchId = (h['batch_id'] ?? '').toString().toLowerCase();
        final officer = (h['officer'] ?? '').toString().toLowerCase();
        final product = (h['product'] ?? '').toString().toLowerCase();
        final sku = (h['sku'] ?? '').toString().toLowerCase();
        final supplier = (h['supplier'] ?? '').toString().toLowerCase();
        return batchId.contains(q) || officer.contains(q) ||
            product.contains(q) || sku.contains(q) || supplier.contains(q);
      }).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> get _paginatedHistory {
    final filtered = _filteredHistory;
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, filtered.length);
    
    if (startIndex >= filtered.length) return [];
    return filtered.sublist(startIndex, endIndex);
  }

  int get _totalPages {
    return (_filteredHistory.length / _itemsPerPage).ceil();
  }

  // Safe helper method
  String _formatPrice(dynamic price) {
    if (price == null) return 'RM 0.00';
    if (price is num) return 'RM ${price.toStringAsFixed(2)}';
    if (price is String) {
      if (price.startsWith('RM')) return price;
      final cleaned = price.replaceAll(',', '');
      final parsed = double.tryParse(cleaned);
      return parsed != null ? 'RM ${parsed.toStringAsFixed(2)}' : price;
    }
    return 'RM 0.00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dark gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),

          // Main content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: ListViewSkeleton(itemCount: 6),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Approval History',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'View all approval and rejection records',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF64B5F6),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: _loadHistory,
                        icon: const Icon(Icons.refresh, color: Color(0xFF64B5F6)),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Search and Filter Bar
                  _GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Search Field
                        Expanded(
                          flex: 2,
                          child: GlassSearchField(
                            hintText: 'Search by batch ID or officer...',
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _currentPage = 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Filter Chips
                        Expanded(
                          flex: 3,
                          child: Wrap(
                            spacing: 8,
                            children: ['ALL', 'APPROVED', 'REJECTED'].map((action) {
                              return GlassFilterChip(
                                label: action,
                                selected: _filterAction == action,
                                onSelected: (_) {
                                  setState(() {
                                    _filterAction = action;
                                    _currentPage = 0;
                                  });
                                },
                                activeColor: const Color(0xFF64B5F6),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Results Count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Showing ${_paginatedHistory.length} of ${_filteredHistory.length} records',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // History List
                  Expanded(
                    child: _filteredHistory.isEmpty
                        ? _GlassContainer(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history,
                                      size: 64, color: Colors.white.withOpacity(0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No results found for "$_searchQuery"'
                                        : 'No approval history found',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _paginatedHistory.length,
                            itemBuilder: (context, index) {
                              final record = _paginatedHistory[index];
                              final globalIndex = _currentPage * _itemsPerPage + index;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildHistoryCard(record, globalIndex),
                              );
                            },
                          ),
                  ),

                  // Pagination Controls
                  if (_totalPages > 1) ...[
                    const SizedBox(height: 16),
                    _GlassContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page ${_currentPage + 1} of $_totalPages',
                            style: const TextStyle(color: Colors.white),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                                icon: const Icon(Icons.chevron_left),
                                color: _currentPage > 0
                                    ? const Color(0xFF64B5F6)
                                    : Colors.white.withOpacity(0.3),
                              ),
                              IconButton(
                                onPressed: _currentPage < _totalPages - 1
                                    ? () => setState(() => _currentPage++)
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                                color: _currentPage < _totalPages - 1
                                    ? const Color(0xFF64B5F6)
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ],
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
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record, int globalIndex) {
    final isApproved = record['action'] == 'APPROVED';
    final actionColor = isApproved ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);
    final isExpanded = _expandedIndex == globalIndex;

    return _GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header row (always visible, clickable)
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? -1 : globalIndex;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Action Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isApproved ? Icons.check_circle : Icons.cancel,
                      color: actionColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Summary
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              record['batch_id'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: actionColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: actionColor),
                              ),
                              child: Text(
                                record['action'] ?? 'UNKNOWN',
                                style: TextStyle(
                                  color: actionColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Officer: ${record['officer'] ?? 'N/A'} • ${record['item_count'] ?? 0} items • ${_formatPrice(record['total_value'])}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Timestamp + expand icon
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        record['date'] ?? 'N/A',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record['time'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          color: Colors.white.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded details
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedDetails(record, actionColor),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(Map<String, dynamic> record, Color actionColor) {
    final riskLevel = (record['risk_level'] ?? '').toString();
    final riskColor = riskLevel.toLowerCase().contains('critical')
        ? const Color(0xFFEF5350)
        : riskLevel.toLowerCase().contains('warning')
            ? const Color(0xFFFFB74D)
            : const Color(0xFF66BB6A);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detail grid
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildDetailItem(Icons.inventory_2, 'Product', record['product'] ?? 'N/A'),
              _buildDetailItem(Icons.qr_code, 'SKU', record['sku'] ?? 'N/A'),
              _buildDetailItem(Icons.local_shipping, 'Supplier', record['supplier'] ?? 'N/A'),
              _buildDetailItem(Icons.attach_money, 'Value', _formatPrice(record['total_value'])),
              _buildDetailItem(Icons.calendar_today, 'Submitted', _formatSubmittedDate(record['submitted_date'])),
            ],
          ),
          const SizedBox(height: 12),

          // Risk level badge
          if (riskLevel.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.shield, size: 16, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  'Risk Level: ',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: riskColor.withOpacity(0.6)),
                  ),
                  child: Text(
                    riskLevel.toUpperCase(),
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Notes
          if (record['notes'] != null && record['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record['notes'].toString(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return SizedBox(
      width: 200,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64B5F6)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSubmittedDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    // Take just the date part if it has time
    final parts = dateStr.split(' ');
    return parts.isNotEmpty ? parts[0] : dateStr;
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassContainer({required this.child, this.padding = EdgeInsets.zero});

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