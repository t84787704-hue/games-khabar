// ===============================================================================
// ADMIN REPORTS TAB — Reports Management with Filters, Search & Actions
// File: lib/screens/admin/admin_reports_tab.dart
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'pending'; // 'pending', 'resolved', 'all'
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshReports() async {
    setState(() => _isRefreshing = true);
    try {
      final reports = await SupabaseService.getReports();
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar & Filter Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: ThemeService.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search reports by reason or user...',
                  hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.report_problem_rounded, color: Color(0xFFFF4655), size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: ThemeService.textSecondary, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: ThemeService.card,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ThemeService.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ThemeService.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: Color(0xFF00FF88)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Filter Chips: Pending, Resolved, All
              StreamBuilder<List<Map<String, dynamic>>>(
                initialData: SupabaseService.cachedReports,
                stream: SupabaseService.getRealtimeReports(),
                builder: (context, snapshot) {
                  final allReports = snapshot.data ?? [];
                  final pendingCount = allReports.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'pending').length;
                  final resolvedCount = allReports.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'resolved').length;
                  final totalCount = allReports.length;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: '⏳ Pending ($pendingCount)',
                          filterKey: 'pending',
                          activeColor: const Color(0xFFFF8A00),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '✅ Resolved ($resolvedCount)',
                          filterKey: 'resolved',
                          activeColor: const Color(0xFF00FF88),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          label: '📋 All Reports ($totalCount)',
                          filterKey: 'all',
                          activeColor: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _showCreateTestReportDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ThemeService.textSecondary,
                            side: BorderSide(color: ThemeService.border),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 14),
                          label: const Text('+ Test Report', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Stream Reports List
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            initialData: SupabaseService.cachedReports,
            stream: SupabaseService.getRealtimeReports(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  (!snapshot.hasData || snapshot.data!.isEmpty) &&
                  !_isRefreshing) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
              }

              final allDocs = snapshot.data ?? [];
              final filtered = allDocs.where((r) {
                final status = (r['status'] ?? 'pending').toString().toLowerCase();

                // Status filter
                if (_selectedStatusFilter == 'pending' && status != 'pending') {
                  return false;
                }
                if (_selectedStatusFilter == 'resolved' && status != 'resolved') {
                  return false;
                }

                // Search query filter
                if (_searchQuery.isNotEmpty) {
                  final reporter = (r['reporter_username'] ?? '').toString().toLowerCase();
                  final reason = (r['reason'] ?? '').toString().toLowerCase();
                  final content = (r['target_content'] ?? '').toString().toLowerCase();
                  final type = (r['target_type'] ?? '').toString().toLowerCase();
                  final targetId = (r['target_id'] ?? '').toString().toLowerCase();

                  final matches = reporter.contains(_searchQuery) ||
                      reason.contains(_searchQuery) ||
                      content.contains(_searchQuery) ||
                      type.contains(_searchQuery) ||
                      targetId.contains(_searchQuery);
                  if (!matches) return false;
                }

                return true;
              }).toList();

              if (filtered.isEmpty) {
                return _buildEmptyState(allDocs);
              }

              return RefreshIndicator(
                color: const Color(0xFF00FF88),
                backgroundColor: ThemeService.card,
                onRefresh: _refreshReports,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = filtered[index];
                    return _buildReportCard(data);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    required Color activeColor,
  }) {
    final isSelected = _selectedStatusFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedStatusFilter = filterKey);
        }
      },
      selectedColor: activeColor.withOpacity(0.2),
      backgroundColor: ThemeService.card,
      labelStyle: TextStyle(
        color: isSelected ? activeColor : ThemeService.textSecondary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? activeColor : ThemeService.border,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
    );
  }

  Widget _buildEmptyState(List<Map<String, dynamic>> allDocs) {
    final resolvedCount = allDocs.where((r) => (r['status'] ?? '').toString().toLowerCase() == 'resolved').length;

    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: ThemeService.card, shape: BoxShape.circle, border: Border.all(color: ThemeService.border)),
                child: Icon(Icons.search_off_rounded, color: ThemeService.textSecondary, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'No reports matching "$_searchQuery"',
                style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Try searching by different username, reason, or clear filter.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedStatusFilter == 'pending') {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'No pending reports. Clean system! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF00FF88),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All user violation & dispute reports have been resolved.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 12.5),
              ),
              if (resolvedCount > 0) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedStatusFilter = 'resolved'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeService.card,
                    foregroundColor: const Color(0xFF00FF88),
                    side: const BorderSide(color: Color(0xFF00FF88)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(
                    'View Resolved Reports ($resolvedCount)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: ThemeService.card, shape: BoxShape.circle, border: Border.all(color: ThemeService.border)),
              child: Icon(Icons.inbox_rounded, color: ThemeService.textSecondary, size: 40),
            ),
            const SizedBox(height: 14),
            Text(
              _selectedStatusFilter == 'resolved' ? 'No resolved reports yet' : 'No reports found',
              style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> data) {
    final reportId = (data['id'] ?? '').toString();
    final reporterName = (data['reporter_username'] ?? 'Player').toString();
    final reason = (data['reason'] ?? 'Report').toString();
    final targetType = (data['target_type'] ?? 'item').toString();
    final targetId = (data['target_id'] ?? '').toString();
    final targetContent = (data['target_content'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString().toLowerCase();

    DateTime? createdAt;
    if (data['created_at'] != null) {
      createdAt = DateTime.tryParse(data['created_at'].toString());
    }
    final formattedDate = createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) : 'Recent';

    final isPending = status == 'pending';
    final isResolved = status == 'resolved';

    final statusColor = isResolved
        ? const Color(0xFF00FF88)
        : (isPending ? const Color(0xFFFF8A00) : const Color(0xFFFF4655));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending ? const Color(0xFFFF8A00).withOpacity(0.4) : ThemeService.border,
          width: isPending ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Type, Status, Date, Delete
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4655).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.5)),
                ),
                child: Text(
                  targetType.toUpperCase(),
                  style: const TextStyle(color: Color(0xFFFF4655), fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isResolved ? Icons.check_circle_rounded : (isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded),
                      color: statusColor,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                formattedDate,
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 11),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4655), size: 18),
                tooltip: 'Delete Report',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () => _confirmDeleteReport(reportId),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Reporter info
          Row(
            children: [
              Icon(Icons.person_pin_rounded, color: const Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Reported by: $reporterName',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Reason Box
          if (reason.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ThemeService.border.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8A00), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(color: ThemeService.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Target Content
          if (targetContent.isNotEmpty) ...[
            Text('Reported Content / Details:', style: TextStyle(color: ThemeService.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeService.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ThemeService.border),
              ),
              child: Text(
                targetContent,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 12),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Footer info & Action Buttons
          Row(
            children: [
              if (targetId.isNotEmpty)
                Text(
                  'Target ID: ${targetId.length > 8 ? targetId.substring(0, 8) : targetId}',
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 10, fontFamily: 'monospace'),
                ),
              const Spacer(),
              if (isPending) ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF4655),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: const Text('Dismiss', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _updateReportStatus(reportId, 'dismissed'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: const Text('Resolve ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                  onPressed: () => _updateReportStatus(reportId, 'resolved'),
                ),
              ] else ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8A00),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 14),
                  label: const Text('Re-open (Pending)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  onPressed: () => _updateReportStatus(reportId, 'pending'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    try {
      await SupabaseService.client
          .from('reports')
          .update({
            'status': newStatus,
          })
          .eq('id', reportId);

      final idx = SupabaseService.cachedReports.indexWhere((r) => r['id'].toString() == reportId);
      if (idx != -1) {
        SupabaseService.cachedReports[idx]['status'] = newStatus;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'resolved' ? 'Report resolved successfully! ✓' : 'Report status: $newStatus'),
            backgroundColor: const Color(0xFF00FF88),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('updated_at')) {
        final idx = SupabaseService.cachedReports.indexWhere((r) => r['id'].toString() == reportId);
        if (idx != -1) {
          SupabaseService.cachedReports[idx]['status'] = newStatus;
        }
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report resolved! (Run SQL: ALTER TABLE reports ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();)'),
              backgroundColor: Color(0xFF00FF88),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating report: $e'), backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  Future<void> _confirmDeleteReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete Report?', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to delete this report record permanently?', style: TextStyle(color: ThemeService.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655), foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await SupabaseService.deleteReport(reportId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Report deleted successfully' : 'Failed to delete report'),
          backgroundColor: ok ? const Color(0xFFFF4655) : const Color(0xFFFF4655),
        ),
      );
    }
  }

  Future<void> _showCreateTestReportDialog() async {
    final reasonController = TextEditingController(text: 'Violation of Community Guidelines');
    final contentController = TextEditingController(text: 'Suspicious in-game behavior / offensive comments');
    String targetType = 'post';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Create Test Report', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: targetType,
                dropdownColor: ThemeService.card,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Target Type',
                  labelStyle: TextStyle(color: ThemeService.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: ['post', 'comment', 'match', 'user'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                onChanged: (v) => setDlgState(() => targetType = v ?? 'post'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Reason',
                  labelStyle: TextStyle(color: ThemeService.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentController,
                maxLines: 2,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Reported Content',
                  labelStyle: TextStyle(color: ThemeService.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final curUser = SupabaseService.client.auth.currentUser;
                await SupabaseService.client.from('reports').insert({
                  'reporter_id': curUser?.id,
                  'reporter_username': curUser?.email?.split('@').first ?? 'Admin',
                  'target_type': targetType,
                  'reason': reasonController.text.trim(),
                  'target_content': contentController.text.trim(),
                  'status': 'pending',
                  'created_at': DateTime.now().toIso8601String(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test pending report created!'), backgroundColor: Color(0xFF00FF88)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
              child: const Text('Create Report', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
