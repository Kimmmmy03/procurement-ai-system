// screens/officer/dashboard_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/skeleton_layouts.dart';
import '../widgets/animated_list_item.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  bool _isConnected = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _checkConnectionAndLoad();
  }

  Future<void> _checkConnectionAndLoad() async {
    await _testConnection();
    await _loadDashboard();
  }

  Future<void> _testConnection() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.checkConnection();
      if (!mounted) return;
      setState(() {
        _isConnected = result['success'] == true;
        _connectionStatus = result['message'];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _connectionStatus = 'Cannot reach backend: $e';
      });
    }
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = await apiService.getOfficerDashboard();
      if (!mounted) return;
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        GlassNotification.show(
          context,
          _isConnected ? 'Failed to load dashboard data' : 'Cannot connect to backend',
          isError: true,
        );
      }
    }
  }

  void _navigate(int index) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const DashboardSkeleton()
          else if (_dashboardData == null)
            _buildErrorState()
          else
            _buildDashboard(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isConnected ? Icons.error_outline : Icons.cloud_off,
            size: 64,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            _isConnected ? 'Failed to load dashboard data' : 'Cannot connect to backend',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _showConnectionDialog,
                icon: const Icon(Icons.settings_ethernet, size: 18),
                label: const Text('Test Connection'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF66BB6A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final stats = _dashboardData!['stats'] as Map<String, dynamic>? ?? {};
    final recentActivity = _dashboardData!['recent_activity'] as List? ?? [];
    final criticalAlerts = _dashboardData!['critical_alerts'] as List? ?? [];
    final topSuppliers = _dashboardData!['top_suppliers'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            AnimatedListItem(
              index: 0,
              child: _buildHeaderRow(stats),
            ),

            const SizedBox(height: 28),

            // Row 1: Stat Cards
            _buildStatCardsRow(stats),

            const SizedBox(height: 24),

            // Row 2: Two columns
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column: Quick Actions + Recent Activity
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedListItem(
                            index: 5,
                            child: _buildQuickActionsCard(),
                          ),
                          const SizedBox(height: 16),
                          AnimatedListItem(
                            index: 6,
                            child: _buildRecentActivityCard(recentActivity),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right column: Critical Alerts + Top Suppliers
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedListItem(
                            index: 7,
                            child: _buildCriticalAlertsCard(criticalAlerts, stats),
                          ),
                          const SizedBox(height: 16),
                          AnimatedListItem(
                            index: 8,
                            child: _buildTopSuppliersCard(topSuppliers),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    AnimatedListItem(index: 5, child: _buildQuickActionsCard()),
                    const SizedBox(height: 16),
                    AnimatedListItem(index: 6, child: _buildRecentActivityCard(recentActivity)),
                    const SizedBox(height: 16),
                    AnimatedListItem(index: 7, child: _buildCriticalAlertsCard(criticalAlerts, stats)),
                    const SizedBox(height: 16),
                    AnimatedListItem(index: 8, child: _buildTopSuppliersCard(topSuppliers)),
                  ],
                );
              }
            }),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeaderRow(Map<String, dynamic> stats) {
    final totalItems = stats['total_items'] ?? 0;
    final approvedCount = stats['approved_count'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Procurement Dashboard',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalItems total items tracked  |  $approvedCount approved',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _GlassIconButton(
              icon: _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? const Color(0xFF66BB6A) : const Color(0xFFFFB74D),
              tooltip: 'Connection: ${_isConnected ? "OK" : "Offline"}',
              onTap: _showConnectionDialog,
            ),
            const SizedBox(width: 8),
            _GlassIconButton(
              icon: Icons.refresh,
              color: Colors.white70,
              tooltip: 'Refresh',
              onTap: _checkConnectionAndLoad,
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARDS ROW
  // ============================================================

  Widget _buildStatCardsRow(Map<String, dynamic> stats) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 1100 ? 4 : 2;
      final ratio = constraints.maxWidth > 1100 ? 2.4 : 1.8;

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: ratio,
        children: [
          AnimatedListItem(
            index: 1,
            child: _StatCard(
              title: 'Pending PRs',
              value: (stats['pending_prs'] ?? 0).toString(),
              icon: Icons.pending_actions,
              color: const Color(0xFF64B5F6),
              onTap: () => _navigate(3),
              subtitle: 'Awaiting review',
            ),
          ),
          AnimatedListItem(
            index: 2,
            child: _StatCard(
              title: 'Critical Items',
              value: (stats['critical_items'] ?? 0).toString(),
              icon: Icons.error_rounded,
              color: const Color(0xFFEF5350),
              onTap: () => _navigate(3),
              subtitle: '${stats['warning_items'] ?? 0} warnings',
            ),
          ),
          AnimatedListItem(
            index: 3,
            child: _StatCard(
              title: 'Total Value',
              value: stats['total_value']?.toString() ?? 'RM 0',
              icon: Icons.payments_rounded,
              color: const Color(0xFF66BB6A),
              onTap: () => _navigate(3),
              subtitle: 'Pending procurement',
              smallValue: true,
            ),
          ),
          AnimatedListItem(
            index: 4,
            child: _StatCard(
              title: 'Active POs',
              value: (stats['active_pos'] ?? 0).toString(),
              icon: Icons.description_rounded,
              color: const Color(0xFFFFB74D),
              onTap: () => _navigate(5),
              subtitle: 'Purchase orders',
            ),
          ),
        ],
      );
    });
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActionsCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: Icons.bolt_rounded, title: 'Quick Actions', color: const Color(0xFFFFB74D)),
          const SizedBox(height: 16),
          _ActionButton(
            icon: Icons.upload_file_rounded,
            label: 'Import Data',
            subtitle: 'Upload inventory & supplier files',
            color: const Color(0xFF1E88E5),
            onTap: () => _navigate(1),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.auto_awesome_rounded,
            label: 'Run AI Forecast',
            subtitle: 'Generate demand predictions',
            color: const Color(0xFF66BB6A),
            onTap: () => _navigate(2),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.edit_note_rounded,
            label: 'Manage Purchase Requests',
            subtitle: 'Review, override & submit batches',
            color: const Color(0xFFAB47BC),
            onTap: () => _navigate(3),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECENT ACTIVITY
  // ============================================================

  Widget _buildRecentActivityCard(List recentActivity) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHeader(
                  icon: Icons.history_rounded,
                  title: 'Recent Activity',
                  color: const Color(0xFF64B5F6),
                ),
              ),
              _GlassIconButton(
                icon: Icons.refresh,
                color: Colors.white54,
                tooltip: 'Refresh',
                onTap: _loadDashboard,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recentActivity.isEmpty)
            _buildEmptyPanel(Icons.history, 'No recent activity', 'Upload data and run forecasts to see activity here')
          else
            ...recentActivity.map((activity) {
              final type = activity['type'] ?? '';
              final IconData icon;
              final Color color;
              switch (type) {
                case 'approval':
                  icon = Icons.check_circle_rounded;
                  color = const Color(0xFF66BB6A);
                  break;
                case 'po':
                  icon = Icons.receipt_long_rounded;
                  color = const Color(0xFF42A5F5);
                  break;
                case 'batch':
                  icon = Icons.send_rounded;
                  color = const Color(0xFFFFB74D);
                  break;
                default:
                  icon = Icons.circle;
                  color = Colors.white54;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['action'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((activity['timestamp'] ?? '').toString().isNotEmpty)
                            Text(
                              _formatTimestamp(activity['timestamp']),
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ============================================================
  // CRITICAL ALERTS + RISK BREAKDOWN
  // ============================================================

  Widget _buildCriticalAlertsCard(List criticalAlerts, Map<String, dynamic> stats) {
    final critical = stats['critical_items'] ?? 0;
    final warning = stats['warning_items'] ?? 0;
    final low = stats['low_risk_items'] ?? 0;

    return _GlassCard(
      borderColor: critical > 0 ? const Color(0xFFEF5350) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.shield_rounded,
            title: 'Risk Overview',
            color: const Color(0xFFEF5350),
          ),
          const SizedBox(height: 14),

          // Risk breakdown bar
          _buildRiskBar(critical, warning, low),
          const SizedBox(height: 16),

          // Risk counts
          Row(
            children: [
              _RiskBadge(label: 'Critical', count: critical, color: const Color(0xFFEF5350)),
              const SizedBox(width: 8),
              _RiskBadge(label: 'Warning', count: warning, color: const Color(0xFFFFB74D)),
              const SizedBox(width: 8),
              _RiskBadge(label: 'Low', count: low, color: const Color(0xFF66BB6A)),
            ],
          ),

          if (criticalAlerts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 10),
            Text('Critical Alerts', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...criticalAlerts.take(3).map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _navigate(3),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF5350), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert.toString(),
                          style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
          ] else ...[
            const SizedBox(height: 16),
            _buildEmptyPanel(Icons.verified_rounded, 'No critical alerts', 'All items within safe stock levels'),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskBar(int critical, int warning, int low) {
    final total = critical + warning + low;
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (critical > 0)
              Flexible(
                flex: critical,
                child: Container(color: const Color(0xFFEF5350)),
              ),
            if (warning > 0)
              Flexible(
                flex: warning,
                child: Container(color: const Color(0xFFFFB74D)),
              ),
            if (low > 0)
              Flexible(
                flex: low,
                child: Container(color: const Color(0xFF66BB6A)),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP SUPPLIERS
  // ============================================================

  Widget _buildTopSuppliersCard(List topSuppliers) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHeader(
                  icon: Icons.business_rounded,
                  title: 'Top Suppliers by Value',
                  color: const Color(0xFF42A5F5),
                ),
              ),
              TextButton.icon(
                onPressed: () => _navigate(6),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('View All', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF64B5F6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (topSuppliers.isEmpty)
            _buildEmptyPanel(Icons.business, 'No supplier data', 'Import supplier data to see top suppliers')
          else
            ...topSuppliers.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value as Map<String, dynamic>;
              final colors = [
                const Color(0xFF1E88E5),
                const Color(0xFF66BB6A),
                const Color(0xFFFFB74D),
                const Color(0xFFAB47BC),
                const Color(0xFFEF5350),
              ];
              final color = colors[i % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${s['items']} items',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        s['value'] ?? '',
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildEmptyPanel(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    try {
      final dt = DateTime.parse(ts);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return ts;
    }
  }

  Future<void> _showConnectionDialog() async {
    await _testConnection();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: Row(
          children: [
            Icon(
              _isConnected ? Icons.check_circle : Icons.error,
              color: _isConnected ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
              size: 24,
            ),
            const SizedBox(width: 10),
            const Text('Connection Status', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isConnected ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(_isConnected ? Icons.cloud_done : Icons.cloud_off,
                      color: _isConnected ? const Color(0xFF66BB6A) : const Color(0xFFEF5350)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            color: _isConnected ? const Color(0xFF66BB6A) : const Color(0xFFEF5350),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _connectionStatus ?? 'Unknown',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Backend: ${ApiService.baseUrl}',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _checkConnectionAndLoad();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5)),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REUSABLE WIDGETS
// ============================================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _GlassCard({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor?.withOpacity(0.3) ?? Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool smallValue;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    this.subtitle,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.12),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white.withOpacity(0.2), size: 16),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: smallValue ? 20 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(title, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.35))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final double size;

  const _GlassIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _RiskBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
