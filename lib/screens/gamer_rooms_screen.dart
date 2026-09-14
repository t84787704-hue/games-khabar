import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/tournament_room_model.dart';
import '../models/coin_wallet_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/tournament_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/ad_free_service.dart';
import 'coin_store_screen.dart';
import 'redeem_rewards_screen.dart';
import '../widgets/coin_history_sheet.dart';

class GamerRoomsScreen extends StatefulWidget {
  const GamerRoomsScreen({super.key});

  @override
  State<GamerRoomsScreen> createState() => _GamerRoomsScreenState();
}

// Alias for backwards compatibility
typedef TournamentBoardScreen = GamerRoomsScreen;

class _GamerRoomsScreenState extends State<GamerRoomsScreen> {
  final TournamentService _tournamentService = TournamentService();
  final GamerAuthService _authService = GamerAuthService();
  final CoinWalletService _walletService = CoinWalletService();

  // State to track joined rooms locally and reactively
  final Set<String> _joinedRoomIds = <String>{};

  String _selectedCategory = 'All Games';

  static const Color _neonGreen = Color(0xFF00FF88);

  static const List<String> _gameCategories = [
    'All Games',
    'BGMI',
    'Free Fire',
    'PUBG Mobile',
    'COD Mobile',
    'Valorant',
    'Ludo King',
    '8 Ball Pool',
  ];

  @override
  void initState() {
    super.initState();
    _tournamentService.addListener(_onServiceChanged);
    _walletService.addListener(_onServiceChanged);
    _tournamentService.fetchRooms();

    final uid = _authService.currentGamer?.uid ?? _authService.currentUid ?? 'guest';
    _walletService.getOrCreateWallet(uid);

    // Populate joined rooms from cached rooms
    for (final r in _tournamentService.rooms) {
      if (r.joinedPlayers.contains(uid) || r.joinedUserIds.contains(uid) || r.hostId == uid) {
        _joinedRoomIds.add(r.id);
      }
    }
  }

  void _onServiceChanged() {
    final uid = _authService.currentGamer?.uid ?? _authService.currentUid ?? 'guest';
    for (final r in _tournamentService.rooms) {
      if (r.joinedPlayers.contains(uid) || r.joinedUserIds.contains(uid) || r.hostId == uid) {
        _joinedRoomIds.add(r.id);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tournamentService.removeListener(_onServiceChanged);
    _walletService.removeListener(_onServiceChanged);
    super.dispose();
  }

  // Handle Joining Room
  Future<void> _handleJoinRoom(BuildContext context, TournamentRoom room) async {
    final currentGamer = _authService.currentGamer;
    final currentUid = currentGamer?.uid ?? _authService.currentUid;
    if (currentGamer == null || currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to join rooms!')),
      );
      return;
    }

    if (room.isFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This room is already full!'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    await AdFreeService().showRewardedAdForAction(
      context: context,
      actionTitle: 'Watch 1 Ad to Join Room',
      onRewardEarned: () async {
        final success = await _tournamentService.joinRoom(
          roomId: room.id,
          hostUid: room.hostId,
          playerUid: currentUid,
          playerName: currentGamer.displayName,
        );

        if (context.mounted) {
          if (success) {
            setState(() {
              _joinedRoomIds.add(room.id);
            });
            await _walletService.recordTournamentJoinedAndCheckReferral(currentUid);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Joined ${room.gameType} Room! Room ID will be shared at start time',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: _neonGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
            _showRoomDetailsSheet(context, room);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to join room. Room might be full.'),
                backgroundColor: GamerTheme.redAccent,
              ),
            );
          }
        }
      },
    );
  }

  // Show In-Room Bottom Sheet with Live Chat, Credentials & Slots
  void _showRoomDetailsSheet(BuildContext context, TournamentRoom room) {
    final currentGamer = _authService.currentGamer;
    final currentUid = currentGamer?.uid ?? _authService.currentUid ?? '';
    final bool isJoined = _joinedRoomIds.contains(room.id) ||
        room.joinedPlayers.contains(currentUid) ||
        room.joinedUserIds.contains(currentUid) ||
        room.hostId == currentUid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _InRoomBottomSheet(
        room: room,
        isJoined: isJoined,
        currentUid: currentUid,
        currentGamerName: currentGamer?.displayName ?? 'Gamer',
        onLeaveRoom: () async {
          await _tournamentService.leaveRoom(room.id, currentUid);
          setState(() {
            _joinedRoomIds.remove(room.id);
          });
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You left the room.'),
                backgroundColor: GamerTheme.redAccent,
              ),
            );
          }
        },
      ),
    );
  }

  // Create Room Dialog
  void _showCreateRoomDialog() {
    final titleController = TextEditingController(text: 'Custom Match');
    final mapController = TextEditingController(text: 'Erangel');
    final roomIdController = TextEditingController();
    final passController = TextEditingController();
    String selectedGame = _selectedCategory == 'All Games' ? 'BGMI' : _selectedCategory;
    int maxSlots = 2;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_moderator_rounded, color: GamerTheme.accentOrange, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Host Custom Room',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: GamerTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Game Selection
                const Text('SELECT GAME', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedGame,
                  dropdownColor: GamerTheme.cardElevated,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: GamerTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _gameCategories
                      .where((g) => g != 'All Games')
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedGame = val);
                  },
                ),
                const SizedBox(height: 12),
                // Title
                const Text('ROOM TITLE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: GamerTheme.bgDark,
                    hintText: 'Enter room title',
                    hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                // Map & Slots
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MAP', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: mapController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: GamerTheme.bgDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          const Text('SLOTS', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: maxSlots,
                            dropdownColor: GamerTheme.cardElevated,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: GamerTheme.bgDark,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: const [
                              DropdownMenuItem(value: 2, child: Text('2 (1v1)')),
                              DropdownMenuItem(value: 4, child: Text('4 (2v2)')),
                              DropdownMenuItem(value: 8, child: Text('8 (4v4)')),
                              DropdownMenuItem(value: 12, child: Text('12 Slots')),
                              DropdownMenuItem(value: 24, child: Text('24 Slots')),
                              DropdownMenuItem(value: 50, child: Text('50 Slots')),
                              DropdownMenuItem(value: 100, child: Text('100 Slots')),
                            ],
                            onChanged: (val) {
                              if (val != null) setSheetState(() => maxSlots = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // In-Game Room ID & Password
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('IN-GAME ROOM ID', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: roomIdController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: GamerTheme.bgDark,
                              hintText: 'e.g. 784920',
                              hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          const Text('PASSWORD', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: passController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: GamerTheme.bgDark,
                              hintText: 'e.g. 1234',
                              hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.accentOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final currentGamer = _authService.currentGamer;
                      final uid = currentGamer?.uid ?? _authService.currentUid ?? 'guest';
                      final name = currentGamer?.displayName ?? 'Gamer';

                      final newRoom = TournamentRoom(
                        id: 'room_${DateTime.now().millisecondsSinceEpoch}',
                        hostId: uid,
                        hostName: name,
                        hostAvatar: currentGamer?.photoUrl ?? '',
                        gameType: selectedGame,
                        title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : '$selectedGame Match',
                        map: mapController.text.trim().isNotEmpty ? mapController.text.trim() : 'Erangel',
                        maxSlots: maxSlots,
                        totalSlots: maxSlots,
                        currentSlots: 1,
                        joinedPlayers: [uid],
                        joinedPlayerNames: {uid: name},
                        prizePoolCoins: 500,
                        escrowCoins: 500,
                        entryFeeCoins: 0,
                        startTime: DateTime.now().add(const Duration(minutes: 15)),
                        roomId: roomIdController.text.trim(),
                        password: passController.text.trim(),
                        isLive: true,
                        isRoomRevealed: true,
                      );

                      await _tournamentService.publishRoom(newRoom);
                      if (mounted) {
                        setState(() {
                          _joinedRoomIds.add(newRoom.id);
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Room "${newRoom.title}" published!'),
                            backgroundColor: _neonGreen,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'PUBLISH ROOM',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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

  // ==========================================
  // Clean Room Card with Enhanced Joined State
  // ==========================================
  Widget _buildCleanRoomCard(TournamentRoom room) {
    final currentGamer = _authService.currentGamer;
    final currentUid = currentGamer?.uid ?? _authService.currentUid ?? '';
    final bool isJoined = _joinedRoomIds.contains(room.id) ||
        room.joinedPlayers.contains(currentUid) ||
        room.joinedUserIds.contains(currentUid) ||
        room.hostId == currentUid;

    final slotsFilled = room.joinedPlayers.length;
    final totalSlots = room.maxSlots > 0 ? room.maxSlots : 1;
    final double fillRatio = (slotsFilled / totalSlots).clamp(0.0, 1.0);
    final bool isNearFull = fillRatio >= 0.7;
    final initial = room.hostName.isNotEmpty ? room.hostName[0].toUpperCase() : 'G';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Card Container
          InkWell(
            onTap: () => _showRoomDetailsSheet(context, room),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GamerTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: isJoined
                    ? Border.all(color: _neonGreen, width: 2.0)
                    : Border.all(color: GamerTheme.borderDark),
                boxShadow: isJoined
                    ? [
                        BoxShadow(
                          color: _neonGreen.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Avatar, Title (+ check icon if joined) + Host/Map, Badge
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20, // 40 diameter
                        backgroundColor: isJoined ? _neonGreen : GamerTheme.accentOrange,
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: isJoined ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    room.title,
                                    style: const TextStyle(
                                      color: GamerTheme.textWhite,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isJoined) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: _neonGreen,
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Host: ${room.hostName} • ${room.map}',
                              style: const TextStyle(
                                color: GamerTheme.textGray,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 85,
                        height: 28,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: GamerTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isJoined ? _neonGreen.withOpacity(0.5) : GamerTheme.borderDark),
                        ),
                        child: Text(
                          room.gameType,
                          style: TextStyle(
                            color: isJoined ? _neonGreen : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: 3 columns with stats
                  Container(
                    decoration: BoxDecoration(
                      color: GamerTheme.bgDark.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Column 1: PRIZE POOL
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.monetization_on_rounded, size: 14, color: Colors.cyanAccent),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      '${room.prizePoolCoins > 0 ? room.prizePoolCoins : (room.escrowCoins > 0 ? room.escrowCoins : 800)} Coins',
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'PRIZE POOL',
                                style: TextStyle(
                                  color: GamerTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 24, width: 1, color: GamerTheme.borderDark),

                        // Column 2: ENTRY FEE
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                room.entryFeeCoins == 0 ? 'FREE' : '${room.entryFeeCoins} Coins',
                                style: const TextStyle(
                                  color: _neonGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'ENTRY FEE',
                                style: TextStyle(
                                  color: GamerTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 24, width: 1, color: GamerTheme.borderDark),

                        // Column 3: SLOTS
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${room.joinedPlayers.length}/${room.maxSlots > 0 ? room.maxSlots : 2}',
                                style: TextStyle(
                                  color: isJoined ? _neonGreen : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'SLOTS',
                                style: TextStyle(
                                  color: isJoined ? _neonGreen.withOpacity(0.8) : GamerTheme.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Stack for progress
                  Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: fillRatio,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: isJoined
                                ? _neonGreen
                                : (isNearFull ? const Color(0xFFFF3366) : const Color(0xFFFFD700)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Slots remaining & Starts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${room.availableSlots} slot${room.availableSlots == 1 ? '' : 's'} remaining',
                        style: TextStyle(
                          color: isJoined ? _neonGreen : GamerTheme.textMuted,
                          fontSize: 12,
                          fontWeight: isJoined ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      Text(
                        'Starts: ${DateFormat('hh:mm a').format(room.startTime)}',
                        style: const TextStyle(
                          color: GamerTheme.accentOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: GamerTheme.borderDark, height: 20),

                  // Status & Action button
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: room.isCompleted
                                  ? Colors.amber
                                  : (room.isLive ? _neonGreen : Colors.grey),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            room.isCompleted ? 'COMPLETED' : 'ACTIVE MATCH',
                            style: TextStyle(
                              color: room.isCompleted ? Colors.amber : _neonGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isJoined
                              ? _neonGreen
                              : (room.isFull ? GamerTheme.cardElevated : GamerTheme.accentBlue),
                          foregroundColor: isJoined ? Colors.white : (room.isFull ? GamerTheme.textMuted : GamerTheme.bgDark),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (isJoined) {
                            _showRoomDetailsSheet(context, room);
                          } else if (!room.isFull) {
                            _handleJoinRoom(context, room);
                          }
                        },
                        child: Text(
                          isJoined
                              ? 'JOINED ✓'
                              : (room.isFull ? 'ROOM FULL' : 'JOIN ROOM'),
                          style: TextStyle(
                            fontSize: isJoined ? 13 : 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Top right badge: Positioned top -8 right 12
          if (isJoined)
            Positioned(
              top: -8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _neonGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _neonGreen.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'JOINED',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentGamer?.uid ?? _authService.currentUid ?? 'guest';

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: G-Coins 400 | REDEEM (outline orange) | EARN COINS (solid orange) - all height 36 small
            ListenableBuilder(
              listenable: _walletService,
              builder: (context, _) {
                final wallet = _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 400);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: GamerTheme.cardDark,
                    border: Border(bottom: BorderSide(color: GamerTheme.borderDark)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // G-Coins Container - height 36
                      GestureDetector(
                        onTap: () => CoinHistorySheet.show(context, userId: uid),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: GamerTheme.bgDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: GamerTheme.borderDark),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(
                                '${NumberFormat("#,###").format(wallet.coins)} G-Coins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Action buttons: REDEEM & EARN COINS
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // REDEEM outline orange - height 36
                          InkWell(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const RedeemRewardsScreen()));
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: GamerTheme.accentOrange, width: 1.2),
                              ),
                              child: const Text(
                                'REDEEM',
                                style: TextStyle(
                                  color: GamerTheme.accentOrange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // EARN COINS orange solid - height 36
                          InkWell(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: GamerTheme.accentOrange,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'EARN COINS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            // Filter chips: height 36, font 13, selected orange
            Container(
              color: GamerTheme.bgDark,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _gameCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final name = _gameCategories[idx];
                    final isSelected = _selectedCategory == name;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = name;
                        });
                      },
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? GamerTheme.accentOrange : GamerTheme.cardDark,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? GamerTheme.accentOrange : GamerTheme.borderDark,
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : GamerTheme.textGray,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Room List Stream
            Expanded(
              child: StreamBuilder<List<TournamentRoom>>(
                stream: _tournamentService.getLiveRoomsStream(
                  gameName: _selectedCategory == 'All Games' ? null : _selectedCategory,
                ),
                initialData: _tournamentService.rooms.isNotEmpty ? _tournamentService.rooms : null,
                builder: (context, snapshot) {
                  final streamRooms = snapshot.data ?? _tournamentService.rooms;

                  // Filter by category
                  final filtered = streamRooms.where((r) {
                    if (_selectedCategory == 'All Games') return true;
                    return r.gameType.toLowerCase() == _selectedCategory.toLowerCase();
                  }).toList();

                  // Sort: Move joined rooms to top of list automatically
                  filtered.sort((a, b) {
                    final aJoined = _joinedRoomIds.contains(a.id) ||
                        a.joinedPlayers.contains(uid) ||
                        a.joinedUserIds.contains(uid) ||
                        a.hostId == uid;
                    final bJoined = _joinedRoomIds.contains(b.id) ||
                        b.joinedPlayers.contains(uid) ||
                        b.joinedUserIds.contains(uid) ||
                        b.hostId == uid;

                    if (aJoined && !bJoined) return -1;
                    if (!aJoined && bJoined) return 1;
                    return b.startTime.compareTo(a.startTime);
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_esports_rounded, size: 52, color: GamerTheme.textMuted.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'No $_selectedCategory rooms active',
                            style: const TextStyle(color: GamerTheme.textMuted, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GamerTheme.accentOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Host First Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: _showCreateRoomDialog,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildCleanRoomCard(filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GamerTheme.accentOrange,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_moderator_rounded, size: 20),
        label: const Text('HOST ROOM', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13)),
        onPressed: _showCreateRoomDialog,
      ),
    );
  }
}

// =======================================================
// In-Room Bottom Sheet with Live Chat, Credentials & Slots
// =======================================================
class _InRoomBottomSheet extends StatefulWidget {
  final TournamentRoom room;
  final bool isJoined;
  final String currentUid;
  final String currentGamerName;
  final VoidCallback onLeaveRoom;

  const _InRoomBottomSheet({
    required this.room,
    required this.isJoined,
    required this.currentUid,
    required this.currentGamerName,
    required this.onLeaveRoom,
  });

  @override
  State<_InRoomBottomSheet> createState() => _InRoomBottomSheetState();
}

class _InRoomBottomSheetState extends State<_InRoomBottomSheet> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastMessageSentTime;
  bool _isSending = false;

  static const Color _neonGreen = Color(0xFF00FF88);

  static const List<Color> _avatarColors = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFF6366F1),
  ];

  Color _getColorForUser(String name) {
    if (name.isEmpty) return _avatarColors[0];
    final index = name.codeUnits.fold<int>(0, (p, c) => p + c) % _avatarColors.length;
    return _avatarColors[index];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'G';
    if (parts.length == 1) {
      return parts[0].length >= 2 ? parts[0].substring(0, 2).toUpperCase() : parts[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatTimeAgo(dynamic ts) {
    if (ts == null) return 'now';
    DateTime time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else if (ts is DateTime) {
      time = ts;
    } else {
      return 'now';
    }
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatCountdown(DateTime startTime) {
    final now = DateTime.now();
    if (now.isAfter(startTime)) {
      return 'Started';
    }
    final diff = startTime.difference(now);
    if (diff.inHours > 0) {
      return 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m';
    } else if (diff.inMinutes > 0) {
      return 'Starts in ${diff.inMinutes}m';
    } else {
      return 'Starts in ${diff.inSeconds}s';
    }
  }

  Future<void> _sendMessage() async {
    if (!widget.isJoined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join room to chat!'),
          backgroundColor: GamerTheme.accentOrange,
        ),
      );
      return;
    }

    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Spam limit: 1 sec delay
    final now = DateTime.now();
    if (_lastMessageSentTime != null &&
        now.difference(_lastMessageSentTime!).inMilliseconds < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait 1s between messages'),
          duration: Duration(milliseconds: 800),
        ),
      );
      return;
    }

    // Limit to 200 chars
    final safeText = text.length > 200 ? text.substring(0, 200) : text;

    setState(() => _isSending = true);
    _lastMessageSentTime = now;
    _msgController.clear();

    try {
      final isHost = widget.room.hostId == widget.currentUid;
      final senderInitial = _getInitials(widget.currentGamerName);

      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.room.id)
          .collection('messages')
          .add({
        'senderId': widget.currentUid,
        'senderName': widget.currentGamerName,
        'senderInitial': senderInitial,
        'message': safeText,
        'timestamp': FieldValue.serverTimestamp(),
        'isHost': isHost,
      });

      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint('Error sending in-room message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final isHost = room.hostId == widget.currentUid;
    final onlineCount = room.joinedUserIds.isNotEmpty
        ? room.joinedUserIds.length
        : room.joinedPlayers.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: GamerTheme.borderLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Room Title, Badge, Close
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _neonGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  room.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GamerTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: Text(
                  room.gameType,
                  style: const TextStyle(
                    color: GamerTheme.accentOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: GamerTheme.textMuted, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // Starts in countdown + Map / Mode info
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: GamerTheme.bgDark.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: GamerTheme.accentOrange, size: 15),
                const SizedBox(width: 6),
                Text(
                  _formatCountdown(room.startTime),
                  style: const TextStyle(
                    color: GamerTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  'Map: ${room.map} • ${room.gameMode}',
                  style: const TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Room Credentials (Room ID + Password with Copy)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GamerTheme.bgDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GamerTheme.borderDark),
            ),
            child: Row(
              children: [
                // Room ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ROOM ID',
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              room.roomId.isNotEmpty ? room.roomId : 'Revealed soon...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.roomId.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: room.roomId));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Room ID copied!'), duration: Duration(seconds: 1)),
                                );
                              },
                              child: const Icon(Icons.copy_rounded, size: 14, color: _neonGreen),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 28, width: 1, color: GamerTheme.borderDark),
                const SizedBox(width: 12),
                // Password
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PASSWORD',
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              room.password.isNotEmpty ? room.password : 'None / Open',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (room.password.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: room.password));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password copied!'), duration: Duration(seconds: 1)),
                                );
                              },
                              child: const Icon(Icons.copy_rounded, size: 14, color: _neonGreen),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // CHAT HEADER: "Room Chat (X online)" with green dot
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: _neonGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Room Chat ($onlineCount online)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // CHAT MESSAGES LIST: height 200, ListView
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: GamerTheme.bgDark.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GamerTheme.borderDark),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .doc(room.id)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Failed to load chat', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _neonGreen),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello to squad!',
                      style: TextStyle(color: GamerTheme.textMuted.withOpacity(0.8), fontSize: 12),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final senderId = data['senderId'] ?? '';
                    final senderName = data['senderName'] ?? 'Player';
                    final senderInitial = data['senderInitial'] ?? _getInitials(senderName);
                    final message = data['message'] ?? '';
                    final timestamp = data['timestamp'];
                    final msgIsHost = data['isHost'] == true || senderId == room.hostId;
                    final isMe = senderId == widget.currentUid;
                    final timeAgo = _formatTimeAgo(timestamp);

                    // MY MESSAGES (Green avatar on right, bubble neonGreen)
                    if (isMe) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: const BoxDecoration(
                                      color: _neonGreen,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(2),
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      message,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeAgo,
                                    style: const TextStyle(color: GamerTheme.textMuted, fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _neonGreen,
                              child: Text(
                                senderInitial.isNotEmpty ? senderInitial[0] : 'Y',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // HOST MESSAGE (Gold border avatar FL + green tick, bubble dark gray)
                    if (msgIsHost) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.amber, width: 1.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: const Color(0xFF232D3F),
                                    child: Text(
                                      senderInitial,
                                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Icon(Icons.check_circle, size: 10, color: _neonGreen),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        senderName,
                                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('HOST', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(timeAgo, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 9)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF232D3F),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(2),
                                        topRight: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      message,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // OTHER PLAYERS (Colored avatar PX, SN, bubble dark)
                    final avatarColor = _getColorForUser(senderName);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: avatarColor,
                            child: Text(
                              senderInitial,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      senderName,
                                      style: const TextStyle(color: GamerTheme.textGray, fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(timeAgo, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 9)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1B2332),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(2),
                                      topRight: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    message,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // CHAT INPUT ROW
          if (widget.isJoined) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: GamerTheme.bgDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: GamerTheme.borderDark),
                    ),
                    child: TextField(
                      controller: _msgController,
                      maxLength: 200,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                        prefixIcon: Icon(Icons.sentiment_satisfied_alt_rounded, color: GamerTheme.textMuted, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(20),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: _neonGreen,
                    child: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GamerTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GamerTheme.borderDark),
              ),
              child: const Text(
                'Join room to chat with squad',
                style: TextStyle(color: GamerTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // SLOTS LIST (KEEP)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SLOT LIST (${room.joinedPlayers.length}/${room.maxSlots})',
                style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Text(
                '${room.availableSlots} available',
                style: const TextStyle(color: _neonGreen, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Players chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: room.joinedPlayers.map((pUid) {
              final pName = room.getPlayerName(pUid);
              final isPlayerHost = pUid == room.hostId;
              final isCurrent = pUid == widget.currentUid;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent ? _neonGreen.withOpacity(0.15) : GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent ? _neonGreen : (isPlayerHost ? Colors.amber : GamerTheme.borderDark),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPlayerHost) ...[
                      const Icon(Icons.shield_rounded, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      pName,
                      style: TextStyle(
                        color: isCurrent ? _neonGreen : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // LEAVE ROOM BUTTON (KEEP)
          if (widget.isJoined && !isHost) ...[
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: GamerTheme.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.exit_to_app_rounded, color: GamerTheme.redAccent, size: 16),
                label: const Text(
                  'LEAVE ROOM',
                  style: TextStyle(color: GamerTheme.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      backgroundColor: GamerTheme.cardDark,
                      title: const Text('Leave Room?', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      content: const Text('Your slot will be given to another player.', style: TextStyle(color: GamerTheme.textMuted, fontSize: 13)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.redAccent),
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('Leave', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    widget.onLeaveRoom();
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
