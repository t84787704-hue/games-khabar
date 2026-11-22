// ===============================================================================
// ADMIN REWARD CLAIMS & UC REQUESTS TAB — Connected to public.reward_claims
// Supports Delivery Proof Screenshot Upload to 'reward-proofs' Storage Bucket
// File: lib/screens/admin/admin_uc_requests_tab.dart
// ===============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/team_service.dart';
import '../../services/theme_service.dart';

class AdminUcRequestsTab extends StatefulWidget {
  const AdminUcRequestsTab({super.key});

  @override
  State<AdminUcRequestsTab> createState() => AdminUcRequestsTabState();
}

class AdminUcRequestsTabState extends State<AdminUcRequestsTab> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _searchQuery = '';
  String _statusFilter = 'pending'; // 'pending', 'delivered', 'rejected', 'all'
  final Set<String> _processingIds = {};
  final Set<String> _uploadingProofIds = {};
  final Map<String, String> _uploadedProofUrls = {};
  final Map<String, Uint8List> _uploadedProofBytes = {};
  late Stream<List<Map<String, dynamic>>> _claimsStream;
  List<Map<String, dynamic>> _lastValidClaims = [];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _lastValidClaims = List<Map<String, dynamic>>.from(SupabaseService.cachedRewardClaims);
    _claimsStream = SupabaseService.getRealtimeRewardClaims();
    _refreshClaimsNow();
  }

  Future<void> _refreshClaimsNow() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final fresh = await SupabaseService.fetchRewardClaims();
      if (mounted && (fresh.isNotEmpty || _lastValidClaims.isEmpty)) {
        setState(() {
          _lastValidClaims = List<Map<String, dynamic>>.from(fresh);
        });
      }
    } catch (_) {
    } finally {
      _isRefreshing = false;
    }
  }

  String _normalizeStatus(dynamic raw) {
    final s = (raw ?? 'pending').toString().trim().toLowerCase();
    if (s.isEmpty || s == 'null' || s.contains('pending') || s == 'processing' || s == 'waiting') {
      return 'pending';
    }
    if (s.contains('deliver') || s == 'approved' || s == 'completed' || s == 'sent') {
      return 'delivered';
    }
    if (s.contains('reject') || s == 'declined' || s == 'cancelled') {
      return 'rejected';
    }
    return s;
  }

  void _upsertLocalClaim(Map<String, dynamic> updatedClaim) {
    SupabaseService.upsertCachedRewardClaim(updatedClaim);
    final String targetKey = _claimKey(updatedClaim);
    final nextList = List<Map<String, dynamic>>.from(_lastValidClaims);
    final idx = nextList.indexWhere((c) => _claimKey(c) == targetKey);
    if (idx >= 0) {
      nextList[idx] = {...nextList[idx], ...updatedClaim};
    } else {
      nextList.insert(0, Map<String, dynamic>.from(updatedClaim));
    }
    _lastValidClaims = nextList;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _claimKey(Map<String, dynamic> claim) {
    final id = (claim['id'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    return (claim['claim_code'] ?? '').toString().trim();
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

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied: $text'),
        backgroundColor: const Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Picks a proof screenshot from device gallery and uploads to Supabase Storage bucket `reward-proofs`.
  Future<String?> _pickAndUploadProofScreenshot(
    Map<String, dynamic> claim, {
    void Function(void Function())? setDialogState,
  }) async {
    final String key = _claimKey(claim);
    final String claimId = (claim['id'] ?? '').toString().trim();
    final String claimCode = (claim['claim_code'] ?? 'RW').toString().trim();

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return null;

      if (mounted) {
        setState(() => _uploadingProofIds.add(key));
      }
      setDialogState?.call(() {});

      final Uint8List bytes = await picked.readAsBytes();
      final String rawExt = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : 'jpg';
      final String ext = (rawExt == 'png' || rawExt == 'webp' || rawExt == 'jpg' || rawExt == 'jpeg')
          ? rawExt
          : 'jpg';
      final String safeCode = claimCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      final int ts = DateTime.now().millisecondsSinceEpoch;
      final String storagePath = 'proofs/${safeCode.isEmpty ? 'claim' : safeCode}_$ts.$ext';

      await SupabaseService.client.storage.from('reward-proofs').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _getMimeType(ext),
            ),
          );

      final String publicUrl =
          SupabaseService.client.storage.from('reward-proofs').getPublicUrl(storagePath);

      if (mounted) {
        setState(() {
          _uploadedProofUrls[key] = publicUrl;
          _uploadedProofBytes[key] = bytes;
          _upsertLocalClaim({...claim, 'proof_image_url': publicUrl});
        });
      }
      setDialogState?.call(() {});

      // Also persist proof_image_url on the claim record immediately so it's never lost
      try {
        if (claimId.isNotEmpty) {
          await SupabaseService.client
              .from('reward_claims')
              .update({'proof_image_url': publicUrl}).eq('id', claimId);
        } else if (claimCode.isNotEmpty) {
          await SupabaseService.client
              .from('reward_claims')
              .update({'proof_image_url': publicUrl}).eq('claim_code', claimCode);
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Delivery proof screenshot uploaded successfully!'),
            backgroundColor: Color(0xFF00FF88),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload proof screenshot: $e'),
            backgroundColor: const Color(0xFFFF4655),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _uploadingProofIds.remove(key));
      }
      setDialogState?.call(() {});
    }
  }

  void _showFullScreenProofDialog({
    required String imageUrl,
    Uint8List? memoryBytes,
    required String claimCode,
    required String playerUid,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Stack(
          children: [
            Column(
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
                    child: memoryBytes != null
                        ? Image.memory(memoryBytes, fit: BoxFit.contain)
                        : Image.network(
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
          ],
        ),
      ),
    );
  }

  Future<void> _updateClaimStatus({
    required Map<String, dynamic> claim,
    required String newStatus,
  }) async {
    final String key = _claimKey(claim);
    final String claimId = (claim['id'] ?? '').toString().trim();
    final String claimCode = (claim['claim_code'] ?? '#RW').toString().trim();
    final String userId = (claim['user_id'] ?? '').toString().trim();
    final String playerUid = (claim['player_uid'] ?? '').toString().trim();
    final String playerIgn = (claim['player_ign'] ?? '').toString().trim();
    final String gameName = _formatGameName((claim['game_name'] ?? '').toString());
    final String rewardLabel = (claim['reward_label'] ?? '').toString();
    final int shareAmountPkr = (claim['share_amount_pkr'] as num?)?.toInt() ?? 375;
    final String existingNote = (claim['admin_note'] ?? '').toString();

    final noteController = TextEditingController(text: existingNote);
    final bool isDelivering = newStatus == 'delivered';

    final String? adminNote = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final String currentProofUrl =
              _uploadedProofUrls[key] ?? (claim['proof_image_url'] ?? '').toString().trim();
          final Uint8List? currentProofBytes = _uploadedProofBytes[key];
          final bool isUploadingProof = _uploadingProofIds.contains(key);

          return AlertDialog(
            backgroundColor: ThemeService.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDelivering ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                width: 1.3,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  isDelivering ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isDelivering ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDelivering ? 'Mark Claim as Delivered' : 'Reject Reward Claim',
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ThemeService.cardSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ThemeService.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Claim: $claimCode • $gameName',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Player UID: $playerUid${playerIgn.isNotEmpty ? ' ($playerIgn)' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF00FF88),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Share: ${NumberFormat('#,###').format(shareAmountPkr)} PKR ($rewardLabel)',
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDelivering) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Delivery Proof Screenshot (Optional but Recommended):',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (currentProofUrl.isNotEmpty || currentProofBytes != null) ...[
                      GestureDetector(
                        onTap: () => _showFullScreenProofDialog(
                          imageUrl: currentProofUrl,
                          memoryBytes: currentProofBytes,
                          claimCode: claimCode,
                          playerUid: playerUid,
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            color: ThemeService.cardSecondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (currentProofBytes != null)
                                  Image.memory(currentProofBytes, fit: BoxFit.cover)
                                else
                                  Image.network(
                                    currentProofUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        'Proof Attached ✓',
                                        style: TextStyle(color: ThemeService.textPrimary),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 13),
                                        SizedBox(width: 4),
                                        Text(
                                          'Proof Attached',
                                          style: TextStyle(
                                            color: Color(0xFF00FF88),
                                            fontSize: 10.5,
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
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isUploadingProof
                            ? null
                            : () => _pickAndUploadProofScreenshot(
                                  claim,
                                  setDialogState: setDialogState,
                                ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF38BDF8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: isUploadingProof
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF38BDF8),
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_rounded, size: 18),
                        label: Text(
                          isUploadingProof
                              ? 'Uploading Proof Screenshot...'
                              : (currentProofUrl.isNotEmpty
                                  ? 'Change Proof Screenshot'
                                  : 'Upload Proof Screenshot'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Admin Note (Optional)',
                      hintText: isDelivering
                          ? 'e.g. Top-up completed to UID $playerUid'
                          : 'e.g. Invalid Player UID provided',
                      labelStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                      hintStyle: TextStyle(color: ThemeService.textSecondary.withOpacity(0.7), fontSize: 12),
                      filled: true,
                      fillColor: ThemeService.cardSecondary,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDelivering ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
                  foregroundColor: isDelivering ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  isDelivering ? Icons.done_all_rounded : Icons.block_rounded,
                  size: 16,
                ),
                label: Text(
                  isDelivering ? 'Confirm Delivered' : 'Confirm Reject',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                ),
                onPressed: isUploadingProof
                    ? null
                    : () => Navigator.pop(ctx, noteController.text.trim()),
              ),
            ],
          );
        },
      ),
    );

    if (adminNote == null) return;

    final String finalProofUrl =
        _uploadedProofUrls[key] ?? (claim['proof_image_url'] ?? '').toString().trim();

    setState(() => _processingIds.add(key));
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final Map<String, dynamic> updatePayload = {
        'status': newStatus,
        if (isDelivering) 'delivered_at': nowIso,
        if (adminNote.isNotEmpty) 'admin_note': adminNote,
        if (finalProofUrl.isNotEmpty) 'proof_image_url': finalProofUrl,
      };

      if (claimId.isNotEmpty) {
        await SupabaseService.client
            .from('reward_claims')
            .update(updatePayload)
            .eq('id', claimId);
      } else {
        await SupabaseService.client
            .from('reward_claims')
            .update(updatePayload)
            .eq('claim_code', claimCode);
      }

      _upsertLocalClaim({...claim, ...updatePayload});
      if (isDelivering) {
        TeamService().invalidateWeeklyCaches();
      }

      if (userId.isNotEmpty) {
        try {
          await NotificationService().createNotification(
            userId: userId,
            title: isDelivering
                ? 'Reward Sent! 🎁 ($claimCode)'
                : 'Reward Claim Update ($claimCode)',
            body: isDelivering
                ? 'Reward Sent! آپ کا ریوارڈ بھیج دیا گیا ہے — براہِ کرم اپنا گیم اکاؤنٹ چیک کر لیں۔ (Claim: $claimCode • Game UID: $playerUid)'
                : 'Your reward claim $claimCode status was updated to $newStatus.${adminNote.isNotEmpty ? ' Note: $adminNote' : ''}',
            type: 'reward_claim_$newStatus',
          );
        } catch (_) {}
      }

      if (mounted) {
        setState(() {});
        _refreshClaimsNow();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDelivering
                  ? '✅ Claim $claimCode marked as DELIVERED!${finalProofUrl.isNotEmpty ? ' (Proof Saved)' : ''}'
                  : 'Claim $claimCode marked as REJECTED.',
            ),
            backgroundColor: isDelivering ? const Color(0xFF00FF88) : const Color(0xFFFF4655),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating reward claim: $e'),
            backgroundColor: const Color(0xFFFF4655),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _claimsStream,
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            (snapshot.data!.isNotEmpty || _lastValidClaims.isEmpty)) {
          _lastValidClaims = List<Map<String, dynamic>>.from(snapshot.data!);
        }

        final list = _lastValidClaims.isNotEmpty
            ? _lastValidClaims
            : (snapshot.data ?? const <Map<String, dynamic>>[]);

        int pendingCount = 0;
        int deliveredCount = 0;
        int rejectedCount = 0;
        for (final c in list) {
          final st = _normalizeStatus(c['status']);
          if (st == 'delivered') {
            deliveredCount++;
          } else if (st == 'rejected') {
            rejectedCount++;
          } else {
            pendingCount++;
          }
        }

        final filtered = list.where((claim) {
          final status = _normalizeStatus(claim['status']);
          if (_statusFilter != 'all' && status != _statusFilter) {
            return false;
          }
          if (_searchQuery.isNotEmpty) {
            final code = (claim['claim_code'] ?? '').toString().toLowerCase();
            final uid = (claim['player_uid'] ?? '').toString().toLowerCase();
            final ign = (claim['player_ign'] ?? '').toString().toLowerCase();
            final team = (claim['team_name'] ?? '').toString().toLowerCase();
            final game = (claim['game_name'] ?? '').toString().toLowerCase();
            final week = (claim['week_key'] ?? '').toString().toLowerCase();
            final matches = code.contains(_searchQuery) ||
                uid.contains(_searchQuery) ||
                ign.contains(_searchQuery) ||
                team.contains(_searchQuery) ||
                game.contains(_searchQuery) ||
                week.contains(_searchQuery);
            if (!matches) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: ThemeService.bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search by Claim Code, Player UID, IGN, Team, or Week...',
                            hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 12.5),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFFD700), size: 18),
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Refresh Claims',
                        onPressed: _refreshClaimsNow,
                        icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00FF88)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          '⏳ Pending ($pendingCount)',
                          'pending',
                          const Color(0xFFFFB800),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          '✅ Delivered ($deliveredCount)',
                          'delivered',
                          const Color(0xFF00FF88),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          '❌ Rejected ($rejectedCount)',
                          'rejected',
                          const Color(0xFFFF4655),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          '📋 All Claims (${list.length})',
                          'all',
                          const Color(0xFF38BDF8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: (snapshot.connectionState == ConnectionState.waiting &&
                      _lastValidClaims.isEmpty &&
                      !snapshot.hasData)
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                    )
                  : filtered.isEmpty
                      ? Center(
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
                                  child: const Icon(
                                    Icons.card_giftcard_rounded,
                                    color: Color(0xFFFFD700),
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No ${_statusFilter == 'all' ? '' : _statusFilter} reward claims found',
                                  style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index < 0 || index >= filtered.length) {
                              return const SizedBox.shrink();
                            }
                            final claim = filtered[index];
                            return _buildClaimCard(claim);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String key, Color color) {
    final isSelected = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = key),
      selectedColor: color.withOpacity(0.2),
      backgroundColor: ThemeService.card,
      labelStyle: TextStyle(
        color: isSelected ? color : ThemeService.textSecondary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : ThemeService.border,
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final String key = _claimKey(claim);
    final String claimCode = (claim['claim_code'] ?? '#RW').toString();
    final String rawGame = (claim['game_name'] ?? 'free_fire').toString();
    final String gameLabel = _formatGameName(rawGame);
    final String playerUid = (claim['player_uid'] ?? 'N/A').toString();
    final String playerIgn = (claim['player_ign'] ?? '').toString();
    final String teamName = (claim['team_name'] ?? 'Rank #1 Team').toString();
    final String weekKey = (claim['week_key'] ?? '').toString();
    final String rewardLabel = (claim['reward_label'] ?? '').toString();
    final int shareAmountPkr = (claim['share_amount_pkr'] as num?)?.toInt() ?? 375;
    final String status = _normalizeStatus(claim['status']);
    final String adminNote = (claim['admin_note'] ?? '').toString();
    final String proofUrl =
        _uploadedProofUrls[key] ?? (claim['proof_image_url'] ?? '').toString().trim();
    final Uint8List? proofBytes = _uploadedProofBytes[key];

    final DateTime? createdAt = DateTime.tryParse((claim['created_at'] ?? '').toString());
    final DateTime? deliveredAt = DateTime.tryParse((claim['delivered_at'] ?? '').toString());

    final bool isDelivered = status == 'delivered';
    final bool isRejected = status == 'rejected';
    final bool isProcessing = _processingIds.contains(key);
    final bool isUploadingProof = _uploadingProofIds.contains(key);

    final Color statusColor = isDelivered
        ? const Color(0xFF00FF88)
        : (isRejected ? const Color(0xFFFF4655) : const Color(0xFFFFB800));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Claim Code + Copy + Game Badge + Status Badge
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.45)),
                    ),
                    child: Text(
                      claimCode,
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _copyToClipboard(claimCode, 'Claim Code'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: ThemeService.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      gameLabel,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  isDelivered
                      ? '✅ DELIVERED'
                      : (isRejected ? '❌ REJECTED' : '⏳ PENDING'),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Player UID + 1-Click Copy Button + IGN
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ThemeService.cardSecondary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ThemeService.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.videogame_asset_rounded, color: Color(0xFF00FF88), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Player Game UID: $playerUid',
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                            ),
                          ),
                          if (playerIgn.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'In-Game Name (IGN): $playerIgn',
                              style: TextStyle(
                                color: ThemeService.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _copyToClipboard(playerUid, 'Player UID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88).withOpacity(0.18),
                        foregroundColor: const Color(0xFF00FF88),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFF00FF88), width: 1),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 13),
                      label: const Text(
                        'Copy UID',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: ThemeService.border),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      '🛡️ Team: $teamName',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '💰 Share: ${NumberFormat('#,###').format(shareAmountPkr)} PKR (of 1,500 PKR)',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (rewardLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '🎁 Reward: $rewardLabel',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (weekKey.isNotEmpty)
                      Text(
                        '📅 Week Key: $weekKey',
                        style: TextStyle(
                          color: ThemeService.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (createdAt != null)
                      Text(
                        '🕒 Claimed: ${DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toLocal())}',
                        style: TextStyle(
                          color: ThemeService.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    if (deliveredAt != null)
                      Text(
                        '✅ Delivered: ${DateFormat('dd MMM yyyy, hh:mm a').format(deliveredAt.toLocal())}',
                        style: const TextStyle(
                          color: Color(0xFF00FF88),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                if (adminNote.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📝 Admin Note: $adminNote',
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                // Delivery Proof Preview inside Card (if attached/uploaded)
                if (proofUrl.isNotEmpty || proofBytes != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.photo_camera_back_rounded, color: Color(0xFF00FF88), size: 15),
                          SizedBox(width: 5),
                          Text(
                            'Delivery Proof Screenshot Attached:',
                            style: TextStyle(
                              color: Color(0xFF00FF88),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: isUploadingProof
                            ? null
                            : () => _pickAndUploadProofScreenshot(claim),
                        icon: const Icon(Icons.edit_rounded, size: 13, color: Color(0xFF38BDF8)),
                        label: const Text(
                          'Replace',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showFullScreenProofDialog(
                      imageUrl: proofUrl,
                      memoryBytes: proofBytes,
                      claimCode: claimCode,
                      playerUid: playerUid,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 125,
                      decoration: BoxDecoration(
                        color: ThemeService.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (proofBytes != null)
                              Image.memory(proofBytes, fit: BoxFit.cover)
                            else
                              Image.network(
                                proofUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    'Tap to View Delivery Proof',
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap to Enlarge',
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
          ),

          const SizedBox(height: 10),
          // Upload Proof Screenshot button directly on card
          if (proofUrl.isEmpty && proofBytes == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isUploadingProof
                      ? null
                      : () => _pickAndUploadProofScreenshot(claim),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isUploadingProof
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF38BDF8),
                          ),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded, size: 17),
                  label: Text(
                    isUploadingProof
                        ? 'Uploading Proof Screenshot...'
                        : 'Upload Proof Screenshot',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ),
            ),

          if (!isDelivered)
            Row(
              children: [
                if (!isRejected) ...[
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: (isProcessing || isUploadingProof)
                          ? null
                          : () => _updateClaimStatus(
                                claim: claim,
                                newStatus: 'rejected',
                              ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4655),
                        side: const BorderSide(color: Color(0xFFFF4655)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        'Reject',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: (isProcessing || isUploadingProof)
                        ? null
                        : () => _updateClaimStatus(
                              claim: claim,
                              newStatus: 'delivered',
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 17),
                    label: Text(
                      isProcessing ? 'Updating...' : 'Mark as Delivered',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}