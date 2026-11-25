// ===============================================================================
// CLEAN TOURNAMENT MANAGEMENT TAB — Single View with Floating/Bottom Create Button
// ===============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/theme_service.dart';
import '../tournament_bracket_screen.dart';

class AdminTournamentsTab extends StatefulWidget {
  const AdminTournamentsTab({super.key});

  @override
  State<AdminTournamentsTab> createState() => AdminTournamentsTabState();
}

class AdminTournamentsTabState extends State<AdminTournamentsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _gameFilter = 'All';
  List<Map<String, dynamic>> _cachedTournaments = [];
  bool _isLoadingFallback = false;
  String? _streamErrorNote;

  final List<String> _gameList = [
    'Free Fire',
    'PUBG Mobile',
    'Call Of Duty',
    'Clash Royale',
    'Candy Crush',
    'Garena Free Fire Max',
    'Clash of Clans',
    'Minecraft',
    'eFootball',
    'Asphalt 9',
    'Brawl Stars',
    'Stumble Guys',
    'Ludo',
    '8 Ball Pool',
  ];

  final Map<String, List<String>> _gameMaps = {
    'Free Fire': ['Bermuda', 'Purgatory', 'Kalahari', 'Alpine', 'NeXTerra'],
    'Garena Free Fire Max': ['Bermuda', 'Purgatory', 'Kalahari', 'Alpine', 'NeXTerra'],
    'PUBG Mobile': ['Erangel', 'Miramar', 'Sanhok', 'Vikendi', 'Livik', 'Nusa'],
    'Call Of Duty': ['Isolated', 'Blackout', 'Alcatraz', 'Rebirth Island'],
    'Clash Royale': ['Arena 1', 'Arena 5', 'Arena 9', 'Legendary Arena'],
    'Candy Crush': ['Level 1-50', 'Level 51-100', 'Level 101-200', 'Level 201+'],
    'Clash of Clans': ['Home Village', 'Builder Base', 'Clan Capital'],
    'Minecraft': ['Survival World', 'Creative World', 'Skyblock'],
    'eFootball': ['Camp Nou', 'Old Trafford', 'Allianz Stadium', 'San Siro'],
    'Asphalt 9': ['San Francisco', 'Shanghai', 'Cairo', 'Himalayas'],
    'Brawl Stars': ['Gem Grab', 'Brawl Ball', 'Heist', 'Showdown'],
    'Stumble Guys': ['Lost Temple', 'Super Slide', 'Over and Under', 'Rush Hour'],
    'Ludo': ['Classic Board', 'Quick Ludo'],
    '8 Ball Pool': ['London', 'Sydney', 'Moscow', 'Las Vegas'],
  };

  @override
  void initState() {
    super.initState();
    _loadTournamentsFallback();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isTransientNetworkError(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains('connection reset by peer') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('connection closed') ||
        lower.contains('connection terminated') ||
        lower.contains('handshakeexception') ||
        lower.contains('timed out') ||
        lower.contains('timeoutexception') ||
        lower.contains('broken pipe');
  }

  String _formatTournamentErrorMessage(Object error) {
    if (_isTransientNetworkError(error)) {
      return 'Network connection was interrupted (Connection reset). Please tap Retry to save again.';
    }
    return 'Could not save tournament: $error';
  }

  Future<T> _runWithNetworkRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        if (!_isTransientNetworkError(e) || attempt >= maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 450 * attempt));
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  Future<void> _loadTournamentsFallback() async {
    if (_isLoadingFallback) return;
    _isLoadingFallback = true;
    try {
      final rows = await _runWithNetworkRetry(
        () => SupabaseService.client
            .from('tournaments')
            .select()
            .order('created_at', ascending: false),
      );
      if (mounted) {
        setState(() {
          _cachedTournaments = List<Map<String, dynamic>>.from(
            rows.map((e) => Map<String, dynamic>.from(e)),
          );
          _streamErrorNote = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _streamErrorNote = _formatTournamentErrorMessage(e);
        });
      }
    } finally {
      _isLoadingFallback = false;
    }
  }

  Future<void> _confirmDeleteTournament(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF4655)),
            const SizedBox(width: 8),
            Text('Delete Tournament?', style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _runWithNetworkRetry(
        () => SupabaseService.client.from('tournaments').delete().eq('id', id),
      );
      if (mounted) {
        setState(() {
          _cachedTournaments.removeWhere((t) => t['id']?.toString() == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament deleted successfully! 🗑️'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_formatTournamentErrorMessage(e)),
            backgroundColor: const Color(0xFFFF4655),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _confirmDeleteTournament(id, title),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeService.isDarkMode;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateEditTournamentModal(
          initialGame: _gameFilter != 'All' ? _gameFilter : null,
        ),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: const Color(0xFF0B0F14),
        icon: const Icon(Icons.add_rounded, size: 20, color: Color(0xFF0B0F14)),
        label: const Text(
          'Create Tournament',
          style: TextStyle(
            color: Color(0xFF0B0F14),
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: ThemeService.bg,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search tournaments by title...',
                    hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 12.5),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? const Color(0xFF00FF88) : const Color(0xFF047857),
                      size: 18,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: ThemeService.card,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeService.border)),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final g in ['All', ..._gameList]) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(g),
                            selected: _gameFilter == g,
                            onSelected: (selected) {
                              if (selected) setState(() => _gameFilter = g);
                            },
                            selectedColor: const Color(0xFF00FF88),
                            backgroundColor: ThemeService.card,
                            labelStyle: TextStyle(
                              color: _gameFilter == g ? const Color(0xFF0B0F14) : ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SupabaseService.client
                  .from('tournaments')
                  .stream(primaryKey: ['id'])
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  _cachedTournaments = snapshot.data!;
                } else if (snapshot.hasError && _cachedTournaments.isEmpty && !_isLoadingFallback) {
                  Future.microtask(_loadTournamentsFallback);
                }

                if ((snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData &&
                        _cachedTournaments.isEmpty) ||
                    (_isLoadingFallback && _cachedTournaments.isEmpty)) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                  );
                }

                final list = snapshot.data ?? _cachedTournaments;

                var filtered = list.where((item) {
                  final game = (item['game_name'] ?? '').toString();
                  final title = (item['title'] ?? '').toString().toLowerCase();

                  if (_gameFilter != 'All' && !game.toLowerCase().contains(_gameFilter.toLowerCase())) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty && !title.contains(_searchQuery)) {
                    return false;
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
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: ThemeService.card,
                              shape: BoxShape.circle,
                              border: Border.all(color: ThemeService.border),
                            ),
                            child: Icon(
                              Icons.emoji_events_outlined,
                              color: isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _streamErrorNote != null ? 'Connection Interrupted' : 'No Tournaments Found',
                            style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _streamErrorNote ??
                                'Tap the "Create Tournament" button below to launch a new match!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                          ),
                          if (_streamErrorNote != null) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadTournamentsFallback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FF88),
                                foregroundColor: Colors.black,
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
                              label: const Text(
                                'Retry Connection',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFF00FF88),
                  onRefresh: _loadTournamentsFallback,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildTournamentCard(filtered[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const String kLastTeamStandingRule =
      'All joined teams play together in one room; the last team standing wins the prize pool.';

  String _getFormatSlotMeaning(String format) {
    final lower = format.trim().toLowerCase();
    if (lower == 'solo') {
      return '1 Slot = 1 Player';
    } else if (lower == 'duo') {
      return '1 Slot = 1 Team (2 players)';
    } else if (lower.contains('single')) {
      return '1 Slot = 1 Team/Entry in a single match room';
    } else {
      return '1 Slot = 1 Team (4 players)';
    }
  }

  String _getMaxSlotsHelperText(String format, int maxSlots) {
    final safeSlots = maxSlots > 0 ? maxSlots : 1;
    final lower = format.trim().toLowerCase();
    if (lower == 'solo') {
      return '$safeSlots ${safeSlots == 1 ? 'Player' : 'Players'} • 1 Slot = 1 Player';
    } else if (lower == 'duo') {
      return '$safeSlots ${safeSlots == 1 ? 'Team' : 'Teams'} • up to ${safeSlots * 2} players';
    } else if (lower.contains('single')) {
      return '$safeSlots ${safeSlots == 1 ? 'Team/Entry' : 'Teams/Entries'} • 1 Slot = 1 Team/Entry in a single match room';
    } else {
      return '$safeSlots ${safeSlots == 1 ? 'Team' : 'Teams'} • up to ${safeSlots * 4} players';
    }
  }

  Widget _buildTournamentCard(Map<String, dynamic> data) {
    final bool isDark = ThemeService.isDarkMode;
    final Color greenText = isDark ? const Color(0xFF00FF88) : const Color(0xFF065F46);
    final Color greenBg =
        isDark ? const Color(0xFF00FF88).withOpacity(0.12) : const Color(0xFFD1FAE5);
    final Color greenBorder =
        isDark ? const Color(0xFF00FF88).withOpacity(0.3) : const Color(0xFF059669);
    final Color goldText = isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309);
    final Color blueText = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);

    final id = data['id']?.toString() ?? '';
    final title = (data['title'] ?? data['name'] ?? 'Untitled Tournament').toString();
    final game = (data['game_name'] ?? data['game'] ?? 'BGMI').toString();
    final format = (data['match_format'] ?? data['format'] ?? 'Squad 4v4').toString();
    final prizePool = data['prize_pool'] ?? data['prize'] ?? '1000';
    final entryFee = data['entry_fee'] ?? 'Free';
    final int maxSlots = int.tryParse((data['max_slots'] ?? data['total_teams'] ?? 25).toString()) ?? 25;
    final int joinedSlots = int.tryParse((data['joined_teams_count'] ?? data['teams_joined'] ?? data['current_teams'] ?? 0).toString()) ?? 0;
    final status = (data['status'] ?? 'upcoming').toString().toLowerCase();
    final roomId = (data['room_id'] ?? '').toString();
    final roomPass = (data['room_password'] ?? '').toString();

    DateTime? matchDateTime;
    if (data['match_time'] != null) {
      matchDateTime = DateTime.tryParse(data['match_time'].toString())?.toLocal();
    }

    final formattedDate = matchDateTime != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(matchDateTime)
        : (data['date_str']?.toString() ?? 'TBA');

    final bool isFull = joinedSlots >= maxSlots && maxSlots > 0;
    final bool isWithin15Mins = matchDateTime != null &&
        DateTime.now().isAfter(matchDateTime.subtract(const Duration(minutes: 15)));
    final bool isEntryLocked = isFull || isWithin15Mins;

    Color statusColor = blueText;
    String statusText = 'UPCOMING';
    if (status == 'cancelled') {
      statusColor = const Color(0xFFFF4655);
      statusText = 'CANCELLED (REFUNDED)';
    } else if (status == 'live') {
      statusColor = const Color(0xFFFF4655);
      statusText = 'LIVE 🔴';
    } else if (status == 'completed') {
      statusColor = greenText;
      statusText = 'COMPLETED ✓';
    } else if (isFull) {
      statusColor = const Color(0xFFFF8A00);
      statusText = 'SLOTS FULL 🔒';
    } else if (isWithin15Mins && joinedSlots >= 2) {
      statusColor = const Color(0xFFFF8A00);
      statusText = 'ENTRY LOCKED 🔒';
    }

    final String slotCapacityHelper = _getMaxSlotsHelperText(format, maxSlots);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'live' || status == 'cancelled'
              ? const Color(0xFFFF4655).withOpacity(0.5)
              : ThemeService.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: greenBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: greenBorder),
                ),
                child: Text(game, style: TextStyle(color: greenText, fontWeight: FontWeight.w900, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: ThemeService.cardSecondary, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '$format • ${_getFormatSlotMeaning(format)}',
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.45)),
                ),
                child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: ThemeService.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: ThemeService.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '$formattedDate • ${isEntryLocked ? "Entry Locked" : "Entry locks 15m before start"}',
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('🪙 Prize: ', style: TextStyle(color: ThemeService.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('$prizePool Coins', style: TextStyle(color: goldText, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(width: 12),
              Text('🎟️ Fee: ', style: TextStyle(color: ThemeService.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('$entryFee', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
              const Spacer(),
              Text('Slots: $joinedSlots/$maxSlots', style: TextStyle(color: blueText, fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$slotCapacityHelper • Min 2 slots required (auto-refund if <2)',
            style: TextStyle(
              color: ThemeService.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: greenBg.withOpacity(isDark ? 0.65 : 0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: greenBorder.withOpacity(0.6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.emoji_events_rounded, size: 14, color: greenText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    kLastTeamStandingRule,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF000000),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ThemeService.cardSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ThemeService.border),
            ),
            child: Row(
              children: [
                Icon(Icons.vpn_key_rounded, size: 14, color: isDark ? const Color(0xFFFF8A00) : const Color(0xFFC2410C)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    roomId.isNotEmpty ? 'Room ID: $roomId | Pass: $roomPass' : 'Room ID & Pass: Not Published Yet',
                    style: TextStyle(
                      color: roomId.isNotEmpty ? ThemeService.textPrimary : ThemeService.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _openRoomCredentialModal(id, roomId, roomPass),
                  child: Text('Set Room ⚙️', style: TextStyle(color: greenText, fontWeight: FontWeight.w900, fontSize: 11.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: ThemeService.border, height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.account_tree_rounded, color: goldText, size: 20),
                tooltip: 'Manage Tournament Bracket',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TournamentBracketScreen(
                        tournamentId: id,
                        tournamentTitle: title,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.edit_note_rounded, color: blueText, size: 20),
                tooltip: 'Edit Tournament',
                onPressed: () => _openCreateEditTournamentModal(existingData: data),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4655), size: 20),
                tooltip: 'Delete Tournament',
                onPressed: () => _confirmDeleteTournament(id, title),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCreateEditTournamentModal({Map<String, dynamic>? existingData, String? initialGame}) {
    final isEdit = existingData != null;
    final titleController = TextEditingController(text: existingData?['title'] ?? '');
    final prizeController = TextEditingController(text: existingData?['prize_pool']?.toString() ?? '1000');
    final feeController = TextEditingController(text: existingData?['entry_fee']?.toString() ?? 'Free');
    final slotsController = TextEditingController(text: existingData?['max_slots']?.toString() ?? '4');
    final rulesController = TextEditingController(
      text: existingData?['rules'] ??
          '$kLastTeamStandingRule Entry locks 15 minutes before start or when slots are full. Minimum 2 joined slots/teams required or tournament cancels with automatic G-Coins refund.',
    );
    final roomIdController = TextEditingController(text: existingData?['room_id'] ?? '');
    final roomPassController = TextEditingController(text: existingData?['room_password'] ?? '');

    String selectedGame;
    if (existingData?['game_name'] != null && _gameList.contains(existingData!['game_name'])) {
      selectedGame = existingData['game_name'];
    } else if (initialGame != null && _gameList.contains(initialGame)) {
      selectedGame = initialGame;
    } else if (_gameFilter != 'All' && _gameList.contains(_gameFilter)) {
      selectedGame = _gameFilter;
    } else {
      selectedGame = _gameList[0];
    }
    String selectedFormat = existingData?['match_format'] ?? 'Squad 4v4';
    if (!['Solo', 'Duo', 'Squad 4v4', 'Single Match'].contains(selectedFormat)) {
      selectedFormat = 'Squad 4v4';
    }

    String selectedMap = existingData?['map_name'] ?? (_gameMaps[selectedGame]?.first ?? 'Default');
    if (!(_gameMaps[selectedGame] ?? []).contains(selectedMap)) {
      selectedMap = _gameMaps[selectedGame]?.first ?? 'Default';
    }

    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));

    if (existingData?['match_time'] != null) {
      selectedDateTime = DateTime.tryParse(existingData!['match_time'].toString()) ?? selectedDateTime;
    }

    bool isSaving = false;
    String? inlineSaveError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeService.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final int parsedMaxSlots = int.tryParse(slotsController.text.trim()) ?? 4;
          final String dynamicSlotsHelper = _getMaxSlotsHelperText(selectedFormat, parsedMaxSlots);
          final String formatSlotRule = _getFormatSlotMeaning(selectedFormat);

          Future<void> performSave() async {
            if (isSaving) return;
            final title = titleController.text.trim();
            if (title.isEmpty) {
              setModalState(() => inlineSaveError = 'Please enter a tournament title!');
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a tournament title!'),
                  backgroundColor: Color(0xFFFF4655),
                ),
              );
              return;
            }

            setModalState(() {
              isSaving = true;
              inlineSaveError = null;
            });

            final payload = <String, dynamic>{
              'title': title,
              'game_name': selectedGame,
              'match_format': selectedFormat,
              'prize_pool': prizeController.text.trim(),
              'entry_fee': feeController.text.trim(),
              'max_slots': (int.tryParse(slotsController.text.trim()) ?? 4).clamp(2, 100),
              'map_name': selectedMap,
              'room_id': roomIdController.text.trim(),
              'room_password': roomPassController.text.trim(),
              'match_time': selectedDateTime.toIso8601String(),
              'rules': rulesController.text.trim(),
              'status': existingData?['status'] ?? 'upcoming',
              'updated_at': DateTime.now().toIso8601String(),
            };

            try {
              if (isEdit) {
                await _runWithNetworkRetry(
                  () => SupabaseService.client
                      .from('tournaments')
                      .update(payload)
                      .eq('id', existingData['id']),
                );
              } else {
                payload['created_at'] = DateTime.now().toIso8601String();
                payload['joined_teams_count'] = 0;
                await _runWithNetworkRetry(
                  () => SupabaseService.client.from('tournaments').insert(payload),
                );
              }

              await _loadTournamentsFallback();
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEdit ? 'Tournament Updated! 🚀' : 'Tournament Published Successfully! 🏆',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
                    ),
                    backgroundColor: const Color(0xFF00FF88),
                  ),
                );
              }
            } catch (e) {
              debugPrint('=== TOURNAMENT SAVE ERROR: $e ===');
              final friendlyErr = _formatTournamentErrorMessage(e);
              if (ctx.mounted) {
                setModalState(() {
                  isSaving = false;
                  inlineSaveError = friendlyErr;
                });
              }
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(friendlyErr),
                    backgroundColor: const Color(0xFFFF4655),
                    duration: const Duration(seconds: 6),
                    action: SnackBarAction(
                      label: 'Retry',
                      textColor: Colors.white,
                      onPressed: () {
                        if (ctx.mounted) {
                          performSave();
                        }
                      },
                    ),
                  ),
                );
              }
            } finally {
              if (ctx.mounted && isSaving) {
                setModalState(() => isSaving = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Tournament ⚙️' : 'Create Tournament 🏆',
                        style: TextStyle(color: ThemeService.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Tournament Title',
                      filled: true,
                      fillColor: ThemeService.cardSecondary,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('game_dropdown_$selectedGame'),
                          value: selectedGame,
                          isExpanded: true,
                          dropdownColor: ThemeService.card,
                          decoration: InputDecoration(
                            labelText: 'Game',
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: _gameList.map((g) => DropdownMenuItem(value: g, child: Text(g, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedGame = val;
                                selectedMap = _gameMaps[selectedGame]?.first ?? 'Default';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedFormat,
                          isExpanded: true,
                          dropdownColor: ThemeService.card,
                          decoration: InputDecoration(
                            labelText: 'Format',
                            helperText: formatSlotRule,
                            helperMaxLines: 2,
                            helperStyle: TextStyle(
                              color: ThemeService.isDarkMode ? const Color(0xFF00FF88) : const Color(0xFF047857),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Solo', child: Text('Solo (1 Player/Slot)')),
                            DropdownMenuItem(value: 'Duo', child: Text('Duo (2 Players/Slot)')),
                            DropdownMenuItem(value: 'Squad 4v4', child: Text('Squad 4v4 (4 Players/Slot)')),
                            DropdownMenuItem(value: 'Single Match', child: Text('Single Match (1 Team/Slot)')),
                          ],
                          selectedItemBuilder: (context) => ['Solo', 'Duo', 'Squad 4v4', 'Single Match']
                              .map((f) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      f,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) => setModalState(() => selectedFormat = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: prizeController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Prize Pool (Coins)',
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: feeController,
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Entry Fee',
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: slotsController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Max Slots',
                            helperText: dynamicSlotsHelper,
                            helperMaxLines: 2,
                            helperStyle: TextStyle(
                              color: ThemeService.isDarkMode ? const Color(0xFFFFD700) : const Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('map_dropdown_${selectedGame}_$selectedMap'),
                          value: selectedMap,
                          isExpanded: true,
                          dropdownColor: ThemeService.card,
                          decoration: InputDecoration(
                            labelText: 'Map Name',
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: (_gameMaps[selectedGame] ?? ['Default']).map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedMap = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: roomIdController,
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Room ID',
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: roomPassController,
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Room Password',
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDateTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );
                        if (pickedTime != null) {
                          setModalState(() {
                            selectedDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ThemeService.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_filled_rounded,
                            color: ThemeService.isDarkMode
                                ? const Color(0xFF00FF88)
                                : const Color(0xFF047857),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Match Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(selectedDateTime)} (Entry locks 15m before)',
                              style: TextStyle(color: ThemeService.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: ThemeService.cardSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ThemeService.isDarkMode
                            ? const Color(0xFF00FF88).withOpacity(0.35)
                            : const Color(0xFF059669).withOpacity(0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🏆 Last Team Standing & Entry Lock Rules',
                          style: TextStyle(
                            color: ThemeService.isDarkMode ? const Color(0xFF00FF88) : const Color(0xFF047857),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• $kLastTeamStandingRule\n'
                          '• $formatSlotRule ($dynamicSlotsHelper).\n'
                          '• New entries lock 15 minutes before match start or immediately when Slots Full.\n'
                          '• At entry close: if ≥ 2 slots/teams joined, remaining slots lock and match proceeds; if < 2 joined, tournament cancels and entry fee coins auto-refund to G-Coins Wallet.',
                          style: TextStyle(
                            color: ThemeService.isDarkMode ? Colors.white : const Color(0xFF000000),
                            fontSize: 11,
                            height: 1.38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (inlineSaveError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4655).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF4655), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              inlineSaveError!,
                              style: TextStyle(
                                color: ThemeService.textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: isSaving ? null : performSave,
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                color: Color(0xFFFF4655),
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : performSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        foregroundColor: const Color(0xFF0B0F14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0B0F14),
                              ),
                            )
                          : const Icon(Icons.rocket_launch_rounded, size: 17, color: Color(0xFF0B0F14)),
                      label: Text(
                        isSaving
                            ? 'Saving...'
                            : (isEdit ? 'Save Changes' : 'Publish Tournament 🚀'),
                        style: const TextStyle(
                          color: Color(0xFF0B0F14),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openRoomCredentialModal(String id, String currentRoomId, String currentPass) {
    final idController = TextEditingController(text: currentRoomId);
    final passController = TextEditingController(text: currentPass);
    bool isSavingRoom = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Update Room Credentials 🔐',
            style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                style: TextStyle(color: ThemeService.textPrimary),
                decoration: const InputDecoration(labelText: 'Custom Room ID'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passController,
                style: TextStyle(color: ThemeService.textPrimary),
                decoration: const InputDecoration(labelText: 'Room Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSavingRoom ? null : () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSavingRoom
                  ? null
                  : () async {
                      setDialogState(() => isSavingRoom = true);
                      try {
                        await _runWithNetworkRetry(
                          () => SupabaseService.client.from('tournaments').update({
                            'room_id': idController.text.trim(),
                            'room_password': passController.text.trim(),
                          }).eq('id', id),
                        );
                        await _loadTournamentsFallback();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Room ID & Password published! 🔐',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                              ),
                              backgroundColor: Color(0xFF00FF88),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isSavingRoom = false);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(_formatTournamentErrorMessage(e)),
                              backgroundColor: const Color(0xFFFF4655),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              child: Text(
                isSavingRoom ? 'Saving...' : 'Save & Publish',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}