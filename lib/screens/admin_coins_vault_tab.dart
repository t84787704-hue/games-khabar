// ===============================================================================
// ADMIN COINS VAULT TAB — Manage Coin Vault, Distribution & Balances
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class _AdminCoinsVaultTab extends StatefulWidget {
  const _AdminCoinsVaultTab();

  @override
  State<_AdminCoinsVaultTab> createState() => _AdminCoinsVaultTabState();
}

class _AdminCoinsVaultTabState extends State<_AdminCoinsVaultTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _adjustCoinsModal(String userId, String username, int currentCoins) async {
    final amountController = TextEditingController();
    bool isAdd = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Manage Coins: @$username', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Balance: 🪙 $currentCoins Coins', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Add Coins ➕'),
                      selected: isAdd,
                      onSelected: (val) => setDialogState(() => isAdd = true),
                      selectedColor: const Color(0xFF00FF88),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Deduct ➖'),
                      selected: !isAdd,
                      onSelected: (val) => setDialogState(() => isAdd = false),
                      selectedColor: const Color(0xFFFF4655),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount of Coins',
                  hintText: 'e.g. 500',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdd ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                foregroundColor: isAdd ? Colors.black : Colors.white,
              ),
              onPressed: () async {
                final val = int.tryParse(amountController.text.trim()) ?? 0;
                if (val <= 0) return;
                Navigator.pop(ctx);

                setState(() => _isLoading = true);
                try {
                  final newTotal = isAdd ? currentCoins + val : (currentCoins - val >= 0 ? currentCoins - val : 0);
                  await SupabaseService.client.from('users').update({'coins': newTotal}).eq('id', userId);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isAdd ? 'Successfully added $val coins!' : 'Successfully deducted $val coins!'),
                        backgroundColor: const Color(0xFF00FF88),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating coins: $e'), backgroundColor: const Color(0xFFFF4655)),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
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
              hintText: 'Search user to manage coins...',
              hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 18),
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
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
              }

              final users = snapshot.data ?? [];
              final filteredUsers = users.where((u) {
                if (_searchQuery.isEmpty) return true;
                final name = (u['username'] ?? u['display_name'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery);
              }).toList();

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: ThemeService.card, shape: BoxShape.circle, border: Border.all(color: ThemeService.border)),
                          child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFFD700), size: 40),
                        ),
                        const SizedBox(height: 14),
                        Text('No users found in vault', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filteredUsers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final u = filteredUsers[index];
                  final userId = u['id']?.toString() ?? '';
                  final username = u['username'] ?? u['display_name'] ?? 'Player';
                  final coins = (u['coins'] as num?)?.toInt() ?? 0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('@$username', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text('Wallet Balance: 🪙 $coins Coins', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 12, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _adjustCoinsModal(userId, username, coins),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD700),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: const Text('Manage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
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
