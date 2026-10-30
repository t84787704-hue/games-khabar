// ===============================================================================
// ADMIN UC REQUESTS TAB — Review & Process UC Top-up / Reward Requests
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class AdminUcRequestsTab extends StatefulWidget {
  const AdminUcRequestsTab({super.key});

  @override
  State<AdminUcRequestsTab> createState() => AdminUcRequestsTabState();
}

class AdminUcRequestsTabState extends State<AdminUcRequestsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _processUcRequest(Map<String, dynamic> request, String newStatus) async {
    final id = request['id']?.toString() ?? '';
    final userId = request['user_id']?.toString() ?? '';
    final ucAmount = request['uc_amount'] ?? request['amount'] ?? 60;

    try {
      await SupabaseService.client.from('uc_requests').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      if (userId.isNotEmpty) {
        try {
          await NotificationService().createNotification(
            userId: userId,
            title: newStatus == 'approved' ? 'UC Request Approved! ⚡' : 'UC Request Rejected ⚠️',
            body: newStatus == 'approved'
                ? 'Your request for $ucAmount UC has been approved and processed!'
                : 'Your UC request could not be processed at this time.',
            type: 'uc_request_${newStatus}',
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'approved' ? 'UC Request Approved Successfully! ⚡' : 'UC Request Rejected'),
            backgroundColor: newStatus == 'approved' ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating UC request: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
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
              hintText: 'Search UC requests by username or game ID...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFFD700), size: 18),
              filled: true,
              fillColor: ThemeService.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.client.from('uc_requests').stream(primaryKey: ['id']).order('created_at', ascending: false),
            builder: (context, snapshot) {
              // 👇 یہاں تبدیلی کی ہے: صرف لوڈنگ چیک کریں
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
              }

              final list = snapshot.data ?? [];
              final pendingRequests = list.where((req) {
                final status = (req['status'] ?? 'pending').toString().toLowerCase();
                if (status != 'pending') return false;

                if (_searchQuery.isNotEmpty) {
                  final title = (req['username'] ?? req['game_id'] ?? '').toString().toLowerCase();
                  if (!title.contains(_searchQuery)) return false;
                }
                return true;
              }).toList();

              if (pendingRequests.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: ThemeService.card, shape: BoxShape.circle, border: Border.all(color: ThemeService.border)),
                          child: const Icon(Icons.bolt_rounded, color: Color(0xFFFFD700), size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text('No pending UC requests', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: pendingRequests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final req = pendingRequests[index];
                  final username = req['username'] ?? req['gamer_name'] ?? 'Player';
                  final gameId = req['game_id'] ?? req['pubg_id'] ?? 'N/A';
                  final ucAmount = req['uc_amount'] ?? req['amount'] ?? 60;
                  final priceCoin = req['coin_price'] ?? req['coins'] ?? 500;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.flash_on_rounded, color: Color(0xFFFFD700), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(username, style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                                  Text('Game ID: $gameId', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFFF8A00).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                              child: const Text('Pending ⚡', style: TextStyle(color: Color(0xFFFF8A00), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: ThemeService.cardSecondary, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Requested UC: $ucAmount ⚡', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Paid Price: $priceCoin Coins 🪙', style: TextStyle(color: ThemeService.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _processUcRequest(req, 'rejected'),
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
                                onPressed: () => _processUcRequest(req, 'approved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00FF88),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Approve UC ⚡', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
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