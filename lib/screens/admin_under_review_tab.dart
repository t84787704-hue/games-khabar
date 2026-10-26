// ===============================================================================
// ADMIN UNDER REVIEW TAB — Review Pending Items & Submissions
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class _AdminUnderReviewTab extends StatefulWidget {
  const _AdminUnderReviewTab();

  @override
  State<_AdminUnderReviewTab> createState() => _AdminUnderReviewTabState();
}

class _AdminUnderReviewTabState extends State<_AdminUnderReviewTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateReviewStatus(String id, String status) async {
    try {
      await SupabaseService.client.from('under_review_items').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Item Approved Successfully! ✓' : 'Item Rejected.'),
            backgroundColor: status == 'approved' ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating review status: $e'), backgroundColor: const Color(0xFFFF4655)),
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
              hintText: 'Search under review items...',
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
            stream: SupabaseService.client.from('under_review_items').stream(primaryKey: ['id']).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
              }

              final items = snapshot.data ?? [];
              final filtered = items.where((item) {
                final status = (item['status'] ?? 'pending').toString().toLowerCase();
                if (status != 'pending' && status != 'under_review') return false;

                if (_searchQuery.isNotEmpty) {
                  final title = (item['title'] ?? item['name'] ?? '').toString().toLowerCase();
                  if (!title.contains(_searchQuery)) return false;
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
                  final item = filtered[index];
                  final id = item['id']?.toString() ?? '';
                  final title = item['title'] ?? item['name'] ?? 'Untitled Item';
                  final subtitle = item['description'] ?? item['subtitle'] ?? 'Pending administrative review.';
                  final author = item['username'] ?? item['author'] ?? 'User';

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
                              child: const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF8A00), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
                                  Text('Submitted by: $author', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5)),
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
                        const SizedBox(height: 10),
                        Text(subtitle, style: TextStyle(color: ThemeService.textSecondary, fontSize: 12.5)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _updateReviewStatus(id, 'rejected'),
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
                                onPressed: () => _updateReviewStatus(id, 'approved'),
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
