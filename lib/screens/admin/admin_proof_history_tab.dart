// ===============================================================================
// ADMIN PROOF HISTORY TAB — Past Verification & Proof History Logs
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class AdminProofHistoryTab extends StatefulWidget {
  const AdminProofHistoryTab({super.key});

  @override
  State<AdminProofHistoryTab> createState() => AdminProofHistoryTabState();
}

class AdminProofHistoryTabState extends State<AdminProofHistoryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search proof history logs...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.history_edu_rounded, color: Color(0xFF00FF88), size: 18),
              filled: true,
              fillColor: ThemeService.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.client.from('proof_history').stream(primaryKey: ['id']).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final logs = snapshot.data ?? [];
              final filtered = logs.where((log) {
                if (_searchQuery.isEmpty) return true;
                final title = (log['title'] ?? log['username'] ?? log['proof_type'] ?? '').toString().toLowerCase();
                return title.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: ThemeService.card, shape: BoxShape.circle, border: Border.all(color: ThemeService.border)),
                          child: const Icon(Icons.folder_open_rounded, color: Color(0xFF00FF88), size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text('No proof history records found', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final log = filtered[index];
                  final username = log['username'] ?? log['gamer_name'] ?? 'User';
                  final proofType = log['proof_type'] ?? log['type'] ?? 'Verification Proof';
                  final status = (log['status'] ?? 'approved').toString().toLowerCase();
                  final adminName = log['admin_name'] ?? log['reviewed_by'] ?? 'Admin';

                  DateTime? createdAt;
                  if (log['created_at'] != null) {
                    createdAt = DateTime.tryParse(log['created_at'].toString());
                  }
                  final formattedDate = createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : 'Past Record';

                  final isApproved = status == 'approved';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isApproved ? const Color(0xFF00FF88).withOpacity(0.3) : const Color(0xFFFF4655).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isApproved ? const Color(0xFF00FF88).withOpacity(0.12) : const Color(0xFFFF4655).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isApproved ? Icons.verified_rounded : Icons.cancel_rounded,
                            color: isApproved ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$username • $proofType', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('Reviewed by: $adminName', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5)),
                              const SizedBox(height: 2),
                              Text(formattedDate, style: TextStyle(color: ThemeService.textSecondary, fontSize: 10.5)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isApproved ? const Color(0xFF00FF88).withOpacity(0.15) : const Color(0xFFFF4655).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: isApproved ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
