import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/supabase_service.dart';
import '../services/gamer_auth_service.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../services/lfg_service.dart';
import '../widgets/gamer_avatar.dart';

class RequestsScreen extends StatefulWidget {
  final String postId;
  final SquadPost? squad;

  const RequestsScreen({
    super.key,
    required this.postId,
    this.squad,
  });

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final LfgService _lfgService = LfgService();

  Stream<Map<String, dynamic>?> _postStream() async* {
    while (true) {
      Map<String, dynamic>? data;
      try {
        data = await SupabaseService.client
            .from('lfg_posts')
            .select()
            .eq('id', widget.postId)
            .maybeSingle();
      } catch (_) {}
      yield data;
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  final Set<String> _processingUids = {};

  Future<void> _handleAccept(String requesterUid, Map<String, dynamic> userData, SquadPost? currentSquad) async {
    setState(() => _processingUids.add(requesterUid));
    try {
      final name = (userData['displayName'] ?? userData['bgmiName'] ?? userData['tag'] ?? 'Gamer').toString();
      await _lfgService.acceptRequest(
        postId: widget.postId,
        requesterId: requesterUid,
        requestDocId: requesterUid,
        requesterName: name,
        leaderUid: currentSquad?.userId ?? GamerAuthService().currentUid ?? '',
        inGameUid: currentSquad?.inGameUid ?? '',
        mode: currentSquad?.mode ?? 'Classic Squad',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('msg_player_added_to_squad'.tr(args: [name])),
            backgroundColor: GamerTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_failed_to_accept'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingUids.remove(requesterUid));
      }
    }
  }

  Future<void> _handleReject(String requesterUid) async {
    setState(() => _processingUids.add(requesterUid));
    try {
      await _lfgService.rejectRequest(
        postId: widget.postId,
        requesterId: requesterUid,
        requestDocId: requesterUid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('msg_request_rejected'.tr()),
            backgroundColor: GamerTheme.cardDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_failed_to_reject'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingUids.remove(requesterUid));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.cardDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: GamerTheme.textWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'title_join_requests'.tr(),
          style: const TextStyle(
            color: GamerTheme.textWhite,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _postStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: GamerTheme.accentOrange));
          }

          final postData = snapshot.data ?? {};
          if (postData.isEmpty) {
            return Center(
              child: Text(
                'err_squad_post_not_found'.tr(),
                style: const TextStyle(color: GamerTheme.textMuted),
              ),
            );
          }

          final List<String> joinRequests = List<String>.from(postData['joinRequests'] ?? []);
          final squad = SquadPost.fromSupabase(postData);

          if (joinRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: GamerTheme.cardElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: GamerTheme.borderLight.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.group_off_rounded, size: 36, color: GamerTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no_pending_requests_title'.tr(),
                    style: const TextStyle(
                      color: GamerTheme.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'no_pending_requests_desc'.tr(),
                    style: const TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: joinRequests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final requesterUid = joinRequests[index];
              final isProcessing = _processingUids.contains(requesterUid);

              return FutureBuilder<Map<String, dynamic>?>(
                future: SupabaseService.getUser(requesterUid),
                builder: (context, userSnap) {
                  final userData = userSnap.data ?? {};
                  final bgmiName = (userData['bgmiName'] ?? userData['displayName'] ?? 'Gamer').toString();
                  final tag = (userData['tag'] ?? userData['username'] ?? 'player').toString();
                  final avatar = (userData['avatar'] ?? userData['photoUrl'] ?? '').toString();
                  final tier = (userData['tier'] ?? userData['rank'] ?? 'Ace').toString();
                  final kd = (userData['kd'] ?? userData['kdRatio'] ?? 3.0).toString();
                  final mic = (userData['mic'] ?? userData['micMandatory'] ?? true) == true;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GamerTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: GamerTheme.borderDark),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GamerAvatar(
                              photoUrl: avatar,
                              displayName: bgmiName,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bgmiName,
                                    style: const TextStyle(
                                      color: GamerTheme.textWhite,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@$tag',
                                    style: const TextStyle(
                                      color: GamerTheme.accentOrange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.military_tech_rounded, size: 13, color: Color(0xFFFF9500)),
                                  const SizedBox(width: 4),
                                  Text(
                                    tier,
                                    style: const TextStyle(color: Color(0xFFFF9500), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF2D55).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.speed_rounded, size: 13, color: Color(0xFFFF2D55)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'kd_ratio_label'.tr(args: [kd]),
                                    style: const TextStyle(color: Color(0xFFFF2D55), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: mic ? GamerTheme.neonGreen.withOpacity(0.12) : GamerTheme.textMuted.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: mic ? GamerTheme.neonGreen.withOpacity(0.4) : GamerTheme.borderLight),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(mic ? Icons.mic_rounded : Icons.mic_off_rounded, size: 13, color: mic ? GamerTheme.neonGreen : GamerTheme.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    mic ? 'mic_on_label'.tr() : 'mic_off_label'.tr(),
                                    style: TextStyle(color: mic ? GamerTheme.neonGreen : GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GamerTheme.neonGreen,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  elevation: 0,
                                ),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      )
                                    : const Icon(Icons.check_rounded, size: 16, color: Colors.black),
                                label: Text(
                                  'btn_accept'.tr(),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black),
                                ),
                                onPressed: isProcessing ? null : () => _handleAccept(requesterUid, userData, squad),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                                label: Text(
                                  'btn_reject'.tr(),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.redAccent),
                                ),
                                onPressed: isProcessing ? null : () => _handleReject(requesterUid),
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
          );
        },
      ),
    );
  }
}
