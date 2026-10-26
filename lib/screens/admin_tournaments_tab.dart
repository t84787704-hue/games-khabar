// ===============================================================================
// CLEAN TOURNAMENT MANAGEMENT TAB — Single View with Floating/Bottom Create Button
// ===============================================================================
class _AdminTournamentsTab extends StatefulWidget {
  const _AdminTournamentsTab();

  @override
  State<_AdminTournamentsTab> createState() => _AdminTournamentsTabState();
}

class _AdminTournamentsTabState extends State<_AdminTournamentsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _gameFilter = 'All';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateEditTournamentModal(),
        backgroundColor: const Color(0xFF00FF88),
        foregroundColor: const Color(0xFF0B0F14),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Create Tournament',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
      ),
      body: Column(
        children: [
          // Search & Game Filter Header
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
            ),
          ),
          // Tournaments List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
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
                          Text('Tap the "Create Tournament" button below to launch a new match!', textAlign: TextAlign.center, style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildTournamentCard(filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
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
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'live' ? const Color(0xFFFF4655).withOpacity(0.5) : ThemeService.border),
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
                child: Text(game, style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: ThemeService.cardSecondary, borderRadius: BorderRadius.circular(6)),
                child: Text(format, style: TextStyle(color: ThemeService.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
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
              Text(formattedDate, style: TextStyle(color: ThemeService.textSecondary, fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🪙 Prize: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text('$prizePool Coins', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 12),
              const Text('🎟️ Fee: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                  child: const Text('Set Room ⚙️', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11.5)),
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
                icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8), size: 20),
                tooltip: 'Edit Tournament',
                onPressed: () => _openCreateEditTournamentModal(existingData: data),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF4655), size: 20),
                tooltip: 'Delete Tournament',
                onPressed: () async {
                  await SupabaseService.client.from('tournaments').delete().eq('id', id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openCreateEditTournamentModal({Map<String, dynamic>? existingData}) {
    final isEdit = existingData != null;
    final titleController = TextEditingController(text: existingData?['title'] ?? '');
    final prizeController = TextEditingController(text: existingData?['prize_pool']?.toString() ?? '1000');
    final feeController = TextEditingController(text: existingData?['entry_fee']?.toString() ?? 'Free');
    final slotsController = TextEditingController(text: existingData?['max_slots']?.toString() ?? '25');
    final mapController = TextEditingController(text: existingData?['map_name'] ?? 'Erangel');
    final rulesController = TextEditingController(text: existingData?['rules'] ?? 'No hacks, fair play required.');

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                        items: ['Solo', 'Duo', 'Squad 4v4'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
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
                  children: [
                    Expanded(
                      child: TextField(
                        controller: slotsController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: ThemeService.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Max Slots',
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
                          labelText: 'Map Name',
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
                          'Match Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(selectedDateTime)}',
                          style: TextStyle(color: ThemeService.textPrimary, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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
                        'status': 'upcoming',
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
                              content: Text(isEdit ? 'Tournament Updated! 🚀' : 'Tournament Published Successfully! 🏆'),
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
            TextField(controller: idController, decoration: const InputDecoration(labelText: 'Custom Room ID')),
            const SizedBox(height: 8),
            TextField(controller: passController, decoration: const InputDecoration(labelText: 'Room Password')),
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
}
