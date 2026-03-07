import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/procurement_models.dart';
import '../../../services/api_service.dart';
import '../../../widgets/glass_dialog.dart';

/// Shows the override dialog and returns the updated PurchaseRequest if override was saved.
Future<PurchaseRequest?> showOverrideDialog(
  BuildContext context,
  PurchaseRequest pr,
) async {
  final qtyController = TextEditingController(
    text: pr.isOverridden
        ? pr.userOverriddenQty.toString()
        : pr.aiRecommendedQty.toString(),
  );
  final detailedReasonController = TextEditingController(
    text: pr.overrideDetails ?? '',
  );
  String? selectedReason = pr.overrideReason;

  const reasons = [
    'Budget Constraints',
    'Seasonal Adjustment',
    'Supplier Lead Time',
    'Storage Capacity',
    'Market Conditions',
    'Other',
  ];

  return showDialog<PurchaseRequest>(
    context: context,
    builder: (dialogContext) => GlassAlertDialog(
      width: 400,
      title: const Row(
        children: [
          Icon(Icons.edit, color: Color(0xFFFFB74D)),
          SizedBox(width: 12),
          Text('Override Recommendation'),
        ],
      ),
      content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pr.productName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${pr.sku}',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // AI recommendation (read-only)
                Text(
                  'AI Recommended: ${pr.aiRecommendedQty} units',
                  style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 14),
                ),
                const SizedBox(height: 16),
                // New quantity input
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'New Quantity',
                    labelStyle: const TextStyle(color: Colors.white70),
                    suffixText: 'units',
                    suffixStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Reason dropdown
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Reason for Override *',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                    ),
                  ),
                  items: reasons.map((reason) {
                    return DropdownMenuItem(value: reason, child: Text(reason));
                  }).toList(),
                  onChanged: (value) => setDialogState(() => selectedReason = value),
                ),
                const SizedBox(height: 16),
                // Detailed reason (optional)
                TextField(
                  controller: detailedReasonController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Detailed Reason (Optional)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'Enter additional details about the override...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
        ),
        ElevatedButton(
          onPressed: () async {
            if (selectedReason == null) {
              GlassNotification.show(dialogContext, 'Please select a reason', isError: true);
              return;
            }

            final newQty = int.tryParse(qtyController.text);
            if (newQty == null || newQty <= 0) {
              GlassNotification.show(dialogContext, 'Please enter a valid quantity', isError: true);
              return;
            }

            try {
              final apiService = Provider.of<ApiService>(dialogContext, listen: false);
              await apiService.overrideRecommendation(
                requestId: pr.requestId,
                quantity: newQty,
                reasonCategory: selectedReason!,
                additionalDetails: detailedReasonController.text.isNotEmpty
                    ? detailedReasonController.text
                    : null,
              );

              final updated = pr.copyWithOverride(
                newQty: newQty,
                reason: selectedReason!,
                details: detailedReasonController.text.isNotEmpty
                    ? detailedReasonController.text
                    : null,
              );

              Navigator.pop(dialogContext, updated);
              GlassNotification.show(context, 'Override saved successfully');
            } catch (e) {
              GlassNotification.show(dialogContext, 'Error: $e', isError: true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB74D),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Save Override'),
        ),
      ],
    ),
  );
}
