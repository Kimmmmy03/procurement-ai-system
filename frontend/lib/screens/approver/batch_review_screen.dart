// screens/approver/batch_review_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/procurement_models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/glass_filter_chip.dart';
import '../../widgets/risk_badge_widget.dart';
import '../../widgets/container_fill_bar.dart';
import '../../widgets/skeleton_layouts.dart';

class BatchReviewScreen extends StatefulWidget {
  const BatchReviewScreen({super.key});

  @override
  State<BatchReviewScreen> createState() => _BatchReviewScreenState();
}

class _BatchReviewScreenState extends State<BatchReviewScreen> {
  List<PurchaseRequest> _requests = [];
  bool _isLoading = true;
  Set<int> _selectedIds = {};
  int? _expandedId;
  String _filterRisk = 'ALL';
  String _sortBy = 'risk';

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final requests = await apiService.getPurchaseRequestsByStatus(['Pending']);
      setState(() {
        _requests = requests;
        _selectedIds.clear();
        _expandedId = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        GlassNotification.show(context, 'Error loading requests: $e', isError: true);
      }
    }
  }

  List<PurchaseRequest> get _filteredRequests {
    var filtered = _filterRisk == 'ALL'
        ? List<PurchaseRequest>.from(_requests)
        : _requests.where((r) => r.riskLevel.toUpperCase() == _filterRisk).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'risk':
          const riskOrder = {'CRITICAL': 0, 'WARNING': 1, 'LOW': 2};
          return (riskOrder[a.riskLevel.toUpperCase()] ?? 3)
              .compareTo(riskOrder[b.riskLevel.toUpperCase()] ?? 3);
        case 'value':
          return b.totalValue.compareTo(a.totalValue);
        case 'stock':
          return a.currentStock.compareTo(b.currentStock);
        default:
          return 0;
      }
    });

    return filtered;
  }

  int get _criticalCount => _requests.where((r) => r.riskLevel.toUpperCase() == 'CRITICAL').length;
  int get _warningCount => _requests.where((r) => r.riskLevel.toUpperCase() == 'WARNING').length;
  int get _lowRiskCount => _requests.where((r) => r.riskLevel.toUpperCase() == 'LOW').length;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds = _filteredRequests.map((r) => r.requestId).toSet();
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  double get _selectedTotalValue {
    return _requests
        .where((r) => _selectedIds.contains(r.requestId))
        .fold(0.0, (sum, r) => sum + r.totalValue);
  }

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

  Future<void> _approveSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        width: 420,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF66BB6A), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Approve Requests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF66BB6A), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_selectedIds.length} item(s) selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Total Value: RM ${_selectedTotalValue.toStringAsFixed(2)}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('These items will be approved and proceed to PO generation.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(ctx, false),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  child: Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF66BB6A).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.5)),
              boxShadow: [BoxShadow(color: const Color(0xFF66BB6A).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(ctx, true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 16, color: Color(0xFF66BB6A)),
                      SizedBox(width: 7),
                      Text('Approve', style: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final result = await apiService.approveRequests(_selectedIds.toList());
        if (mounted) {
          GlassNotification.show(context, '${result['approved_count'] ?? _selectedIds.length} request(s) approved');
          _loadPendingRequests();
        }
      } catch (e) {
        if (mounted) {
          GlassNotification.show(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  Future<void> _rejectSelected() async {
    if (_selectedIds.isEmpty) return;

    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        width: 420,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cancel_outlined, color: Color(0xFFEF5350), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Reject Requests', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reject ${_selectedIds.length} item(s)?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Rejection Reason',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'e.g., Budget constraints, Not urgent',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.pop(ctx, null),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  child: Text('Cancel', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.5)),
              boxShadow: [BoxShadow(color: const Color(0xFFEF5350).withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  final text = reasonController.text.trim();
                  Navigator.pop(ctx, text.isEmpty ? 'Rejected by approver' : text);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, size: 16, color: Color(0xFFEF5350)),
                      SizedBox(width: 7),
                      Text('Reject', style: TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (reason != null) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        final result = await apiService.rejectRequests(_selectedIds.toList(), reason);
        if (mounted) {
          GlassNotification.show(context, '${result['rejected_count'] ?? _selectedIds.length} request(s) rejected', isError: true);
          _loadPendingRequests();
        }
      } catch (e) {
        if (mounted) {
          GlassNotification.show(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  Future<void> _approveSingle(PurchaseRequest pr) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.approveRequests([pr.requestId]);
      if (mounted) {
        GlassNotification.show(context, '${pr.productName} approved');
        _loadPendingRequests();
      }
    } catch (e) {
      if (mounted) {
        GlassNotification.show(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _rejectSingle(PurchaseRequest pr) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: Text('Reject ${pr.productName}', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Rejection Reason',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: 'e.g., Budget constraints',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = reasonController.text.trim();
              Navigator.pop(ctx, text.isEmpty ? 'Rejected by approver' : text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason != null) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.rejectRequests([pr.requestId], reason);
        if (mounted) {
          GlassNotification.show(context, '${pr.productName} rejected', isError: true);
          _loadPendingRequests();
        }
      } catch (e) {
        if (mounted) {
          GlassNotification.show(context, 'Error: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: BatchReviewSkeleton(),
            )
          else
            Column(
              children: [
                // Header + Filter bar
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'Batch Review',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Review and approve/reject pending purchase requests',
                              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filter bar (same pattern as John's Manage PRs)
                      GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Risk filter chips
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      GlassFilterChip(
                                        label: 'All (${_requests.length})',
                                        selected: _filterRisk == 'ALL',
                                        onSelected: (_) => setState(() => _filterRisk = 'ALL'),
                                        activeColor: const Color(0xFF64B5F6),
                                      ),
                                      GlassFilterChip(
                                        label: 'Critical ($_criticalCount)',
                                        selected: _filterRisk == 'CRITICAL',
                                        onSelected: (_) => setState(() => _filterRisk = 'CRITICAL'),
                                        activeColor: const Color(0xFFEF5350),
                                      ),
                                      GlassFilterChip(
                                        label: 'Warning ($_warningCount)',
                                        selected: _filterRisk == 'WARNING',
                                        onSelected: (_) => setState(() => _filterRisk = 'WARNING'),
                                        activeColor: const Color(0xFFFFB74D),
                                      ),
                                      GlassFilterChip(
                                        label: 'Low ($_lowRiskCount)',
                                        selected: _filterRisk == 'LOW',
                                        onSelected: (_) => setState(() => _filterRisk = 'LOW'),
                                        activeColor: const Color(0xFF66BB6A),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Sort dropdown
                                GlassDropdown<String>(
                                  value: _sortBy,
                                  icon: Icons.sort,
                                  items: const [
                                    DropdownMenuItem(value: 'risk', child: Text('Sort: Risk')),
                                    DropdownMenuItem(value: 'value', child: Text('Sort: Value')),
                                    DropdownMenuItem(value: 'stock', child: Text('Sort: Stock')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _sortBy = v);
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: Colors.white54),
                                  onPressed: _loadPendingRequests,
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Selection controls row
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _selectAll,
                                  icon: const Icon(Icons.select_all, size: 16, color: Color(0xFF64B5F6)),
                                  label: const Text('Select All', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: _clearSelection,
                                  icon: const Icon(Icons.deselect, size: 16, color: Colors.white54),
                                  label: const Text('Clear', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ),
                                const Spacer(),
                                _buildCountBadge('$_criticalCount Critical', const Color(0xFFEF5350)),
                                const SizedBox(width: 8),
                                _buildCountBadge('$_warningCount Warning', const Color(0xFFFFB74D)),
                                const SizedBox(width: 8),
                                _buildCountBadge('$_lowRiskCount Low', const Color(0xFF66BB6A)),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF64B5F6).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${filtered.length} items',
                                    style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Table header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 48), // checkbox space
                        SizedBox(width: 100, child: Text('SKU', style: _headerStyle)),
                        Expanded(flex: 2, child: Text('Product', style: _headerStyle)),
                        SizedBox(width: 80, child: Text('AI Qty', style: _headerStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 100, child: Text('Risk', style: _headerStyle, textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('AI Insight', style: _headerStyle)),
                        SizedBox(width: 110, child: Text('Value', style: _headerStyle, textAlign: TextAlign.right)),
                        const SizedBox(width: 32), // expand toggle space
                      ],
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No pending requests to review',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final pr = filtered[index];
                            final isSelected = _selectedIds.contains(pr.requestId);
                            final isExpanded = _expandedId == pr.requestId;
                            return _buildRequestItem(pr, isSelected, isExpanded);
                          },
                        ),
                ),

                // Bottom action bar
                if (_selectedIds.isNotEmpty)
                  ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64B5F6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_selectedIds.length} selected',
                                style: const TextStyle(color: Color(0xFF64B5F6), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Total: RM ${_selectedTotalValue.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Spacer(),
                            // Reject button — glass morphism
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF5350).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.5), width: 1),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFFEF5350).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _rejectSelected,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.close, size: 18, color: Color(0xFFEF5350)),
                                        SizedBox(width: 8),
                                        Text('Reject Selected', style: TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Approve button — glass morphism
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF66BB6A).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.5), width: 1),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF66BB6A).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _approveSelected,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check, size: 18, color: Color(0xFF66BB6A)),
                                        SizedBox(width: 8),
                                        Text('Approve Selected', style: TextStyle(color: Color(0xFF66BB6A), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Expandable data grid row — matches PRListItem pattern from John's Manage PRs
  Widget _buildRequestItem(PurchaseRequest pr, bool isSelected, bool isExpanded) {
    final riskColor = _getRiskColor(pr.riskLevel);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Main row (always visible) — clickable to expand
            InkWell(
              onTap: () {
                setState(() {
                  _expandedId = _expandedId == pr.requestId ? null : pr.requestId;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Checkbox
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(pr.requestId),
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
                    // AI Qty
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
                              '-> ${pr.userOverriddenQty}',
                              style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                    // Risk badge widget
                    SizedBox(
                      width: 100,
                      child: RiskBadge(riskLevel: pr.riskLevel),
                    ),
                    // AI Insight (truncated) + transit days
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pr.aiInsightText ?? '',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            if (pr.estimatedTransitDays > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.flight, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${pr.estimatedTransitDays} days transit',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.5),
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Total value
                    SizedBox(
                      width: 110,
                      child: Text(
                        'RM ${pr.totalValue.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
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
            // Expanded detail — three-column layout + approve/reject actions
            if (isExpanded) _buildExpandedDetail(pr),
          ],
        ),
      ),
    );
  }

  /// Three-column expanded detail panel — matches PRExpandedDetail from John's view
  Widget _buildExpandedDetail(PurchaseRequest pr) {
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
                    _DetailRow('Unit Price', 'RM ${pr.unitPrice.toStringAsFixed(2)}'),
                    _DetailRow('Total Value', 'RM ${pr.totalValue.toStringAsFixed(2)}'),
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
                if (pr.isOverridden) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Officer Override: ${pr.userOverriddenQty} units (${pr.overrideReason})',
                      style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11),
                    ),
                  ),
                ],
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
          // Action buttons — Approve / Reject (GM-specific)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _rejectSingle(pr),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _approveSingle(pr),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF66BB6A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
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

  TextStyle get _headerStyle => TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
