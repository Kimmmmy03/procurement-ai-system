// lib/screens/warehouse_stock_screen.dart

import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../widgets/glass_skeleton.dart';
import '../widgets/glass_dialog.dart';

class WarehouseStockScreen extends StatefulWidget {
  const WarehouseStockScreen({super.key});

  @override
  State<WarehouseStockScreen> createState() => _WarehouseStockScreenState();
}

class _WarehouseStockScreenState extends State<WarehouseStockScreen> {
  Map<String, dynamic>? _stockData;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int? _selectedItemIndex;
  final _numberFormat = NumberFormat('#,##0');
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.getWarehouseStock();
      if (!mounted) return;
      setState(() { _stockData = data; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _fmt(dynamic value) {
    if (value == null) return '0';
    final n = num.tryParse(value.toString()) ?? 0;
    return _numberFormat.format(n);
  }

  int _intVal(dynamic value) => (value as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> get _items {
    if (_stockData == null) return [];
    final list = (_stockData!['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((item) {
      return (item['sku']?.toString().toLowerCase().contains(q) ?? false) ||
             (item['product']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  static const List<_ChannelCol> _channels = [
    _ChannelCol('R-NM', 'sellable_main_warehouse', Color(0xFF42A5F5)),
    _ChannelCol('BR-NM6 (TikTok)', 'sellable_tiktok', Color(0xFFEF5350)),
    _ChannelCol('BR-NM8 (Lazada)', 'sellable_lazada', Color(0xFF7E57C2)),
    _ChannelCol('BR-NM9 (Shopee)', 'sellable_shopee', Color(0xFFFF7043)),
    _ChannelCol('BR-NM10 (e-store)', 'sellable_estore', Color(0xFF26A69A)),
    _ChannelCol('BR-NM1 (Project)', 'reserved_b2b_projects', Color(0xFF66BB6A)),
    _ChannelCol('BR-NM2 (Corporate)', 'sellable_corporate', Color(0xFFFFCA28)),
    _ChannelCol('BR-NM3 (East Mas)', 'sellable_east_mas', Color(0xFF8D6E63)),
    _ChannelCol('BR-NM11 (minor BP)', 'sellable_minor_bp', Color(0xFF78909C)),
    _ChannelCol('BR-RW (rework)', 'quarantine_rework', Color(0xFFFF8A65)),
    _ChannelCol('BR-BP', 'stock_bp', Color(0xFF4DB6AC)),
    _ChannelCol('BR-DM', 'stock_dm', Color(0xFFBA68C8)),
    _ChannelCol('BR-INC (SIRIM)', 'quarantine_sirim', Color(0xFFE57373)),
    _ChannelCol('BR-INC2 (incomplete)', 'quarantine_incomplete', Color(0xFF90A4AE)),
    _ChannelCol('MGIT', 'stock_mgit', Color(0xFF4FC3F7)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalSkus = _items.length;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF42A5F5).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.warehouse, color: Color(0xFF42A5F5), size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Warehouse Stock',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('$totalSkus SKUs across all warehouse channels',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
        const Spacer(),
        _buildGlassButton(icon: Icons.refresh, label: 'Refresh', onTap: _loadStock),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final items = _items;
    int sumField(String key) => items.fold<int>(0, (s, e) => s + _intVal(e[key]));

    final totalInHand = sumField('total_stocks_in_hand');
    final totalIncoming = sumField('total_stocks_incoming');
    final totalStocks = sumField('total_stocks');

    return Row(
      children: [
        _buildSummaryCard('Total In Hand', _numberFormat.format(totalInHand), Icons.inventory_2, const Color(0xFF26A69A)),
        const SizedBox(width: 12),
        _buildSummaryCard('Total Incoming', _numberFormat.format(totalIncoming), Icons.local_shipping, const Color(0xFF42A5F5)),
        const SizedBox(width: 12),
        _buildSummaryCard('Total Stocks', _numberFormat.format(totalStocks), Icons.assessment, const Color(0xFFFFB74D)),
        const SizedBox(width: 12),
        _buildSummaryCard('Total SKUs', _numberFormat.format(items.length), Icons.category, const Color(0xFFAB47BC)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
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
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white30, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search by SKU or product name...',
                    hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() { _searchQuery = v; _selectedItemIndex = null; }),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                InkWell(
                  onTap: () {
                    _searchController.clear();
                    setState(() { _searchQuery = ''; _selectedItemIndex = null; });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, color: Color(0xFFEF5350), size: 16),
                        SizedBox(width: 4),
                        Text('Clear', style: TextStyle(color: Color(0xFFEF5350), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              Text('${_items.length} items', style: const TextStyle(color: Colors.white30, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return _buildSkeletonLoading();
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        _buildGlassButton(icon: Icons.refresh, label: 'Retry', onTap: _loadStock),
      ]));
    }
    final items = _items;
    if (items.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warehouse_outlined, color: Colors.white24, size: 64),
        SizedBox(height: 12),
        Text('No warehouse stock data found', style: TextStyle(color: Colors.white54, fontSize: 16)),
        Text('Upload Xeersoft inventory data to populate stock levels', style: TextStyle(color: Colors.white38, fontSize: 13)),
      ]));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: channel distribution chart + top channels
        SizedBox(
          width: 340,
          child: Column(
            children: [
              _buildChannelDistributionChart(items),
              const SizedBox(height: 12),
              Expanded(child: _buildTopChannelsList(items)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right: item list with expandable cards
        Expanded(
          child: _buildItemList(items),
        ),
      ],
    );
  }

  // ── Channel Distribution Pie Chart ────────────────────────────────────────

  Widget _buildChannelDistributionChart(List<Map<String, dynamic>> items) {
    // Aggregate stock per channel
    final channelTotals = <String, int>{};
    for (final ch in _channels) {
      channelTotals[ch.header] = items.fold<int>(0, (s, e) => s + _intVal(e[ch.field]));
    }
    // Filter out zero channels
    final nonZero = _channels.where((ch) => (channelTotals[ch.header] ?? 0) > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    final total = nonZero.fold<int>(0, (s, ch) => s + (channelTotals[ch.header] ?? 0));

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stock Distribution by Channel',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Total: ${_numberFormat.format(total)} units',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 36,
                    sections: nonZero.map((ch) {
                      final val = channelTotals[ch.header] ?? 0;
                      final pct = total > 0 ? (val / total * 100) : 0.0;
                      return PieChartSectionData(
                        color: ch.color,
                        value: val.toDouble(),
                        title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                        titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        radius: 40,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Channels List ─────────────────────────────────────────────────────

  Widget _buildTopChannelsList(List<Map<String, dynamic>> items) {
    final channelTotals = <_ChannelCol, int>{};
    for (final ch in _channels) {
      channelTotals[ch] = items.fold<int>(0, (s, e) => s + _intVal(e[ch.field]));
    }
    final sorted = _channels.toList()..sort((a, b) => (channelTotals[b] ?? 0).compareTo(channelTotals[a] ?? 0));
    final maxVal = sorted.isNotEmpty ? (channelTotals[sorted.first] ?? 1).toDouble() : 1.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Channel Breakdown',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final ch = sorted[i];
                    final val = channelTotals[ch] ?? 0;
                    final pct = maxVal > 0 ? val / maxVal : 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: ch.color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ch.header, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                            Text(_numberFormat.format(val), style: TextStyle(color: ch.color, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.white.withOpacity(0.05),
                            valueColor: AlwaysStoppedAnimation(ch.color.withOpacity(0.7)),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Item List with Expandable Cards ───────────────────────────────────────

  Widget _buildItemList(List<Map<String, dynamic>> items) {
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
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 120, child: Text('SKU', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
                    const Expanded(child: Text('Product', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 90, child: Text('Main (R-NM)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    const SizedBox(width: 90, child: Text('Total Stock', style: TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final isSelected = _selectedItemIndex == i;
                    return _buildItemCard(item, i, isSelected);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index, bool isSelected) {
    final sku = item['sku']?.toString() ?? '';
    final product = item['product']?.toString() ?? '';
    final mainStock = _intVal(item['sellable_main_warehouse']);
    final totalStock = _intVal(item['total_stocks']);

    return Column(
      children: [
        // Collapsed row
        InkWell(
          onTap: () => setState(() => _selectedItemIndex = isSelected ? null : index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.08) : (index % 2 == 0 ? Colors.transparent : Colors.white.withOpacity(0.02)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                SizedBox(width: 120, child: GestureDetector(
                  onTap: () {
                    _searchController.text = sku;
                    setState(() { _searchQuery = sku; _selectedItemIndex = null; });
                  },
                  child: Tooltip(
                    message: 'Click to search "$sku"',
                    child: Text(sku, style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace', decoration: TextDecoration.underline, decorationColor: Color(0xFF64B5F6))),
                  ),
                )),
                Expanded(child: Text(product, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
                SizedBox(width: 90, child: Text(_fmt(mainStock), style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.right)),
                SizedBox(width: 90, child: Text(_fmt(totalStock), style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                SizedBox(width: 40, child: Icon(isSelected ? Icons.expand_less : Icons.expand_more, color: Colors.white30, size: 18)),
              ],
            ),
          ),
        ),
        // Expanded detail
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildItemDetail(item),
          crossFadeState: isSelected ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildItemDetail(Map<String, dynamic> item) {
    // Build bar chart data for this item
    final nonZeroChannels = _channels.where((ch) => _intVal(item[ch.field]) > 0).toList();
    final allChannelValues = _channels.map((ch) => _intVal(item[ch.field])).toList();
    final maxVal = allChannelValues.isEmpty ? 1.0 : allChannelValues.reduce(max).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel bar chart
          if (nonZeroChannels.isNotEmpty) ...[
            Row(
              children: [
                const Text('Stock by Channel', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                InkWell(
                  onTap: () => _showEditDialog(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, color: Color(0xFFFFB74D), size: 14),
                        SizedBox(width: 4),
                        Text('Edit Stock', style: TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.15,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: const Color(0xFF1E2A3A),
                      getTooltipItem: (group, gIndex, rod, rIndex) {
                        final ch = _channels[group.x.toInt()];
                        return BarTooltipItem(
                          '${ch.header}\n${_numberFormat.format(rod.toY.toInt())}',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(_numberFormat.format(v.toInt()), style: const TextStyle(color: Colors.white24, fontSize: 9)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 70,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= _channels.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: RotatedBox(
                              quarterTurns: -1,
                              child: Text(
                                _channels[idx].header.length > 14 ? _channels[idx].header.substring(0, 14) : _channels[idx].header,
                                style: const TextStyle(color: Colors.white38, fontSize: 9),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(_channels.length, (i) {
                    final val = _intVal(item[_channels[i].field]).toDouble();
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: val,
                        color: _channels[i].color,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          ] else ...[
            const Text('No stock in any channel', style: TextStyle(color: Colors.white30, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          // Totals row
          Row(
            children: [
              _buildTotalChip('In Hand', _fmt(item['total_stocks_in_hand']), const Color(0xFF26A69A)),
              const SizedBox(width: 8),
              _buildTotalChip('Incoming', _fmt(item['total_stocks_incoming']), const Color(0xFF42A5F5)),
              const SizedBox(width: 8),
              _buildTotalChip('Total', _fmt(item['total_stocks']), const Color(0xFFFFB74D)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Edit Dialog ────────────────────────────────────────────────────────────

  Future<void> _showEditDialog(Map<String, dynamic> item) async {
    final sku = item['sku']?.toString() ?? '';
    final controllers = <String, TextEditingController>{};
    for (final ch in _channels) {
      controllers[ch.field] = TextEditingController(text: _intVal(item[ch.field]).toString());
    }

    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => GlassDialog(
          width: 550,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB74D).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit, color: Color(0xFFFFB74D), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Stock \u2014 $sku', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(item['product']?.toString() ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: _channels.map((ch) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: ch.color, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            SizedBox(width: 160, child: Text(ch.header, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: controllers[ch.field],
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.08),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : () async {
                      setDialogState(() => isSaving = true);
                      final data = <String, int>{};
                      for (final ch in _channels) {
                        final val = int.tryParse(controllers[ch.field]!.text) ?? 0;
                        data[ch.field] = val;
                      }
                      try {
                        final api = Provider.of<ApiService>(ctx, listen: false);
                        await api.updateWarehouseStock(sku, data.cast<String, dynamic>());
                        Navigator.pop(ctx);
                        await _loadStock();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Stock updated for $sku'), backgroundColor: const Color(0xFF66BB6A)),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    icon: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 16),
                    label: Text(isSaving ? 'Saving...' : 'Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66BB6A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    for (final c in controllers.values) { c.dispose(); }
  }

  // ── Skeleton Loading ──────────────────────────────────────────────────────

  Widget _buildSkeletonLoading() {
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: Column(
            children: [
              GlassSkeletonCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: const [
                  GlassSkeleton(width: 200, height: 14),
                  SizedBox(height: 12),
                  GlassSkeleton(width: double.infinity, height: 200),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(child: GlassSkeletonCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: List.generate(8, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: const [
                    GlassSkeleton(width: 8, height: 8),
                    SizedBox(width: 8),
                    Expanded(child: GlassSkeleton(height: 10)),
                    SizedBox(width: 8),
                    GlassSkeleton(width: 40, height: 10),
                  ]),
                ))),
              )),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: GlassSkeletonCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: List.generate(12, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: const [
              GlassSkeleton(width: 100, height: 12),
              SizedBox(width: 14),
              Expanded(child: GlassSkeleton(height: 12)),
              SizedBox(width: 14),
              GlassSkeleton(width: 60, height: 12),
              SizedBox(width: 14),
              GlassSkeleton(width: 60, height: 12),
            ]),
          ))),
        )),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelCol {
  final String header;
  final String field;
  final Color color;
  const _ChannelCol(this.header, this.field, this.color);
}
