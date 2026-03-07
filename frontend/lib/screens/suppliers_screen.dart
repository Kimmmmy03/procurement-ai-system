// lib/screens/suppliers_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/glass_skeleton.dart';
import '../widgets/animated_list_item.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int? _expandedSupplierId;
  Map<String, dynamic>? _supplierDetail;
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final suppliers = await api.getSuppliersList();
      setState(() { _suppliers = suppliers; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadSupplierDetail(int supplierId) async {
    setState(() { _isLoadingDetail = true; });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final detail = await api.getSupplierDetail(supplierId);
      setState(() { _supplierDetail = detail; _isLoadingDetail = false; });
    } catch (e) {
      setState(() { _isLoadingDetail = false; });
    }
  }

  List<Map<String, dynamic>> get _filteredSuppliers {
    if (_searchQuery.isEmpty) return _suppliers;
    final q = _searchQuery.toLowerCase();
    return _suppliers.where((s) {
      return (s['name']?.toString().toLowerCase().contains(q) ?? false) ||
             (s['supplier_code']?.toString().toLowerCase().contains(q) ?? false) ||
             (s['categories']?.toString().toLowerCase().contains(q) ?? false) ||
             (s['email']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'RM 0.00';
    final num = double.tryParse(value.toString()) ?? 0;
    return 'RM ${NumberFormat('#,##0.00').format(num)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildSummaryCards(),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF26A69A).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.business, color: Color(0xFF26A69A), size: 28),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier Directory',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('View all registered suppliers and their catalog',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
        const Spacer(),
        _buildGlassButton(
          icon: Icons.refresh,
          label: 'Refresh',
          onTap: _loadSuppliers,
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final total = _suppliers.length;
    final totalItems = _suppliers.fold<int>(0, (sum, s) => sum + ((s['item_count'] as num?)?.toInt() ?? 0));
    final withEmail = _suppliers.where((s) => (s['email']?.toString() ?? '').isNotEmpty).length;

    return Row(
      children: [
        _buildSummaryCard('Total Suppliers', '$total', Icons.business, const Color(0xFF26A69A)),
        const SizedBox(width: 12),
        _buildSummaryCard('Total Items', '$totalItems', Icons.inventory_2, const Color(0xFF42A5F5)),
        const SizedBox(width: 12),
        _buildSummaryCard('With Email', '$withEmail', Icons.email, const Color(0xFFAB47BC)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Search suppliers by name, code, category, or email...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
              icon: Icon(Icons.search, color: Colors.white38),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildSkeletonLoading();
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            _buildGlassButton(icon: Icons.refresh, label: 'Retry', onTap: _loadSuppliers),
          ],
        ),
      );
    }
    if (_suppliers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 12),
            Text('No suppliers found', style: TextStyle(color: Colors.white54, fontSize: 16)),
            Text('Upload a Supplier & Item Master file to populate this list',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      );
    }

    final filtered = _filteredSuppliers;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => AnimatedListItem(
                    index: i,
                    child: _buildSupplierRow(filtered[i], i),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: const Row(
        children: [
          SizedBox(width: 40),
          Expanded(flex: 2, child: Text('Supplier', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Contact', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Categories', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
          SizedBox(width: 80, child: Text('Items', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
          SizedBox(width: 100, child: Text('Lead Time', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
          SizedBox(width: 120, child: Text('Currency', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildSupplierRow(Map<String, dynamic> supplier, int index) {
    final id = supplier['id'] as int;
    final isExpanded = _expandedSupplierId == id;
    final itemCount = (supplier['item_count'] as num?)?.toInt() ?? 0;
    final leadTime = supplier['standard_lead_time_days'] ?? 14;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSupplierId = null;
                _supplierDetail = null;
              } else {
                _expandedSupplierId = id;
                _loadSupplierDetail(id);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isExpanded ? Colors.white.withOpacity(0.08) : Colors.transparent,
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38, size: 20,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supplier['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(supplier['supplier_code'] ?? '',
                        style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((supplier['email'] ?? '').isNotEmpty)
                        Text(supplier['email'], style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 12)),
                      if ((supplier['phone'] ?? '').isNotEmpty)
                        Text(supplier['phone'], style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      if ((supplier['contact_person'] ?? '').isNotEmpty)
                        Text(supplier['contact_person'], style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(supplier['categories'] ?? 'Uncategorized',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$itemCount', style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Center(
                    child: Text('$leadTime days',
                      style: TextStyle(
                        color: leadTime > 30 ? Colors.orangeAccent : Colors.white70,
                        fontSize: 13,
                      )),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Text(supplier['currency'] ?? 'MYR',
                      style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) _buildExpandedDetail(),
      ],
    );
  }

  Widget _buildExpandedDetail() {
    if (_isLoadingDetail || _supplierDetail == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white.withOpacity(0.04),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF26A69A), strokeWidth: 2)),
      );
    }

    final detail = _supplierDetail!;
    final items = (detail['items'] as List?) ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info chips row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if ((detail['payment_terms'] ?? '').isNotEmpty)
                _buildInfoChip(Icons.payment, 'Terms: ${detail['payment_terms']}', const Color(0xFF42A5F5)),
              if ((detail['address'] ?? '').isNotEmpty)
                _buildInfoChip(Icons.location_on, detail['address'], const Color(0xFF66BB6A)),
            ],
          ),
          const SizedBox(height: 16),

          // Items table
          if (items.isNotEmpty) ...[
            Text('Catalog Items (${items.length})',
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
                  dataRowColor: WidgetStateProperty.all(Colors.transparent),
                  columnSpacing: 20,
                  horizontalMargin: 16,
                  headingTextStyle: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                  dataTextStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                  columns: const [
                    DataColumn(label: Text('Item Code')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Unit Price'), numeric: true),
                    DataColumn(label: Text('MOQ'), numeric: true),
                    DataColumn(label: Text('Lead Time'), numeric: true),
                    DataColumn(label: Text('CBM'), numeric: true),
                    DataColumn(label: Text('Weight (kg)'), numeric: true),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: items.map<DataRow>((item) {
                    final status = item['status'] ?? 'Active';
                    final isActive = status == 'Active';
                    return DataRow(cells: [
                      DataCell(Text(item['item_code'] ?? '', style: const TextStyle(color: Color(0xFF64B5F6), fontWeight: FontWeight.w600))),
                      DataCell(Text(item['primary_category'] ?? '')),
                      DataCell(Text(_formatCurrency(item['unit_price']))),
                      DataCell(Text('${item['moq'] ?? 0}')),
                      DataCell(Text('${item['lead_time'] ?? '-'} days')),
                      DataCell(Text('${item['cbm'] ?? 0}')),
                      DataCell(Text('${item['weight_kg'] ?? 0}')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isActive ? Colors.green : Colors.red).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status, style: TextStyle(
                          color: isActive ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 11,
                        )),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ] else
            const Text('No catalog items linked to this supplier.',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        // Table header skeleton
        GlassSkeletonCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: const [
              GlassSkeleton(width: 40, height: 16),
              SizedBox(width: 14),
              Expanded(flex: 2, child: GlassSkeleton(height: 14)),
              SizedBox(width: 14),
              Expanded(flex: 2, child: GlassSkeleton(height: 14)),
              SizedBox(width: 14),
              Expanded(flex: 2, child: GlassSkeleton(height: 14)),
              SizedBox(width: 14),
              GlassSkeleton(width: 60, height: 14),
              SizedBox(width: 14),
              GlassSkeleton(width: 80, height: 14),
              SizedBox(width: 14),
              GlassSkeleton(width: 80, height: 14),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Row skeletons
        Expanded(
          child: ListView.separated(
            itemCount: 8,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (_, __) => GlassSkeletonCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: const [
                  GlassSkeleton(width: 28, height: 28, borderRadius: 6),
                  SizedBox(width: 14),
                  Expanded(flex: 2, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassSkeleton(width: 140, height: 14),
                      SizedBox(height: 6),
                      GlassSkeleton(width: 80, height: 10),
                    ],
                  )),
                  SizedBox(width: 14),
                  Expanded(flex: 2, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassSkeleton(width: 160, height: 12),
                      SizedBox(height: 6),
                      GlassSkeleton(width: 100, height: 10),
                    ],
                  )),
                  SizedBox(width: 14),
                  Expanded(flex: 2, child: GlassSkeleton(height: 12)),
                  SizedBox(width: 14),
                  GlassSkeleton(width: 40, height: 22, borderRadius: 12),
                  SizedBox(width: 14),
                  GlassSkeleton(width: 70, height: 14),
                  SizedBox(width: 14),
                  GlassSkeleton(width: 50, height: 14),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
