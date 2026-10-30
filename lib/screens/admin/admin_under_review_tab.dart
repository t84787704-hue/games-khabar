// ===============================================================================
// ADMIN UNDER REVIEW TAB — Review Pending Items & Submissions
// File: lib/screens/admin/admin_under_review_tab.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class AdminUnderReviewTab extends StatefulWidget {
  const AdminUnderReviewTab({super.key});

  @override
  State<AdminUnderReviewTab> createState() => AdminUnderReviewTabState();
}

class AdminUnderReviewTabState extends State<AdminUnderReviewTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateTournamentProofStatus(String tournamentId, String status, {String? rejectReason}) async {
    try {
      // 1. ٹورنامنٹ ٹیبل کو اپ ڈیٹ کریں
      final updateData = <String, dynamic>{
        'proof_status': status,
        'status': status == 'approved' ? 'completed' : 'upcoming',
        if (status == 'approved') 'winner_team_id': null,
        if (status == 'rejected') 'rejection_reason': rejectReason ?? 'Invalid screenshot submitted.',
        if (status == 'rejected') 'proof_url': null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client
          .from('tournaments')
          .update(updateData)
          .eq('id', tournamentId);

      // 2. پروو ہسٹری ٹیبل میں ریکارڈ محفوظ کریں
      try {
        final tData = await SupabaseService.client
            .from('tournaments')
            .select('title, proof_team_name, proof_url')
            .eq('id', tournamentId)
            .maybeSingle();

        if (tData != null) {
          await SupabaseService.client.from('proof_history').insert({
            'username': tData['proof_team_name'] ?? 'Unknown Team',
            'proof_type': tData['title'] ?? 'Tournament Proof',
            'status': status,
            'admin_name': 'Admin',
            'tournament_id': tournamentId,
            'proof_url': tData['proof_url'],
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (historyError) {
        debugPrint('Error saving to proof_history: $historyError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Tournament Proof Approved! 🏆' : 'Proof Rejected.'),
            backgroundColor: status == 'approved' ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  void _showRejectDialog(String tournamentId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: ThemeService.border)),
        title: Text('Reject Win Proof', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonController,
          style: TextStyle(color: ThemeService.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter rejection reason (e.g. Fake screenshot)',
            hintStyle: TextStyle(color: ThemeService.textSecondary),
            filled: true,
            fillColor: ThemeService.cardSecondary,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655)),
            onPressed: () {
              Navigator.pop(ctx);
              _updateTournamentProofStatus(tournamentId, 'rejected', rejectReason: reasonController.text.trim());
            },
            child: const Text('Reject Proof', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
              hintText: 'Search pending tournament proofs...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.rate_review_rounded, color: Color(0xFFFF8A00), size: 18),
              filled: true,
              fillColor: ThemeService.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.client
                .from('tournaments')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
              }

              final tournaments = snapshot.data ?? [];
              
              final filtered = tournaments.where((t) {
                final proofUrl = (t['proof_url'] ?? '').toString().trim();
                final proofStatus = (t['proof_status'] ?? 'pending').toString().toLowerCase();
                
                if (proofUrl.isEmpty) return false;
                if (proofStatus != 'pending' && proofStatus != 'under_review') return false;

                if (_searchQuery.isNotEmpty) {
                  final title = (t['title'] ?? '').toString().toLowerCase();
                  final teamName = (t['proof_team_name'] ?? '').toString().toLowerCase();
                  if (!title.contains(_searchQuery) && !teamName.contains(_searchQuery)) return false;
                }
                return true;
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
                          child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00FF88), size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text('No items currently under review', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final t = filtered[index];
                  final id = t['id']?.toString() ?? '';
                  final title = t['title'] ?? 'Tournament Match';
                  final teamName = t['proof_team_name'] ?? 'Submitted Squad';
                  final leaderName = t['proof_leader_name'] ?? 'Leader';
                  final proofUrl = t['proof_url']?.toString() ?? '';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFFF8A00).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFF8A00), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                                  Text('Squad: $teamName ( Leader: $leaderName )', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFFF8A00).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: const Text('REVIEW ⏳', style: TextStyle(color: Color(0xFFFF8A00), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (proofUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: proofUrl,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const SizedBox(
                                height: 150,
                                child: Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
                              ),
                              errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _showRejectDialog(id),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF4655),
                                  side: const BorderSide(color: Color(0xFFFF4655)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _updateTournamentProofStatus(id, 'approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00FF88),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Approve ✓', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                              ),
                            ),
                          ],
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