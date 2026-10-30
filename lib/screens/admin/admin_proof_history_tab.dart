// ===============================================================================
// ADMIN PROOF HISTORY TAB — (Disabled / Placeholder)
// ===============================================================================

import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

class AdminProofHistoryTab extends StatefulWidget {
  const AdminProofHistoryTab({super.key});

  @override
  State<AdminProofHistoryTab> createState() => AdminProofHistoryTabState();
}

class AdminProofHistoryTabState extends State<AdminProofHistoryTab> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThemeService.card,
                shape: BoxShape.circle,
                border: Border.all(color: ThemeService.border),
              ),
              child: const Icon(Icons.history_rounded, color: Color(0xFF00FF88), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Proof History Coming Soon',
              style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'This feature is currently under development.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}