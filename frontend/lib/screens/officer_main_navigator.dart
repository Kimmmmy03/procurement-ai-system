// lib/screens/officer_main_navigator.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'upload_screen.dart';
import 'forecast_screen.dart';
import 'purchase_requests/purchase_requests_screen.dart';
import 'approval_screen.dart';
import 'purchase_orders_screen.dart';
import 'custom_seasonality_screen.dart';
import 'warehouse_stock_screen.dart';
import 'suppliers_screen.dart';
import 'role_selection_screen.dart';

class OfficerMainNavigator extends StatefulWidget {
  const OfficerMainNavigator({super.key});

  @override
  State<OfficerMainNavigator> createState() => _OfficerMainNavigatorState();
}

class _OfficerMainNavigatorState extends State<OfficerMainNavigator> {
  int _selectedIndex = 0;

  // WORKFLOW ORDER: Dashboard → Upload → Forecast → Manage PRs → Approval Status → Purchase Orders
  List<Widget> get _screens => [
    DashboardScreen(onNavigate: (i) => setState(() => _selectedIndex = i)),
    const UploadScreen(),
    ForecastScreen(onNavigate: (i) => setState(() => _selectedIndex = i)),
    PurchaseRequestsScreen(onNavigate: (i) => setState(() => _selectedIndex = i)),
    const ApprovalScreen(),
    const PurchaseOrdersScreen(),
    const WarehouseStockScreen(),
    const SuppliersScreen(),
    const CustomSeasonalityScreen(),
  ];

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Dashboard',
      tooltip: 'Identify critical items',
    ),
    _NavItem(
      icon: Icons.upload_file_outlined,
      selectedIcon: Icons.upload_file,
      label: 'Data Import',
      tooltip: 'Import POs, inventory & supplier data',
    ),
    _NavItem(
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      label: 'Run Forecast',
      tooltip: 'Generate AI predictions',
    ),
    _NavItem(
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note,
      label: 'Manage PRs',
      tooltip: 'Review & submit batches',
    ),
    _NavItem(
      icon: Icons.pending_actions_outlined,
      selectedIcon: Icons.pending_actions,
      label: 'Approval Status',
      tooltip: 'Track GM/MD approvals',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'Purchase Orders',
      tooltip: 'Generate & send POs',
    ),
    _NavItem(
      icon: Icons.warehouse_outlined,
      selectedIcon: Icons.warehouse,
      label: 'Warehouse Stock',
      tooltip: 'View stock by warehouse channel',
    ),
    _NavItem(
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      label: 'Suppliers',
      tooltip: 'View all registered suppliers',
    ),
    _NavItem(
      icon: Icons.event_repeat_outlined,
      selectedIcon: Icons.event_repeat,
      label: 'Seasonality',
      tooltip: 'Manage seasonal demand patterns',
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
                            color: const Color(0xFF1E88E5).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF64B5F6),
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
                                  'Officer Portal',
                                  style: TextStyle(
                                    color: Color(0xFF64B5F6),
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
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
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
                          CircleAvatar(
                            backgroundColor: const Color(0xFF1E88E5),
                            child: const Text(
                              'JL',
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
                                  'John Lance',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Procurement Officer',
                                  style: TextStyle(
                                    color: Color(0xFF64B5F6),
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
