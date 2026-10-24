// ===============================================================================
// TOURNAMENT DETAIL SCREEN — Match Info, Room Credentials, Win Proof & Squads
// File: lib/screens/tournament_detail_screen.dart
// ===============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'admin_bracket_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tournament;
  final bool isRegistered;

  const TournamentDetailScreen({
    super.key,
    required this.tournament,
    required this.isRegistered,
  });

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUploadingProof = false;
  List<Map<String, dynamic>> _registeredTeams = [];
  Map<String, dynamic>? _tournamentData;

  @override
  void initState() {
    super.initState();
    _tournamentData = widget.tournament;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    final tId = _tournamentData!['id'].toString();

    try {
      // 1. Fetch fresh tournament data
      final tRes = await _supabase
          .from('tournaments')
          .select()
          .eq('id', tId)
          .maybeSingle();

      if (tRes != null) {
        _tournamentData = Map<String, dynamic>.from(tRes);
      }

      // 2. Fetch registered teams
      final regRes = await _supabase
          .from('tournament_registrations')
          .select('id, registered_at, team_id, teams:teams(id, name, logo_url, leader_id)')
          .eq('tournament_id', tId)
          .order('registered_at', ascending: true);

      if (mounted) {
        setState(() {
          _registeredTeams = List<Map<String, dynamic>>.from(regRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF00FF88),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleUploadWinProof() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Check if user is leader of any registered team in this tournament
    Map<String, dynamic>? myRegisteredTeam;
    for (final reg in _registeredTeams) {
      final t = reg['teams'] as Map<String, dynamic>?;
      if (t != null && t['leader_id']?.toString() == currentUserId) {
        myRegisteredTeam = t;
        break;
      }
    }

    if (myRegisteredTeam == null && !widget.isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only registered team leaders can submit win proof!'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;

    setState(() => _isUploadingProof = true);

    try {
      final tId = _tournamentData!['id'].toString();
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.split('.').last;
      final fileName = 'proof_${tId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload image to public tournament bucket
      await _supabase.storage.from('posts').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _supabase.storage.from('posts').getPublicUrl(fileName);

      final teamId = myRegisteredTeam?['id']?.toString() ??
          (_registeredTeams.isNotEmpty ? _registeredTeams.first['team_id']?.toString() : null);

      // Update tournament proof info
      await _supabase.from('tournaments').update({
        'proof_url': publicUrl,
        'submitted_team_id': teamId,
        'submitted_at': DateTime.now().toIso8601String(),
      }).eq('id', tId);

      await _fetchDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Victory proof uploaded successfully! Admin will verify soon.'),
            backgroundColor: Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload proof: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingProof = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _tournamentData ?? widget.tournament;
    final title = (t['title'] ?? 'Tournament Match').toString();
    final gameMode = (t['game_mode'] ?? 'Squad (4v4)').toString();
    final mapName = (t['map_name'] ?? 'Erangel').toString();
    final fee = (t['entry_fee'] ?? 0).toString();
    final prize = (t['prize_pool'] ?? 0).toString();
    final maxTeams = (t['max_teams'] ?? 16) as int;
    final currentTeams = (t['current_teams'] ?? _registeredTeams.length) as int;
    final status = (t['status'] ?? 'upcoming').toString().toUpperCase();
    final roomId = (t['room_id'] ?? '').toString().trim();
    final roomPass = (t['room_password'] ?? '').toString().trim();
    final proofUrl = (t['proof_url'] ?? '').toString().trim();
    final isCompleted = status.toLowerCase() == 'completed';

    String matchTimeStr = 'TBD';
    if (t['match_time'] != null) {
      try {
        final parsed = DateTime.parse(t['match_time'].toString()).toLocal();
        matchTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A22),
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_rounded, color: Color(0xFF00FF88)),
            tooltip: 'Manage Tournament Bracket',
            onPressed: () {
              final tId = (_tournamentData?['id'] ?? widget.tournament['id']).toString();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminBracketScreen(tournamentId: tId),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDetails,
        color: const Color(0xFF00FF88),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF161A22), Color(0xFF1E2430)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFFFFD700).withOpacity(0.15)
                                : const Color(0xFF00FF88).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCompleted
                                  ? const Color(0xFFFFD700).withOpacity(0.4)
                                  : const Color(0xFF00FF88).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: isCompleted ? const Color(0xFFFFD700) : const Color(0xFF00FF88),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD700), size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '$prize Coins',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: Colors.white60, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          'Match Time: $matchTimeStr',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Match Info Grid
              Row(
                children: [
                  Expanded(child: _buildInfoTile(Icons.sports_esports_rounded, 'Mode', gameMode)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoTile(Icons.map_rounded, 'Map', mapName)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildInfoTile(Icons.payments_rounded, 'Entry Fee', '$fee Coins')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildInfoTile(Icons.groups_rounded, 'Slots', '$currentTeams / $maxTeams Teams')),
                ],
              ),

              const SizedBox(height: 20),

              // Room Credentials Section
              const Text(
                'Custom Room Credentials',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!widget.isRegistered)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, color: Color(0xFFFF8A00), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Room ID & Password will be unlocked once you register your squad.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else if (roomId.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded, color: Color(0xFF38BDF8), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Host has not shared Room ID yet. Check back 10-15 minutes before match time.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ROOM ID', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                roomId,
                                style: const TextStyle(
                                  color: Color(0xFF00FF88),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF00FF88), size: 20),
                            onPressed: () => _copyToClipboard(roomId, 'Room ID'),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PASSWORD', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                roomPass.isNotEmpty ? roomPass : 'No Password',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          if (roomPass.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                              onPressed: () => _copyToClipboard(roomPass, 'Password'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // ================= WIN PROOF SUBMISSION BLOCK =================
              const Text(
                'Match Result & Win Proof',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (isCompleted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.military_tech_rounded, color: Color(0xFFFFD700), size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tournament Completed 🏆',
                              style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Winner has been declared and prize coins distributed!',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (proofUrl.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF8A00), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Proof Under Review',
                                style: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          if (widget.isRegistered)
                            TextButton.icon(
                              onPressed: _isUploadingProof ? null : _handleUploadWinProof,
                              icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF38BDF8)),
                              label: const Text('Change Proof', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: proofUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Admin is verifying this screenshot. Prize will be sent once approved.',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else if (widget.isRegistered)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Did your squad win this match?',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload your end-game victory (#1 Winner) screenshot here to claim the prize pool.',
                        style: TextStyle(color: Colors.white60, fontSize: 11.5),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingProof ? null : _handleUploadWinProof,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF88),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _isUploadingProof
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                )
                              : const Icon(Icons.emoji_events_rounded, size: 18),
                          label: Text(
                            _isUploadingProof ? 'Uploading Proof...' : 'Upload Win Screenshot 🏆',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'Win proof submissions are only open for participating squad leaders.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),

              // Registered Squads
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registered Squads',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_registeredTeams.length} / $maxTeams',
                    style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                  ),
                )
              else if (_registeredTeams.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('No squads registered yet.', style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _registeredTeams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _registeredTeams[index];
                    final team = item['teams'] as Map<String, dynamic>?;
                    final teamName = team?['name']?.toString() ?? 'Squad #${index + 1}';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161A22),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00FF88).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFF00FF88),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              teamName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Icon(Icons.shield_outlined, color: Colors.white38, size: 18),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
