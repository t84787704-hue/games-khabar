import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../models/team_model.dart';
import 'team_match_room_screen.dart';

class MyTeamMatchesScreen extends StatefulWidget {
  const MyTeamMatchesScreen({super.key});

  @override
  State<MyTeamMatchesScreen> createState() => _MyTeamMatchesScreenState();
}

class _MyTeamMatchesScreenState extends State<MyTeamMatchesScreen> {
  final TeamService _teamService = TeamService();
  bool _isLoading = false;

  Future<void> _refresh() async {
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('⚔️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'TEAM MATCHES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF6B00),
        backgroundColor: const Color(0xFF131A29),
        onRefresh: _refresh,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: SupabaseService.client
              .from('active_matches')
              .stream(primaryKey: ['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
              );
            }

            final allMatches = snapshot.data ?? [];
            // Filter strictly: status in ['active', 'under_review']
            final activeMatches = allMatches.where((m) {
              final status = (m['status'] ?? '').toString().toLowerCase();
              return status == 'active' || status == 'under_review';
            }).toList();

            // Sort by created_at ascending (desc: false)
            activeMatches.sort((a, b) {
              final aDate = a['created_at']?.toString() ?? '';
              final bDate = b['created_at']?.toString() ?? '';
              return aDate.compareTo(bDate);
            });

            if (activeMatches.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161F2E),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF2A3447)),
                          ),
                          child: const Text('⚔️', style: TextStyle(fontSize: 40)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Active Matches',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'فی الوقت کوئی ایکٹو چیلنج یا لائیو میچ نہیں ہے۔ نئی ٹیموں کو چیلنج بھیجیں!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: activeMatches.length,
              itemBuilder: (context, index) {
                final match = activeMatches[index];
                return _buildActiveMatchCard(match);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveMatchCard(Map<String, dynamic> match) {
    final matchId = match['id']?.toString() ?? '';
    final t1 = (match['team1_id'] ?? '').toString();
    final t2 = (match['team2_id'] ?? '').toString();
    final status = (match['status'] ?? '').toString().toLowerCase();
    final proofStatus = (match['proof_status'] ?? '').toString().toLowerCase();
    final adminNote = match['admin_note']?.toString();
    final game = match['game']?.toString() ?? 'BGMI';
    final mode = match['mode']?.toString() ?? '4v4';

    final int attempts = (match['proof_attempts'] as num?)?.toInt() ??
        (proofStatus == 'rejected' ? 2 : (status == 'under_review' ? 1 : 0));

    DateTime matchDate = DateTime.now();
    final dateRaw = match['created_at'];
    if (dateRaw != null) {
      try {
        matchDate = DateTime.parse(dateRaw.toString()).toLocal();
      } catch (_) {}
    }

    // Badge configuration
    String badgeText = 'LIVE';
    Color badgeColor = const Color(0xFFFF4655);
    if (status == 'under_review') {
      if (proofStatus == 'rejected') {
        badgeText = 'PROOF REJECTED';
        badgeColor = const Color(0xFFFF4655);
      } else {
        badgeText = 'PROOF SUBMITTED';
        badgeColor = const Color(0xFF38BDF8);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131A29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badgeColor.withOpacity(0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: BGMI • 4v4 badge & Status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.4)),
                ),
                child: Text(
                  '$game • $mode',
                  style: const TextStyle(
                    color: Color(0xFFFF6B00),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              Row(
                children: [
                  if (status == 'active') ...[
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF4655),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeColor),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Teams Row: Team1 VS Team2 (e.g. Jf19 VS J17)
          FutureBuilder<List<TeamModel?>>(
            future: Future.wait([
              _teamService.getTeam(t1),
              _teamService.getTeam(t2),
            ]),
            builder: (context, snap) {
              final t1Name = snap.data?[0]?.name ?? match['team1_name'] ?? 'Team 1';
              final t2Name = snap.data?[1]?.name ?? match['team2_name'] ?? 'Team 2';

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      t1Name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Color(0xFFFF4655),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      t2Name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),

          // Proof Under Review / Attempts Box
          if (status == 'under_review') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F141E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: proofStatus == 'rejected'
                      ? const Color(0xFFFF4655).withOpacity(0.3)
                      : const Color(0xFF38BDF8).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Proof Attempts: 1/2 or 2/2 Max limit reached
                  Row(
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 13,
                        color: attempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFFB020),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Proof Attempts: $attempts/2 ${attempts >= 2 ? "(Max limit reached)" : ""}',
                        style: TextStyle(
                          color: attempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFFB020),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Urdu text
                  Row(
                    children: [
                      Icon(
                        proofStatus == 'rejected' ? Icons.info_outline : Icons.hourglass_top_rounded,
                        size: 13,
                        color: proofStatus == 'rejected' ? const Color(0xFFFF4655) : const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          proofStatus == 'rejected'
                              ? (adminNote != null && adminNote.isNotEmpty
                                  ? 'ثبوت مسترد: $adminNote - براہ کرم نیا ثبوت اپلوڈ کریں'
                                  : 'آپ کا ثبوت مسترد ہو گیا ہے، براہ کرم نیا ثبوت اپلوڈ کریں')
                              : 'آپ کا نیا ثبوت ایڈمن کے پاس چلا گیا ہے، براہ کرم انتظار کریں',
                          style: TextStyle(
                            color: proofStatus == 'rejected' ? const Color(0xFFFF4655) : const Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Footer: Date & OPEN ROOM button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Color(0xFF8B949E),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(matchDate),
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamMatchRoomScreen(matchId: matchId),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4655),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.meeting_room_rounded, size: 14),
                label: const Text(
                  'OPEN ROOM',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
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
