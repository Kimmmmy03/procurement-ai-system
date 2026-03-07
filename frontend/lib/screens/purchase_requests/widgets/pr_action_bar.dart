import 'package:flutter/material.dart';
import 'dart:ui';

class PRActionBar extends StatelessWidget {
  final int selectedCount;
  final double totalValue;
  final bool isEnabled;
  final VoidCallback onSubmitForApproval;

  const PRActionBar({
    super.key,
    required this.selectedCount,
    required this.totalValue,
    required this.isEnabled,
    required this.onSubmitForApproval,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F).withOpacity(0.85),
                const Color(0xFF0D2137).withOpacity(0.92),
              ],
            ),
            border: const Border(
              top: BorderSide(color: Color(0xFF1E88E5), width: 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E88E5).withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Selection info pills
              if (selectedCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E88E5).withOpacity(0.25),
                        const Color(0xFF1565C0).withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.5), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 15, color: Color(0xFF64B5F6)),
                      const SizedBox(width: 6),
                      Text(
                        '$selectedCount selected',
                        style: const TextStyle(
                          color: Color(0xFF64B5F6),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF66BB6A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.4), width: 1),
                  ),
                  child: Text(
                    'RM ${totalValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF81C784),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ] else
                Text(
                  'Select items to submit for approval',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13),
                ),
              const Spacer(),

              // Glassmorphism Submit for Approval button
              Opacity(
                opacity: isEnabled ? 1.0 : 0.4,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isEnabled
                          ? [const Color(0xFF1E88E5), const Color(0xFF1565C0)]
                          : [Colors.grey.shade700, Colors.grey.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isEnabled
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1E88E5).withOpacity(0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                    border: Border.all(
                      color: isEnabled
                          ? const Color(0xFF42A5F5).withOpacity(0.6)
                          : Colors.white.withOpacity(0.1),
                      width: 1.2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isEnabled ? onSubmitForApproval : null,
                      splashColor: Colors.white.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Submit for Approval',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
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
