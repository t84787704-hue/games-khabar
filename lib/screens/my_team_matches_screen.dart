import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/team_match_model.dart';
import '../services/team_match_service.dart';
import 'team_match_room_screen.dart';

class MyTeamMatchesScreen extends StatefulWidget {
  const MyTeamMatchesScreen({super.key});

  @override
  State<MyTeamMatchesScreen> createState() => _MyTeamMatchesScreenState();
}

class _MyTeamMatchesScreenState extends State<MyTeamMatchesScreen>
    with SingleTickerProviderStateMixin {
  final TeamMatchService _matchService = TeamMatchService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFFB020);
      case 'Accepted':
        return const Color(0xFF00FF88);
      case 'Live':
        return const Color(0xFFFF4655);
      case 'Proof Submitted':
        return const Color(0xFF38BDF8);
      case 'Verified':
        return const Color(0xFF00FF88);
      case 'Disputed':
        return const Color(0xFFFF4655);
      case 'Rejected':
      case 'Cancelled':
        return Colors.grey;
      default:
        return const Color(0xFFFF6B00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        title: const Row(
          children: [
            Text('⚔️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'TEAM MATCHES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B00),
          labelColor: const Color(0xFFFF6B00),
          unselectedLabelColor: const Color(0xFF8B949E),
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.flash_on_rounded, size: 18),
              text: 'Active Matches',
            ),
            Tab(
              icon: Icon(Icons.history_rounded, size: 18),
              text: 'Match History',
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<TeamMatch>>(
        stream: _matchService.getUserTeamMatchesStream(currentUid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
            );
          }

          final allMatches = snapshot.data ?? [];

          // Separate active vs history matches
          // Active: Pending, Accepted, Live, Proof Submitted, Disputed
          // History: Verified, Rejected, Cancelled
          final activeMatches = allMatches.where((m) => m.isActive).toList();
          final historyMatches = allMatches.where((m) => m.isHistory).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildMatchList(
                matches: activeMatches,
                currentUid: currentUid,
                emptyTitle: 'No Active Matches',
                emptySubtitle:
                    'فی الوقت کوئی ایکٹو چیلنج یا لائیو میچ نہیں ہے۔ نئی ٹیموں کو چیلنج بھیجیں!',
                isActiveTab: true,
              ),
              _buildMatchList(
                matches: historyMatches,
                currentUid: currentUid,
                emptyTitle: 'No Match History',
                emptySubtitle:
                    'مکمل ہو چکے اور سابقہ میچز کا ریکارڈ یہاں نظر آئے گا۔',
                isActiveTab: false,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchList({
    required List<TeamMatch> matches,
    required String currentUid,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isActiveTab,
  }) {
    if (matches.isEmpty) {
      return Center(
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
                child: Text(
                  isActiveTab ? '⚔️' : '📜',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        final statusColor = _getStatusColor(match.status);
        final isTeam1Leader = match.isTeam1Leader(currentUid);
        final isTeam2Leader = match.isTeam2Leader(currentUid);
        final isLeader = isTeam1Leader || isTeam2Leader;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamMatchRoomScreen(matchId: match.matchId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF131A29),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: match.isLive
                    ? const Color(0xFFFF4655).withOpacity(0.5)
                    : const Color(0xFF2A3447),
                width: match.isLive ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Game & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${match.game} • ${match.mode}',
                        style: const TextStyle(
                          color: Color(0xFFFF6B00),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (match.isLive) ...[
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor),
                          ),
                          child: Text(
                            match.status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Teams Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match.team1Name,
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
                        match.team2Name,
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
                ),
                const SizedBox(height: 12),

                // Footer Row: Match Time & Buttons
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
                          DateFormat('dd MMM, hh:mm a').format(match.matchTime),
                          style: const TextStyle(
                            color: Color(0xFF8B949E),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // If Pending and user is Team 1 leader, allow Cancel button right from card
                        if (match.isPending && isTeam1Leader) ...[
                          InkWell(
                            onTap: () => _confirmCancelChallenge(match, currentUid),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4655).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFFF4655),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    size: 12,
                                    color: Color(0xFFFF4655),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'CANCEL',
                                    style: TextStyle(
                                      color: Color(0xFFFF4655),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // If Live, show Open Room badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: match.isLive
                                ? const Color(0xFFFF4655).withOpacity(0.18)
                                : const Color(0xFF00FF88).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: match.isLive
                                  ? const Color(0xFFFF4655)
                                  : const Color(0xFF00FF88),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                match.isLive ? 'OPEN LIVE ROOM' : 'OPEN ROOM',
                                style: TextStyle(
                                  color: match.isLive
                                      ? const Color(0xFFFF4655)
                                      : const Color(0xFF00FF88),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: match.isLive
                                    ? const Color(0xFFFF4655)
                                    : const Color(0xFF00FF88),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmCancelChallenge(TeamMatch match, String currentUid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655), size: 22),
            SizedBox(width: 8),
            Text(
              'چیلنج Cancel کریں؟',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'کیا آپ واقعی ${match.team2Name} کو بھیجا گیا چیلنج Cancel کرنا چاہتے ہیں؟',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _matchService.cancelChallenge(
                match.matchId,
                cancelledByUid: currentUid,
              );
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('چیلنج کامیابی سے Cancel ہو گیا!'),
                      backgroundColor: Color(0xFFFF6B00),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('چیلنج Cancel کرنے میں خرابی ہوئی'),
                      backgroundColor: Color(0xFFFF4655),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Cancel Challenge',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
