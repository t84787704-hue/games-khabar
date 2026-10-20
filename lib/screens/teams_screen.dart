// ===============================================================================
// File: lib/screens/teams_screen.dart
// Clean Teams Screen with Realtime Matches, Proof Submission, Leaderboard & Full Localization
// ===============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../widgets/team_card.dart';
import '../widgets/create_team_dialog.dart';
import 'team_match_room_screen.dart';
import 'team_leaderboard_screen.dart';
import 'team_profile_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String? _selectedGame;
  String? _myTeamId;
  String? _myTeamName;
  bool _isLoadingMyTeam = true;

  StreamSubscription? _myTeamSub;

  final List<String> _gameFilters = [
    'All',
    'PUBG Mobile',
    'BGMI',
    'Free Fire',
    'Call of Duty Mobile',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyTeam();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _myTeamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMyTeam() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingMyTeam = false);
      return;
    }

    try {
      final res = await SupabaseService.client
          .from('teams')
          .select('id, name, leader_id')
          .eq('leader_id', user.id)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _myTeamId = res['id']?.toString();
          _myTeamName = res['name']?.toString();
          _isLoadingMyTeam = false;
        });
        return;
      }

      final memberRes = await SupabaseService.client
          .from('team_members')
          .select('team_id, teams(name)')
          .eq('user_id', user.id)
          .maybeSingle();

      if (memberRes != null && mounted) {
        setState(() {
          _myTeamId = memberRes['team_id']?.toString();
          _myTeamName = memberRes['teams']?['name']?.toString();
          _isLoadingMyTeam = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[Teams] Error loading my team: $e');
    }

    if (mounted) {
      setState(() => _isLoadingMyTeam = false);
    }
  }

  void _openCreateTeamDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateTeamDialog(
        onTeamCreated: () {
          _loadMyTeam();
        },
      ),
    );
  }

  void _showProofDialog(BuildContext context, Map<String, dynamic> match) {
    showDialog(
      context: context,
      builder: (ctx) => _ProofUploadDialog(
        match: match,
        myTeamId: _myTeamId ?? '',
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('new_proof_sent'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showViewProofDialog(BuildContext context, String proofUrl, String? adminNote) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('match_proof_title'.tr(),
                      style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  IconButton(
                    icon: Icon(Icons.close, color: ThemeService.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  proofUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 150,
                    child: Center(
                      child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              if (adminNote != null && adminNote.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          adminNote,
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            title: Text(
              'nav_teams'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.leaderboard_outlined, color: Color(0xFF1877F2)),
                tooltip: 'top_100_teams_leaderboard'.tr(),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TeamLeaderboardScreen(),
                    ),
                  );
                },
              ),
              if (_myTeamId != null)
                IconButton(
                  icon: const Icon(Icons.shield_outlined, color: Color(0xFF1877F2)),
                  tooltip: 'My Team',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamProfileScreen(teamId: _myTeamId!),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1877F2),
              unselectedLabelColor: ThemeService.textSecondary,
              indicatorColor: const Color(0xFF1877F2),
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'all_teams'.tr()),
                Tab(text: 'my_matches'.tr()),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTeamsTab(),
              _buildMatchesTab(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.add),
            label: Text(_myTeamId == null ? 'create_team'.tr() : 'my_team'.tr()),
            onPressed: () {
              if (_myTeamId == null) {
                _openCreateTeamDialog();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TeamProfileScreen(teamId: _myTeamId!),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  // ─────────────────────────── Tab 1: Teams Tab ───────────────────────────

  Widget _buildTeamsTab() {
    return Column(
      children: [
        // Search & Filter
        Container(
          color: ThemeService.appBarBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                style: TextStyle(color: ThemeService.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'search_teams'.tr(),
                  hintStyle: TextStyle(color: ThemeService.textSecondary),
                  prefixIcon: Icon(Icons.search, color: ThemeService.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: ThemeService.textSecondary, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _gameFilters.length,
                  itemBuilder: (context, i) {
                    final game = _gameFilters[i];
                    final isSelected = (_selectedGame == null && game == 'All') ||
                        _selectedGame == game;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(game),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGame = (game == 'All') ? null : game;
                          });
                        },
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : ThemeService.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: ThemeService.cardSecondary,
                        selectedColor: const Color(0xFF1877F2),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        showCheckmark: false,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Teams List Stream
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: SupabaseService.client
                .from('teams')
                .stream(primaryKey: ['id'])
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: ThemeService.textSecondary),
                      const SizedBox(height: 12),
                      Text('connection_timeout'.tr(),
                          style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'db_connection_slow_msg'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('retry'.tr()),
                      ),
                    ],
                  ),
                );
              }

              var list = snapshot.data ?? [];

              // Search & Game Filter
              if (_searchQuery.isNotEmpty) {
                list = list.where((t) {
                  final name = (t['name'] ?? '').toString().toLowerCase();
                  final tag = (t['tag'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || tag.contains(_searchQuery);
                }).toList();
              }

              if (_selectedGame != null) {
                list = list.where((t) {
                  final game = (t['game'] ?? '').toString();
                  return game == _selectedGame;
                }).toList();
              }

              if (list.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 64, color: ThemeService.textSecondary.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('no_teams_found'.tr(),
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'create_team_compete_others'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final team = list[i];
                  return TeamCard(
                    teamMap: team,
                    myTeamId: _myTeamId,
                    onChallengeSent: () {
                      _tabController.animateTo(1);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────── Tab 2: My Matches Tab ───────────────────────────

  Widget _buildMatchesTab() {
    if (_isLoadingMyTeam) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myTeamId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sports_esports_outlined, size: 64, color: ThemeService.textSecondary.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text('no_active_teams'.tr(),
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'create_team_first_to_challenge'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: ThemeService.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add),
                label: Text('create_team'.tr()),
                onPressed: _openCreateTeamDialog,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('team_matches')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allMatches = snapshot.data ?? [];
        final myMatches = allMatches.where((m) {
          final t1 = m['team1_id']?.toString();
          final t2 = m['team2_id']?.toString();
          return t1 == _myTeamId || t2 == _myTeamId;
        }).toList();

        if (myMatches.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.military_tech_outlined, size: 64, color: ThemeService.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('no_matches_found'.tr(),
                      style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'no_matches_challenge_prompt'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ThemeService.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: myMatches.length,
          itemBuilder: (context, i) {
            final match = myMatches[i];
            return _buildMatchItemCard(match);
          },
        );
      },
    );
  }

  Widget _buildMatchItemCard(Map<String, dynamic> match) {
    final status = (match['status'] ?? 'pending').toString().toLowerCase();
    final team1Id = match['team1_id']?.toString();
    final isTeam1 = team1Id == _myTeamId;

    final myTeamName = isTeam1 ? (match['team1_name'] ?? 'My Team') : (match['team2_name'] ?? 'My Team');
    final oppTeamName = isTeam1 ? (match['team2_name'] ?? 'Opponent') : (match['team1_name'] ?? 'Opponent');

    final game = (match['game'] ?? 'Gaming').toString();
    final mode = (match['mode'] ?? 'Squad').toString();
    final proofUrl = match['proof_url']?.toString();
    final adminNote = match['admin_note']?.toString();
    final winnerId = match['winner_team_id']?.toString();
    final isWinner = winnerId == _myTeamId;

    Color statusColor;
    String statusText;

    switch (status) {
      case 'active':
      case 'live':
        statusColor = Colors.green;
        statusText = 'status_live_caps'.tr();
        break;
      case 'review':
      case 'under_review':
        statusColor = Colors.amber;
        statusText = 'proof_under_admin_review'.tr();
        break;
      case 'completed':
      case 'finished':
        statusColor = isWinner ? Colors.green : Colors.red;
        statusText = isWinner ? 'won_trophy'.tr() : 'DEFEATED';
        break;
      case 'rejected':
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'challenge_cancelled'.tr();
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'challenge_status_pending'.tr();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ThemeService.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: (status == 'active' || status == 'live')
              ? Colors.green.withOpacity(0.5)
              : ThemeService.border,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TeamMatchRoomScreen(
                matchId: match['id'].toString(),
                myTeamId: _myTeamId ?? '',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Status & Game
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'active' || status == 'live') ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$game • $mode',
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // VS Banner
              Row(
                children: [
                  Expanded(
                    child: Text(
                      myTeamName.toString(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1877F2).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Color(0xFF1877F2),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      oppTeamName.toString(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Divider(height: 1, color: ThemeService.border),
              const SizedBox(height: 10),

              // Actions Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (proofUrl != null && proofUrl.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.remove_red_eye, size: 16),
                      label: Text('view_proof'.tr(), style: const TextStyle(fontSize: 12)),
                      onPressed: () => _showViewProofDialog(context, proofUrl, adminNote),
                    )
                  else if (status == 'active' || status == 'live')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: Text('upload_proof'.tr(), style: const TextStyle(fontSize: 12)),
                      onPressed: () => _showProofDialog(context, match),
                    )
                  else
                    const SizedBox.shrink(),

                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Text('match_room'.tr(), style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TeamMatchRoomScreen(
                            matchId: match['id'].toString(),
                            myTeamId: _myTeamId ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Proof Upload Dialog ───────────────────────────

class _ProofUploadDialog extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myTeamId;
  final VoidCallback onSuccess;

  const _ProofUploadDialog({
    required this.match,
    required this.myTeamId,
    required this.onSuccess,
  });

  @override
  State<_ProofUploadDialog> createState() => _ProofUploadDialogState();
}

class _ProofUploadDialogState extends State<_ProofUploadDialog> {
  File? _selectedImage;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _uploadProof() async {
    if (_selectedImage == null) return;
    setState(() => _isUploading = true);

    try {
      final matchId = widget.match['id'].toString();
      final fileName = 'proof_${matchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'match_proofs/$fileName';

      final bytes = await _selectedImage!.readAsBytes();
      await SupabaseService.client.storage
          .from('proofs')
          .uploadBinary(storagePath, bytes);

      final publicUrl = SupabaseService.client.storage
          .from('proofs')
          .getPublicUrl(storagePath);

      await SupabaseService.client.from('team_matches').update({
        'proof_url': publicUrl,
        'status': 'under_review',
        'proof_submitted_by': widget.myTeamId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', matchId);

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      debugPrint('[Proof] Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('err_upload_proof'.tr()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ThemeService.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'upload_match_proof_hint'.tr(),
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: ThemeService.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThemeService.border, style: BorderStyle.solid),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 48, color: ThemeService.textSecondary),
                          const SizedBox(height: 8),
                          Text('pick_image_from_gallery'.tr(),
                              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_selectedImage != null && !_isUploading) ? _uploadProof : null,
                child: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('submit_proof'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}