// screens/approver/supplier_role_mapping_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/glass_filter_chip.dart';
import '../../widgets/skeleton_layouts.dart';

class SupplierRoleMappingScreen extends StatefulWidget {
  const SupplierRoleMappingScreen({super.key});

  @override
  State<SupplierRoleMappingScreen> createState() =>
      _SupplierRoleMappingScreenState();
}

class _SupplierRoleMappingScreenState extends State<SupplierRoleMappingScreen> {
  Map<String, dynamic>? _mappingData;
  bool _isLoading = true;
  String? _selectedOfficerId;
  String _filterRole = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadMappingData();
  }

  Future<void> _loadMappingData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final data = await apiService.getRoleMappingData();
      setState(() {
        _mappingData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        GlassNotification.show(context, 'Failed to load data', isError: true);
      }
    }
  }

  List<Map<String, dynamic>> get _officers {
    final all = (_mappingData?['officers'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    if (_filterRole == 'ALL') return all;
    return all.where((o) => o['role'] == _filterRole).toList();
  }

  Set<String> get _allRoles {
    final all = (_mappingData?['officers'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    return {'ALL', ...all.map((o) => o['role']?.toString() ?? '')};
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'RM 0.00';
    final num v = value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatted = v.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'RM $formatted';
  }

  bool _isSupervisorRole(String? role) {
    return role == 'General Manager' || role == 'Managing Director';
  }

  /// Get all officers list (unfiltered) from mapping data
  List<Map<String, dynamic>> get _allOfficers {
    return (_mappingData?['officers'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
  }

  /// Find officer by id from all officers
  Map<String, dynamic>? _findOfficerById(String? id) {
    if (id == null) return null;
    return _allOfficers.where((o) => o['id'].toString() == id).firstOrNull;
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'Managing Director':
        return const Color(0xFFAB47BC);
      case 'General Manager':
        return const Color(0xFF42A5F5);
      case 'Senior Procurement Officer':
        return const Color(0xFF66BB6A);
      case 'Procurement Executive':
        return const Color(0xFFFFB74D);
      default:
        return const Color(0xFF78909C);
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role) {
      case 'Managing Director':
        return Icons.verified_user;
      case 'General Manager':
        return Icons.admin_panel_settings;
      case 'Senior Procurement Officer':
        return Icons.engineering;
      case 'Procurement Executive':
        return Icons.person;
      default:
        return Icons.badge;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
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

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: DashboardSkeleton(),
            )
          else if (_mappingData == null)
            _buildErrorState()
          else
            _buildMainContent(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64,
              color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Failed to load team data',
              style: TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadMappingData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final selectedOfficer = _selectedOfficerId != null
        ? (_mappingData!['officers'] as List?)
            ?.cast<Map<String, dynamic>>()
            .where((o) => o['id'].toString() == _selectedOfficerId)
            .firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.all(24.0),
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
                  Text('Team & Role Management',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: 8),
                  Text('Manage officer assignments, suppliers & approval limits',
                      style:
                          TextStyle(fontSize: 15, color: Color(0xFF64B5F6))),
                ],
              ),
              IconButton(
                onPressed: _loadMappingData,
                icon: const Icon(Icons.refresh, color: Color(0xFF64B5F6)),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Role filter chips
          _GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.filter_list,
                    size: 18, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allRoles.map((role) {
                      return GlassFilterChip(
                        label: role == 'ALL' ? 'All Roles' : role,
                        selected: _filterRole == role,
                        onSelected: (_) =>
                            setState(() => _filterRole = role),
                        activeColor: role == 'ALL'
                            ? const Color(0xFF64B5F6)
                            : _getRoleColor(role),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main split view
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Officer list
                SizedBox(
                  width: 380,
                  child: _buildOfficerList(),
                ),
                const SizedBox(width: 24),

                // Right: Detail panel
                Expanded(
                  child: selectedOfficer != null
                      ? _buildDetailPanel(selectedOfficer)
                      : _buildEmptyDetail(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerList() {
    final officers = _officers;

    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, size: 20, color: Color(0xFF64B5F6)),
              const SizedBox(width: 10),
              Text('Team Members (${officers.length})',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: officers.length,
              itemBuilder: (context, index) {
                final officer = officers[index];
                return _buildOfficerListTile(officer);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerListTile(Map<String, dynamic> officer) {
    final isSelected = _selectedOfficerId == officer['id'].toString();
    final roleColor = _getRoleColor(officer['role']);
    final categories = officer['categories'] as List? ?? [];
    final isAllAccess =
        categories.length == 1 && categories[0].toString() == 'ALL';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedOfficerId =
                  isSelected ? null : officer['id'].toString();
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        roleColor.withOpacity(0.25),
                        roleColor.withOpacity(0.10),
                      ],
                    )
                  : null,
              color: isSelected ? null : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? roleColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.08),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: roleColor.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 0)
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        roleColor.withOpacity(0.4),
                        roleColor.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: roleColor.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      (officer['name'] ?? 'U')
                          .toString()
                          .substring(0, 1)
                          .toUpperCase(),
                      style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        officer['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(_getRoleIcon(officer['role']),
                              size: 12, color: roleColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              officer['role'] ?? 'N/A',
                              style: TextStyle(
                                  color: roleColor.withOpacity(0.9),
                                  fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Supplier count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAllAccess
                        ? const Color(0xFF66BB6A).withOpacity(0.2)
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAllAccess ? 'ALL' : '${categories.length}',
                    style: TextStyle(
                      color: isAllAccess
                          ? const Color(0xFF66BB6A)
                          : Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Arrow
                const SizedBox(width: 6),
                Icon(
                  isSelected
                      ? Icons.chevron_right
                      : Icons.chevron_right,
                  size: 18,
                  color: isSelected
                      ? roleColor
                      : Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDetail() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _GlassContainer(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search,
                      size: 72, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 20),
                  Text('Select a team member',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 18,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(
                      'Click on an officer to view details and manage assignments',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(Map<String, dynamic> officer) {
    final roleColor = _getRoleColor(officer['role']);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile header card (same for all roles)
          _buildProfileHeader(officer, roleColor),
          const SizedBox(height: 16),

          // Role-specific content
          if (_isSupervisorRole(officer['role']))
            _buildSupervisorDetail(officer, roleColor)
          else
            _buildOfficerDetail(officer, roleColor),

        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> officer, Color roleColor) {
    return _GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Row(
            children: [
              // Large avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      roleColor.withOpacity(0.5),
                      roleColor.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: roleColor.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                        color: roleColor.withOpacity(0.2),
                        blurRadius: 16,
                        spreadRadius: 0),
                  ],
                ),
                child: Center(
                  child: Text(
                    (officer['name'] ?? 'U')
                        .toString()
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(officer['name'] ?? 'Unknown',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: roleColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getRoleIcon(officer['role']),
                              size: 14, color: roleColor),
                          const SizedBox(width: 6),
                          Text(officer['role'] ?? 'N/A',
                              style: TextStyle(
                                  color: roleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Info row
          Row(
            children: [
              _buildInfoTile(
                Icons.email_outlined,
                'Email',
                officer['email'] ?? 'N/A',
                const Color(0xFF64B5F6),
              ),
              const SizedBox(width: 16),
              _buildInfoTile(
                Icons.badge_outlined,
                'Staff ID',
                'EMP-${officer['id']?.toString().padLeft(3, '0') ?? '000'}',
                const Color(0xFFFFB74D),
              ),
              const SizedBox(width: 16),
              _buildInfoTile(
                Icons.business,
                'Department',
                'Procurement',
                const Color(0xFF66BB6A),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Detail panel for GM / MD — shows subordinates, no approval limit or suppliers
  Widget _buildSupervisorDetail(Map<String, dynamic> officer, Color roleColor) {
    final subordinateIds = (officer['subordinates'] as List?)?.cast<String>() ?? [];
    final subordinates = subordinateIds
        .map((id) => _findOfficerById(id))
        .where((o) => o != null)
        .cast<Map<String, dynamic>>()
        .toList();

    return _GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.groups, color: roleColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Officers Under Management (${subordinates.length})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          if (subordinates.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Text('No officers assigned yet',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 13),
                  textAlign: TextAlign.center),
            )
          else
            ...subordinates.map((sub) {
              final subRoleColor = _getRoleColor(sub['role']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: subRoleColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: subRoleColor.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              subRoleColor.withOpacity(0.4),
                              subRoleColor.withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            (sub['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: subRoleColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub['name'] ?? 'Unknown',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(sub['role'] ?? '',
                                style: TextStyle(
                                    color: subRoleColor.withOpacity(0.9),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(_formatCurrency(sub['approval_limit']),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      _buildReassignButton(sub, officer),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReassignButton(Map<String, dynamic> subordinate, Map<String, dynamic> currentSupervisor) {
    return IconButton(
      icon: const Icon(Icons.swap_horiz, size: 18),
      color: const Color(0xFF64B5F6),
      tooltip: 'Reassign to different supervisor',
      onPressed: () => _showReassignDialog(subordinate, currentSupervisor),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }

  Future<void> _showReassignDialog(Map<String, dynamic> subordinate, Map<String, dynamic> currentSupervisor) async {
    final supervisors = _allOfficers
        .where((o) => _isSupervisorRole(o['role']) && o['id'] != currentSupervisor['id'])
        .toList();

    if (supervisors.isEmpty) {
      if (mounted) {
        GlassNotification.show(context, 'No other supervisors available', icon: Icons.warning_amber_rounded);
      }
      return;
    }

    String? selectedSupervisorId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => GlassAlertDialog(
          width: 400,
          title: const Text('Reassign Officer',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Move ${subordinate['name']} to a different supervisor.',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1A2332),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Supervisor',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                ),
                items: supervisors
                    .map((s) => DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text('${s['name']} (${s['role']})')))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedSupervisorId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.6))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedSupervisorId != null) {
                  Navigator.pop(ctx);
                  await _reassignOfficer(
                      subordinate['id'].toString(), selectedSupervisorId!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64B5F6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reassign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reassignOfficer(String officerId, String newSupervisorId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.assignOfficerToSupervisor(officerId, newSupervisorId);
      _loadMappingData();
      if (mounted) {
        GlassNotification.show(context, 'Officer reassigned successfully');
      }
    } catch (e) {
      if (mounted) {
        GlassNotification.show(context, 'Error: $e', isError: true);
      }
    }
  }

  /// Detail panel for officers — shows "Reports To", approval limit, suppliers
  Widget _buildOfficerDetail(Map<String, dynamic> officer, Color roleColor) {
    final categories = officer['categories'] as List? ?? [];
    final isAllAccess =
        categories.length == 1 && categories[0].toString() == 'ALL';
    final approvalLimit = officer['approval_limit'] ?? 0;
    final supervisor = _findOfficerById(officer['reports_to']?.toString());

    return Column(
      children: [
        // Reports To card
        _GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFAB47BC).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.supervisor_account,
                        color: Color(0xFFAB47BC), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Reports To',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showChangeSupervisorDialog(officer),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Change'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64B5F6)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFAB47BC).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFAB47BC).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    if (supervisor != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getRoleColor(supervisor['role']).withOpacity(0.4),
                              _getRoleColor(supervisor['role']).withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            (supervisor['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: _getRoleColor(supervisor['role']),
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(supervisor['name'] ?? '',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text(supervisor['role'] ?? '',
                                style: TextStyle(
                                    color: _getRoleColor(supervisor['role']),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text('Not assigned',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Approval limit card
        _GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                    child: const Icon(Icons.account_balance_wallet,
                        color: Color(0xFFFFB74D), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Maximum Approval Value',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        _showEditApprovalLimitDialog(officer),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64B5F6)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFB74D).withOpacity(0.12),
                      const Color(0xFFFF9800).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFFB74D).withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatCurrency(approvalLimit),
                      style: const TextStyle(
                        color: Color(0xFFFFB74D),
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'per purchase request',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Assigned suppliers/categories card
        _GlassContainer(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF66BB6A).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_shipping,
                        color: Color(0xFF66BB6A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Assigned Suppliers / Categories',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Spacer(),
                  if (!isAllAccess)
                    TextButton.icon(
                      onPressed: () =>
                          _showAddCategoryDialog(officer),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF66BB6A)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (isAllAccess)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF66BB6A).withOpacity(0.12),
                        const Color(0xFF4CAF50).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF66BB6A).withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified,
                          color: Color(0xFF66BB6A), size: 20),
                      SizedBox(width: 12),
                      Text('Full Access — All Suppliers',
                          style: TextStyle(
                              color: Color(0xFF66BB6A),
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                )
              else if (categories.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Text('No suppliers assigned yet',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13),
                      textAlign: TextAlign.center),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) {
                    return _buildSupplierChip(
                        cat.toString(), officer['id'].toString());
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showChangeSupervisorDialog(Map<String, dynamic> officer) async {
    final supervisors = _allOfficers
        .where((o) => _isSupervisorRole(o['role']))
        .toList();
    String? selectedId = officer['reports_to']?.toString();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => GlassAlertDialog(
          width: 400,
          title: const Text('Change Supervisor',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select a supervisor for ${officer['name']}.',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: supervisors.any((s) => s['id'].toString() == selectedId) ? selectedId : null,
                dropdownColor: const Color(0xFF1A2332),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Supervisor',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                ),
                items: supervisors
                    .map((s) => DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text('${s['name']} (${s['role']})')))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: TextStyle(color: Colors.white.withOpacity(0.6))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedId != null) {
                  Navigator.pop(ctx);
                  await _reassignOfficer(
                      officer['id'].toString(), selectedId!);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64B5F6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierChip(String name, String officerId) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.business, size: 14, color: Color(0xFF64B5F6)),
              const SizedBox(width: 8),
              Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _removeCategory(officerId, name),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF5350).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.close,
                      size: 14, color: Color(0xFFEF5350)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // === Dialogs ===

  Future<void> _showEditApprovalLimitDialog(
      Map<String, dynamic> officer) async {
    final controller = TextEditingController(
      text: (officer['approval_limit'] ?? 0).toString(),
    );

    await showDialog(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: const Text('Set Maximum Approval Value',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set the maximum value that ${officer['name']} can approve per purchase request.',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'RM  ',
                prefixStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFFFB74D)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 0) {
                Navigator.pop(ctx);
                await _updateApprovalLimit(
                    officer['id'].toString(), val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB74D),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateApprovalLimit(
      String officerId, double newLimit) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateRoleAssignment(
        officerId: officerId,
        approvalLimit: newLimit,
      );
      _loadMappingData();
      if (mounted) {
        GlassNotification.show(context, 'Approval limit updated to ${_formatCurrency(newLimit)}');
      }
    } catch (e) {
      if (mounted) {
        GlassNotification.show(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _showAddCategoryDialog(Map<String, dynamic> officer) async {
    final availableCategories = [
      'TechCorp Industries',
      'ChemSupply Co',
      'HydroMax Ltd',
      'SafetyFirst Inc',
      'MotorTech Systems',
      'Electronics',
      'Furniture',
      'Supplies',
      'Equipment',
      'Services',
      'Machinery',
      'Raw Materials',
    ];
    final currentCats = (officer['categories'] as List? ?? [])
        .map((e) => e.toString())
        .toSet();
    final remaining = availableCategories
        .where((c) => !currentCats.contains(c))
        .toList();

    String? selected;

    await showDialog(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: const Text('Add Supplier / Category',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assign to ${officer['name']}',
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
            const SizedBox(height: 16),
            if (remaining.isEmpty)
              Text('All categories already assigned',
                  style: TextStyle(color: Colors.white.withOpacity(0.4)))
            else
              DropdownButtonFormField<String>(
                dropdownColor: const Color(0xFF1A2332),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Select Supplier / Category',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.15)),
                  ),
                ),
                items: remaining
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => selected = v,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: remaining.isEmpty
                ? null
                : () async {
                    if (selected != null) {
                      Navigator.pop(ctx);
                      try {
                        final apiService =
                            Provider.of<ApiService>(context, listen: false);
                        await apiService.updateRoleAssignment(
                          officerId: officer['id'].toString(),
                          category: selected!,
                          action: 'add',
                        );
                        _loadMappingData();
                        if (mounted) {
                          GlassNotification.show(context, '$selected assigned');
                        }
                      } catch (e) {
                        if (mounted) {
                          GlassNotification.show(context, 'Error: $e', isError: true);
                        }
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeCategory(String officerId, String category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title:
            const Text('Remove Supplier?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "$category" from this officer\'s assignments?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.updateRoleAssignment(
        officerId: officerId,
        category: category,
        action: 'remove',
      );
      _loadMappingData();
      if (mounted) {
        GlassNotification.show(context, '$category removed', icon: Icons.warning_amber_rounded);
      }
    } catch (e) {
      if (mounted) {
        GlassNotification.show(context, 'Error: $e', isError: true);
      }
    }
  }

}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassContainer(
      {required this.child, this.padding = EdgeInsets.zero});

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
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
