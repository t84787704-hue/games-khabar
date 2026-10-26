// ===============================================================================
// ADMIN BLUE TICK REQUESTS TAB — Review & Approve Profile Verification Badges
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/gamer_user_model.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/gamer_avatar.dart';

class _AdminBlueTickTab extends StatefulWidget {
  const _AdminBlueTickTab();

  @override
  State<_AdminBlueTickTab> createState() => _AdminBlueTickTabState();
}

class _AdminBlueTickTabState extends State<_AdminBlueTickTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _approveBlueTick(GamerUser user) async {
    try {
      await SupabaseService.client.from('users').update({
        'is_verified': true,
        'verification_status': 'approved',
      }).eq('id', user.uid);

      try {
        await NotificationService().createNotification(
          userId: user.uid,
          title: 'Blue Tick Verified! 💙',
          body: 'Congratulations! Your profile verification request has been approved by admin.',
          type: 'blue_tick_approved',
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved Blue Tick for @${user.username}! 💙'),
            backgroundColor: const Color(0xFF38BDF8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving blue tick: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _rejectBlueTick(GamerUser user) async {
    final reasonCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Verification Request ⚠️', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter rejection reason...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.client.from('users').update({
                  'verification_status': 'rejected',
                  'verification_reject_reason': reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Requirements not met.',
                }).eq('id', user.uid);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Blue tick request rejected.'), backgroundColor: Color(0xFFFF4655)),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search pending verification requests...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF38BDF8), size: 18),
              filled: true,
              fillColor: ThemeService.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.getRealtimeUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
              }

              final docs = snapshot.data ?? [];
              List<GamerUser> requests = docs.map((d) => GamerUser.fromMap(d)).where((u) {
                final status = u.verificationStatus.toLowerCase();
                return status == 'pending';
              }).toList();

              if (_searchQuery.isNotEmpty) {
                requests = requests.where((u) {
                  return u.username.toLowerCase().contains(_searchQuery) || u.displayName.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              if (requests.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: ThemeService.card, shape: BoxShape.circle, border: Border.all(color: ThemeService.border)),
                          child: const Icon(Icons.verified_user_outlined, color: Color(0xFF38BDF8), size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text('No pending blue tick requests', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = requests[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GamerAvatar(photoUrl: user.photoUrl, radius: 20, displayName: user.displayName),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(user.displayName.isNotEmpty ? user.displayName : user.username,
                                          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, color: Color(0xFF38BDF8), size: 14),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('@${user.username} • 🪙 ${user.coins} Coins', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Pending ⏳', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if (user.verificationProofUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: user.verificationProofUrl,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _rejectBlueTick(user),
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
                                onPressed: () => _approveBlueTick(user),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF38BDF8),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Approve Tick 💙', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
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
