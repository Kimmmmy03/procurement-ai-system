import 'dart:ui';
import 'package:flutter/material.dart';
import 'approver_dashboard_screen.dart';
import 'batch_review_screen.dart';
import 'executive_analytics_screen.dart';
import 'approval_history_screen.dart';
import 'supplier_role_mapping_screen.dart';
import '../role_selection_screen.dart';

class ApproverMainNavigator extends StatefulWidget {
  const ApproverMainNavigator({super.key});

  @override
  State<ApproverMainNavigator> createState() => _ApproverMainNavigatorState();
}

class _ApproverMainNavigatorState extends State<ApproverMainNavigator> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
    ApproverDashboardScreen(onNavigate: (i) => setState(() => _selectedIndex = i)),
    const BatchReviewScreen(),
    const ExecutiveAnalyticsScreen(),
    const ApprovalHistoryScreen(),
    const SupplierRoleMappingScreen(),
  ];

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
      tooltip: 'Pending batches & alerts',
    ),
    _NavItem(
      icon: Icons.rate_review_outlined,
      selectedIcon: Icons.rate_review,
      label: 'Batch Review',
      tooltip: 'Approve/reject requests',
    ),
    _NavItem(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Analytics',
      tooltip: 'Budget & KPIs',
    ),
    _NavItem(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'Approval History',
      tooltip: 'Decision audit trail',
    ),
    _NavItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: 'Role Mapping',
      tooltip: 'Manage assignments',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

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
          Row(
            children: [
              // Desktop Sidebar
              if (isDesktop)
                _GlassNavigationRail(
                  selectedIndex: _selectedIndex,
                  items: _navItems,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  extended: MediaQuery.of(context).size.width >= 1024,
                ),

              // Screen Content with fade transition
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_selectedIndex),
                    child: _screens[_selectedIndex],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // Mobile Bottom Navigation
      bottomNavigationBar: !isDesktop
          ? _GlassBottomNavigationBar(
              selectedIndex: _selectedIndex,
              items: _navItems,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
            )
          : null,
    );
  }
}

// Navigation Item Model
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltip;

  _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltip,
  });
}

// Glass Navigation Rail for Desktop
class _GlassNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  const _GlassNavigationRail({
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 240 : 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: extended
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.verified_user,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        if (extended) ...[
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Procurement AI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Executive View',
                                  style: TextStyle(
                                    color: Color(0xFFFFB74D),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(color: Colors.white.withOpacity(0.1)),
                  ],
                ),
              ),

              // Navigation Items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = selectedIndex == index;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Tooltip(
                        message: item.tooltip,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onDestinationSelected(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.6),
                                    size: 24,
                                  ),
                                  if (extended) ...[
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.6),
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // User Info + Logout
              if (extended)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                        (route) => false,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              'SL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sarah Lee',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'General Manager',
                                  style: TextStyle(
                                    color: Color(0xFFFFB74D),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.logout, color: Colors.white.withOpacity(0.5), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Glass Bottom Navigation Bar for Mobile
class _GlassBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onDestinationSelected;

  const _GlassBottomNavigationBar({
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor: Colors.transparent,
            indicatorColor: Colors.white.withOpacity(0.2),
            destinations: items
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                    tooltip: item.tooltip,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
