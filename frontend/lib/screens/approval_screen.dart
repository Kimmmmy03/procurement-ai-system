// screens/approval_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/procurement_models.dart';
import '../services/api_service.dart';
import '../widgets/glass_filter_chip.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/skeleton_layouts.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  List<PurchaseRequest> _requests = [];
  bool _isLoading = true;
  String _filterStatus = 'ALL';
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final requests = await apiService.getPurchaseRequestsByStatus(
        ['Pending', 'Approved', 'Rejected'],
      );
      setState(() {
        _requests = requests;
        _selectedIds.clear();
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
    if (_filterStatus == 'ALL') return _requests;
    return _requests.where((r) => r.status == _filterStatus).toList();
  }

  List<PurchaseRequest> get _approvedRequests =>
      _requests.where((r) => r.status == 'Approved').toList();

  List<int> get _selectedApprovedIds =>
      _selectedIds.where((id) => _approvedRequests.any((r) => r.requestId == id)).toList();

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAllApproved() {
    setState(() {
      _selectedIds = _approvedRequests.map((r) => r.requestId).toSet();
    });
  }

  void _clearSelection() {
    setState(() => _selectedIds.clear());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFFB74D);
      case 'Approved':
        return const Color(0xFF66BB6A);
      case 'Rejected':
        return const Color(0xFFEF5350);
      default:
        return Colors.grey;
    }
  }

  Color _riskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFEF5350);
      case 'WARNING':
        return const Color(0xFFFFB74D);
      default:
        return const Color(0xFF66BB6A);
    }
  }

  Future<void> _generateGroupedPOs() async {
    final ids = _selectedApprovedIds;
    if (ids.isEmpty) {
      GlassNotification.show(context, 'Please select approved items to generate POs', isError: true);
      return;
    }

    // Show which suppliers will get POs
    final selectedPRs = _approvedRequests.where((r) => ids.contains(r.requestId)).toList();
    final supplierGroups = <String, List<PurchaseRequest>>{};
    for (final pr in selectedPRs) {
      supplierGroups.putIfAbsent(pr.supplierName ?? 'Unknown', () => []).add(pr);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        width: 480,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.4)),
              ),
              child: const Icon(Icons.receipt_long, color: Color(0xFF64B5F6), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Generate Purchase Orders',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF64B5F6), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${supplierGroups.length} PO(s) will be created, grouped by supplier:',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...supplierGroups.entries.map((entry) {
                final total = entry.value.fold(0.0, (sum, r) => sum + r.totalValue);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.07),
                          Colors.white.withOpacity(0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.business, color: Color(0xFF64B5F6), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.key,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.value.length} item(s)',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF66BB6A).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.3)),
                          ),
                          child: Text(
                            'RM ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Color(0xFF66BB6A),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.receipt_long, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Generate POs',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
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
        final result = await apiService.generateGroupedPurchaseOrders(ids);
        if (mounted) {
          final posCreated = result['pos_created'] ?? 0;
          GlassNotification.show(context, '$posCreated Purchase Order(s) generated successfully');
          _selectedIds.clear();
          _loadRequests();
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
    final pendingCount = _requests.where((r) => r.status == 'Pending').length;
    final approvedCount = _requests.where((r) => r.status == 'Approved').length;
    final rejectedCount = _requests.where((r) => r.status == 'Rejected').length;

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
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'Approval Status',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Track submitted purchase requests',
                              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filter chips + controls
                      _GlassContainer(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      GlassFilterChip(
                                        label: 'All (${_requests.length})',
                                        selected: _filterStatus == 'ALL',
                                        onSelected: (_) => setState(() => _filterStatus = 'ALL'),
                                        activeColor: const Color(0xFF64B5F6),
                                      ),
                                      GlassFilterChip(
                                        label: 'Pending ($pendingCount)',
                                        selected: _filterStatus == 'Pending',
                                        onSelected: (_) => setState(() => _filterStatus = 'Pending'),
                                        activeColor: const Color(0xFFFFB74D),
                                      ),
                                      GlassFilterChip(
                                        label: 'Approved ($approvedCount)',
                                        selected: _filterStatus == 'Approved',
                                        onSelected: (_) => setState(() => _filterStatus = 'Approved'),
                                        activeColor: const Color(0xFF66BB6A),
                                      ),
                                      GlassFilterChip(
                                        label: 'Rejected ($rejectedCount)',
                                        selected: _filterStatus == 'Rejected',
                                        onSelected: (_) => setState(() => _filterStatus = 'Rejected'),
                                        activeColor: const Color(0xFFEF5350),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _loadRequests,
                                  icon: const Icon(Icons.refresh, color: Color(0xFF64B5F6)),
                                  tooltip: 'Refresh',
                                ),
                              ],
                            ),
                            if (approvedCount > 0) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: _selectAllApproved,
                                    icon: const Icon(Icons.select_all, size: 16),
                                    label: const Text('Select All Approved', style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF66BB6A)),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_selectedIds.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: _clearSelection,
                                      icon: const Icon(Icons.deselect, size: 16),
                                      label: Text('Clear (${_selectedIds.length})', style: const TextStyle(fontSize: 12)),
                                      style: TextButton.styleFrom(foregroundColor: Colors.white54),
                                    ),
                                ],
                              ),
                            ],
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
                        const SizedBox(width: 48),
                        SizedBox(width: 100, child: Text('SKU', style: _headerStyle)),
                        Expanded(flex: 2, child: Text('Product', style: _headerStyle)),
                        SizedBox(width: 80, child: Text('Qty', style: _headerStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 100, child: Text('Risk', style: _headerStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 110, child: Text('Value', style: _headerStyle, textAlign: TextAlign.right)),
                        SizedBox(width: 100, child: Text('Status', style: _headerStyle, textAlign: TextAlign.center)),
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
                              Icon(Icons.inbox, size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No requests found',
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
                            return _buildRequestRow(pr);
                          },
                        ),
                ),

                // Bottom action bar for PO generation
                if (_selectedApprovedIds.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1E88E5).withOpacity(0.15),
                              Colors.black.withOpacity(0.35),
                            ],
                          ),
                          border: Border(
                            top: BorderSide(
                              color: const Color(0xFF1E88E5).withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Badge with selection count
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF1E88E5).withOpacity(0.3),
                                    const Color(0xFF1E88E5).withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF1E88E5).withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: Color(0xFF64B5F6), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedApprovedIds.length} item(s) selected',
                                    style: const TextStyle(
                                      color: Color(0xFF64B5F6),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Ready to generate purchase orders',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            // Glassmorphism Generate PO Button
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF1E88E5),
                                        Color(0xFF1565C0),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1E88E5).withOpacity(0.4),
                                        blurRadius: 16,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _generateGroupedPOs,
                                      borderRadius: BorderRadius.circular(14),
                                      splashColor: Colors.white.withOpacity(0.2),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.receipt_long,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Generate PO (Grouped by Supplier)',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
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

  Widget _buildRequestRow(PurchaseRequest pr) {
    final statusColor = _statusColor(pr.status);
    final riskColor = _riskColor(pr.riskLevel);
    final isSelected = _selectedIds.contains(pr.requestId);
    final isApproved = pr.status == 'Approved';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1E88E5).withOpacity(0.4)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: isApproved
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(pr.requestId),
                              activeColor: const Color(0xFF1E88E5),
                              side: BorderSide(color: Colors.white.withOpacity(0.4)),
                            )
                          : const SizedBox(),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(pr.sku, style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(pr.productName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        '${pr.effectiveQty}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: riskColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            pr.riskLevel.toUpperCase(),
                            style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        'RM ${pr.totalValue.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withOpacity(0.4)),
                          ),
                          child: Text(
                            pr.status.toUpperCase(),
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Show rejection reason if rejected
                if (pr.status == 'Rejected' && pr.rejectionReason != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFEF5350), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reason: ${pr.rejectionReason}',
                            style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12),
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
