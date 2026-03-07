import 'package:flutter/material.dart';
import 'glass_skeleton.dart';

/// Skeleton for a single dashboard metric card (e.g. Pending PRs, Total Value).
class MetricCardSkeleton extends StatelessWidget {
  const MetricCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassSkeletonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          GlassSkeleton(width: 90, height: 14),
          SizedBox(height: 14),
          GlassSkeleton(width: 130, height: 28, borderRadius: 8),
          SizedBox(height: 10),
          GlassSkeleton(width: 70, height: 12),
        ],
      ),
    );
  }
}

/// Skeleton for a grid of metric cards (typically 4 cards).
class MetricGridSkeleton extends StatelessWidget {
  final int count;
  const MetricGridSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.0,
          ),
          itemCount: count,
          itemBuilder: (_, __) => const MetricCardSkeleton(),
        );
      },
    );
  }
}

/// Skeleton for a single list row (e.g. a Purchase Request or Purchase Order).
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassSkeletonCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Checkbox placeholder
          const GlassSkeleton(width: 22, height: 22, borderRadius: 6),
          const SizedBox(width: 14),
          // SKU badge
          const GlassSkeleton(width: 80, height: 18, borderRadius: 6),
          const SizedBox(width: 14),
          // Product name
          const Expanded(child: GlassSkeleton(height: 16)),
          const SizedBox(width: 14),
          // Quantity
          const GlassSkeleton(width: 50, height: 18, borderRadius: 6),
          const SizedBox(width: 14),
          // Risk badge
          const GlassSkeleton(width: 68, height: 24, borderRadius: 12),
          const SizedBox(width: 14),
          // Value
          const GlassSkeleton(width: 90, height: 16),
        ],
      ),
    );
  }
}

/// Skeleton for a list of items (simulates 5-8 loading rows).
class ListViewSkeleton extends StatelessWidget {
  final int itemCount;
  const ListViewSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const ListItemSkeleton(),
    );
  }
}

/// Skeleton for the 3-column expanded detail view (sales, inventory, AI risk).
class DetailViewSkeleton extends StatelessWidget {
  const DetailViewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassSkeletonCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column 1: Sales data
          Expanded(child: _buildColumn(4)),
          const SizedBox(width: 20),
          // Column 2: Inventory data
          Expanded(child: _buildColumn(5)),
          const SizedBox(width: 20),
          // Column 3: AI Risk
          Expanded(child: _buildColumn(3)),
        ],
      ),
    );
  }

  Widget _buildColumn(int lineCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlassSkeleton(width: 110, height: 16),
        const SizedBox(height: 16),
        for (int i = 0; i < lineCount; i++) ...[
          GlassSkeleton(
            height: 14,
            width: i == 0 ? double.infinity : (120.0 + i * 20),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Skeleton for a chart / analytics card (large block with title).
class ChartSkeleton extends StatelessWidget {
  final double height;
  const ChartSkeleton({super.key, this.height = 220});

  @override
  Widget build(BuildContext context) {
    return GlassSkeletonCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GlassSkeleton(width: 140, height: 16),
          const SizedBox(height: 6),
          const GlassSkeleton(width: 200, height: 12),
          const SizedBox(height: 20),
          GlassSkeleton(height: height - 80, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Skeleton for the full dashboard page (metrics + quick actions + activity).
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          const GlassSkeleton(width: 220, height: 28, borderRadius: 8),
          const SizedBox(height: 6),
          const GlassSkeleton(width: 160, height: 14),
          const SizedBox(height: 28),
          // Metric cards
          const MetricGridSkeleton(),
          const SizedBox(height: 28),
          // Quick actions
          const GlassSkeleton(width: 130, height: 18),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(child: GlassSkeleton(height: 56, borderRadius: 14)),
              SizedBox(width: 14),
              Expanded(child: GlassSkeleton(height: 56, borderRadius: 14)),
              SizedBox(width: 14),
              Expanded(child: GlassSkeleton(height: 56, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: 28),
          // Recent activity
          const GlassSkeleton(width: 150, height: 18),
          const SizedBox(height: 14),
          for (int i = 0; i < 4; i++) ...[
            const GlassSkeleton(height: 44, borderRadius: 12),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Skeleton for the batch review / analytics screens.
class BatchReviewSkeleton extends StatelessWidget {
  const BatchReviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter bar
          Row(
            children: const [
              GlassSkeleton(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 10),
              GlassSkeleton(width: 80, height: 32, borderRadius: 16),
              SizedBox(width: 10),
              GlassSkeleton(width: 80, height: 32, borderRadius: 16),
              Spacer(),
              GlassSkeleton(width: 120, height: 32, borderRadius: 8),
            ],
          ),
          const SizedBox(height: 20),
          // List items
          const ListViewSkeleton(itemCount: 5),
        ],
      ),
    );
  }
}
