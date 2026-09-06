import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/tournament_room_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/tournament_service.dart';
import '../widgets/gamer_avatar.dart';
import '../screens/gamer_profile_screen.dart';

class TournamentBoardScreen extends StatefulWidget {
  const TournamentBoardScreen({super.key});

  @override
  State<TournamentBoardScreen> createState() => _TournamentBoardScreenState();
}

class _TournamentBoardScreenState extends State<TournamentBoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TournamentService _tournamentService = TournamentService();
  final GamerAuthService _authService = GamerAuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tournamentService.addListener(_onTournamentServiceChanged);
    print('TournamentBoardScreen: Initializing and calling fetchRooms()...');
    _tournamentService.fetchRooms();
  }

  void _onTournamentServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tournamentService.removeListener(_onTournamentServiceChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _openHostRoomSheet() {
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to host tournament rooms!')),
      );
      return;
    }

    String selectedType = 'Classic Scrim';
    String selectedMap = 'Erangel';
    final titleController = TextEditingController(text: 'BGMI Night Scrims - Daily Pro Match');
    final prizeController = TextEditingController(text: '₹500 Cash Prize');
    final feeController = TextEditingController(text: 'FREE');
    final roomIdController = TextEditingController();
    final passController = TextEditingController();
    int maxSlots = 100;
    TimeOfDay selectedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GamerTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Text(
                      'HOST CUSTOM ROOM / TOURNAMENT',
                      style: TextStyle(
                        color: GamerTheme.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Title
                const Text('TOURNAMENT TITLE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Conqueror Scrims #44',
                    hintStyle: const TextStyle(color: GamerTheme.textMuted),
                    filled: true,
                    fillColor: GamerTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),

                const SizedBox(height: 14),

                // Match Type & Map
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ROOM TYPE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: GamerTheme.bgDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: GamerTheme.borderDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedType,
                                isExpanded: true,
                                dropdownColor: GamerTheme.cardDark,
                                items: ['Classic Scrim', 'TDM 1v1', 'TDM 4v4', 'Payload']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13))))
                                    .toList(),
                                onChanged: (v) {
                                  setSheetState(() {
                                    selectedType = v ?? selectedType;
                                    if (selectedType == 'TDM 1v1') {
                                      maxSlots = 2;
                                      selectedMap = 'Warehouse';
                                    } else if (selectedType == 'TDM 4v4') {
                                      maxSlots = 8;
                                      selectedMap = 'Warehouse';
                                    } else {
                                      maxSlots = 100;
                                      selectedMap = 'Erangel';
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MAP', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: GamerTheme.bgDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: GamerTheme.borderDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedMap,
                                isExpanded: true,
                                dropdownColor: GamerTheme.cardDark,
                                items: ['Erangel', 'Warehouse', 'Miramar', 'Sanhok', 'Hangar']
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setSheetState(() => selectedMap = v ?? selectedMap),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Prize Pool & Entry Fee
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PRIZE POOL', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: prizeController,
                            style: const TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '₹500 Cash or Glory',
                              hintStyle: const TextStyle(color: GamerTheme.textMuted),
                              filled: true,
                              fillColor: GamerTheme.bgDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ENTRY FEE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: feeController,
                            style: const TextStyle(color: GamerTheme.neonGreen, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'FREE or ₹10',
                              hintStyle: const TextStyle(color: GamerTheme.textMuted),
                              filled: true,
                              fillColor: GamerTheme.bgDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Room ID & Password (Optional now, can reveal later)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('IN-GAME ROOM ID (BGMI)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: roomIdController,
                            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: 'Optional',
                              hintStyle: const TextStyle(color: GamerTheme.textMuted),
                              filled: true,
                              fillColor: GamerTheme.bgDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ROOM PASSWORD', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: passController,
                            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: 'Optional',
                              hintStyle: const TextStyle(color: GamerTheme.textMuted),
                              filled: true,
                              fillColor: GamerTheme.bgDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.accentBlue,
                      foregroundColor: GamerTheme.bgDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      print('TournamentBoardScreen: PUBLISH CUSTOM ROOM button pressed');
                      final now = DateTime.now();
                      final start = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute)
                          .add(const Duration(minutes: 30));

                      final room = TournamentRoom(
                        id: '',
                        hostId: currentGamer.uid,
                        hostName: currentGamer.displayName,
                        hostAvatar: currentGamer.photoUrl,
                        roomType: selectedType,
                        title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'BGMI Custom Match',
                        map: selectedMap,
                        entryFee: feeController.text.trim().isNotEmpty ? feeController.text.trim() : 'FREE',
                        prize: prizeController.text.trim().isNotEmpty ? prizeController.text.trim() : 'Bragging Rights',
                        roomId: roomIdController.text.trim(),
                        password: passController.text.trim(),
                        startTime: start,
                        maxSlots: maxSlots,
                        joinedPlayers: [currentGamer.uid],
                        isRoomRevealed: roomIdController.text.trim().isNotEmpty,
                      );

                      print('TournamentBoardScreen: Publishing custom room: "${room.title}"...');
                      await _tournamentService.publishRoom(room);

                      print('TournamentBoardScreen: Calling setState() and popping the form...');
                      setState(() {});
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }

                      print('TournamentBoardScreen: Calling fetchRooms() so that new room card shows instantly...');
                      await _tournamentService.fetchRooms();

                      if (mounted) {
                        setState(() {});
                        print('TournamentBoardScreen: setState called after fetchRooms() - Total rooms: ${_tournamentService.rooms.length}');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 Tournament Room is LIVE! Gamers can now join slots.'),
                            backgroundColor: GamerTheme.accentBlue,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'PUBLISH CUSTOM ROOM 🎮',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Container(
              color: GamerTheme.bgDark,
              child: TabBar(
                controller: _tabController,
                indicatorColor: GamerTheme.accentBlue,
                indicatorWeight: 3,
                labelColor: GamerTheme.accentBlue,
                unselectedLabelColor: GamerTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                tabs: const [
                  Tab(text: 'All Rooms'),
                  Tab(text: 'TDM 1v1/4v4'),
                  Tab(text: 'Classic Scrims'),
                  Tab(text: 'Free Entry'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildRoomsList(filter: 'all'),
            _buildRoomsList(filter: 'tdm'),
            _buildRoomsList(filter: 'classic'),
            _buildRoomsList(filter: 'free'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GamerTheme.accentBlue,
        foregroundColor: GamerTheme.bgDark,
        elevation: 6,
        icon: const Icon(Icons.add_moderator_rounded, color: GamerTheme.bgDark),
        label: const Text('HOST ROOM', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        onPressed: _openHostRoomSheet,
      ),
    );
  }

  Widget _buildRoomsList({required String filter}) {
    final localRooms = _tournamentService.rooms;

    return StreamBuilder<List<TournamentRoom>>(
      stream: _tournamentService.getLiveRoomsStream(),
      initialData: localRooms.isNotEmpty ? localRooms : null,
      builder: (context, snapshot) {
        final streamRooms = snapshot.data ?? [];

        // Combine local instant rooms with stream rooms
        final Map<String, TournamentRoom> roomMap = {};
        for (final r in _tournamentService.rooms) {
          if (r.isLive) roomMap[r.id] = r;
        }
        for (final r in streamRooms) {
          if (r.isLive) roomMap[r.id] = r;
        }

        final rooms = roomMap.values.toList();

        if (snapshot.connectionState == ConnectionState.waiting && rooms.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
        }

        final filtered = rooms.where((r) {
          if (filter == 'tdm') return r.roomType.toLowerCase().contains('tdm');
          if (filter == 'classic') return r.roomType.toLowerCase().contains('classic');
          if (filter == 'free') return r.entryFee.toLowerCase().contains('free');
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
                      color: GamerTheme.cardDark,
                      shape: BoxShape.circle,
                      border: Border.all(color: GamerTheme.borderDark),
                    ),
                    child: const Text('🏆', style: TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Active Custom Rooms',
                    style: TextStyle(color: GamerTheme.textWhite, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Host your own BGMI Custom Room or Scrim and invite all players!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.accentBlue,
                      foregroundColor: GamerTheme.bgDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, color: GamerTheme.bgDark),
                    label: const Text('Host First Room', style: TextStyle(fontWeight: FontWeight.w900)),
                    onPressed: _openHostRoomSheet,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildRoomCard(filtered[index]),
        );
      },
    );
  }

  Widget _buildRoomCard(TournamentRoom room) {
    final currentGamer = _authService.currentGamer;
    final currentUid = currentGamer?.uid ?? '';
    final isJoined = room.joinedPlayers.contains(currentUid);
    final isHost = room.hostId == currentUid;
    final fillPercentage = (room.joinedPlayers.length / room.maxSlots).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isJoined ? GamerTheme.accentBlue : GamerTheme.borderDark,
          width: isJoined ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Host info + Live / Map Badge
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (room.hostId.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: room.hostId)),
                      );
                    }
                  },
                  child: GamerAvatar(
                    photoUrl: room.hostAvatar,
                    displayName: room.hostName,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.title,
                        style: const TextStyle(
                          color: GamerTheme.textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Host: ${room.hostName}',
                            style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(
                            room.map,
                            style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.35)),
                  ),
                  child: Text(
                    room.roomType,
                    style: const TextStyle(
                      color: GamerTheme.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Prize and Fee Row
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  GamerTheme.accentBlue.withOpacity(0.1),
                  GamerTheme.accentOrange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GamerTheme.borderLight.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('PRIZE POOL', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      room.prize,
                      style: const TextStyle(
                        color: GamerTheme.accentBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(height: 24, width: 1, color: GamerTheme.borderDark),
                Column(
                  children: [
                    const Text('ENTRY FEE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      room.entryFee,
                      style: const TextStyle(
                        color: GamerTheme.neonGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Container(height: 24, width: 1, color: GamerTheme.borderDark),
                Column(
                  children: [
                    const Text('SLOTS', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      '${room.joinedPlayers.length}/${room.maxSlots}',
                      style: const TextStyle(
                        color: GamerTheme.textWhite,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Slots Progress Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillPercentage,
                    backgroundColor: GamerTheme.bgDark,
                    color: fillPercentage > 0.8 ? const Color(0xFFFF2D55) : GamerTheme.accentBlue,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${room.availableSlots} slots remaining',
                      style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                    ),
                    Text(
                      'Starts: ${DateFormat('hh:mm a').format(room.startTime)}',
                      style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Revealed Room ID & Password (If joined or host)
          if ((isJoined || isHost) && (room.roomId.isNotEmpty || room.isRoomRevealed)) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B29),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, color: GamerTheme.accentBlue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'ID: ${room.roomId}  |  Pass: ${room.password}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: 'Room: ${room.roomId} Pass: ${room.password}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room ID & Password copied!')),
                      );
                    },
                    child: const Text('COPY', style: TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Footer Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: GamerTheme.borderDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  room.isLive ? '🟢 MATCH ACTIVE' : '⚪ CLOSED',
                  style: const TextStyle(
                    color: GamerTheme.neonGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isHost) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: GamerTheme.textMuted),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Close Room', style: TextStyle(fontSize: 12)),
                    onPressed: () async => await _tournamentService.closeRoom(room.id),
                  ),
                ] else if (isJoined) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: GamerTheme.accentBlue),
                      foregroundColor: GamerTheme.accentBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: GamerTheme.accentBlue),
                    label: const Text('SLOT BOOKED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    onPressed: () async {
                      await _tournamentService.leaveRoom(room.id, currentUid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Left tournament slot.')),
                        );
                      }
                    },
                  ),
                ] else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: room.isFull ? GamerTheme.cardElevated : GamerTheme.accentBlue,
                      foregroundColor: room.isFull ? GamerTheme.textMuted : GamerTheme.bgDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    ),
                    onPressed: room.isFull
                        ? null
                        : () async {
                            if (currentGamer == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please create your Gamer ID to join tournaments!')),
                              );
                              return;
                            }
                            final success = await _tournamentService.joinRoom(
                              roomId: room.id,
                              hostUid: room.hostId,
                              playerUid: currentGamer.uid,
                              playerName: currentGamer.displayName,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? '🎮 Slot confirmed for ${room.title}!' : 'Room is full!'),
                                  backgroundColor: success ? GamerTheme.accentBlue : GamerTheme.redAccent,
                                ),
                              );
                            }
                          },
                    child: Text(
                      room.isFull ? 'ROOM FULL' : 'JOIN ROOM ⚔️',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: room.isFull ? GamerTheme.textMuted : GamerTheme.bgDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
