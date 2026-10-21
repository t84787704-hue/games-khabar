// ===============================================================================
// TEAMS SCREEN — Futuristic Dark Neon Gaming Theme (Matched to Reference)
// File: lib/screens/teams_screen.dart
// ===============================================================================

import "dart:io";
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:cached_network_image/cached_network_image.dart";
import "../services/supabase_service.dart";
import "../models/team_model.dart";
import "../models/coin_wallet_model.dart";
import "../services/team_service.dart";
import "../widgets/team_card.dart";
import "../widgets/create_team_dialog.dart";
import "../widgets/end_match_dialog.dart";
import "../widgets/match_rules_dialog.dart";
import "team_matches_screen.dart";
import "team_match_room_screen.dart";
import "leaderboard_screen.dart";
import "private_match_room_screen.dart";
import "../services/coin_wallet_service.dart";
import "../services/notification_service.dart";
import "../services/language_service.dart";
import "../widgets/coin_or_ad_popup.dart";
import "../services/theme_service.dart";

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen>
    with SingleTickerProviderStateMixin {
  final TeamService _teamService = TeamService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  String _selectedGameFilter = "All";
  String _searchQuery = "";
  final List<String> _gameFilterOptions = ["All", "BGMI", "Free Fire", "PUBG", "COD", "Valorant"];

  final Set<String> _cancelledChallengeIds = {};
  final Set<String> _acceptingChallengeIds = {};
  final Set<String> _acceptedChallengeIds = {};
  final Set<String> _completedMatchIds = {};
  Map<String, String> _lastReadMatchTimes = {};
  int _teamsRetryKey = 0;
  List<TeamModel>? _cachedTeams;

  // Futuristic Gaming Theme Palette
  static const Color neonBlue = Color(0xFF00E5FF);
  static const Color neonCyan = Color(0xFF1877F2);
  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color cardBg = Color(0xFF131B2E);
  static const Color cardBorder = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLastReadTimes();
  }

  Future<void> _loadLastReadTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith("last_read_match_"));
      final map = <String, String>{};
      for (final k in keys) {
        final mId = k.replaceFirst("last_read_match_", "");
        final v = prefs.getString(k);
        if (v != null) map[mId] = v;
      }
      if (mounted) setState(() => _lastReadMatchTimes = map);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showCoinRequirementDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: cardBorder)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB800), size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: neonBlue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showProofImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: cardBorder)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('match_proof_title'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
            ),
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: neonBlue))),
                  errorWidget: (_, __, ___) => const SizedBox(height: 180, child: Center(child: Icon(Icons.broken_image, color: Colors.white30))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcceptChallenge({
    required String challengeId,
    required String fromTeamId,
    required String toTeamId,
    required bool isMyTeamFrozen,
    Map<String, dynamic>? challengeData,
  }) async {
    if (isMyTeamFrozen) {
      _showCoinRequirementDialog(
        title: 'Team Frozen',
        message: 'Your team balance is below 1,000 coins. Top up to accept challenges.',
      );
      return;
    }

    final cId = challengeId.trim();
    if (_acceptingChallengeIds.contains(cId)) return;
    setState(() => _acceptingChallengeIds.add(cId));

    try {
      final targetChallengeId = challengeData?["id"]?.toString() ?? cId;
      bool rpcSuccess = false;
      try {
        await SupabaseService.client.rpc("accept_challenge_safe", params: {"p_challenge_id": targetChallengeId});
        rpcSuccess = true;
      } catch (rpcErr) {
        debugPrint("[TeamsScreen] accept_challenge_safe RPC notice: $rpcErr");
      }

      if (!rpcSuccess) {
        await SupabaseService.client.from("challenges").update({"status": "accepted"}).eq("id", targetChallengeId);

        final t1 = (challengeData?["from_team_id"] ?? fromTeamId).toString();
        final t2 = (challengeData?["to_team_id"] ?? toTeamId).toString();
        final t1Uuid = SupabaseService.toUuid(t1);
        final t2Uuid = SupabaseService.toUuid(t2);

        final startTime = DateTime.now().toUtc().toIso8601String();
        try {
          await SupabaseService.client.from("active_matches").insert({
            "team1_id": t1Uuid,
            "team2_id": t2Uuid,
            "status": "active",
            "start_time": startTime,
            "created_at": startTime,
          }).select().maybeSingle();
        } catch (fallbackErr) {
          debugPrint("[TeamsScreen] Match insert fallback failed: $fallbackErr");
        }
      }

      if (mounted) {
        setState(() => _acceptedChallengeIds.add(cId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match started live! ⚡'), backgroundColor: Color(0xFF2E7D32), duration: Duration(seconds: 3)),
        );
      }
    } catch (e) {
      debugPrint("[TeamsScreen] Error accepting challenge: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFFF4655)));
    } finally {
      if (mounted) setState(() => _acceptingChallengeIds.remove(cId));
    }
  }

  Future<void> _handleRejectChallenge(String challengeId) async {
    final cId = challengeId.trim();
    setState(() => _acceptedChallengeIds.add(cId));
    try {
      await SupabaseService.client.from("challenges").update({"status": "rejected"}).eq("id", cId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge rejected')));
    } catch (e) {
      debugPrint("[TeamsScreen] Error rejecting challenge: $e");
    }
  }

  Future<void> _handleCancelChallenge(String challengeId) async {
    setState(() => _cancelledChallengeIds.add(challengeId));
    try {
      await SupabaseService.client.from("challenges").delete().eq("id", challengeId);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("[TeamsScreen] Error cancelling challenge: $e");
    }
  }

  void _openCreateTeamDialog() async {
    final currentUid = SupabaseService.client.auth.currentUser?.id ?? "";
    if (currentUid.isNotEmpty) {
      final wallet = await CoinWalletService().getOrCreateWallet(currentUid);
      if (wallet.coins < 1000) {
        _showCoinRequirementDialog(
          title: 'Insufficient Balance',
          message: 'You need at least 1,000 coins to create or maintain a team. Current: ${wallet.coins} coins',
        );
        return;
      }
    }

    await CoinOrAdPopup.show(
      context: context,
      actionName: "Team Create",
      onConfirm: () async {
        final created = await CreateTeamDialog.show(context);
        if (created == true && mounted) setState(() {});
      },
    );
  }

  List<Map<String, dynamic>> _filterMyActiveMatches(
      List<Map<String, dynamic>> rawList, String myTeamId, String myTeamUuid) {
    final sortedList = List<Map<String, dynamic>>.from(rawList);
    sortedList.sort((a, b) =>
        (b["created_at"] ?? "").toString().compareTo((a["created_at"] ?? "").toString()));

    final Map<String, Map<String, dynamic>> dedupMap = {};
    for (final m in sortedList) {
      final id = m["id"]?.toString() ?? "";
      if (id.isNotEmpty && !dedupMap.containsKey(id)) dedupMap[id] = m;
    }

    return dedupMap.values.where((m) {
      final status = (m["status"] ?? "").toString().toLowerCase();
      if (status != "active" && status != "under_review" && status != "rejected") return false;
      if (_completedMatchIds.contains(m["id"]?.toString())) return false;

      final List<String> pList = [];
      final participants = m["participants"];
      if (participants is List) {
        for (final p in participants) {
          if (p != null) pList.add(p.toString().toLowerCase());
        }
      }
      pList.add((m["team1_id"] ?? "").toString().toLowerCase());
      pList.add((m["team2_id"] ?? "").toString().toLowerCase());

      final myIdLower = myTeamId.toLowerCase();
      final myUuidLower = myTeamUuid.toLowerCase();
      return pList.any((p) =>
          (myIdLower.isNotEmpty && (p == myIdLower || p.contains(myIdLower))) ||
          (myUuidLower.isNotEmpty && (p == myUuidLower || p.contains(myUuidLower))));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = SupabaseService.client.auth.currentUser?.id ?? "";

    return StreamBuilder<List<TeamModel>>(
      stream: currentUid.isNotEmpty ? _teamService.getUserTeamsStream(currentUid) : Stream.value([]),
      builder: (context, userTeamsSnap) {
        final userTeams = userTeamsSnap.data ?? [];
        final myLeaderTeams = userTeams.where((t) => t.isLeader(currentUid)).toList();
        final myTeam = myLeaderTeams.isNotEmpty ? myLeaderTeams.first : null;
        final String myTeamId = myTeam?.id ?? "";
        final String myTeamName = myTeam?.name ?? "";
        final String myTeamUuid = SupabaseService.toUuid(myTeamId);

        return StreamBuilder<CoinWallet>(
          stream: currentUid.isNotEmpty
              ? CoinWalletService().walletStream(currentUid)
              : Stream.value(const CoinWallet(userId: 'guest', coins: 1000)),
          builder: (context, walletSnap) {
            final myCoins = walletSnap.data?.coins ??
                CoinWalletService().currentWallet?.coins ??
                1000;
            final bool isMyTeamFrozen = myTeam != null && myCoins < 1000;

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: myTeamId.isNotEmpty
                  ? SupabaseService.client.from("active_matches").stream(primaryKey: ["id"])
                  : Stream.value([]),
              builder: (context, matchSnap) {
                final rawMatches = matchSnap.data ?? [];
                final myActiveMatches = _filterMyActiveMatches(rawMatches, myTeamId, myTeamUuid);
                final liveCount = myActiveMatches.length;

                return Scaffold(
                  backgroundColor: darkBg,
                  appBar: AppBar(
                    backgroundColor: darkBg,
                    elevation: 0,
                    title: const Text(
                      'Teams',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: 0.5,
                      ),
                    ),
                    actions: [
                      IconButton(
                        tooltip: "Leaderboard",
                        icon: const Icon(Icons.emoji_events_rounded, color: neonBlue, size: 26),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          indicatorColor: neonBlue,
                          indicatorWeight: 3,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white54,
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          tabs: [
                            const Tab(text: 'Teams'),
                            Tab(text: liveCount > 0 ? "Live 🔴 $liveCount" : "Live"),
                          ],
                        ),
                      ),
                    ),
                  ),
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTeamsTab(
                        myTeamId: myTeamId,
                        myTeamUuid: myTeamUuid,
                        myTeamName: myTeamName,
                        isMyTeamFrozen: isMyTeamFrozen,
                      ),
                      _buildLiveMatchesTab(
                        myActiveMatches: myActiveMatches,
                        myTeamId: myTeamId,
                        myTeamUuid: myTeamUuid,
                        myTeamName: myTeamName,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTeamsTab({
    required String myTeamId,
    required String myTeamUuid,
    required String myTeamName,
    required bool isMyTeamFrozen,
  }) {
    return Column(
      children: [
        if (isMyTeamFrozen)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF4655).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_clock_rounded, color: Color(0xFFFF4655), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Team Frozen',
                        style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your balance is below 1000 coins. Team features are frozen.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Search Bar & Create Team Button (Exact Match to Reference)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: darkBg,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: cardBorder),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search teams by name or tag',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white54),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: Colors.white54),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = "");
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _openCreateTeamDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neonCyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      elevation: 4,
                      shadowColor: neonCyan.withOpacity(0.4),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Filter Chips (Matched to Reference)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _gameFilterOptions.map((game) {
                    final isSel = _selectedGameFilter == game;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSel) ...[
                              const Icon(Icons.check, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              game,
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.white70,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        selected: isSel,
                        selectedColor: neonCyan,
                        backgroundColor: cardBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(color: isSel ? neonCyan : cardBorder),
                        onSelected: (val) {
                          if (val) setState(() => _selectedGameFilter = game);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Teams List Stream
        Expanded(
          child: StreamBuilder<List<TeamModel>>(
            key: ValueKey("teams_stream_${_selectedGameFilter}_${_searchQuery}_$_teamsRetryKey"),
            stream: _teamService.getTeamsStream(
              gameFilter: _selectedGameFilter,
              searchQuery: _searchQuery,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                _cachedTeams = snapshot.data;
              }

              final teams = snapshot.data ?? _cachedTeams;

              if (teams == null && (snapshot.connectionState == ConnectionState.waiting || (!snapshot.hasData && !snapshot.hasError))) {
                return const Center(child: CircularProgressIndicator(color: neonBlue));
              }

              final displayTeams = teams ?? [];
              if (displayTeams.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_rounded, size: 48, color: Colors.white24),
                      const SizedBox(height: 12),
                      const Text(
                        'No Teams Found',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Be the first to create a team and compete!',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _openCreateTeamDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: neonCyan,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Create Team', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: displayTeams.length,
                itemBuilder: (context, index) {
                  final team = displayTeams[index];
                  final targetUuid = SupabaseService.toUuid(team.id).toLowerCase();
                  final rawTeamId = team.id.toLowerCase();

                  return TeamCard(
                    team: team,
                    myTeamId: myTeamId,
                    myTeamName: myTeamName,
                    isMyTeamFrozen: isMyTeamFrozen,
                    pendingChallenge: null,
                    onCancelChallenge: _handleCancelChallenge,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMatchesTab({
    required List<Map<String, dynamic>> myActiveMatches,
    required String myTeamId,
    required String myTeamUuid,
    required String myTeamName,
  }) {
    if (myActiveMatches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: cardBorder),
                ),
                child: const Icon(
                  Icons.sports_esports_outlined,
                  size: 48,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Live Matches',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Challenge other teams from the Teams tab to start live matches and win rewards.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: myActiveMatches.length,
      itemBuilder: (context, index) {
        final match = myActiveMatches[index];
        return _ActiveMatchBothTeamsBanner(
          key: ValueKey(match["id"]?.toString() ?? UniqueKey().toString()),
          match: match,
          myTeamId: myTeamId,
          myTeamUuid: myTeamUuid,
          myTeamName: myTeamName,
          teamService: _teamService,
          onShowProofImage: (url) => _showProofImageDialog(context, url),
          onAutoCompleted: (mId) {
            if (mounted) setState(() => _completedMatchIds.add(mId));
          },
        );
      },
    );
  }
}

class _ActiveMatchBothTeamsBanner extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myTeamId;
  final String myTeamUuid;
  final String myTeamName;
  final TeamService teamService;
  final void Function(String imageUrl) onShowProofImage;
  final void Function(String matchId) onAutoCompleted;

  const _ActiveMatchBothTeamsBanner({
    super.key,
    required this.match,
    required this.myTeamId,
    required this.myTeamUuid,
    required this.myTeamName,
    required this.teamService,
    required this.onShowProofImage,
    required this.onAutoCompleted,
  });

  @override
  State<_ActiveMatchBothTeamsBanner> createState() =>
      _ActiveMatchBothTeamsBannerState();
}

class _ActiveMatchBothTeamsBannerState
    extends State<_ActiveMatchBothTeamsBanner> {
  Timer? _timer;
  DateTime? _bannerMountedTime;
  TeamModel? _myTeam;
  TeamModel? _oppTeam;
  String _myLeaderName = "Leader";
  String _oppLeaderName = "Leader";
  int _myMemberCount = 1;
  int _oppMemberCount = 1;
  bool _isLoading = true;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _bannerMountedTime = DateTime.now();
    _fetchTeams();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTeams() async {
    final t1 = widget.match["team1_id"]?.toString() ?? "";
    final t2 = widget.match["team2_id"]?.toString() ?? "";

    final isT1Mine = t1.toLowerCase() == widget.myTeamUuid.toLowerCase() ||
        t1.toLowerCase() == widget.myTeamId.toLowerCase();
    final myTId = isT1Mine ? t1 : t2;
    final oppTId = isT1Mine ? t2 : t1;

    try {
      final myT = await widget.teamService.getTeam(myTId);
      final oppT = await widget.teamService.getTeam(oppTId);

      if (mounted) {
        setState(() {
          _myTeam = myT;
          _oppTeam = oppT;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final match = widget.match;
    final matchId = match["id"]?.toString() ?? "";
    final t1 = match["team1_id"]?.toString() ?? "";
    final t2 = match["team2_id"]?.toString() ?? "";
    final opponentId = (t1.toLowerCase() == widget.myTeamUuid.toLowerCase() ||
            t1.toLowerCase() == widget.myTeamId.toLowerCase())
        ? t2
        : t1;

    final myTeamDisplay = _myTeam?.name ?? widget.myTeamName;
    final oppTeamDisplay = _oppTeam?.name ?? match["opponent_name"]?.toString() ?? 'Opponent Team';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF4655), size: 20),
              const SizedBox(width: 6),
              const Text(
                "LIVE BATTLE",
                style: TextStyle(
                  color: Color(0xFFFF4655),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrivateMatchRoomScreen(
                        matchId: matchId,
                        myTeamId: widget.myTeamId,
                        myTeamName: myTeamDisplay,
                        opponentId: opponentId,
                        opponentName: oppTeamDisplay,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.forum_rounded, size: 14),
                label: const Text('Match Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
