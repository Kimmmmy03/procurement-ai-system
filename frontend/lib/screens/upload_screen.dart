// screens/upload_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/glass_dialog.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Purchase Order state
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  Map<String, dynamic>? _uploadResult;
  String? _errorMessage;

  // Xeersoft Inventory state
  PlatformFile? _xeersoftFile;
  bool _isXeersoftUploading = false;
  Map<String, dynamic>? _xeersoftResult;
  String? _xeersoftError;

  // Xeersoft table expand/collapse
  bool _xeersoftItemsExpanded = false;

  // Supplier table expand/collapse
  bool _supplierItemsExpanded = false;

  // Supplier & Item Master state
  PlatformFile? _supplierFile;
  bool _isSupplierUploading = false;
  Map<String, dynamic>? _supplierResult;
  String? _supplierError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile({String target = 'po'}) async {
    try {
      final extensions = target == 'po'
          ? ['pdf']
          : ['xlsx', 'xls', 'csv'];
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: true,
      );

      if (result != null) {
        setState(() {
          if (target == 'xeersoft') {
            _xeersoftFile = result.files.single;
            _xeersoftResult = null;
            _xeersoftError = null;
            _xeersoftItemsExpanded = false;
          } else if (target == 'supplier') {
            _supplierFile = result.files.single;
            _supplierResult = null;
            _supplierError = null;
            _supplierItemsExpanded = false;
          } else {
            _selectedFile = result.files.single;
            _uploadResult = null;
            _errorMessage = null;
          }
        });
      }
    } catch (e) {
      setState(() {
        if (target == 'xeersoft') {
          _xeersoftError = 'Error picking file: $e';
        } else if (target == 'supplier') {
          _supplierError = 'Error picking file: $e';
        } else {
          _errorMessage = 'Error picking file: $e';
        }
      });
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.uploadPurchaseOrder(_selectedFile!);

      setState(() {
        _uploadResult = result;
        _isUploading = false;
      });

      if (mounted) {
        GlassNotification.show(
          context,
          'Uploaded successfully! ${result['items_detected']} items detected.',
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = e.toString();
      });

      if (mounted) {
        GlassNotification.show(
          context,
          'Upload failed: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _uploadXeersoft() async {
    if (_xeersoftFile == null) return;

    setState(() {
      _isXeersoftUploading = true;
      _xeersoftError = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.uploadXeersoftInventory(_xeersoftFile!);

      setState(() {
        _xeersoftResult = result;
        _isXeersoftUploading = false;
      });

      if (mounted) {
        final itemsUpserted =
            result['items_upserted'] ?? result['items_processed'] ?? 0;
        final salesIngested = result['sales_months_ingested'] ?? 0;
        GlassNotification.show(
          context,
          'Xeersoft data imported! $itemsUpserted items, $salesIngested sales records.',
        );
      }
    } catch (e) {
      setState(() {
        _isXeersoftUploading = false;
        _xeersoftError = e.toString();
      });
      if (mounted) {
        GlassNotification.show(context, 'Xeersoft upload failed: $e', isError: true);
      }
    }
  }

  Future<void> _uploadSupplier() async {
    if (_supplierFile == null) return;

    setState(() {
      _isSupplierUploading = true;
      _supplierError = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.uploadSupplierMaster(_supplierFile!);

      setState(() {
        _supplierResult = result;
        _isSupplierUploading = false;
      });

      if (mounted) {
        final added = result['suppliers_added'] ?? 0;
        final updated = result['suppliers_updated'] ?? 0;
        GlassNotification.show(
          context,
          'Supplier & Item Master imported! $added added, $updated updated.',
        );
      }
    } catch (e) {
      setState(() {
        _isSupplierUploading = false;
        _supplierError = e.toString();
      });
      if (mounted) {
        GlassNotification.show(context, 'Supplier upload failed: $e', isError: true);
      }
    }
  }

  Future<void> _downloadTemplate(String templateKey) async {
    final url = '${ApiService.baseUrl}/upload/template/$templateKey';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        GlassNotification.show(context, 'Could not open template URL', isError: true);
      }
    }
  }

  // ── Tab colours ──

  static const _tabColors = [
    Color(0xFF42A5F5), // Purchase Order — blue
    Color(0xFF26C6DA), // Xeersoft Inventory — teal
    Color(0xFFAB47BC), // Supplier & Item Master — purple
  ];

  Color get _activeTabColor => _tabColors[_tabController.index];

  // ── Helpers ──

  String _fileExtIcon(PlatformFile file) {
    final ext = file.extension?.toLowerCase() ?? '';
    if (ext == 'pdf') return 'PDF';
    if (ext == 'csv') return 'CSV';
    if (ext == 'xls') return 'XLS';
    return 'XLSX';
  }

  Color _fileExtColor(PlatformFile file) {
    final ext = file.extension?.toLowerCase() ?? '';
    if (ext == 'pdf') return const Color(0xFFEF5350);
    if (ext == 'csv') return const Color(0xFF66BB6A);
    if (ext == 'xls') return const Color(0xFFFFB74D);
    return const Color(0xFF42A5F5);
  }

  // ════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════

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
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),

          // Main content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Data Import Centre',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Upload purchase orders, inventory data, or supplier & item master for AI-powered procurement',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        colors: [
                          _activeTabColor,
                          _activeTabColor.withValues(alpha: 0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _activeTabColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor:
                        Colors.white.withValues(alpha: 0.45),
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w400, fontSize: 13),
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(10),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.description_outlined, size: 18),
                        text: 'Purchase Order',
                      ),
                      Tab(
                        icon: Icon(Icons.inventory_2_outlined, size: 18),
                        text: 'Xeersoft Inventory',
                      ),
                      Tab(
                        icon: Icon(Icons.store_outlined, size: 18),
                        text: 'Supplier & Item Master',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPurchaseOrderTab(),
                      _buildXeersoftTab(),
                      _buildSupplierMasterTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // PURCHASE ORDER TAB
  // ════════════════════════════════════════

  Widget _buildPurchaseOrderTab() {
    final card = _buildUploadCard(
      icon: Icons.description_outlined,
      iconColor: const Color(0xFF42A5F5),
      title: 'Upload Purchase Order',
      subtitle:
          'Import customer purchase orders for AI demand analysis and procurement planning',
      acceptedFormats: 'PDF',
      description: const [
        'Upload customer PO files in PDF format containing SKU, product names, quantities, and pricing',
        'The AI engine will match items against your inventory and flag discrepancies',
        'Detected items feed directly into the forecasting and procurement pipeline',
      ],
      file: _selectedFile,
      isUploading: _isUploading,
      onPick: () => _pickFile(target: 'po'),
      onUpload: _uploadFile,
      onClear: () {
        setState(() {
          _selectedFile = null;
          _uploadResult = null;
          _errorMessage = null;
        });
      },
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          card,
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            _buildErrorPanel(_errorMessage!),
          ],
          if (_uploadResult != null) ...[
            const SizedBox(height: 20),
            _buildPOSummary(_uploadResult!),
            if ((_uploadResult!['preview'] as List? ?? []).isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildPOPreviewTable(_uploadResult!),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPOSummary(Map<String, dynamic> result) {
    return _GlassContainer(
      padding: const EdgeInsets.all(24),
      borderColor: const Color(0xFF66BB6A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: Color(0xFF66BB6A), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Import Successful',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result['filename']?.toString() ?? '',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildMetricCard(
                      'Items Detected',
                      result['items_detected']?.toString() ?? '0',
                      Icons.inventory_2_outlined,
                      const Color(0xFF42A5F5))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildMetricCard(
                      'Matched',
                      result['matched_items']?.toString() ?? '0',
                      Icons.link,
                      const Color(0xFF66BB6A))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildMetricCard(
                      'Unmatched',
                      result['unmatched_items']?.toString() ?? '0',
                      Icons.link_off,
                      const Color(0xFFFFB74D))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPOPreviewTable(Map<String, dynamic> result) {
    final preview = result['preview'] as List? ?? [];
    if (preview.isEmpty) return const SizedBox.shrink();

    // Dynamically detect columns from the first row
    final firstRow = preview.first as Map<String, dynamic>;
    final columns = firstRow.keys.take(6).toList();

    return _GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Data Preview',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${preview.length} rows',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      Colors.white.withValues(alpha: 0.04)),
                  dataRowColor: WidgetStateProperty.all(Colors.transparent),
                  headingTextStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  dataTextStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                  columnSpacing: 32,
                  horizontalMargin: 16,
                  headingRowHeight: 40,
                  dataRowMinHeight: 36,
                  dataRowMaxHeight: 44,
                  columns: columns
                      .map((col) => DataColumn(
                          label: Text(col
                              .toString()
                              .replaceAll('_', ' ')
                              .split(' ')
                              .map((w) => w.isNotEmpty
                                  ? '${w[0].toUpperCase()}${w.substring(1)}'
                                  : '')
                              .join(' '))))
                      .toList(),
                  rows: preview.map((item) {
                    final row = item as Map<String, dynamic>;
                    return DataRow(
                      cells: columns
                          .map((col) =>
                              DataCell(Text(row[col]?.toString() ?? '')))
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // XEERSOFT INVENTORY TAB
  // ════════════════════════════════════════

  Widget _buildXeersoftTab() {
    final card = _buildUploadCard(
      icon: Icons.inventory_2_outlined,
      iconColor: const Color(0xFF26C6DA),
      title: 'Upload Xeersoft Inventory Export',
      subtitle:
          'Multi-channel stock levels, 24-month sales history, and product master data',
      acceptedFormats: 'XLSX, XLS, CSV',
      description: const [
        'Import Xeersoft ERP export with multi-channel stock (warehouse, TikTok, Shopee, Lazada)',
        '24-month sales history is extracted for seasonality detection and trend analysis',
        'Inline annotations like "[special promo]" are automatically captured and flagged',
        'Data updates existing items or creates new records — safe to re-upload anytime',
      ],
      file: _xeersoftFile,
      isUploading: _isXeersoftUploading,
      onPick: () => _pickFile(target: 'xeersoft'),
      onUpload: _uploadXeersoft,
      templateKey: 'xeersoft',
      uploadDone: _xeersoftResult != null,
      onUploadAnother: () {
        setState(() {
          _xeersoftFile = null;
          _xeersoftResult = null;
          _xeersoftError = null;
          _xeersoftItemsExpanded = false;
        });
      },
      onClear: () {
        setState(() {
          _xeersoftFile = null;
          _xeersoftResult = null;
          _xeersoftError = null;
          _xeersoftItemsExpanded = false;
        });
      },
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          card,
          if (_xeersoftError != null) ...[
            const SizedBox(height: 20),
            _buildErrorPanel(_xeersoftError!),
          ],
          if (_xeersoftResult != null) ...[
            const SizedBox(height: 20),
            _buildXeersoftSummary(_xeersoftResult!),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // SUPPLIER & ITEM MASTER TAB
  // ════════════════════════════════════════

  Widget _buildSupplierMasterTab() {
    final card = _buildUploadCard(
      icon: Icons.store_outlined,
      iconColor: const Color(0xFFAB47BC),
      title: 'Upload Supplier & Item Master',
      subtitle:
          'Supplier details, item specs, pricing, lead times, and packaging info',
      acceptedFormats: 'XLSX, XLS, CSV',
      description: const [
        'Import supplier & item master — vendor details, MOQ, unit price, failure rates',
        'Packaging info (Units/Ctn, CBM, Weight) and lead times enrich inventory items',
        'Existing records are updated automatically; new suppliers and items are added',
        'Column headers are auto-detected — supports various naming conventions',
      ],
      file: _supplierFile,
      isUploading: _isSupplierUploading,
      onPick: () => _pickFile(target: 'supplier'),
      onUpload: _uploadSupplier,
      templateKey: 'supplier',
      uploadDone: _supplierResult != null,
      onUploadAnother: () {
        setState(() {
          _supplierFile = null;
          _supplierResult = null;
          _supplierError = null;
          _supplierItemsExpanded = false;
        });
      },
      onClear: () {
        setState(() {
          _supplierFile = null;
          _supplierResult = null;
          _supplierError = null;
          _supplierItemsExpanded = false;
        });
      },
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          card,
          if (_supplierError != null) ...[
            const SizedBox(height: 20),
            _buildErrorPanel(_supplierError!),
          ],
          if (_supplierResult != null) ...[
            const SizedBox(height: 20),
            _buildSupplierSummary(_supplierResult!),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // SHARED UPLOAD CARD
  // ════════════════════════════════════════

  Widget _buildUploadCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String acceptedFormats,
    required List<String> description,
    required PlatformFile? file,
    required bool isUploading,
    required VoidCallback onPick,
    required VoidCallback onUpload,
    required VoidCallback onClear,
    String? templateKey,
    bool uploadDone = false,
    VoidCallback? onUploadAnother,
  }) {
    return _GlassContainer(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Description box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What this does',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: iconColor.withValues(alpha: 0.8))),
                const SizedBox(height: 10),
                ...description.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Icon(Icons.circle,
                                size: 5,
                                color: iconColor.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(line,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white
                                        .withValues(alpha: 0.6),
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Drop Zone (full width below)
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: file != null ? 100 : 180,
              decoration: BoxDecoration(
                color: file != null
                    ? iconColor.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: file != null
                      ? iconColor.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.2),
                  width: file != null ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: file == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('Click to browse files',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.8))),
                        const SizedBox(height: 4),
                        Text('or drag & drop here',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white
                                    .withValues(alpha: 0.4))),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(acceptedFormats,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white
                                      .withValues(alpha: 0.5),
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const SizedBox(width: 20),
                        Container(
                          width: 52,
                          height: 62,
                          decoration: BoxDecoration(
                            color: _fileExtColor(file)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _fileExtColor(file)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.insert_drive_file,
                                  color: _fileExtColor(file), size: 22),
                              const SizedBox(height: 2),
                              Text(_fileExtIcon(file),
                                  style: TextStyle(
                                      color: _fileExtColor(file),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(file.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(_formatFileSize(file.size),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white
                                          .withValues(alpha: 0.5))),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onPick,
                          icon: Icon(Icons.swap_horiz,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 20),
                          tooltip: 'Change file',
                        ),
                        IconButton(
                          onPressed: onClear,
                          icon: Icon(Icons.close,
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 18),
                          tooltip: 'Remove',
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 18),

          // Action row
          Row(
            children: [
              // Download Template button (Xeersoft & Supplier tabs)
              if (templateKey != null)
                _buildOutlineButton(
                  label: 'Download Template',
                  icon: Icons.download_outlined,
                  color: iconColor,
                  onTap: () => _downloadTemplate(templateKey),
                ),
              if (templateKey != null) const SizedBox(width: 10),
              if (file != null && !isUploading && !uploadDone)
                Text(
                  'Ready to import',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4)),
                ),
              const Spacer(),
              // Upload Another File button — shown after successful import
              if (uploadDone && onUploadAnother != null) ...[
                _buildOutlineButton(
                  label: 'Upload Another File',
                  icon: Icons.add_circle_outline,
                  color: iconColor,
                  onTap: onUploadAnother,
                ),
                const SizedBox(width: 10),
              ],
              _buildUploadButton(
                isEnabled: file != null && !isUploading,
                isUploading: isUploading,
                onTap: onUpload,
                color: iconColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildUploadButton({
    required bool isEnabled,
    required bool isUploading,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: isEnabled
            ? LinearGradient(colors: [
                color,
                color.withValues(alpha: 0.8),
              ])
            : null,
        color: !isEnabled ? Colors.white.withValues(alpha: 0.06) : null,
        boxShadow: isEnabled
            ? [
                BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isEnabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: isUploading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white))),
                      SizedBox(width: 10),
                      Text('Importing...',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload_outlined,
                          color: isEnabled
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          size: 18),
                      const SizedBox(width: 8),
                      Text('Import Data',
                          style: TextStyle(
                              color: isEnabled
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // ERROR PANEL
  // ════════════════════════════════════════

  Widget _buildErrorPanel(String error) {
    return _GlassContainer(
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFFEF5350),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline,
                color: Color(0xFFEF5350), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upload Error',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF5350))),
                const SizedBox(height: 2),
                Text(error,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // METRIC CARD (compact)
  // ════════════════════════════════════════

  Widget _buildXeersoftDataTable(List<dynamic> rows, {int startIndex = 0}) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(44),   // #
        1: FixedColumnWidth(140),  // SKU
        2: FlexColumnWidth(2.5),   // Product
        3: FlexColumnWidth(1.2),   // Category
        4: FixedColumnWidth(80),   // Stock
        5: FixedColumnWidth(80),   // 30d Sales
        6: FixedColumnWidth(100),  // Lifecycle
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          children: [
            _tableHeader('#'),
            _tableHeader('SKU'),
            _tableHeader('Product'),
            _tableHeader('Category'),
            _tableHeader('Stock', align: TextAlign.right),
            _tableHeader('30d Sales', align: TextAlign.right),
            _tableHeader('Lifecycle', align: TextAlign.center),
          ],
        ),
        // Data rows
        for (int i = 0; i < rows.length; i++)
          _buildXeersoftRow(rows[i], startIndex + i),
      ],
    );
  }

  TableRow _buildXeersoftRow(dynamic item, int index) {
    final lifecycle = item['lifecycle_status']?.toString() ?? 'ACTIVE';
    final lifecycleColor = lifecycle == 'NEW'
        ? const Color(0xFF42A5F5)
        : lifecycle == 'PHASING_OUT'
            ? const Color(0xFFFFB74D)
            : const Color(0xFF66BB6A);
    final isEven = index % 2 == 0;

    return TableRow(
      decoration: BoxDecoration(
        color: isEven
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      children: [
        // Row number
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Text(
            '${index + 1}',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11),
          ),
        ),
        // SKU
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            item['sku']?.toString() ?? '',
            style: const TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace'),
          ),
        ),
        // Product
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            item['product']?.toString() ?? '',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        // Category
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item['category']?.toString() ?? '',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // Stock
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            (item['current_stock'] ?? 0).toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                fontWeight: FontWeight.w500),
          ),
        ),
        // 30d Sales
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            (item['sales_last_30_days'] ?? 0).toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                fontWeight: FontWeight.w500),
          ),
        ),
        // Lifecycle badge
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: lifecycleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: lifecycleColor.withValues(alpha: 0.3)),
              ),
              child: Text(lifecycle,
                  style: TextStyle(
                      color: lifecycleColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSupplierDataTable(List<dynamic> rows, {int startIndex = 0}) {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(44),   // #
        1: FixedColumnWidth(90),   // Code
        2: FlexColumnWidth(2),     // Name
        3: FlexColumnWidth(1.3),   // Contact
        4: FlexColumnWidth(1.5),   // Email
        5: FixedColumnWidth(90),   // Lead Time
        6: FlexColumnWidth(1.2),   // Payment Terms
        7: FixedColumnWidth(70),   // Status
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          children: [
            _tableHeader('#'),
            _tableHeader('Code'),
            _tableHeader('Supplier Name'),
            _tableHeader('Contact'),
            _tableHeader('Email'),
            _tableHeader('Lead Time', align: TextAlign.right),
            _tableHeader('Payment Terms'),
            _tableHeader('Status', align: TextAlign.center),
          ],
        ),
        for (int i = 0; i < rows.length; i++)
          _buildSupplierRow(rows[i], startIndex + i),
      ],
    );
  }

  TableRow _buildSupplierRow(dynamic item, int index) {
    final status = item['status']?.toString() ?? 'Active';
    final statusColor = status.toLowerCase() == 'active'
        ? const Color(0xFF66BB6A)
        : const Color(0xFFFFB74D);
    final isEven = index % 2 == 0;

    return TableRow(
      decoration: BoxDecoration(
        color: isEven
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      children: [
        // Row number
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Text(
            '${index + 1}',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11),
          ),
        ),
        // Code
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            item['supplier_code']?.toString() ??
                item['supplier_id']?.toString() ??
                '',
            style: const TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace'),
          ),
        ),
        // Name
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            item['name']?.toString() ?? '',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        // Contact
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            item['contact_person']?.toString() ?? '-',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Email
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            item['email']?.toString() ?? '-',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Lead Time
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Text(
            '${item['standard_lead_time_days'] ?? '-'} days',
            textAlign: TextAlign.right,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                fontWeight: FontWeight.w500),
          ),
        ),
        // Payment Terms
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: item['payment_terms']?.toString().isNotEmpty == true
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['payment_terms'].toString(),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : Text('-',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12)),
        ),
        // Status badge
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // XEERSOFT SUMMARY
  // ════════════════════════════════════════

  Widget _buildXeersoftSummary(Map<String, dynamic> result) {
    final preview = result['preview'] as List? ?? [];
    final annotations = result['annotations'] as List? ?? [];
    return Column(
      children: [
        _GlassContainer(
          padding: const EdgeInsets.all(24),
          borderColor: const Color(0xFF66BB6A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF66BB6A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_outline,
                        color: Color(0xFF66BB6A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Xeersoft Import Successful',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _buildMetricCard(
                          'Items Upserted',
                          (result['items_upserted'] ??
                                  result['items_processed'] ??
                                  0)
                              .toString(),
                          Icons.check_circle_outline,
                          const Color(0xFF66BB6A))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildMetricCard(
                          'Rows Skipped',
                          (result['items_skipped'] ?? 0).toString(),
                          Icons.skip_next_outlined,
                          const Color(0xFFFFB74D))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildMetricCard(
                          'Sales Records',
                          (result['sales_months_ingested'] ?? 0).toString(),
                          Icons.trending_up,
                          const Color(0xFF42A5F5))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildMetricCard(
                          'Annotations',
                          (result['annotations_extracted'] ?? 0).toString(),
                          Icons.notes,
                          const Color(0xFFCE93D8))),
                ],
              ),
            ],
          ),
        ),

        // Item preview table
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 20),
          _GlassContainer(
            padding: const EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header bar
                InkWell(
                  onTap: preview.length > 10
                      ? () => setState(() =>
                            _xeersoftItemsExpanded =
                                !_xeersoftItemsExpanded)
                      : null,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: preview.length <= 10 || _xeersoftItemsExpanded
                          ? const BorderRadius.vertical(
                              top: Radius.circular(18))
                          : const BorderRadius.vertical(
                              top: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF42A5F5)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: Color(0xFF42A5F5), size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text('Imported Items',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${preview.length}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white
                                      .withValues(alpha: 0.6))),
                        ),
                        const Spacer(),
                        if (preview.length > 10)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF42A5F5)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF42A5F5)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _xeersoftItemsExpanded
                                      ? 'Collapse'
                                      : 'Show all',
                                  style: const TextStyle(
                                      color: Color(0xFF42A5F5),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _xeersoftItemsExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF42A5F5),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Divider line
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),

                // Table content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _xeersoftItemsExpanded
                      ? ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxHeight: 1200),
                          child: SingleChildScrollView(
                            child: _buildXeersoftDataTable(preview),
                          ),
                        )
                      : _buildXeersoftDataTable(
                          preview.take(10).toList()),
                ),

                // Expand footer
                if (!_xeersoftItemsExpanded &&
                    preview.length > 10) ...[
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  InkWell(
                    onTap: () =>
                        setState(() => _xeersoftItemsExpanded = true),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.expand_more_rounded,
                              color: Colors.white.withValues(alpha: 0.4),
                              size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Show ${preview.length - 10} more items',
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Annotations
        if (annotations.isNotEmpty) ...[
          const SizedBox(height: 20),
          _GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notes,
                        color: Color(0xFFCE93D8), size: 20),
                    const SizedBox(width: 8),
                    const Text('Extracted Annotations',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${annotations.length}',
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  Colors.white.withValues(alpha: 0.5))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...annotations.take(10).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF42A5F5)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              a['sku']?.toString() ?? '',
                              style: const TextStyle(
                                  color: Color(0xFF42A5F5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a['annotation']?.toString() ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white
                                      .withValues(alpha: 0.7)),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ════════════════════════════════════════
  // VENDOR SUMMARY
  // ════════════════════════════════════════

  Widget _buildSupplierSummary(Map<String, dynamic> result) {
    final preview = result['preview'] as List? ?? [];
    return Column(
      children: [
        _GlassContainer(
          padding: const EdgeInsets.all(24),
          borderColor: const Color(0xFF66BB6A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF66BB6A).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_outline,
                        color: Color(0xFF66BB6A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Supplier & Item Master Import Successful',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                      child: _buildMetricCard(
                          'Rows Processed',
                          (result['rows_processed'] ?? 0).toString(),
                          Icons.table_rows_outlined,
                          const Color(0xFF42A5F5))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildMetricCard(
                          'Suppliers Added',
                          (result['suppliers_added'] ?? 0).toString(),
                          Icons.person_add_outlined,
                          const Color(0xFF66BB6A))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildMetricCard(
                          'Suppliers Updated',
                          (result['suppliers_updated'] ?? 0).toString(),
                          Icons.sync,
                          const Color(0xFFFFB74D))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildMetricCard(
                          'Rows Skipped',
                          (result['rows_skipped'] ?? 0).toString(),
                          Icons.skip_next_outlined,
                          const Color(0xFFCE93D8))),
                ],
              ),
            ],
          ),
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 20),
          _GlassContainer(
            padding: const EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header bar
                InkWell(
                  onTap: preview.length > 10
                      ? () => setState(() =>
                            _supplierItemsExpanded =
                                !_supplierItemsExpanded)
                      : null,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB74D)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.business_outlined,
                              color: Color(0xFFFFB74D), size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text('Imported Supplier & Item Master',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${preview.length}',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white
                                      .withValues(alpha: 0.6))),
                        ),
                        const Spacer(),
                        if (preview.length > 10)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB74D)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFFFB74D)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _supplierItemsExpanded
                                      ? 'Collapse'
                                      : 'Show all',
                                  style: const TextStyle(
                                      color: Color(0xFFFFB74D),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  _supplierItemsExpanded
                                      ? Icons
                                          .keyboard_arrow_up_rounded
                                      : Icons
                                          .keyboard_arrow_down_rounded,
                                  color: const Color(0xFFFFB74D),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Divider
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),

                // Table content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _supplierItemsExpanded
                      ? ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxHeight: 1200),
                          child: SingleChildScrollView(
                            child: _buildSupplierDataTable(preview),
                          ),
                        )
                      : _buildSupplierDataTable(
                          preview.take(10).toList()),
                ),

                // Expand footer
                if (!_supplierItemsExpanded &&
                    preview.length > 10) ...[
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  InkWell(
                    onTap: () => setState(
                        () => _supplierItemsExpanded = true),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(18)),
                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.expand_more_rounded,
                              color: Colors.white
                                  .withValues(alpha: 0.4),
                              size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Show ${preview.length - 10} more records',
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.45),
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════
// GLASS CONTAINER
// ════════════════════════════════════════

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const _GlassContainer({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
