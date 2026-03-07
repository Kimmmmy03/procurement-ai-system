// screens/approver/executive_analytics_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/skeleton_layouts.dart';

class ExecutiveAnalyticsScreen extends StatefulWidget {
  const ExecutiveAnalyticsScreen({super.key});

  @override
  State<ExecutiveAnalyticsScreen> createState() => _ExecutiveAnalyticsScreenState();
}

class _ExecutiveAnalyticsScreenState extends State<ExecutiveAnalyticsScreen> {
  Map<String, dynamic>? _analyticsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = await apiService.getAnalyticsData();

      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
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
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),

          if (_isLoading)
            const DashboardSkeleton()
          else if (_analyticsData == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics, size: 64, color: Colors.white54),
                  const SizedBox(height: 16),
                  const Text('No analytics data available',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadAnalytics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SingleChildScrollView(
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
                            Text('Executive Analytics',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            SizedBox(height: 8),
                            Text('Procurement performance overview',
                                style: TextStyle(fontSize: 16, color: Color(0xFF64B5F6))),
                          ],
                        ),
                        IconButton(
                          onPressed: _loadAnalytics,
                          icon: const Icon(Icons.refresh, color: Color(0xFF64B5F6)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // KPI Cards
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.5,
                      children: [
                        _buildKPICard('Total Spend',
                            _analyticsData!['total_spend']?.toString() ?? 'RM 0',
                            Icons.payments, const Color(0xFF66BB6A)),
                        _buildKPICard('Approved Batches',
                            (_analyticsData!['approved_batches'] ?? 0).toString(),
                            Icons.check_circle, const Color(0xFF9C27B0)),
                        _buildKPICard('Avg Approval Time',
                            _analyticsData!['avg_approval_time']?.toString() ?? 'N/A',
                            Icons.schedule, const Color(0xFF64B5F6)),
                        _buildKPICard('Cost Savings',
                            _analyticsData!['cost_savings']?.toString() ?? 'RM 0',
                            Icons.trending_down, const Color(0xFFFFB74D)),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Charts Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _GlassContainer(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Spending by Category',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                const SizedBox(height: 20),
                                ...((_analyticsData!['spending_by_category'] as List?) ?? [])
                                    .map((cat) => _buildCategoryBar(
                                        cat['category'] ?? 'Unknown',
                                        (cat['amount'] as num?)?.toDouble() ?? 0,
                                        (cat['percentage'] as num?)?.toDouble() ?? 0))
                                    .toList(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _GlassContainer(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Monthly Trends',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                const SizedBox(height: 20),
                                Center(
                                  child: Text('Chart placeholder',
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.5))),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildCategoryBar(String category, double amount, double percentage) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text('RM ${amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Color(0xFF66BB6A), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF66BB6A)),
            ),
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