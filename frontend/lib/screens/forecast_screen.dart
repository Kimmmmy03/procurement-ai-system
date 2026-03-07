import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_filter_chip.dart';

class ForecastScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const ForecastScreen({super.key, this.onNavigate});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  bool _isRunning = false;
  int _currentStep = 0; // 0: not started, 1: Guardian, 2: Forecaster, 3: Logistics, 4: Complete
  Map<String, dynamic>? _workflowResult;

  // FIXED: Proper type annotation for null-safety
  void Function(void Function())? _dialogSetState;

  // Date State Variables — defaults set per user requirements
  DateTime _historicalStart = DateTime(2024, 2, 1);
  DateTime _historicalEnd = DateTime(2025, 11, 30);
  DateTime _planStart = DateTime(2026, 1, 1);
  DateTime _planEnd = DateTime(2026, 3, 31);

  // Seasonality state
  Map<String, dynamic>? _seasonalityResult;
  bool _seasonalityLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSeasonality();
  }

  Future<void> _loadSeasonality() async {
    setState(() => _seasonalityLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final result = await apiService.getSeasonalityAnalysis(
        _planStart.toIso8601String().split('T').first,
        _planEnd.toIso8601String().split('T').first,
      );
      if (mounted) {
        setState(() {
          _seasonalityResult = result;
          _seasonalityLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _seasonalityLoading = false);
      }
    }
  }

  // Quality Gate State
  String _qualityGate = 'Standard (2%)';

  final List<String> _qualityGateOptions = [
    'Strict (1%)',
    'Standard (2%)',
    'Relaxed (5%)',
  ];

  final TextEditingController _contextController = TextEditingController();

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _selectDate(
    BuildContext context,
    Function(DateTime) onDateSelected,
    DateTime initialDate,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1E88E5),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E293B),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != initialDate) {
      setState(() {
        onDateSelected(picked);
      });
      // Reload seasonality when plan dates change
      _loadSeasonality();
    }
  }

  Future<void> _runForecast() async {
    setState(() {
      _isRunning = true;
      _currentStep = 0;
      _workflowResult = null;
    });

    // Show loading dialog
    _showWorkflowDialog();

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);

      // Prepare batch data
      final batchData = {
        'batch_id': 'BATCH-${DateTime.now().millisecondsSinceEpoch}',
        'config': {
          'quality_gate': _qualityGate,
          'history_start': _historicalStart.toIso8601String(),
          'history_end': _historicalEnd.toIso8601String(),
          'plan_start': _planStart.toIso8601String(),
          'plan_end': _planEnd.toIso8601String(),
        },
        'additional_context': _contextController.text.isEmpty ? null : _contextController.text,
      };

      // Step 1: Guardian Agent
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _currentStep = 1);
      _dialogSetState?.call(() {});

      // Step 2: Forecaster Agent — start API call in parallel
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _currentStep = 2);
      _dialogSetState?.call(() {});

      // Fire the API call while animating step 3
      final apiFuture = apiService.runAIWorkflow(batchData);

      await Future.delayed(const Duration(seconds: 1));
      setState(() => _currentStep = 3);
      _dialogSetState?.call(() {});

      // Wait for actual API response
      final result = await apiFuture;

      print('🔍 Backend Response keys: ${result.keys}');

      // Step 3 complete — wait a moment, then move to 'Saving'
      setState(() {
        _currentStep = 3;
        _workflowResult = result['workflow_result'] ?? result;
        _isRunning = false;
      });
      _dialogSetState?.call(() {});

      // Save forecast results as Draft PRs in the database
      try {
        if (_workflowResult != null) {
          await apiService.saveForecastResults(_workflowResult!);
          print('✅ Forecast results saved to DB as Draft PRs');
        }
      } catch (saveErr) {
        print('⚠️ Could not save forecast to DB: $saveErr');
      }

      // Mark workflow as complete JUST before we close the dialog and show results
      setState(() => _currentStep = 4);
      _dialogSetState?.call(() {});
      await Future.delayed(const Duration(milliseconds: 600));

      // Close workflow dialog
      if (mounted) {
        Navigator.of(context).pop();
        _dialogSetState = null;
      }

      // Show result dialog
      await _showResultDialog();

    } catch (e) {
      setState(() {
        _isRunning = false;
        _currentStep = 0;
      });

      if (mounted) {
        Navigator.of(context).pop(); // Close workflow dialog
        _dialogSetState = null; // Clear reference
        GlassNotification.show(
          context,
          'Forecast error: $e',
          isError: true,
          duration: const Duration(seconds: 6),
        );
      }
    }
  }

  void _showWorkflowDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // FIXED: Use StatefulBuilder with proper type annotation
        return StatefulBuilder(
          builder: (context, StateSetter setDialogState) {
            // Store setDialogState for use in main setState
            _dialogSetState = setDialogState;
            
            return GlassAlertDialog(
              width: 400,
              content: SizedBox(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AI Workflow Processing',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Step 1: Guardian
                    _buildWorkflowStep(
                      stepNumber: 1,
                      title: 'Guardian Agent',
                      subtitle: 'Quality Gatekeeper',
                      icon: Icons.security,
                      isActive: _currentStep >= 1,
                      isComplete: _currentStep > 1,
                    ),
                    
                    _buildStepConnector(_currentStep >= 2),
                    
                    // Step 2: Forecaster
                    _buildWorkflowStep(
                      stepNumber: 2,
                      title: 'Forecaster Agent',
                      subtitle: 'Demand Strategist',
                      icon: Icons.trending_up,
                      isActive: _currentStep >= 2,
                      isComplete: _currentStep > 2,
                    ),
                    
                    _buildStepConnector(_currentStep >= 3),
                    
                    // Step 3: Logistics
                    _buildWorkflowStep(
                      stepNumber: 3,
                      title: 'Logistics Agent',
                      subtitle: 'Shipping Optimizer',
                      icon: Icons.local_shipping,
                      isActive: _currentStep >= 3,
                      isComplete: _currentStep > 3,
                    ),
                    
                    if (_currentStep == 4) ...[
                      const SizedBox(height: 24),
                      const Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Workflow Complete!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWorkflowStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required bool isComplete,
  }) {
    Color color;
    if (isComplete) {
      color = Colors.greenAccent;
    } else if (isActive) {
      color = const Color(0xFF1E88E5);
    } else {
      color = Colors.white24;
    }

    return Row(
      children: [
        // Step Circle
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: isComplete
                ? const Icon(Icons.check, color: Colors.greenAccent, size: 24)
                : isActive
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(width: 16),
        
        // Step Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isActive || isComplete ? Colors.white : Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isActive || isComplete ? Colors.white70 : Colors.white38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      margin: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
      width: 2,
      height: 30,
      color: isActive ? Colors.greenAccent : Colors.white24,
    );
  }

  Future<void> _showResultDialog() async {
    if (_workflowResult == null) return;

    // Handle both backend response structures:
    // Structure A (db fallback): {summary: {...}, steps: [...], final_output: "..."}
    // Structure B (agent path):  {agents_output: {agents: [...]}, final_recommendations: "...", batch_id: "..."}
    final summary = _workflowResult!['summary'] as Map<String, dynamic>? ?? {};
    final steps = _workflowResult!['steps'] as List? ?? [];
    final agentsOutputMap = _workflowResult!['agents_output'] as Map<String, dynamic>?;
    final agentsOutput = agentsOutputMap != null ? (agentsOutputMap['agents'] as List? ?? []) : [];
    final finalOutput = _workflowResult!['final_output']
        ?? _workflowResult!['final_recommendations']
        ?? '';

    // Build unified step list from whichever source is available
    final displaySteps = steps.isNotEmpty
        ? steps
        : agentsOutput.asMap().entries.map((e) => {
              'step': e.key + 1,
              'agent': (e.value as Map<String, dynamic>)['agent'] ?? 'Agent ${e.key + 1}',
              'result': {'output': (e.value as Map<String, dynamic>)['output'] ?? ''},
            }).toList();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        return GlassAlertDialog(
          width: screenWidth * 0.8,
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
              const SizedBox(width: 12),
              const Text(
                'Forecast Complete',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: SizedBox(
            height: screenHeight * 0.7,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Summary Stats
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow('Total Items', summary['total_items']?.toString() ?? '${displaySteps.length} agents completed'),
                        const Divider(color: Colors.white24),
                        _buildSummaryRow('Total Value', summary['total_value']?.toString() ?? 'Calculated'),
                        const Divider(color: Colors.white24),
                        _buildSummaryRow('Critical Items', summary['critical_items']?.toString() ?? '—', Colors.red),
                        const Divider(color: Colors.white24),
                        _buildSummaryRow('Warning Items', summary['warning_items']?.toString() ?? '—', Colors.orange),
                        const Divider(color: Colors.white24),
                        _buildSummaryRow('Status', summary.isNotEmpty ? (summary['estimated_delivery'] ?? 'Completed') : 'Saved as Draft PRs'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Workflow Steps Results
                  if (displaySteps.isNotEmpty) ...[
                    const Text(
                      'Workflow Steps:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...displaySteps.map((step) {
                      final stepData = step as Map<String, dynamic>;
                      final result = stepData['result'] as Map<String, dynamic>? ?? {};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Step ${stepData['step']}: ${stepData['agent']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF64B5F6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result['output']?.toString() ?? 'No output',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  height: 1.4,
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 20),

                  // AI Summarization
                  if (finalOutput.toString().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.withValues(alpha: 0.15),
                            Colors.teal.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.08),
                            blurRadius: 20,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'AI Analysis & Recommendations',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Generated by Azure AI Foundry agents',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SelectableText(
                              finalOutput.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                _navigateToPurchaseRequests();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFF64B5F6).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment, color: Color(0xFF64B5F6), size: 20),
                    SizedBox(width: 10),
                    Text(
                      'View in Purchase Requests',
                      style: TextStyle(
                        color: Color(0xFF64B5F6),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios, color: Color(0xFF64B5F6), size: 14),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPurchaseRequests() {
    if (widget.onNavigate != null) {
      widget.onNavigate!(3); // Navigate to Manage PRs tab
    } else {
      GlassNotification.show(
        context,
        'Forecast saved! Navigate to Purchase Requests to view details.',
      );
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
            padding: const EdgeInsets.all(32.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Generate Procurement Plan',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI-powered demand forecasting based on historical data',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 1. Forecasting Configuration
                  _GlassSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Forecasting Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Row 1: Date Ranges
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Analysis Data Range (Historical Basis)'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: _formatDate(_historicalStart),
                                          onTap: () => _selectDate(
                                            context,
                                            (date) => _historicalStart = date,
                                            _historicalStart,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'to',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: _formatDate(_historicalEnd),
                                          onTap: () => _selectDate(
                                            context,
                                            (date) => _historicalEnd = date,
                                            _historicalEnd,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 48),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Planning Horizon (Forecast)'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: _formatDate(_planStart),
                                          onTap: () => _selectDate(
                                            context,
                                            (date) => _planStart = date,
                                            _planStart,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          'to',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildDatePickerField(
                                          label: _formatDate(_planEnd),
                                          onTap: () => _selectDate(
                                            context,
                                            (date) => _planEnd = date,
                                            _planEnd,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Row 2: Quality Gate & Context
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Quality Gate Threshold'),
                                  const SizedBox(height: 8),
                                  _buildGlassDropdown(
                                    value: _qualityGate,
                                    items: _qualityGateOptions,
                                    onChanged: (newValue) {
                                      if (newValue != null) {
                                        setState(() => _qualityGate = newValue);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 48),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Additional Context for AI (Optional)'),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withOpacity(0.10),
                                              Colors.white.withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.15),
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _contextController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                            hintText: 'Example: Add 20% more Stock Based on Demand',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withOpacity(0.4),
                                              fontSize: 14,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Seasonality Detection
                  _GlassSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Seasonality Detection',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_seasonalityLoading) ...[
                              const SizedBox(width: 12),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64B5F6)),
                                ),
                              ),
                            ],
                            const Spacer(),
                            // Manage Custom Seasonality Events button
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/custom-seasonality')
                                    .then((_) => _loadSeasonality());
                              },
                              icon: const Icon(Icons.tune, size: 16, color: Color(0xFF64B5F6)),
                              label: const Text(
                                'Manage Custom Events',
                                style: TextStyle(color: Color(0xFF64B5F6), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_seasonalityLoading)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SkeletonBox(width: 280, height: 13),
                              const SizedBox(height: 6),
                              _SkeletonBox(width: 200, height: 13),
                            ],
                          )
                        else
                          Text(
                            _seasonalityResult?['summary_text'] ?? 'No seasonality data available.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        const SizedBox(height: 24),
                        _buildSeasonalityCards(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 3. Run Button
                  Center(
                    child: SizedBox(
                      width: 300,
                      child: _LiquidButton(
                        text: _isRunning ? 'Processing...' : 'Run AI Forecast',
                        icon: Icons.auto_awesome,
                        onPressed: _isRunning ? null : _runForecast,
                        isPrimary: true,
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return GlassDropdown<String>(
      value: value,
      icon: Icons.keyboard_arrow_down,
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSeasonalityCards() {
    final events = (_seasonalityResult?['detected_events'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (_seasonalityLoading) {
      return _buildSeasonalitySkeletonLoader();
    }

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white.withOpacity(0.5), size: 20),
            const SizedBox(width: 12),
            Text(
              'No seasonal events detected for the selected plan period. Base demand forecasting will be used.',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
      );
    }

    // Show ALL events in a wrapped grid — each card is clickable for detail
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${events.length} event(s) detected',
          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: events.map((event) => _buildSeasonalityEventChip(event)).toList(),
        ),
      ],
    );
  }

  Widget _buildSeasonalitySkeletonLoader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skeleton for "X event(s) detected" text
        _SkeletonBox(width: 140, height: 14),
        const SizedBox(height: 12),
        // Skeleton event chips matching the real card layout
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(3, (index) => _buildSkeletonEventCard()),
        ),
      ],
    );
  }

  Widget _buildSkeletonEventCard() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: icon + category badge
          Row(
            children: [
              _SkeletonBox(width: 18, height: 18, borderRadius: 4),
              const SizedBox(width: 8),
              _SkeletonBox(width: 60, height: 14),
              const Spacer(),
              _SkeletonBox(width: 40, height: 20, borderRadius: 10),
            ],
          ),
          const SizedBox(height: 10),
          // Event name
          _SkeletonBox(width: 160, height: 15),
          const SizedBox(height: 6),
          // Date range
          _SkeletonBox(width: 120, height: 12),
          const SizedBox(height: 8),
          // Affected items
          _SkeletonBox(width: 100, height: 12),
        ],
      ),
    );
  }

  Widget _buildSeasonalityEventChip(Map<String, dynamic> event) {
    final name = event['event'] ?? 'Unknown';
    final mult = event['multiplier'] ?? 1.0;
    final severity = event['severity'] ?? 'medium';
    final category = event['category'] ?? 'general';
    final icon = _seasonalityIcon(event['icon'] ?? 'event');

    // Severity-based accent colour
    final Color accentColor;
    switch (severity) {
      case 'high':
        accentColor = const Color(0xFFEF5350); // red
        break;
      case 'low':
        accentColor = const Color(0xFF66BB6A); // green
        break;
      default:
        accentColor = const Color(0xFFFFB74D); // orange
    }

    // Multiplier label colour (red for dip, blue for surge)
    final bool isDip = (mult as num) < 1.0;
    final Color multColor = isDip ? const Color(0xFFEF5350) : const Color(0xFF64B5F6);
    final String multLabel = isDip ? 'x${mult.toStringAsFixed(2)}' : '+${((mult - 1) * 100).toStringAsFixed(0)}%';

    return InkWell(
      onTap: () => _showSeasonalityDetail(event),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: icon + category badge
            Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Multiplier + category row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: multColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    multLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: multColor),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Months
            Text(
              'Months: ${(event['months'] as List?)?.map(_monthName).join(', ') ?? ''}',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 4),
            // Tap hint
            Text(
              'Tap for details',
              style: TextStyle(fontSize: 10, color: accentColor.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeasonalityDetail(Map<String, dynamic> event) {
    final name = event['event'] ?? 'Unknown';
    final mult = event['multiplier'] ?? 1.0;
    final severity = event['severity'] ?? 'medium';
    final category = event['category'] ?? 'general';
    final description = event['description'] ?? '';
    final months = (event['months'] as List?)?.map(_monthName).join(', ') ?? '';
    final affected = event['affected_sku_count'] ?? 0;
    final total = event['total_sku_count'] ?? 0;
    final affectedSkus = (event['affected_skus'] as List?)?.cast<String>() ?? [];
    final icon = _seasonalityIcon(event['icon'] ?? 'event');

    final Color accentColor;
    switch (severity) {
      case 'high':
        accentColor = const Color(0xFFEF5350);
        break;
      case 'low':
        accentColor = const Color(0xFF66BB6A);
        break;
      default:
        accentColor = const Color(0xFFFFB74D);
    }

    final bool isDip = (mult as num) < 1.0;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2A3A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 24, color: accentColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _detailBadge(severity.toUpperCase(), accentColor),
                            const SizedBox(width: 8),
                            _detailBadge(category, Colors.white.withOpacity(0.4)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Description
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Metrics row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _detailMetric(
                      'Multiplier',
                      isDip ? 'x${mult.toStringAsFixed(2)}' : 'x${mult.toStringAsFixed(2)}',
                      isDip ? const Color(0xFFEF5350) : const Color(0xFF64B5F6),
                    ),
                    _detailDivider(),
                    _detailMetric('Months', months, Colors.white),
                    _detailDivider(),
                    _detailMetric(
                      'Impact',
                      isDip
                          ? '${((1 - mult) * 100).toStringAsFixed(0)}% decrease'
                          : '+${((mult - 1) * 100).toStringAsFixed(0)}% demand',
                      isDip ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Affected SKUs
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Affected SKUs: $affected / $total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (affectedSkus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: affectedSkus.map((sku) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sku,
                            style: TextStyle(fontSize: 12, color: accentColor),
                          ),
                        )).toList(),
                      ),
                    ],
                    if (affectedSkus.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'No individual SKUs exceeded the seasonal threshold (1.25x), but the calendar multiplier still applies to all forecasts.',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _detailMetric(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _detailDivider() {
    return Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1));
  }

  String _monthName(dynamic m) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final idx = m is int ? m : int.tryParse(m.toString()) ?? 0;
    return (idx >= 1 && idx <= 12) ? names[idx] : '?';
  }

  IconData _seasonalityIcon(String iconName) {
    switch (iconName) {
      case 'celebration': return Icons.celebration;
      case 'temple_hindu': return Icons.temple_hindu;
      case 'nights_stay': return Icons.nights_stay;
      case 'trending_down': return Icons.trending_down;
      case 'mosque': return Icons.mosque;
      case 'self_improvement': return Icons.self_improvement;
      case 'backpack': return Icons.backpack;
      case 'assessment': return Icons.assessment;
      case 'flag': return Icons.flag;
      case 'light_mode': return Icons.light_mode;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'card_giftcard': return Icons.card_giftcard;
      case 'construction': return Icons.construction;
      case 'thunderstorm': return Icons.thunderstorm;
      case 'school': return Icons.school;
      default: return Icons.event;
    }
  }

  @override
  void dispose() {
    _contextController.dispose();
    super.dispose();
  }
}

// Local Styled Components
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.04, end: 0.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class _GlassSection extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _GlassSection({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LiquidButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _LiquidButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isPrimary && onPressed != null
            ? const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: onPressed == null ? Colors.grey : null,
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: const Color(0xFF1E88E5).withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}