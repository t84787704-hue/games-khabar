// ===============================================================================
// ADMIN REWARD CLAIMS HISTORY TAB — Delivered & Rejected Claims from public.reward_claims
// Shows Delivery Proof Screenshot Thumbnail & Full-Screen Preview
// File: lib/screens/admin/admin_uc_history_tab.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class AdminUcHistoryTab extends StatefulWidget {
  const AdminUcHistoryTab({super.key});

  @override
  State<AdminUcHistoryTab> createState() => AdminUcHistoryTabState();
}

class AdminUcHistoryTabState extends State<AdminUcHistoryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatGameName(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'pubg_mobile' || lower.contains('pubg') || lower.contains('bgmi')) {
      return 'PUBG Mobile';
    }
    if (lower == 'free_fire' || lower.contains('free fire')) {
      return 'Free Fire';
    }
    return raw.isEmpty ? 'Game' : raw;
  }

  void _showFullScreenProof(String imageUrl, String claimCode, String playerUid) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delivery Proof • $claimCode (UID: $playerUid)',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ThemeService.textPrimary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 260,
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'Unable to load proof image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
              hintText: 'Search delivered/rejected claims by Claim Code, UID, or Team...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 12.5),
              prefixIcon: const Icon(Icons.history_rounded, color: Color(0xFF38BDF8), size: 18),
              filled: true,
              fillColor: ThemeService.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: ThemeService.border),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.client
                .from('reward_claims')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
              }

              final list = snapshot.data ?? [];
              final historyList = list.where((req) {
                final status = (req['status'] ?? 'pending').toString().toLowerCase();
                if (status == 'pending') return false;

                if (_searchQuery.isNotEmpty) {
                  final code = (req['claim_code'] ?? '').toString().toLowerCase();
                  final uid = (req['player_uid'] ?? '').toString().toLowerCase();
                  final ign = (req['player_ign'] ?? '').toString().toLowerCase();
                  final team = (req['team_name'] ?? '').toString().toLowerCase();
                  if (!code.contains(_searchQuery) &&
                      !uid.contains(_searchQuery) &&
                      !ign.contains(_searchQuery) &&
                      !team.contains(_searchQuery)) {
                    return false;
                  }
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
                          decoration: BoxDecoration(
                            color: ThemeService.card,
                            shape: BoxShape.circle,
                            border: Border.all(color: ThemeService.border),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF38BDF8), size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No processed reward claims yet',
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
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
                  final claimCode = (item['claim_code'] ?? '#RW').toString();
                  final gameLabel = _formatGameName((item['game_name'] ?? '').toString());
                  final playerUid = (item['player_uid'] ?? 'N/A').toString();
                  final playerIgn = (item['player_ign'] ?? '').toString();
                  final teamName = (item['team_name'] ?? 'Rank #1 Team').toString();
                  final rewardLabel = (item['reward_label'] ?? '').toString();
                  final shareAmountPkr = (item['share_amount_pkr'] as num?)?.toInt() ?? 375;
                  final weekKey = (item['week_key'] ?? '').toString();
                  final status = (item['status'] ?? 'delivered').toString().toLowerCase();
                  final adminNote = (item['admin_note'] ?? '').toString();
                  final proofUrl = (item['proof_image_url'] ?? '').toString().trim();

                  final DateTime? deliveredAt =
                      DateTime.tryParse((item['delivered_at'] ?? item['created_at'] ?? '').toString());
                  final String formattedDate = deliveredAt != null
                      ? DateFormat('dd MMM yyyy, hh:mm a').format(deliveredAt.toLocal())
                      : 'Recent';

                  final bool isDelivered = status == 'delivered' || status == 'approved' || status == 'completed';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDelivered
                            ? const Color(0xFF00FF88).withOpacity(0.35)
                            : const Color(0xFFFF4655).withOpacity(0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDelivered
                                    ? const Color(0xFF00FF88).withOpacity(0.12)
                                    : const Color(0xFFFF4655).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isDelivered ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: isDelivered ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$claimCode • $gameLabel ($teamName)',
                                    style: TextStyle(
                                      color: ThemeService.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'UID: $playerUid${playerIgn.isNotEmpty ? ' ($playerIgn)' : ''} • $shareAmountPkr PKR',
                                          style: const TextStyle(
                                            color: Color(0xFF00FF88),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: playerUid));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('UID copied: $playerUid'),
                                              backgroundColor: const Color(0xFF00FF88),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 14,
                                          color: ThemeService.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (rewardLabel.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Reward: $rewardLabel${weekKey.isNotEmpty ? ' • Week: $weekKey' : ''}',
                                      style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
                                    ),
                                  ],
                                  if (adminNote.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Note: $adminNote',
                                      style: TextStyle(
                                        color: ThemeService.textSecondary,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDelivered
                                    ? const Color(0xFF00FF88).withOpacity(0.15)
                                    : const Color(0xFFFF4655).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: isDelivered ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (proofUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _showFullScreenProof(proofUrl, claimCode, playerUid),
                            child: Container(
                              width: double.infinity,
                              height: 110,
                              decoration: BoxDecoration(
                                color: ThemeService.cardSecondary,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.45)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      proofUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          'Tap to View Delivery Proof Screenshot',
                                          style: TextStyle(
                                            color: ThemeService.textSecondary,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.zoom_in_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text(
                                              'Delivery Proof',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
