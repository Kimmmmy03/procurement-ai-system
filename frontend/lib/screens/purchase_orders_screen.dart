// screens/officer/purchase_orders_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/procurement_models.dart';
import '../widgets/skeleton_layouts.dart';
import '../widgets/glass_filter_chip.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/animated_list_item.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _filterStatus = 'ALL';
  int? _expandedPoId;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final orders = await apiService.getPurchaseOrderList();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        GlassNotification.show(context, 'Error loading purchase orders', isError: true);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_filterStatus == 'ALL') return _orders;
    return _orders.where((o) => o['status'] == _filterStatus).toList();
  }

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

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateValue.toString());
      return DateFormat('d MMM yyyy, h:mm a').format(dt);
    } catch (_) {
      return dateValue.toString();
    }
  }

  int get _draftCount => _orders.where((o) => o['status'] == 'DRAFT').length;
  int get _sentCount => _orders.where((o) => o['status'] == 'SENT').length;
  int get _negotiatingCount => _orders.where((o) => o['status'] == 'NEGOTIATING').length;
  int get _reapprovalCount => _orders.where((o) => o['status'] == 'PENDING_REAPPROVAL').length;
  int get _confirmedCount => _orders.where((o) => o['status'] == 'CONFIRMED').length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

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
              child: ListViewSkeleton(itemCount: 5),
            )
          else
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'Purchase Orders',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Manage, negotiate, and send purchase orders to suppliers',
                              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Summary cards
                      Row(
                        children: [
                          _buildSummaryCard('Total POs', '${_orders.length}', Icons.receipt_long, const Color(0xFF64B5F6)),
                          const SizedBox(width: 12),
                          _buildSummaryCard('Draft', '$_draftCount', Icons.edit_note, const Color(0xFF64B5F6)),
                          const SizedBox(width: 12),
                          _buildSummaryCard('Sent', '$_sentCount', Icons.send, const Color(0xFFFFB74D)),
                          const SizedBox(width: 12),
                          _buildSummaryCard('Confirmed', '$_confirmedCount', Icons.check_circle, const Color(0xFF66BB6A)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Filter chips
                      _buildGlassPanel(
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  GlassFilterChip(
                                    label: 'All (${_orders.length})',
                                    selected: _filterStatus == 'ALL',
                                    onSelected: (_) => setState(() => _filterStatus = 'ALL'),
                                    activeColor: const Color(0xFF64B5F6),
                                  ),
                                  GlassFilterChip(
                                    label: 'Draft ($_draftCount)',
                                    selected: _filterStatus == 'DRAFT',
                                    onSelected: (_) => setState(() => _filterStatus = 'DRAFT'),
                                    activeColor: const Color(0xFF64B5F6),
                                  ),
                                  GlassFilterChip(
                                    label: 'Sent ($_sentCount)',
                                    selected: _filterStatus == 'SENT',
                                    onSelected: (_) => setState(() => _filterStatus = 'SENT'),
                                    activeColor: const Color(0xFFFFB74D),
                                  ),
                                  if (_negotiatingCount > 0)
                                    GlassFilterChip(
                                      label: 'Negotiating ($_negotiatingCount)',
                                      selected: _filterStatus == 'NEGOTIATING',
                                      onSelected: (_) => setState(() => _filterStatus = 'NEGOTIATING'),
                                      activeColor: const Color(0xFF4FC3F7),
                                    ),
                                  if (_reapprovalCount > 0)
                                    GlassFilterChip(
                                      label: 'Re-Approval ($_reapprovalCount)',
                                      selected: _filterStatus == 'PENDING_REAPPROVAL',
                                      onSelected: (_) => setState(() => _filterStatus = 'PENDING_REAPPROVAL'),
                                      activeColor: const Color(0xFFEF5350),
                                    ),
                                  GlassFilterChip(
                                    label: 'Confirmed ($_confirmedCount)',
                                    selected: _filterStatus == 'CONFIRMED',
                                    onSelected: (_) => setState(() => _filterStatus = 'CONFIRMED'),
                                    activeColor: const Color(0xFF66BB6A),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _loadOrders,
                              icon: const Icon(Icons.refresh, color: Color(0xFF64B5F6)),
                              tooltip: 'Refresh',
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
                        const SizedBox(width: 40),
                        SizedBox(width: 100, child: Text('PO Number', style: _headerStyle)),
                        Expanded(flex: 2, child: Text('Supplier', style: _headerStyle)),
                        SizedBox(width: 60, child: Text('Items', style: _headerStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 130, child: Text('Total Value', style: _headerStyle, textAlign: TextAlign.right)),
                        SizedBox(width: 160, child: Text('Vehicle / Container', style: _headerStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 140, child: Text('Created', style: _headerStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 100, child: Text('Status', style: _headerStyle, textAlign: TextAlign.center)),
                        const SizedBox(width: 100),
                      ],
                    ),
                  ),
                ),

                // PO List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 16),
                              Text(
                                _filterStatus == 'ALL'
                                    ? 'No purchase orders found'
                                    : 'No ${_filterStatus.toLowerCase()} orders found',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final po = filtered[index];
                            return AnimatedListItem(
                              index: index,
                              child: _buildPORow(po),
                            );
                          },
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.12),
                  color.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPORow(Map<String, dynamic> po) {
    final statusColor = _getStatusColor(po['status']);
    final status = po['status'] ?? 'DRAFT';
    final items = po['items'] as List? ?? [];
    final isExpanded = _expandedPoId == po['po_id'];
    final originalTotal = (po['original_total_value'] ?? po['total_value'] ?? 0).toDouble();
    final confirmedTotal = (po['confirmed_total_value'] ?? po['total_value'] ?? 0).toDouble();
    final variancePct = originalTotal > 0 ? ((confirmedTotal - originalTotal) / originalTotal * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isExpanded ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.07),
                  isExpanded ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isExpanded
                    ? const Color(0xFF1E88E5).withOpacity(0.4)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Column(
              children: [
                // Main row
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _expandedPoId = isExpanded ? null : po['po_id'];
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Expand icon
                        SizedBox(
                          width: 40,
                          child: Icon(
                            isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: Colors.white.withOpacity(0.5),
                            size: 20,
                          ),
                        ),
                        // PO Number
                        SizedBox(
                          width: 100,
                          child: Text(
                            po['po_number'] ?? 'N/A',
                            style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ),
                        // Supplier
                        Expanded(
                          flex: 2,
                          child: Text(
                            po['supplier'] ?? 'Unknown',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Item count
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${po['item_count'] ?? items.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Total value
                        SizedBox(
                          width: 130,
                          child: Text(
                            _formatPrice(po['total_value']),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        // Vehicle / Container
                        SizedBox(
                          width: 160,
                          child: (po['logistics_vehicle'] ?? '').toString().isNotEmpty
                              ? Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF42A5F5).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF42A5F5).withOpacity(0.25)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.local_shipping, color: Color(0xFF42A5F5), size: 12),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                po['logistics_vehicle'] ?? '',
                                                style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 10, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if ((po['container_strategy'] ?? '').toString().isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.inventory_2, color: Color(0xFF42A5F5), size: 10),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  po['container_strategy'] ?? '',
                                                  style: TextStyle(color: const Color(0xFF42A5F5).withOpacity(0.7), fontSize: 9),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 2),
                                        Text(
                                          '${(po['total_cbm'] ?? 0).toStringAsFixed(1)} CBM \u00B7 ${(po['total_weight_kg'] ?? 0).toStringAsFixed(0)} kg \u00B7 ${(po['utilization_percentage'] ?? 0).toStringAsFixed(0)}%',
                                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text('\u2014', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                                ),
                        ),
                        // Created date
                        SizedBox(
                          width: 140,
                          child: Text(
                            _formatDate(po['created_date']),
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Status badge
                        SizedBox(
                          width: 100,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.4)),
                              ),
                              child: Text(
                                _getStatusLabel(status),
                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ),
                          ),
                        ),
                        // Action buttons
                        SizedBox(
                          width: 100,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildIconAction(Icons.visibility, const Color(0xFF64B5F6), 'View', () => _showDetailDialog(po)),
                              const SizedBox(width: 4),
                              _buildIconAction(Icons.picture_as_pdf, const Color(0xFFFFB74D), 'PDF', () => _generatePdf(po)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded detail
                if (isExpanded) _buildExpandedDetail(po, status, items, statusColor, variancePct, originalTotal, confirmedTotal),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconAction(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }

  Widget _buildExpandedDetail(Map<String, dynamic> po, String status, List items,
      Color statusColor, double variancePct, double originalTotal, double confirmedTotal) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 8),

          // Re-approval warning
          if (status == 'PENDING_REAPPROVAL') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Requires Executive Re-Approval — Price increased by ${variancePct.toStringAsFixed(1)}% (>5% threshold)',
                      style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Info row
          Row(
            children: [
              _buildDetailChip(Icons.calendar_today, 'Created', _formatDate(po['created_date']), Colors.white54),
              const SizedBox(width: 10),
              _buildDetailChip(Icons.payments, 'Total', _formatPrice(po['total_value']), const Color(0xFF66BB6A)),
              const SizedBox(width: 10),
              if ((po['logistics_vehicle'] ?? '').toString().isNotEmpty) ...[
                _buildDetailChip(Icons.local_shipping, 'Vehicle', po['logistics_vehicle'] ?? '', const Color(0xFF42A5F5)),
                const SizedBox(width: 10),
                _buildDetailChip(Icons.inventory_2, 'Container',
                    (po['container_strategy'] ?? '').toString().isNotEmpty
                        ? '${po['container_strategy']} \u00B7 ${(po['utilization_percentage'] ?? 0).toStringAsFixed(0)}% full'
                        : '${(po['total_cbm'] ?? 0).toStringAsFixed(1)} CBM \u00B7 ${(po['total_weight_kg'] ?? 0).toStringAsFixed(0)} kg \u00B7 ${(po['utilization_percentage'] ?? 0).toStringAsFixed(0)}% full',
                    const Color(0xFF42A5F5)),
              ],
              if (po['etd_date'] != null) ...[
                const SizedBox(width: 10),
                _buildDetailChip(Icons.event, 'ETD', _formatDate(po['etd_date']), const Color(0xFFAB47BC)),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Variance info
          if ((status == 'NEGOTIATING' || status == 'PENDING_REAPPROVAL' || status == 'CONFIRMED' || status == 'COMPLETED') && variancePct.abs() > 0.01) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB74D).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_vert, color: Color(0xFFFFB74D), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Price variance: ${variancePct >= 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}%  |  Original: ${_formatPrice(originalTotal)}  \u2192  Confirmed: ${_formatPrice(confirmedTotal)}',
                    style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Line items — show negotiation line items if available, otherwise original items
          if ((po['line_items'] as List? ?? []).isNotEmpty) ...[
            Text('Negotiation Line Items', style: TextStyle(color: const Color(0xFFFFB74D).withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 80, child: Text('SKU', style: _subHeaderStyle)),
                        Expanded(child: Text('Product', style: _subHeaderStyle)),
                        SizedBox(width: 55, child: Text('Req Qty', style: _subHeaderStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 75, child: Text('Req Price', style: _subHeaderStyle, textAlign: TextAlign.right)),
                        SizedBox(width: 55, child: Text('Cnf Qty', style: _subHeaderStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 75, child: Text('Cnf Price', style: _subHeaderStyle, textAlign: TextAlign.right)),
                        SizedBox(width: 90, child: Text('Total', style: _subHeaderStyle, textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  ...(po['line_items'] as List).map<Widget>((li) {
                    final reqQty = li['requested_qty'] ?? 0;
                    final cnfQty = li['confirmed_qty'] ?? reqQty;
                    final reqPrice = (li['requested_price'] ?? 0).toDouble();
                    final cnfPrice = (li['confirmed_price'] ?? reqPrice).toDouble();
                    final qtyChanged = cnfQty != reqQty;
                    final priceChanged = (cnfPrice - reqPrice).abs() > 0.001;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(li['sku'] ?? '', style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontFamily: 'monospace')),
                          ),
                          Expanded(
                            child: Text(li['product_name'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11), overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(
                            width: 55,
                            child: Text('$reqQty', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11), textAlign: TextAlign.center),
                          ),
                          SizedBox(
                            width: 75,
                            child: Text(_formatPrice(reqPrice), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11), textAlign: TextAlign.right),
                          ),
                          SizedBox(
                            width: 55,
                            child: Text('$cnfQty', style: TextStyle(color: qtyChanged ? const Color(0xFFFFB74D) : Colors.white, fontSize: 11, fontWeight: qtyChanged ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center),
                          ),
                          SizedBox(
                            width: 75,
                            child: Text(_formatPrice(cnfPrice), style: TextStyle(color: priceChanged ? const Color(0xFFFFB74D) : Colors.white, fontSize: 11, fontWeight: priceChanged ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.right),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(_formatPrice(cnfQty * cnfPrice), style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ] else if (items.isNotEmpty) ...[
            Text('Line Items', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 100, child: Text('SKU', style: _subHeaderStyle)),
                        Expanded(child: Text('Product', style: _subHeaderStyle)),
                        SizedBox(width: 60, child: Text('Qty', style: _subHeaderStyle, textAlign: TextAlign.center)),
                        SizedBox(width: 100, child: Text('Unit Price', style: _subHeaderStyle, textAlign: TextAlign.right)),
                        SizedBox(width: 110, child: Text('Total', style: _subHeaderStyle, textAlign: TextAlign.right)),
                      ],
                    ),
                  ),
                  ...items.map<Widget>((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(item['sku'] ?? '', style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontFamily: 'monospace')),
                          ),
                          Expanded(
                            child: Text(item['product'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11), overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text('${item['quantity'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(_formatPrice(item['unit_price']), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11), textAlign: TextAlign.right),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(_formatPrice(item['total_value']), style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'DRAFT') ...[
                _buildGlassButton(
                  icon: Icons.send,
                  label: 'Send to Supplier',
                  color: const Color(0xFF66BB6A),
                  onTap: () => _showEmailDialog(po),
                ),
              ] else if (status == 'SENT' || status == 'NEGOTIATING') ...[
                _buildGlassButton(
                  icon: Icons.edit_note,
                  label: 'Amend Terms',
                  color: const Color(0xFFFFB74D),
                  onTap: () => _showAmendmentDialog(po),
                  outlined: true,
                ),
                const SizedBox(width: 10),
                _buildGlassButton(
                  icon: Icons.lock,
                  label: 'Lock & Confirm',
                  color: const Color(0xFF66BB6A),
                  onTap: () => _confirmPO(po),
                ),
              ] else if (status == 'PENDING_REAPPROVAL') ...[
                _buildGlassButton(
                  icon: Icons.edit_note,
                  label: 'Amend Terms',
                  color: const Color(0xFFFFB74D),
                  onTap: () => _showAmendmentDialog(po),
                  outlined: true,
                ),
                const SizedBox(width: 8),
                _buildGlassButton(
                  icon: Icons.verified,
                  label: 'Executive Approve',
                  color: const Color(0xFF66BB6A),
                  onTap: () => _reapprovePO(po),
                ),
              ] else if (status == 'CONFIRMED') ...[
                _buildGlassButton(
                  icon: Icons.check_circle,
                  label: 'Mark as Completed',
                  color: const Color(0xFF66BB6A),
                  onTap: () => _markAsCompleted(po),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color.withOpacity(0.7)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                  Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          decoration: BoxDecoration(
            gradient: outlined
                ? null
                : LinearGradient(colors: [color, color.withOpacity(0.8)]),
            color: outlined ? color.withOpacity(0.08) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(outlined ? 0.4 : 0.6)),
            boxShadow: outlined
                ? null
                : [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: outlined ? color : Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: outlined ? color : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassPanel({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING_REAPPROVAL': return 'RE-APPROVAL';
      default: return status;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'DRAFT': return const Color(0xFF64B5F6);
      case 'SENT': return const Color(0xFFFFB74D);
      case 'NEGOTIATING': return const Color(0xFF4FC3F7);
      case 'PENDING_REAPPROVAL': return const Color(0xFFEF5350);
      case 'CONFIRMED': return const Color(0xFF66BB6A);
      case 'PENDING_ETD': return const Color(0xFFAB47BC);
      case 'IN_TRANSIT': return const Color(0xFF7E57C2);
      case 'ARRIVED': return const Color(0xFF26A69A);
      case 'COMPLETED': return const Color(0xFF78909C);
      default: return Colors.grey;
    }
  }

  TextStyle get _headerStyle => TextStyle(
        color: Colors.white.withOpacity(0.5),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );

  TextStyle get _subHeaderStyle => TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.3,
      );

  // ── Amendment Dialog ───────────────────────────────────────────────

  Future<void> _showAmendmentDialog(Map<String, dynamic> po) async {
    final poId = po['po_id'] as int? ?? 0;
    final apiService = Provider.of<ApiService>(context, listen: false);

    Map<String, dynamic> detail;
    try {
      detail = await apiService.getPurchaseOrderDetail(poId);
    } catch (_) {
      detail = po;
    }

    final rawLineItems = detail['line_items'] as List? ?? [];
    if (rawLineItems.isEmpty) {
      if (mounted) {
        GlassNotification.show(context, 'No line items available for amendment', isError: true);
      }
      return;
    }

    final lineItems = rawLineItems.map((li) => POLineItem.fromJson(Map<String, dynamic>.from(li))).toList();
    final qtyControllers = lineItems.map((li) => TextEditingController(text: li.confirmedQty.toString())).toList();
    final priceControllers = lineItems.map((li) => TextEditingController(text: li.confirmedPrice.toStringAsFixed(2))).toList();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final etdController = TextEditingController(text: todayStr);
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double confirmedTotal = 0;
          for (int i = 0; i < lineItems.length; i++) {
            final qty = int.tryParse(qtyControllers[i].text) ?? lineItems[i].requestedQty;
            final price = double.tryParse(priceControllers[i].text) ?? lineItems[i].requestedPrice;
            confirmedTotal += qty * price;
          }
          final origTotal = (detail['original_total_value'] ?? detail['total_value'] ?? 0).toDouble();
          final varPct = origTotal > 0 ? ((confirmedTotal - origTotal) / origTotal * 100) : 0.0;
          final willTriggerReapproval = varPct > 5.0;

          return GlassDialog(
            width: 750,
            constraints: const BoxConstraints(maxHeight: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB74D).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_note, color: Color(0xFFFFB74D), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amend Terms \u2014 ${detail['po_number'] ?? po['po_number']}',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Input supplier counter-offer for ${detail['supplier'] ?? po['supplier']}',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (willTriggerReapproval)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Price increase of ${varPct.toStringAsFixed(1)}% exceeds 5% threshold \u2014 PO will be routed to Executive Approver',
                            style: const TextStyle(color: Color(0xFFEF5350), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Value summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryChip('Original', _formatPrice(origTotal), Colors.white54),
                      const Icon(Icons.arrow_forward, color: Colors.white24, size: 16),
                      _summaryChip('Confirmed', _formatPrice(confirmedTotal),
                          willTriggerReapproval ? const Color(0xFFEF5350) : const Color(0xFF66BB6A)),
                      _summaryChip('Variance', '${varPct >= 0 ? "+" : ""}${varPct.toStringAsFixed(1)}%',
                          varPct.abs() < 0.01 ? Colors.white54 : (willTriggerReapproval ? const Color(0xFFEF5350) : const Color(0xFFFFB74D))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Line Items', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 80, child: Text('SKU', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold))),
                      Expanded(child: Text('Product', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold))),
                      SizedBox(width: 60, child: Text('Req Qty', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      SizedBox(width: 80, child: Text('Req Price', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      const SizedBox(width: 10),
                      SizedBox(width: 70, child: Text('Conf Qty', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      SizedBox(width: 90, child: Text('Conf Price', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    ],
                  ),
                ),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(lineItems.length, (i) {
                        final li = lineItems[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 80, child: Text(li.sku, style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontFamily: 'monospace'))),
                              Expanded(child: Text(li.productName, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis)),
                              SizedBox(width: 60, child: Text('${li.requestedQty}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11), textAlign: TextAlign.center)),
                              SizedBox(width: 80, child: Text(_formatPrice(li.requestedPrice), style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11), textAlign: TextAlign.right)),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 70,
                                child: TextField(
                                  controller: qtyControllers[i],
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 90,
                                child: TextField(
                                  controller: priceControllers[i],
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  textAlign: TextAlign.right,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setDialogState(() {}),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                    prefixText: 'RM ',
                                    prefixStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: etdController,
                        readOnly: true,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'ETD (Today\'s Date)',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.calendar_today, size: 16, color: Colors.white.withOpacity(0.3)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: reasonController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Reason for Amendment',
                          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildGlassButton(
                      icon: Icons.close,
                      label: 'Cancel',
                      color: Colors.white54,
                      onTap: () => Navigator.pop(context),
                      outlined: true,
                    ),
                    const SizedBox(width: 12),
                    _buildGlassButton(
                      icon: isSubmitting ? Icons.hourglass_empty : Icons.save,
                      label: willTriggerReapproval ? 'Submit (Triggers Re-Approval)' : 'Save Amendment',
                      color: willTriggerReapproval ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
                      onTap: isSubmitting ? () {} : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          final amendments = <Map<String, dynamic>>[];
                          for (int i = 0; i < lineItems.length; i++) {
                            amendments.add({
                              'request_id': lineItems[i].requestId,
                              'confirmed_qty': int.tryParse(qtyControllers[i].text) ?? lineItems[i].requestedQty,
                              'confirmed_price': double.tryParse(priceControllers[i].text) ?? lineItems[i].requestedPrice,
                            });
                          }
                          final result = await apiService.amendPurchaseOrder(
                            poId: poId,
                            lineItems: amendments,
                            etdDate: etdController.text.isNotEmpty ? etdController.text : null,
                            reason: reasonController.text.isNotEmpty ? reasonController.text : null,
                          );
                          Navigator.pop(context);
                          await _loadOrders();
                          if (mounted) {
                            final requiresReapproval = result['requires_reapproval'] == true;
                            GlassNotification.show(
                              context,
                              requiresReapproval
                                  ? 'PO amended \u2014 routed to Executive for re-approval (${result['price_variance_pct']}% increase)'
                                  : 'PO amended successfully',
                              isError: requiresReapproval,
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (mounted) {
                            GlassNotification.show(context, 'Error: $e', isError: true);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── Confirm PO ─────────────────────────────────────────────────────

  Future<void> _confirmPO(Map<String, dynamic> po) async {
    final poId = po['po_id'] as int? ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        width: 420,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock, color: Color(0xFF66BB6A), size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Confirm Purchase Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF66BB6A), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lock ${po['po_number']} as CONFIRMED?\nThis will finalize the negotiation and lock all terms.',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                    ),
                  ),
                ],
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
              gradient: const LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF43A047)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: const Color(0xFF66BB6A).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
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
                      Icon(Icons.lock, size: 15, color: Colors.white),
                      SizedBox(width: 7),
                      Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.confirmPurchaseOrder(poId);
      await _loadOrders();
      if (mounted) {
        GlassNotification.show(context, 'PO confirmed and locked');
      }
    } catch (e) {
      if (mounted) {
        GlassNotification.show(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _markAsCompleted(Map<String, dynamic> po) async {
    final poId = po['po_id'] as int? ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        width: 420,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF66BB6A).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Mark as Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mark ${po['po_number']} as COMPLETED?',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'This indicates the purchase order has been fully fulfilled.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.markPOCompleted(poId);
      await _loadOrders();
      if (mounted) {
        GlassNotification.show(context, 'PO marked as completed');
      }
    } catch (e) {
      if (mounted) {
        GlassNotification.show(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _reapprovePO(Map<String, dynamic> po) async {
    final poId = po['po_id'] as int;
    final variance = po['confirmed_total_value'] != null && po['original_total_value'] != null
        ? (((po['confirmed_total_value'] as num).toDouble() - (po['original_total_value'] as num).toDouble()) / (po['original_total_value'] as num).toDouble() * 100)
        : 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => GlassDialog(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF66BB6A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified, color: Color(0xFF66BB6A), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Executive Re-Approval', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF5350).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFEF5350), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Price variance: +${variance.toStringAsFixed(1)}% exceeds the 5% threshold.\nApproving will return the PO to NEGOTIATING status for the officer to confirm.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildGlassButton(
                  icon: Icons.close,
                  label: 'Cancel',
                  color: Colors.white54,
                  onTap: () => Navigator.pop(context, false),
                  outlined: true,
                ),
                const SizedBox(width: 8),
                _buildGlassButton(
                  icon: Icons.verified,
                  label: 'Approve Variance',
                  color: const Color(0xFF66BB6A),
                  onTap: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.reapprovePurchaseOrder(poId);
      await _loadOrders();
      if (mounted) {
        GlassNotification.show(context, 'PO re-approved - returned to NEGOTIATING');
      }
    } catch (e) {
      if (mounted) {
        GlassNotification.show(context, 'Error: $e', isError: true);
      }
    }
  }

  // ── PDF Generation ────────────────────────────────────────────────

  Future<void> _generatePdf(Map<String, dynamic> po) async {
    final poNumber = po['po_number'] ?? 'Unknown';
    final supplier = po['supplier'] ?? 'N/A';
    final totalValue = _formatPrice(po['total_value']);
    final date = po['created_date'] ?? 'N/A';
    final items = po['items'] as List? ?? [];
    final status = po['status'] ?? 'DRAFT';
    final etdDate = po['etd_date'];
    final vehicle = po['logistics_vehicle'] ?? '';
    final containerStrategy = po['container_strategy'] ?? '';

    // Check if negotiation happened
    final hasNegotiation = (status == 'NEGOTIATING' || status == 'CONFIRMED' || status == 'COMPLETED' || status == 'PENDING_REAPPROVAL');
    final lineItems = po['line_items'] as List? ?? [];
    final origTotal = (po['original_total_value'] ?? po['total_value'] ?? 0).toDouble();
    final confirmedTotal = (po['confirmed_total_value'] ?? po['total_value'] ?? 0).toDouble();
    final varPct = origTotal > 0 ? ((confirmedTotal - origTotal) / origTotal * 100) : 0.0;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PURCHASE ORDER', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(poNumber, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Supplier: $supplier'),
                      pw.Text('Date: $date'),
                      if (etdDate != null) pw.Text('ETD: $etdDate'),
                      if (vehicle.isNotEmpty || containerStrategy.isNotEmpty)
                        pw.Text('Logistics: ${[vehicle, containerStrategy].where((s) => s.isNotEmpty).join(' + ')}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Total: $totalValue', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Status: $status', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Show negotiation summary if applicable
              if (hasNegotiation && varPct.abs() > 0.01) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(border: pw.Border.all()),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Negotiation Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Original Total: ${_formatPrice(origTotal)}'),
                          pw.Text('Confirmed Total: ${_formatPrice(confirmedTotal)}'),
                          pw.Text('Variance: ${varPct >= 0 ? "+" : ""}${varPct.toStringAsFixed(1)}%'),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],

              // Show negotiation line items if available, otherwise original items
              if (hasNegotiation && lineItems.isNotEmpty) ...[
                pw.Text('Negotiated Line Items:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headers: ['SKU', 'Product', 'Req Qty', 'Req Price', 'Conf Qty', 'Conf Price', 'Total'],
                  data: lineItems.map((li) {
                    final confQty = li['confirmed_qty'] ?? li['requested_qty'] ?? 0;
                    final confPrice = (li['confirmed_price'] ?? li['requested_price'] ?? 0).toDouble();
                    return [
                      li['sku']?.toString() ?? '',
                      li['product_name']?.toString() ?? '',
                      (li['requested_qty'] ?? '').toString(),
                      _formatPrice(li['requested_price']),
                      confQty.toString(),
                      _formatPrice(confPrice),
                      _formatPrice(confQty * confPrice),
                    ];
                  }).toList(),
                ),
              ] else if (items.isNotEmpty) ...[
                pw.Text('Line Items:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headers: ['SKU', 'Product', 'Qty', 'Unit Price', 'Total'],
                  data: items.map((item) {
                    return [
                      item['sku']?.toString() ?? '',
                      item['product']?.toString() ?? '',
                      item['quantity']?.toString() ?? '',
                      _formatPrice(item['unit_price']),
                      _formatPrice(item['total_value']),
                    ];
                  }).toList(),
                ),
              ],
              pw.Spacer(),
              pw.Divider(),
              pw.Text('Generated by Procurement AI System', style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();

    // Use sharePdf to download/save the actual PDF file with selectable text
    // layoutPdf opens print preview which may render as image in some browsers
    await Printing.sharePdf(bytes: bytes, filename: '$poNumber.pdf');
  }

  // ── Detail Dialog ─────────────────────────────────────────────────

  Future<void> _showDetailDialog(Map<String, dynamic> po) async {
    final poId = po['po_id'];

    Map<String, dynamic> details;
    if (poId != null) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        details = await apiService.getPurchaseOrderDetail(poId);
      } catch (e) {
        details = po;
      }
    } else {
      details = po;
    }

    if (!mounted) return;

    final items = details['items'] as List? ?? po['items'] as List? ?? [];
    final lineItems = details['line_items'] as List? ?? [];
    final revisions = details['revisions'] as List? ?? [];

    showDialog(
      context: context,
      builder: (context) => GlassDialog(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64B5F6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long, color: Color(0xFF64B5F6), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details['po_number'] ?? po['po_number'] ?? 'Purchase Order',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Supplier: ${details['supplier'] ?? po['supplier'] ?? 'N/A'}',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                _buildInfoChip('Status', _getStatusLabel(details['status'] ?? po['status'] ?? 'N/A'), _getStatusColor(details['status'] ?? po['status'])),
                const SizedBox(width: 12),
                _buildInfoChip('Original', _formatPrice(details['original_total_value'] ?? po['total_value']), Colors.white54),
                const SizedBox(width: 12),
                _buildInfoChip('Confirmed', _formatPrice(details['confirmed_total_value'] ?? po['total_value']), const Color(0xFF66BB6A)),
                const SizedBox(width: 12),
                _buildInfoChip('Date', details['created_date'] ?? po['created_date'] ?? 'N/A', Colors.white54),
              ],
            ),
            const SizedBox(height: 20),

            if (lineItems.isNotEmpty) ...[
              const Text('Negotiation Line Items', style: TextStyle(color: Color(0xFFFFB74D), fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text('SKU', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold))),
                    Expanded(child: Text('Product', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold))),
                    SizedBox(width: 55, child: Text('Req Qty', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    SizedBox(width: 70, child: Text('Req Price', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    SizedBox(width: 55, child: Text('Cnf Qty', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    SizedBox(width: 70, child: Text('Cnf Price', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              ...lineItems.map((li) {
                final reqQty = li['requested_qty'] ?? 0;
                final cnfQty = li['confirmed_qty'] ?? reqQty;
                final reqPrice = (li['requested_price'] ?? 0).toDouble();
                final cnfPrice = (li['confirmed_price'] ?? reqPrice).toDouble();
                final qtyChanged = cnfQty != reqQty;
                final priceChanged = (cnfPrice - reqPrice).abs() > 0.001;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 70, child: Text(li['sku'] ?? '', style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontFamily: 'monospace'))),
                      Expanded(child: Text(li['product_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 55, child: Text('$reqQty', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11), textAlign: TextAlign.center)),
                      SizedBox(width: 70, child: Text(_formatPrice(reqPrice), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11), textAlign: TextAlign.right)),
                      SizedBox(width: 55, child: Text('$cnfQty', style: TextStyle(color: qtyChanged ? const Color(0xFFFFB74D) : Colors.white, fontSize: 11, fontWeight: qtyChanged ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center)),
                      SizedBox(width: 70, child: Text(_formatPrice(cnfPrice), style: TextStyle(color: priceChanged ? const Color(0xFFFFB74D) : Colors.white, fontSize: 11, fontWeight: priceChanged ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.right)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            if (lineItems.isEmpty && items.isNotEmpty) ...[
              const Text('Line Items', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 80, child: Text('SKU', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold))),
                            Expanded(child: Text('Product', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold))),
                            SizedBox(width: 60, child: Text('Qty', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            SizedBox(width: 100, child: Text('Unit Price', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            SizedBox(width: 100, child: Text('Total', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      ...items.map((item) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 80, child: Text(item['sku'] ?? '', style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 12, fontFamily: 'monospace'))),
                              Expanded(child: Text(item['product'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                              SizedBox(width: 60, child: Text('${item['quantity'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center)),
                              SizedBox(width: 100, child: Text(_formatPrice(item['unit_price']), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12), textAlign: TextAlign.right)),
                              SizedBox(width: 100, child: Text(_formatPrice(item['total_value'] ?? item['total']), style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],

            if (revisions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Revision History', style: TextStyle(color: Color(0xFF9575CD), fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...revisions.take(5).map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.history, size: 14, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                            children: [
                              TextSpan(text: '${r['field_name']}', style: const TextStyle(color: Color(0xFF64B5F6))),
                              TextSpan(text: '  ${r['previous_value']} \u2192 ${r['new_value']}'),
                              if (r['reason'] != null) TextSpan(text: '  (${r['reason']})', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ),
                      Text(r['timestamp'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildGlassButton(
                  icon: Icons.close,
                  label: 'Close',
                  color: Colors.white54,
                  onTap: () => Navigator.pop(context),
                  outlined: true,
                ),
                const SizedBox(width: 8),
                _buildGlassButton(
                  icon: Icons.picture_as_pdf,
                  label: 'Download PDF',
                  color: const Color(0xFFFFB74D),
                  onTap: () {
                    Navigator.pop(context);
                    _generatePdf(po);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ── Email Dialog ──────────────────────────────────────────────────

  String _buildProfessionalEmailBody(Map<String, dynamic> po) {
    final poNumber = po['po_number'] ?? 'Unknown';
    final supplier = po['supplier'] ?? 'Valued Supplier';
    final date = po['created_date'] ?? 'N/A';
    final totalValue = _formatPrice(po['total_value']);
    final items = po['items'] as List? ?? [];

    final buffer = StringBuffer();
    buffer.writeln('Dear $supplier,');
    buffer.writeln();
    buffer.writeln('We are pleased to issue the following Purchase Order for your reference and fulfillment.');
    buffer.writeln();
    buffer.writeln('--- Purchase Order: $poNumber ---');
    buffer.writeln('Date: $date');
    buffer.writeln();
    buffer.writeln('ORDER DETAILS:');
    buffer.writeln('${'Item'.padRight(30)} ${'Qty'.padLeft(6)} ${'Unit Price'.padLeft(14)} ${'Total'.padLeft(14)}');
    buffer.writeln('-' * 70);
    for (final item in items) {
      final name = (item['product'] ?? 'N/A').toString();
      final qty = (item['quantity'] ?? 0).toString();
      final unitPrice = _formatPrice(item['unit_price']);
      final total = _formatPrice(item['total_value']);
      buffer.writeln('${name.padRight(30)} ${qty.padLeft(6)} ${unitPrice.padLeft(14)} ${total.padLeft(14)}');
    }
    buffer.writeln('-' * 70);
    buffer.writeln('${'TOTAL ORDER VALUE:'.padRight(52)} $totalValue');
    buffer.writeln();
    buffer.writeln('DELIVERY INSTRUCTIONS:');
    buffer.writeln('- Please confirm receipt of this Purchase Order within 2 business days.');
    buffer.writeln('- Kindly provide expected delivery date upon confirmation.');
    buffer.writeln('- All goods must comply with agreed quality standards and specifications.');
    buffer.writeln();
    buffer.writeln('PAYMENT TERMS:');
    buffer.writeln('- Net 30 days from date of invoice.');
    buffer.writeln();
    buffer.writeln('Should you have any questions regarding this order, please do not hesitate to contact our Procurement Department.');
    buffer.writeln();
    buffer.writeln('Best regards,');
    buffer.writeln('Procurement Team');
    buffer.writeln('Chin Hin Group Berhad');

    return buffer.toString();
  }

  Future<void> _showEmailDialog(Map<String, dynamic> po) async {
    final emailController = TextEditingController(
      text: po['supplier_email'] ?? '',
    );
    final subjectController = TextEditingController(
      text: 'Purchase Order ${po['po_number']} - ${po['supplier'] ?? ''}',
    );
    final bodyController = TextEditingController(
      text: _buildProfessionalEmailBody(po),
    );

    await showDialog(
      context: context,
      builder: (context) => GlassDialog(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF66BB6A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.email, color: Color(0xFF66BB6A), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Send Purchase Order', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Supplier Email',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.email_outlined, color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF66BB6A))),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: subjectController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Subject',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.subject, color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF66BB6A))),
              ),
            ),
            const SizedBox(height: 16),

            // PDF attachment note
            InkWell(
              onTap: () => _generatePdf(po),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Color(0xFFFFB74D), size: 16),
                    const SizedBox(width: 8),
                    const Text('Generate PO PDF to attach', style: TextStyle(color: Color(0xFFFFB74D), fontSize: 12)),
                    const Spacer(),
                    Icon(Icons.download, color: Colors.white.withOpacity(0.4), size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Email Preview', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: TextField(
                controller: bodyController,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace', height: 1.5),
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildGlassButton(
                  icon: Icons.close,
                  label: 'Cancel',
                  color: Colors.white54,
                  onTap: () => Navigator.pop(context),
                  outlined: true,
                ),
                const SizedBox(width: 8),
                _buildGlassButton(
                  icon: Icons.open_in_new,
                  label: 'Open in Mail App',
                  color: const Color(0xFF64B5F6),
                  outlined: true,
                  onTap: () async {
                    final subject = Uri.encodeComponent(subjectController.text);
                    final body = Uri.encodeComponent(bodyController.text);
                    final mailto = Uri.parse('mailto:${emailController.text}?subject=$subject&body=$body');
                    if (await canLaunchUrl(mailto)) {
                      await launchUrl(mailto);
                    } else {
                      GlassNotification.show(context, 'Could not open email client', isError: true);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildGlassButton(
                  icon: Icons.mark_email_read,
                  label: 'I Have Sent for Negotiation',
                  color: const Color(0xFF66BB6A),
                  onTap: () async {
                    if (emailController.text.isEmpty) {
                      GlassNotification.show(context, 'Please enter supplier email', isError: true);
                      return;
                    }
                    try {
                      final apiService = Provider.of<ApiService>(context, listen: false);
                      await apiService.sendPurchaseOrderEmail(
                        po['po_number'] ?? '',
                        {
                          'email': emailController.text,
                          'subject': subjectController.text,
                          'body': bodyController.text,
                        },
                      );
                      Navigator.pop(context);
                      await _loadOrders();
                      if (mounted) {
                        GlassNotification.show(context, 'PO marked as SENT for negotiation');
                      }
                    } catch (e) {
                      if (mounted) GlassNotification.show(context, 'Error: $e', isError: true);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
