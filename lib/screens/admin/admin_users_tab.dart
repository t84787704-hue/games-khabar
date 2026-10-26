// ===============================================================================
// ADMIN USERS MANAGEMENT TAB — Search, Banning, Coins & Demo Accounts Manager
// ===============================================================================

import 'package:flutter/material.dart';
import '../../models/gamer_user_model.dart';
import '../../services/demo_accounts_service.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/gamer_avatar.dart';
import '../../widgets/rank_badge_widget.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => AdminUsersTabState();
}

class AdminUsersTabState extends State<AdminUsersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _userSearchQuery = '';
  bool _isSeedingDemo = false;
  bool _isDeletingDemo = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSeedDemoAccounts() async {
    setState(() => _isSeedingDemo = true);
    try {
      await DemoAccountsService().seedDemoAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully created 10 Professional Demo Accounts!'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error seeding demo accounts: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeedingDemo = false);
    }
  }

  Future<void> _handleDeleteAllDemoAccounts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655)),
            const SizedBox(width: 8),
            Text('Delete All Demo Accounts?',
                style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'This will permanently delete all demo accounts and their posts. Real accounts will remain untouched.',
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeletingDemo = true);
    try {
      final count = await DemoAccountsService().deleteAllDemoAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted $count demo accounts.'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting demo accounts: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingDemo = false);
    }
  }

  Future<void> _toggleBanUser(GamerUser user) async {
    final nextBanned = !user.isBanned;
    final sbAdminId = SupabaseService.client.auth.currentUser?.id ?? '';
    try {
      bool ok;
      if (nextBanned) {
        ok = await SupabaseService.banUser(
          userId: user.uid,
          adminId: sbAdminId,
          reason: 'Violating community guidelines',
        );
      } else {
        ok = await SupabaseService.unbanUser(user.uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? (nextBanned ? 'User @${user.username} banned successfully' : 'User @${user.username} unbanned successfully')
                  : 'Error updating ban status',
            ),
            backgroundColor: ok ? (nextBanned ? const Color(0xFFFF4655) : const Color(0xFF00FF88)) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating user ban: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Demo Action Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _userSearchQuery = val.toLowerCase().trim()),
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search users by name, username, or ID...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, color: ThemeService.textSecondary, size: 20),
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: ThemeService.textSecondary, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _userSearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: ThemeService.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeService.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ThemeService.border)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSeedingDemo ? null : _handleSeedDemoAccounts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88).withOpacity(0.12),
                    foregroundColor: const Color(0xFF00FF88),
                    side: const BorderSide(color: Color(0xFF00FF88), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isSeedingDemo
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88)))
                      : const Icon(Icons.group_add_rounded, size: 16),
                  label: Text(_isSeedingDemo ? 'Seeding...' : 'Seed 10 Demo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDeletingDemo ? null : _handleDeleteAllDemoAccounts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4655).withOpacity(0.12),
                    foregroundColor: const Color(0xFFFF4655),
                    side: const BorderSide(color: Color(0xFFFF4655), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: _isDeletingDemo
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4655)))
                      : const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: Text(_isDeletingDemo ? 'Deleting...' : 'Delete Demo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Users List Stream
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.getRealtimeUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final docs = snapshot.data ?? [];
              List<GamerUser> users = docs.map((d) => GamerUser.fromMap(d)).toList();

              if (_userSearchQuery.isNotEmpty) {
                users = users.where((u) {
                  return u.displayName.toLowerCase().contains(_userSearchQuery) ||
                      u.username.toLowerCase().contains(_userSearchQuery) ||
                      u.uid.toLowerCase().contains(_userSearchQuery);
                }).toList();
              }

              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, color: ThemeService.textSecondary, size: 40),
                        const SizedBox(height: 14),
                        Text('No users found', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: user.isBanned ? const Color(0xFFFF4655) : ThemeService.border,
                        width: user.isBanned ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        GamerAvatar(
                          photoUrl: user.photoUrl,
                          displayName: user.displayName,
                          radius: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.displayName.isNotEmpty ? user.displayName : '@${user.username}',
                                      style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (user.hasBlueTick) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Color(0xFF38BDF8), size: 14),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${user.username} • 🪙 ${user.coins} Coins',
                                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _toggleBanUser(user),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: user.isBanned ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                            side: BorderSide(color: user.isBanned ? const Color(0xFF00FF88) : const Color(0xFFFF4655)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: Icon(user.isBanned ? Icons.check_circle_outline : Icons.block_rounded, size: 13),
                          label: Text(user.isBanned ? 'Unban' : 'Ban', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
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
