import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/procurement_models.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_dialog.dart';
import 'widgets/pr_filter_bar.dart';
import 'widgets/pr_list_item.dart';
import 'widgets/pr_action_bar.dart';
import 'widgets/pr_override_dialog.dart';
import '../../widgets/skeleton_layouts.dart';
import '../../widgets/animated_list_item.dart';

class PurchaseRequestsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const PurchaseRequestsScreen({super.key, this.onNavigate});

  @override
  State<PurchaseRequestsScreen> createState() => _PurchaseRequestsScreenState();
}

class _PurchaseRequestsScreenState extends State<PurchaseRequestsScreen> {
  List<PurchaseRequest> _requests = [];
  bool _isLoading = true;
  String _filterRisk = 'ALL';
  String _sortBy = 'risk';
  Set<int> _selectedIds = {};
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final requests = await apiService.getPurchaseRequestsList(status: 'Draft');
      setState(() {
        _requests = requests;
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

  double get _selectedTotalValue {
    return _requests
        .where((r) => _selectedIds.contains(r.requestId))
        .fold(0.0, (sum, r) => sum + r.totalValue);
  }

  int get _criticalCount => _requests.where((r) => r.riskLevel.toUpperCase() == 'CRITICAL').length;
  int get _warningCount => _requests.where((r) => r.riskLevel.toUpperCase() == 'WARNING').length;
  int get _lowRiskCount => _requests.where((r) => r.riskLevel.toUpperCase() == 'LOW').length;

  void _toggleSelection(int requestId) {
    setState(() {
      if (_selectedIds.contains(requestId)) {
        _selectedIds.remove(requestId);
      } else {
        _selectedIds.add(requestId);
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

  Future<void> _handleOverride(PurchaseRequest pr) async {
    final updated = await showOverrideDialog(context, pr);
    if (updated != null) {
      setState(() {
        final index = _requests.indexWhere((r) => r.requestId == updated.requestId);
        if (index >= 0) {
          _requests[index] = updated;
        }
      });
    }
  }


  Future<void> _submitForApproval() async {
    if (_selectedIds.isEmpty) {
      GlassNotification.show(context, 'Please select at least one item', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        width: 420,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Submit for Approval',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E88E5).withOpacity(0.12),
                    const Color(0xFF0D47A1).withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF64B5F6), size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedIds.length} item(s) selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Value: RM ${_selectedTotalValue.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'These items will be sent to the GM for approval.',
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
            ),
          ],
        ),
        actions: [
          // Cancel button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
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
          // Submit button
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E88E5).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
                      Icon(Icons.send_rounded, size: 15, color: Colors.white),
                      SizedBox(width: 7),
                      Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        final result = await apiService.submitForApproval(_selectedIds.toList());
        if (mounted) {
          GlassNotification.show(
            context,
            '${result['updated_count'] ?? _selectedIds.length} item(s) submitted for approval',
          );
          setState(() => _selectedIds.clear());
          _loadRequests();
          // Navigate to Approval Status
          if (widget.onNavigate != null) {
            widget.onNavigate!(4);
          }
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
          // Dark gradient background
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
              child: ListViewSkeleton(itemCount: 6),
            )
          else
            Column(
              children: [
                // Header + controls
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'Purchase Request Details',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Review and select items for approval',
                              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      PRFilterBar(
                        filterRisk: _filterRisk,
                        sortBy: _sortBy,
                        selectedCount: _selectedIds.length,
                        totalCount: filtered.length,
                        criticalCount: _criticalCount,
                        warningCount: _warningCount,
                        lowRiskCount: _lowRiskCount,
                        onFilterChanged: (risk) => setState(() => _filterRisk = risk),
                        onSortChanged: (sort) => setState(() => _sortBy = sort),
                        onRefresh: _loadRequests,
                        onSelectAll: _selectAll,
                        onClearSelection: _clearSelection,
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
                        const SizedBox(width: 68), // action icons space
                      ],
                    ),
                  ),
                ),
                // List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No purchase requests found',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final pr = filtered[index];
                            return AnimatedListItem(
                              index: index,
                              child: PRListItem(
                              pr: pr,
                              isSelected: _selectedIds.contains(pr.requestId),
                              isExpanded: _expandedId == pr.requestId,
                              onToggleSelection: () => _toggleSelection(pr.requestId),
                              onToggleExpand: () {
                                setState(() {
                                  _expandedId = _expandedId == pr.requestId ? null : pr.requestId;
                                });
                              },
                              onOverride: () => _handleOverride(pr),
                              onSkip: () {
                                setState(() => _selectedIds.remove(pr.requestId));
                              },
                            ),
                            );
                          },
                        ),
                ),
                // Bottom action bar — only visible when items are selected
                if (_selectedIds.isNotEmpty)
                  PRActionBar(
                    selectedCount: _selectedIds.length,
                    totalValue: _selectedTotalValue,
                    isEnabled: _selectedIds.isNotEmpty,
                    onSubmitForApproval: _submitForApproval,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
}
