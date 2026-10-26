// ===============================================================================
// ADMIN RANK VERIFY TAB — Review User Game Ranks & Screenshot Proofs
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/gamer_user_model.dart';
import '../../services/gamer_auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/gamer_avatar.dart';

class AdminRankVerifyTab extends StatefulWidget {
  const AdminRankVerifyTab({super.key});

  @override
  State<AdminRankVerifyTab> createState() => AdminRankVerifyTabState();
}

class AdminRankVerifyTabState extends State<AdminRankVerifyTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showOnlyPending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showScreenshotViewer(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ThemeService.card,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: ThemeService.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                    ),
                    errorWidget: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(48),
                      child: Icon(Icons.broken_image_rounded, color: Colors.red, size: 48),
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

  Future<void> _approveRank(GamerUser user, UserGameRank game) async {
    try {
      final currentAdmin = GamerAuthService().currentGamer?.displayName ?? 'Admin';
      final ok = await SupabaseService.approveRank(
        userId: user.uid,
        rank: game.claimedRank,
        gameName: game.gameName,
        adminName: currentAdmin,
      );

      try {
        await NotificationService().createNotification(
          userId: user.uid,
          title: 'Rank Verified! 🎉',
          body: 'Your ${game.gameName} rank (${game.claimedRank}) has been verified successfully by admin!',
          type: 'rank_verified',
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Approved ${game.gameName} rank for @${user.username}!' : 'Error approving rank'),
            backgroundColor: ok ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving rank: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _rejectRank(GamerUser user) async {
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Rank Proof ⚠️', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: reasonController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter reason (e.g., Blurry screenshot, fake UID)...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final reason = reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Invalid rank screenshot proof.';
              try {
                final currentAdmin = GamerAuthService().currentGamer?.displayName ?? 'Admin';
                await SupabaseService.rejectRank(userId: user.uid, reason: reason, adminName: currentAdmin);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rank verification rejected.'), backgroundColor: Color(0xFFFF4655)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF4655)),
                  );
                }
              }
            },
            child: const Text('Confirm Reject', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Filter Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search username or Game ID...',
                    hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00FF88), size: 18),
                    filled: true,
                    fillColor: ThemeService.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(_showOnlyPending ? '⏳ Pending' : '📋 All'),
                selected: _showOnlyPending,
                onSelected: (val) => setState(() => _showOnlyPending = val),
                selectedColor: const Color(0xFFFF8A00).withOpacity(0.2),
                backgroundColor: ThemeService.card,
                labelStyle: TextStyle(
                  color: _showOnlyPending ? const Color(0xFFFF8A00) : ThemeService.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: _showOnlyPending ? const Color(0xFFFF8A00) : ThemeService.border),
                ),
              ),
            ],
          ),
        ),
        // Requests Stream Builder
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.getRealtimeUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final docs = snapshot.data ?? [];
              final List<_RankQueueItem> allItems = [];

              for (final doc in docs) {
                final user = GamerUser.fromMap(doc);
                for (int i = 0; i < user.games.length; i++) {
                  allItems.add(_RankQueueItem(user: user, game: user.games[i], gameIndex: i));
                }

                // If user has primary rank pending submission
                if (user.rank.isNotEmpty && user.rank.toLowerCase() != 'none' && user.rankStatus.toLowerCase() == 'pending') {
                  final primaryGame = UserGameRank(
                    id: 'primary_${user.uid}',
                    gameName: user.selectedGame.isNotEmpty ? user.selectedGame : 'BGMI',
                    gameId: user.gameId.isNotEmpty ? user.gameId : 'N/A',
                    claimedRank: user.rank,
                    verifiedRank: '',
                    isVerified: false,
                    screenshotUrl: user.rankScreenshot,
                    status: 'pending',
                    submittedAt: user.createdAt,
                    rejectReason: user.rankRejectReason,
                    ownerUid: user.uid,
                  );
                  allItems.add(_RankQueueItem(user: user, game: primaryGame, gameIndex: -1));
                }
              }

              final filtered = allItems.where((item) {
                if (_showOnlyPending && item.game.status != 'pending') return false;
                if (_searchQuery.isNotEmpty) {
                  final uName = item.user.username.toLowerCase();
                  final dName = item.user.displayName.toLowerCase();
                  final gId = item.game.gameId.toLowerCase();
                  if (!uName.contains(_searchQuery) && !dName.contains(_searchQuery) && !gId.contains(_searchQuery)) {
                    return false;
                  }
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
                          child: Icon(Icons.verified_outlined, color: ThemeService.textSecondary, size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text('No rank verification requests found', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
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
                  final item = filtered[index];
                  final user = item.user;
                  final game = item.game;
                  final isPending = game.status == 'pending';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isPending ? const Color(0xFFFF8A00).withOpacity(0.5) : ThemeService.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GamerAvatar(photoUrl: user.photoUrl, radius: 18, displayName: user.displayName),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.displayName.isNotEmpty ? user.displayName : user.username, style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                                  Text('@${user.username}', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPending ? const Color(0xFFFF8A00).withOpacity(0.15) : const Color(0xFF00FF88).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPending ? 'Pending ⏳' : 'Verified ✓',
                                style: TextStyle(color: isPending ? const Color(0xFFFF8A00) : const Color(0xFF00FF88), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(color: ThemeService.border, height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Game: ${game.gameName}', style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 10),
                            Text('ID: ${game.gameId}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Claimed Rank: ${game.claimedRank}', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 10),
                        if (game.screenshotUrl.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => _showScreenshotViewer(game.screenshotUrl, '${user.displayName} • Rank Proof'),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: game.screenshotUrl,
                                    height: 130,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      height: 130,
                                      color: ThemeService.cardSecondary,
                                      child: const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88), strokeWidth: 2)),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      height: 130,
                                      color: ThemeService.cardSecondary,
                                      child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Tap to zoom 🔍', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (isPending) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _rejectRank(user),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF4655),
                                    side: const BorderSide(color: Color(0xFFFF4655)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _approveRank(user, game),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00FF88),
                                    foregroundColor: const Color(0xFF0B0F14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Approve Rank', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                ),
                              ),
                            ],
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

class _RankQueueItem {
  final GamerUser user;
  final UserGameRank game;
  final int gameIndex;
  _RankQueueItem({required this.user, required this.game, required this.gameIndex});
}
