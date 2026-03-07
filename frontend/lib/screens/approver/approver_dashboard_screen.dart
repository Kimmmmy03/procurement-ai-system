// screens/approver/approver_dashboard_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/skeleton_layouts.dart';
import '../../widgets/animated_list_item.dart';

class ApproverDashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const ApproverDashboardScreen({super.key, this.onNavigate});

  @override
  State<ApproverDashboardScreen> createState() => _ApproverDashboardScreenState();
}

class _ApproverDashboardScreenState extends State<ApproverDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionAndLoad();
  }

  Future<void> _checkConnectionAndLoad() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.checkConnection();
      setState(() => _isConnected = result['success'] == true);
    } catch (_) {
      setState(() => _isConnected = false);
    }
    await _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = await apiService.getApproverDashboard();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        GlassNotification.show(context, 'Failed to load dashboard', isError: true);
      }
    }
  }

  void _navigate(int index) {
    if (widget.onNavigate != null) widget.onNavigate!(index);
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
          Icon(_isConnected ? Icons.error_outline : Icons.cloud_off, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          Text(
            _isConnected ? 'Failed to load dashboard' : 'Cannot connect to backend',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _checkConnectionAndLoad,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF66BB6A)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final stats = _dashboardData!['stats'] as Map<String, dynamic>? ?? {};
    final pendingBatches = _dashboardData!['pending_batches'] as List? ?? [];
    final recentDecisions = _dashboardData!['recent_decisions'] as List? ?? [];
    final riskBreakdown = _dashboardData!['risk_breakdown'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            AnimatedListItem(index: 0, child: _buildHeader(stats)),
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
                    // Left: Pending Batches
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedListItem(index: 5, child: _buildPendingBatchesCard(pendingBatches)),
                          const SizedBox(height: 16),
                          AnimatedListItem(index: 6, child: _buildRiskBreakdownCard(riskBreakdown)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: Recent Decisions + Quick Stats
                    Expanded(
                      child: Column(
                        children: [
                          AnimatedListItem(index: 7, child: _buildRecentDecisionsCard(recentDecisions)),
                          const SizedBox(height: 16),
                          AnimatedListItem(index: 8, child: _buildApprovalSummaryCard(stats)),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    AnimatedListItem(index: 5, child: _buildPendingBatchesCard(pendingBatches)),
                    const SizedBox(height: 16),
                    AnimatedListItem(index: 6, child: _buildRiskBreakdownCard(riskBreakdown)),
                    const SizedBox(height: 16),
                    AnimatedListItem(index: 7, child: _buildRecentDecisionsCard(recentDecisions)),
                    const SizedBox(height: 16),
                    AnimatedListItem(index: 8, child: _buildApprovalSummaryCard(stats)),
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

  Widget _buildHeader(Map<String, dynamic> stats) {
    final pending = stats['pending_approvals'] ?? 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Executive Dashboard',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('General Manager', style: TextStyle(color: Color(0xFFCE93D8), fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  if (pending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB74D).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$pending pending', style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ),
        ),
        _GlassIconBtn(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onTap: _checkConnectionAndLoad,
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARDS
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
            child: _ApproverStatCard(
              title: 'Pending Batches',
              value: (stats['pending_approvals'] ?? 0).toString(),
              icon: Icons.pending_actions_rounded,
              color: const Color(0xFFFFB74D),
              onTap: () => _navigate(1),
              subtitle: '${stats['total_pending_items'] ?? 0} items awaiting review',
            ),
          ),
          AnimatedListItem(
            index: 2,
            child: _ApproverStatCard(
              title: 'Pending Value',
              value: stats['total_pending_value']?.toString() ?? 'RM 0',
              icon: Icons.payments_rounded,
              color: const Color(0xFF64B5F6),
              smallValue: true,
              subtitle: 'Total batch value',
            ),
          ),
          AnimatedListItem(
            index: 3,
            child: _ApproverStatCard(
              title: 'Approved Today',
              value: (stats['approved_today'] ?? 0).toString(),
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF66BB6A),
              subtitle: '${stats['total_approved'] ?? 0} total approved',
            ),
          ),
          AnimatedListItem(
            index: 4,
            child: _ApproverStatCard(
              title: 'Critical Items',
              value: (stats['critical_items'] ?? 0).toString(),
              icon: Icons.warning_rounded,
              color: const Color(0xFFEF5350),
              onTap: () => _navigate(1),
              subtitle: 'High-risk pending',
            ),
          ),
        ],
      );
    });
  }

  // ============================================================
  // PENDING BATCHES
  // ============================================================

  Widget _buildPendingBatchesCard(List pendingBatches) {
    return _GlassCard(
      borderColor: pendingBatches.isNotEmpty ? const Color(0xFFFFB74D) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHead(
                  icon: Icons.inbox_rounded,
                  title: 'Pending Batches',
                  color: const Color(0xFFFFB74D),
                ),
              ),
              if (pendingBatches.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB74D).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${pendingBatches.length}',
                    style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (pendingBatches.isEmpty)
            _buildEmpty(Icons.check_circle_outline_rounded, 'All caught up', 'No batches awaiting your approval')
          else
            ...pendingBatches.take(5).toList().asMap().entries.map((entry) {
              final batch = entry.value as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _navigate(1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB74D).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.folder_open_rounded, color: Color(0xFFFFB74D), size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch['batch_id'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '${batch['item_count'] ?? 0} items',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
                                  ),
                                  Flexible(
                                    child: Text(
                                      batch['total_value'] ?? 'RM 0',
                                      style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFF1E88E5).withOpacity(0.2), const Color(0xFF1565C0).withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Review', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          if (pendingBatches.length > 5)
            Center(
              child: TextButton.icon(
                onPressed: () => _navigate(1),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: Text('View all ${pendingBatches.length} batches', style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF64B5F6)),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // RISK BREAKDOWN
  // ============================================================

  Widget _buildRiskBreakdownCard(List riskBreakdown) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHead(icon: Icons.pie_chart_rounded, title: 'Risk Distribution', color: const Color(0xFFAB47BC)),
          const SizedBox(height: 14),
          if (riskBreakdown.isEmpty)
            _buildEmpty(Icons.pie_chart_outline_rounded, 'No data', 'Risk breakdown will show when items are pending')
          else ...[
            ...riskBreakdown.map((item) {
              final risk = (item['risk'] ?? 'LOW').toString().toUpperCase();
              final Color color;
              final IconData icon;
              switch (risk) {
                case 'CRITICAL':
                  color = const Color(0xFFEF5350);
                  icon = Icons.error_rounded;
                  break;
                case 'WARNING':
                  color = const Color(0xFFFFB74D);
                  icon = Icons.warning_rounded;
                  break;
                default:
                  color = const Color(0xFF66BB6A);
                  icon = Icons.check_circle_rounded;
              }
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
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 10),
                      Text(risk, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${item['count']} items', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      const SizedBox(width: 12),
                      Text(item['value'] ?? '', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // RECENT DECISIONS
  // ============================================================

  Widget _buildRecentDecisionsCard(List recentDecisions) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionHead(
                  icon: Icons.gavel_rounded,
                  title: 'Recent Decisions',
                  color: const Color(0xFF66BB6A),
                ),
              ),
              TextButton.icon(
                onPressed: () => _navigate(3),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('History', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF64B5F6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentDecisions.isEmpty)
            _buildEmpty(Icons.gavel_rounded, 'No decisions yet', 'Your approval history will appear here')
          else
            ...recentDecisions.take(5).map((d) {
              final decision = d['decision'] ?? '';
              final isApproved = decision == 'Approved';
              final color = isApproved ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);
              final icon = isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d['product'] ?? ''} (${d['sku'] ?? ''})',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(decision, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                                Text(' | ${d['value'] ?? ''}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _riskColor(d['risk']).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          d['risk'] ?? 'Low',
                          style: TextStyle(color: _riskColor(d['risk']), fontSize: 9, fontWeight: FontWeight.w600),
                        ),
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
  // APPROVAL SUMMARY
  // ============================================================

  Widget _buildApprovalSummaryCard(Map<String, dynamic> stats) {
    final approved = stats['total_approved'] ?? 0;
    final rejected = stats['total_rejected'] ?? 0;
    final total = approved + rejected;
    final approvalRate = total > 0 ? (approved / total * 100).toStringAsFixed(0) : '-';

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHead(icon: Icons.insights_rounded, title: 'Approval Summary', color: const Color(0xFF42A5F5)),
          const SizedBox(height: 16),
          // Approval rate
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF66BB6A).withOpacity(0.12), const Color(0xFF66BB6A).withOpacity(0.04)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$approvalRate%',
                        style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      const Text('Approval Rate', style: TextStyle(color: Color(0xFF81C784), fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _MiniStat(label: 'Approved', value: '$approved', color: const Color(0xFF66BB6A)),
                    const SizedBox(height: 8),
                    _MiniStat(label: 'Rejected', value: '$rejected', color: const Color(0xFFEF5350)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 10),
          Row(
            children: [
              _InfoChip(label: 'Approved Value', value: stats['approved_value'] ?? 'RM 0', color: const Color(0xFF66BB6A)),
              const SizedBox(width: 8),
              _InfoChip(label: 'POs Generated', value: '${stats['total_pos'] ?? 0}', color: const Color(0xFF42A5F5)),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildEmpty(IconData icon, String title, String subtitle) {
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

  Color _riskColor(dynamic risk) {
    switch (risk?.toString().toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF5350);
      case 'warning':
        return const Color(0xFFFFB74D);
      default:
        return const Color(0xFF66BB6A);
    }
  }
}

// ============================================================
// SHARED WIDGETS
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

class _ApproverStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool smallValue;

  const _ApproverStatCard({
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
                colors: [color.withOpacity(0.12), Colors.white.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(fontSize: smallValue ? 20 : 28, fontWeight: FontWeight.bold, color: Colors.white),
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

class _SectionHead extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHead({required this.icon, required this.title, required this.color});

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

class _GlassIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassIconBtn({required this.icon, required this.tooltip, required this.onTap});

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
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
