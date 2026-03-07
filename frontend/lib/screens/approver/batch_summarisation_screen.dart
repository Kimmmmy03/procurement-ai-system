// screens/approver/batch_summarisation_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_dialog.dart';

class BatchSummarisationScreen extends StatefulWidget {
  const BatchSummarisationScreen({super.key});

  @override
  State<BatchSummarisationScreen> createState() => _BatchSummarisationScreenState();
}

class _BatchSummarisationScreenState extends State<BatchSummarisationScreen> {
  List<Map<String, dynamic>> _batches = [];
  bool _isLoading = true;
  String _filterStatus = 'PENDING_APPROVAL';

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final batches = await apiService.getBatchList();

      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading batches: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        GlassNotification.show(context, 'Failed to load batches', isError: true);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBatches {
    if (_filterStatus == 'ALL') return _batches;
    return _batches.where((b) => b['status'] == _filterStatus).toList();
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
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Approval Batches',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Review and approve procurement request batches',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Filter Chips
                    _GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                'PENDING_APPROVAL',
                                'APPROVED',
                                'REJECTED',
                                'ALL'
                              ].map((status) {
                                final isSelected = _filterStatus == status;
                                return FilterChip(
                                  label: Text(_formatStatusLabel(status)),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() => _filterStatus = status);
                                  },
                                  selectedColor: const Color(0xFF1E88E5).withOpacity(0.3),
                                  backgroundColor: Colors.white.withOpacity(0.05),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF64B5F6)
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF64B5F6)
                                        : Colors.white.withOpacity(0.1),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          IconButton(
                            onPressed: _loadBatches,
                            icon: const Icon(Icons.refresh, color: Color(0xFF64B5F6)),
                            tooltip: 'Refresh',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Batches List
                    if (_filteredBatches.isEmpty)
                      _GlassContainer(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox,
                                  size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No ${_filterStatus == 'ALL' ? '' : _formatStatusLabel(_filterStatus).toLowerCase()} batches found',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredBatches.length,
                        itemBuilder: (context, index) {
                          final batch = _filteredBatches[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildBatchCard(batch),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'PENDING_APPROVAL':
        return 'Pending';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'ALL':
        return 'All';
      default:
        return status;
    }
  }

  Widget _buildBatchCard(Map<String, dynamic> batch) {
    final statusColor = _getStatusColor(batch['status']);

    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Batch ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch['batch_id'] ?? 'Unknown Batch',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted: ${batch['submitted_date'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor, width: 2),
                ),
                child: Text(
                  _formatStatusLabel(batch['status'] ?? ''),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details Grid
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Total Items',
                  (batch['item_count'] ?? 0).toString(),
                  Icons.shopping_cart,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Total Value',
                  _formatPrice(batch['total_value']),
                  Icons.payments,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Critical',
                  (batch['critical_items'] ?? 0).toString(),
                  Icons.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showBatchDetail(batch),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64B5F6),
                ),
              ),
              if (batch['status'] == 'PENDING_APPROVAL') ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showApprovalDialog(batch, isReject: true),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF5350),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showApprovalDialog(batch, isReject: false),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66BB6A),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white.withOpacity(0.4)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'PENDING_APPROVAL':
        return const Color(0xFFFFB74D);
      case 'APPROVED':
        return const Color(0xFF66BB6A);
      case 'REJECTED':
        return const Color(0xFFEF5350);
      default:
        return Colors.grey;
    }
  }

  Future<void> _showBatchDetail(Map<String, dynamic> batch) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final details = await apiService.getBatchDetail(batch['batch_id'] ?? '');

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            batch['batch_id'] ?? 'Batch Details',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Status', _formatStatusLabel(details['status'] ?? '')),
                  _buildDetailRow('Total Items', (details['item_count'] ?? 0).toString()),
                  _buildDetailRow('Total Value', _formatPrice(details['total_value'])),
                  _buildDetailRow('Critical Items', (details['critical_items'] ?? 0).toString()),
                  _buildDetailRow('Submitted', details['submitted_date'] ?? 'N/A'),
                  const Divider(color: Colors.white24),
                  const Text(
                    'Items in Batch:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64B5F6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(details['items'] as List? ?? []).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _getRiskColor(item['risk']).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                _getRiskIcon(item['risk']),
                                color: _getRiskColor(item['risk']),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['product'] ?? 'Unknown Product',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Qty: ${item['quantity'] ?? 0} × ${_formatPrice(item['unit_price'])}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatPrice(item['total_value']),
                              style: const TextStyle(
                                color: Color(0xFF66BB6A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (batch['status'] == 'PENDING_APPROVAL')
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showApprovalDialog(batch, isReject: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF66BB6A),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Approve'),
              ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error loading batch details: $e');
      if (mounted) GlassNotification.show(context, 'Error loading details: $e', isError: true);
    }
  }

  Color _getRiskColor(String? risk) {
    switch (risk) {
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

  IconData _getRiskIcon(String? risk) {
    switch (risk) {
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showApprovalDialog(Map<String, dynamic> batch, {required bool isReject}) async {
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isReject ? Icons.close : Icons.check,
              color: isReject ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
            ),
            const SizedBox(width: 12),
            Text(
              isReject ? 'Reject Batch' : 'Approve Batch',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Batch: ${batch['batch_id']}',
                    style: const TextStyle(
                      color: Color(0xFF64B5F6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Items: ${batch['item_count']} • Value: ${_formatPrice(batch['total_value'])}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: isReject ? 'Reason for rejection *' : 'Notes (optional)',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (isReject && notesController.text.isEmpty) {
                GlassNotification.show(
                  context,
                  'Please provide a reason for rejection',
                  isError: true,
                );
                return;
              }

              try {
                final apiService = Provider.of<ApiService>(context, listen: false);
                
                if (isReject) {
                  await apiService.rejectBatch(
                    batch['batch_id'] ?? '',
                    reason: notesController.text,
                  );
                } else {
                  await apiService.approveBatch(
                    batch['batch_id'] ?? '',
                    notes: notesController.text,
                  );
                }

                Navigator.pop(context);
                if (mounted) {
                  GlassNotification.show(
                    context,
                    isReject ? 'Batch rejected' : 'Batch approved successfully',
                    isError: isReject,
                  );
                }
              } catch (e) {
                print('❌ Error processing approval: $e');
                if (mounted) GlassNotification.show(context, 'Error: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isReject
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF66BB6A),
            ),
            child: Text(isReject ? 'Reject' : 'Approve'),
          ),
        ],
      ),
    );
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