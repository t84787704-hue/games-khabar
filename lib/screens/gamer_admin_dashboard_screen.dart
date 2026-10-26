// ===============================================================================
// ADVANCED TOURNAMENT MANAGEMENT SYSTEM (PUBG, BGMI, FREE FIRE, COD)
// ===============================================================================
class _AdminTournamentsTab extends StatefulWidget {
  const _AdminTournamentsTab();

  @override
  State<_AdminTournamentsTab> createState() => _AdminTournamentsTabState();
}

class _AdminTournamentsTabState extends State<_AdminTournamentsTab> {
  int _currentSubTab = 0;
  String _gameFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _gameList = [
    'PUBG Mobile',
    'BGMI',
    'Free Fire',
    'COD Mobile',
    'Apex Legends',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          color: ThemeService.bg,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ThemeService.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _currentSubTab = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currentSubTab == 0
                                      ? const Color(0xFF00FF88)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🎮 Tournaments',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _currentSubTab == 0
                                        ? const Color(0xFF0B0F14)
                                        : ThemeService.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _currentSubTab = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currentSubTab == 1
                                      ? const Color(0xFFFF8A00)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🏆 Winner Proofs',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _currentSubTab == 1
                                        ? Colors.white
                                        : ThemeService.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _openCreateEditTournamentModal(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF0B0F14),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (_currentSubTab == 0) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search tournaments by title or game...',
                    hintStyle: TextStyle(color: ThemeService.textSecondary, fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00FF88), size: 18),
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
            ],
          ),
        ),
        Expanded(
          child: _currentSubTab == 0
              ? _buildTournamentsList()
              : _buildWinnerProofsList(),
        ),
      ],
    );
  }

  Widget _buildTournamentsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('tournaments')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final list = snapshot.data ?? [];
        var filtered = list.where((item) {
          final game = (item['game_name'] ?? item['game'] ?? '').toString();
          final title = (item['title'] ?? item['name'] ?? '').toString().toLowerCase();

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
                    child: const Icon(Icons.emoji_events_outlined, color: Color(0xFFFFD700), size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text('No Tournaments Found', style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Tap the "+ Create" button at top to launch a new tournament!', textAlign: TextAlign.center, style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
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
            return _buildTournamentCard(filtered[index]);
          },
        );
      },
    );
  }

  Widget _buildTournamentCard(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final title = (data['title'] ?? data['name'] ?? 'Untitled Tournament').toString();
    final game = (data['game_name'] ?? data['game'] ?? 'BGMI').toString();
    final format = (data['match_format'] ?? data['format'] ?? 'Squad 4v4').toString();
    final prizePool = data['prize_pool'] ?? data['prize'] ?? '1000';
    final entryFee = data['entry_fee'] ?? 'Free';
    final maxSlots = data['max_slots'] ?? data['total_teams'] ?? 25;
    final joinedSlots = data['joined_teams_count'] ?? data['teams_joined'] ?? 0;
    final status = (data['status'] ?? 'upcoming').toString().toLowerCase();
    final roomId = (data['room_id'] ?? '').toString();
    final roomPass = (data['room_password'] ?? '').toString();

    DateTime? matchDateTime;
    if (data['match_time'] != null) {
      matchDateTime = DateTime.tryParse(data['match_time'].toString());
    }

    final formattedDate = matchDateTime != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(matchDateTime)
        : (data['date_str']?.toString() ?? 'TBA');

    Color statusColor = const Color(0xFF38BDF8);
    String statusText = 'UPCOMING';
    if (status == 'live') {
      statusColor = const Color(0xFFFF4655);
      statusText = 'LIVE 🔴';
    } else if (status == 'completed') {
      statusColor = const Color(0xFF00FF88);
      statusText = 'COMPLETED ✓';
    } else if (status == 'cancelled') {
      statusColor = Colors.grey;
      statusText = 'CANCELLED';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status == 'live' ? const Color(0xFFFF4655).withOpacity(0.5) : ThemeService.border,
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
                  color: const Color(0xFF00FF88).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
                ),
                child: Text(
                  game,
                  style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  format,
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(color: ThemeService.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: ThemeService.textSecondary),
              const SizedBox(width: 5),
              Text(formattedDate, style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('🪙 Prize: ', style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
              Text('$prizePool Coins', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 12),
              Text('🎟️ Fee: ', style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
              Text('$entryFee', style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              Text('Slots: $joinedSlots/$maxSlots', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
            ],
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
                const Icon(Icons.vpn_key_rounded, size: 14, color: Color(0xFFFF8A00)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    roomId.isNotEmpty ? 'Room ID: $roomId | Pass: $roomPass' : 'Room ID & Pass: Not Published Yet',
                    style: TextStyle(
                      color: roomId.isNotEmpty ? ThemeService.textPrimary : ThemeService.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => _openRoomCredentialModal(id, roomId, roomPass),
                  child: const Text(
                    'Set Room ⚙️',
                    style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: ThemeService.border, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              PopupMenuButton<String>(
                onSelected: (val) => _updateTournamentStatus(id, val),
                color: ThemeService.card,
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'upcoming', child: Text('Mark as Upcoming')),
                  const PopupMenuItem(value: 'live', child: Text('Mark as LIVE 🔴')),
                  const PopupMenuItem(value: 'completed', child: Text('Mark as Completed ✓')),
                  const PopupMenuItem(value: 'cancelled', child: Text('Mark as Cancelled ✕')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: const Row(
                    children: [
                      Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8), size: 20),
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

  Widget _buildWinnerProofsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('tournament_claims')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
        }

        final proofs = snapshot.data ?? [];

        if (proofs.isEmpty) {
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
                    child: const Icon(Icons.checklist_rounded, color: Color(0xFF38BDF8), size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text('No Winner Proofs Submitted', style: TextStyle(color: ThemeService.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('When winning teams upload their victory screenshot, it will appear here for review!', textAlign: TextAlign.center, style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: proofs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildWinnerProofCard(proofs[index]);
          },
        );
      },
    );
  }

  Widget _buildWinnerProofCard(Map<String, dynamic> proof) {
    final claimId = proof['id']?.toString() ?? '';
    final tourneyTitle = (proof['tournament_title'] ?? 'Tournament Match').toString();
    final teamName = (proof['team_name'] ?? proof['player_name'] ?? 'Winning Team').toString();
    final game = (proof['game_name'] ?? 'BGMI').toString();
    final screenshotUrl = (proof['screenshot_url'] ?? proof['proof_url'] ?? '').toString();
    final status = (proof['status'] ?? 'pending').toString().toLowerCase();
    final rejectReason = (proof['reject_reason'] ?? '').toString();

    final isPending = status == 'pending';
    final isApproved = status == 'approved';

    Color stColor = const Color(0xFFFF8A00);
    String stLabel = 'Pending Review ⏳';
    if (isApproved) {
      stColor = const Color(0xFF00FF88);
      stLabel = 'Approved Winner 🏆';
    } else if (status == 'rejected') {
      stColor = const Color(0xFFFF4655);
      stLabel = 'Rejected ✕';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPending ? const Color(0xFFFF8A00).withOpacity(0.5) : ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tourneyTitle, style: TextStyle(color: ThemeService.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Team/Winner: $teamName • $game', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: stColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: stColor.withOpacity(0.4)),
                ),
                child: Text(stLabel, style: TextStyle(color: stColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (screenshotUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _openScreenshotViewer(screenshotUrl, '$teamName - Victory Proof'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: screenshotUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 150,
                        color: ThemeService.cardSecondary,
                        child: const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 150,
                        color: ThemeService.cardSecondary,
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Inspect Proof', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ThemeService.cardSecondary, borderRadius: BorderRadius.circular(8)),
              child: const Text('No screenshot uploaded with this claim.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ],
          if (rejectReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4655).withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.3)),
              ),
              child: Text('Rejection Reason: $rejectReason', style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11.5)),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectProofDialog(claimId, teamName),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF4655)),
                      foregroundColor: const Color(0xFFFF4655),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 15),
                    label: const Text('Reject Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveWinningProof(claimId, teamName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF0B0F14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 15),
                    label: const Text('Approve Winner', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openCreateEditTournamentModal({Map<String, dynamic>? existingData}) {
    final isEdit = existingData != null;
    final titleController = TextEditingController(text: existingData?['title'] ?? existingData?['name'] ?? '');
    final prizeController = TextEditingController(text: existingData?['prize_pool']?.toString() ?? '1000');
    final feeController = TextEditingController(text: existingData?['entry_fee']?.toString() ?? 'Free');
    final slotsController = TextEditingController(text: existingData?['max_slots']?.toString() ?? '25');
    final mapController = TextEditingController(text: existingData?['map_name'] ?? 'Erangel / Bermuda');
    final rulesController = TextEditingController(text: existingData?['rules'] ?? 'No hacks, emulators not allowed without approval.');

    String selectedGame = existingData?['game_name'] ?? _gameList[0];
    String selectedFormat = existingData?['match_format'] ?? 'Squad 4v4';
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));

    if (existingData?['match_time'] != null) {
      selectedDateTime = DateTime.tryParse(existingData!['match_time'].toString()) ?? selectedDateTime;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeService.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Tournament Title',
                    hintText: 'e.g. BGMI Pro Championship Weekly',
                    filled: true,
                    fillColor: ThemeService.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedGame,
                        dropdownColor: ThemeService.card,
                        decoration: InputDecoration(
                          labelText: 'Game',
                          filled: true,
                          fillColor: ThemeService.cardSecondary,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: _gameList.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) => setModalState(() => selectedGame = val!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedFormat,
                        dropdownColor: ThemeService.card,
                        decoration: InputDecoration(
                          labelText: 'Format',
                          filled: true,
                          fillColor: ThemeService.cardSecondary,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: ['Solo', 'Duo', 'Squad 4v4', 'Squad BR'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
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
                          labelText: 'Entry Fee (Free or Coins)',
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
                  children: [
                    Expanded(
                      child: TextField(
                        controller: slotsController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Max Slots/Teams',
                          filled: true,
                          fillColor: ThemeService.cardSecondary,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: mapController,
                        style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Map',
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
                      context: context,
                      initialDate: selectedDateTime,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
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
                        const Icon(Icons.access_time_filled_rounded, color: Color(0xFF00FF88), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Match Date & Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(selectedDateTime)}',
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rulesController,
                  maxLines: 2,
                  style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Rules & Guidelines',
                    filled: true,
                    fillColor: ThemeService.cardSecondary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;

                      final payload = {
                        'title': title,
                        'game_name': selectedGame,
                        'match_format': selectedFormat,
                        'prize_pool': prizeController.text.trim(),
                        'entry_fee': feeController.text.trim(),
                        'max_slots': int.tryParse(slotsController.text.trim()) ?? 25,
                        'map_name': mapController.text.trim(),
                        'match_time': selectedDateTime.toIso8601String(),
                        'rules': rulesController.text.trim(),
                        'status': existingData?['status'] ?? 'upcoming',
                        'updated_at': DateTime.now().toIso8601String(),
                      };

                      try {
                        if (isEdit) {
                          await SupabaseService.client
                              .from('tournaments')
                              .update(payload)
                              .eq('id', existingData['id']);
                        } else {
                          payload['created_at'] = DateTime.now().toIso8601String();
                          payload['joined_teams_count'] = 0;
                          await SupabaseService.client.from('tournaments').insert(payload);
                        }
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'Tournament Updated! 🚀' : 'Tournament Created Successfully! 🏆'),
                              backgroundColor: const Color(0xFF00FF88),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error saving tournament: $e'), backgroundColor: const Color(0xFFFF4655)),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: const Color(0xFF0B0F14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isEdit ? 'Save Changes' : 'Publish Tournament 🚀', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRoomCredentialModal(String id, String currentRoomId, String currentPass) {
    final idController = TextEditingController(text: currentRoomId);
    final passController = TextEditingController(text: currentPass);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Room Credentials 🔐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(labelText: 'Custom Room ID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passController,
              decoration: const InputDecoration(labelText: 'Room Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.client.from('tournaments').update({
                'room_id': idController.text.trim(),
                'room_password': passController.text.trim(),
              }).eq('id', id);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
            child: const Text('Save & Publish'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTournamentStatus(String id, String status) async {
    try {
      await SupabaseService.client.from('tournaments').update({'status': status}).eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $status!'), backgroundColor: const Color(0xFF00FF88)),
        );
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  Future<void> _confirmDeleteTournament(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        title: Text('Delete Tournament "$title"?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: const Text('Are you sure you want to permanently delete this tournament?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SupabaseService.client.from('tournaments').delete().eq('id', id);
    }
  }

  void _showRejectProofDialog(String claimId, String teamName) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject Proof for $teamName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter reason (Blurry screenshot, wrong match, fake proof)...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                'Blurry Screenshot',
                'Wrong Tournament ID',
                'Score mismatch',
                'Fake Proof',
              ].map((r) => ActionChip(
                label: Text(r, style: const TextStyle(fontSize: 10)),
                onPressed: () => reasonController.text = r,
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Invalid match proof screenshot.';
              await SupabaseService.client.from('tournament_claims').update({
                'status': 'rejected',
                'reject_reason': reason,
              }).eq('id', claimId);
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4655)),
            child: const Text('Reject Proof'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveWinningProof(String claimId, String teamName) async {
    try {
      await SupabaseService.client.from('tournament_claims').update({
        'status': 'approved',
      }).eq('id', claimId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Winner Approved for $teamName! 🏆'),
            backgroundColor: const Color(0xFF00FF88),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error approving: $e');
    }
  }

  void _openScreenshotViewer(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ThemeService.card,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}