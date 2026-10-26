// ===============================================================================
// ADMIN UC HISTORY TAB — Past UC Transactions & Log History
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class _AdminUcHistoryTab extends StatefulWidget {
  const _AdminUcHistoryTab();

  @override
  State<_AdminUcHistoryTab> createState() => _AdminUcHistoryTabState();
}

class _AdminUcHistoryTabState extends State<_AdminUcHistoryTab> {
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
              hintText: 'Search history by username or game ID...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.history_rounded, color: Color(0xFF38BDF8), size: 18),
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
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
              }

              final list = snapshot.data ?? [];
              final historyList = list.where((req) {
                final status = (req['status'] ?? 'pending').toString().toLowerCase();
                if (status == 'pending') return false; // Show only completed/rejected in history

                if (_searchQuery.isNotEmpty) {
                  final title = (req['username'] ?? req['game_id'] ?? '').toString().toLowerCase();
                  if (!title.contains(_searchQuery)) return false;
                }
                return true;
              }).toList();

              if (historyList.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: ThemeService.card, shape: BoxShape.circle, border: Border.all(color: ThemeService.border)),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF38BDF8), size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text('No UC transaction history', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: historyList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = historyList[index];
                  final username = item['username'] ?? item['gamer_name'] ?? 'Player';
                  final gameId = item['game_id'] ?? item['pubg_id'] ?? 'N/A';
                  final ucAmount = item['uc_amount'] ?? item['amount'] ?? 60;
                  final status = (item['status'] ?? 'completed').toString().toLowerCase();

                  DateTime? createdAt;
                  if (item['created_at'] != null) {
                    createdAt = DateTime.tryParse(item['created_at'].toString());
                  }
                  final formattedDate = createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : 'Recent';

                  final isApproved = status == 'approved' || status == 'completed';

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
                            isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isApproved ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(username, style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('Game ID: $gameId • $ucAmount UC', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5)),
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
