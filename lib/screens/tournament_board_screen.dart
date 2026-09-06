import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/tournament_room_model.dart';
import '../models/coin_wallet_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/tournament_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/screenshot_ocr_service.dart';
import '../widgets/gamer_avatar.dart';
import '../screens/gamer_profile_screen.dart';
import 'coin_store_screen.dart';

class TournamentBoardScreen extends StatefulWidget {
  const TournamentBoardScreen({super.key});

  @override
  State<TournamentBoardScreen> createState() => _TournamentBoardScreenState();
}

class _TournamentBoardScreenState extends State<TournamentBoardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TournamentService _tournamentService = TournamentService();
  final GamerAuthService _authService = GamerAuthService();
  final CoinWalletService _walletService = CoinWalletService();
  final ScreenshotOcrService _ocrService = ScreenshotOcrService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tournamentService.addListener(_onTournamentServiceChanged);
    _tournamentService.fetchRooms();

    final uid = _authService.currentUid ?? 'guest';
    _walletService.getOrCreateWallet(uid);
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

  void _showNotEnoughCoinsDialog(int needed, int available) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GamerTheme.accentOrange, width: 1.5),
        ),
        title: const Row(
          children: [
            Text('💰', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Text(
              'Not Enough G-Coins',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You need $needed G-Coins for this action, but your available balance is $available G-Coins.',
              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GamerTheme.bgDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: GamerTheme.neonGreen, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Earn free coins easily via Daily Bonus, Watching Ads, or Inviting friends!',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.neonGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
            },
            child: const Text('EARN COINS NOW 💰', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _openHostRoomSheet() {
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to host tournament rooms!')),
      );
      return;
    }

    final wallet = _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 1000);

    String selectedType = 'TDM 1v1';
    String selectedMap = 'Warehouse';
    final titleController = TextEditingController(text: 'BGMI TDM 1v1 - Winner Takes All');
    int prizePoolCoins = 500;
    int entryFeeCoins = 0;
    final roomIdController = TextEditingController();
    final passController = TextEditingController();
    int maxSlots = 2;
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('🏆', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          'HOST TOURNAMENT (COINS)',
                          style: TextStyle(
                            color: GamerTheme.textWhite,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: GamerTheme.accentBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.4)),
                      ),
                      child: Text(
                        '💰 ${wallet.coins} Coins',
                        style: const TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Title
                const Text('TOURNAMENT TITLE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Conqueror TDM 1v1 #10',
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
                                items: ['TDM 1v1', 'TDM 4v4', 'Classic Scrim', 'Payload']
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
                                items: ['Warehouse', 'Erangel', 'Miramar', 'Sanhok', 'Hangar']
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

                // Prize Pool Selection (Coins Escrow)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PRIZE POOL (ESCROW HOLD)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                    Text('💰 $prizePoolCoins Coins', style: const TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [100, 200, 500, 1000].map((amount) {
                    final isSelected = prizePoolCoins == amount;
                    return ChoiceChip(
                      label: Text('💰 $amount', style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: GamerTheme.accentBlue,
                      backgroundColor: GamerTheme.bgDark,
                      onSelected: (val) => setSheetState(() => prizePoolCoins = amount),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Entry Fee Selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ENTRY FEE (PER PLAYER)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                    Text(entryFeeCoins == 0 ? 'FREE' : '💰 $entryFeeCoins Coins', style: const TextStyle(color: GamerTheme.neonGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [0, 20, 50, 100].map((fee) {
                    final isSelected = entryFeeCoins == fee;
                    return ChoiceChip(
                      label: Text(fee == 0 ? 'FREE' : '💰 $fee', style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                      selected: isSelected,
                      selectedColor: GamerTheme.neonGreen,
                      backgroundColor: GamerTheme.bgDark,
                      onSelected: (val) => setSheetState(() => entryFeeCoins = fee),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Room ID & Password
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('IN-GAME ROOM ID', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: roomIdController,
                            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                            decoration: InputDecoration(
                              hintText: 'e.g. 582910',
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
                              hintText: 'e.g. 1234',
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
                      // Check wallet coins for prize pool escrow
                      if (wallet.coins < prizePoolCoins) {
                        Navigator.pop(ctx);
                        _showNotEnoughCoinsDialog(prizePoolCoins, wallet.coins);
                        return;
                      }

                      final now = DateTime.now();
                      final start = DateTime(now.year, now.month, now.day, selectedTime.hour, selectedTime.minute)
                          .add(const Duration(minutes: 30));

                      final roomTitle = titleController.text.trim().isNotEmpty
                          ? titleController.text.trim()
                          : 'BGMI $selectedType Match';

                      final room = TournamentRoom(
                        id: '',
                        hostId: currentGamer.uid,
                        hostName: currentGamer.displayName,
                        hostAvatar: currentGamer.photoUrl,
                        roomType: selectedType,
                        title: roomTitle,
                        map: selectedMap,
                        entryFee: entryFeeCoins == 0 ? 'FREE' : '$entryFeeCoins Coins',
                        prize: '💰 $prizePoolCoins Coins Prize',
                        prizePoolCoins: prizePoolCoins,
                        entryFeeCoins: entryFeeCoins,
                        escrowCoins: prizePoolCoins,
                        status: 'OPEN',
                        roomId: roomIdController.text.trim(),
                        password: passController.text.trim(),
                        startTime: start,
                        maxSlots: maxSlots,
                        joinedPlayers: [currentGamer.uid],
                        isRoomRevealed: roomIdController.text.trim().isNotEmpty,
                      );

                      final published = await _tournamentService.publishRoom(room);

                      // Hold host coins in escrow
                      await _walletService.holdRoomHostCoins(
                        userId: currentGamer.uid,
                        prizePoolCoins: prizePoolCoins,
                        roomId: published.id,
                        roomTitle: roomTitle,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      _tabController.animateTo(0);
                      await _tournamentService.fetchRooms();

                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Tournament is LIVE! $prizePoolCoins Coins held in Escrow.'),
                            backgroundColor: GamerTheme.accentBlue,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'HOST & LOCK 💰 $prizePoolCoins COINS 🔒',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
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

  void _showRoomDetailsDialog(BuildContext context, TournamentRoom room, String currentUid) {
    final roomIdText = room.roomId.trim().isNotEmpty ? room.roomId.trim() : 'TBD (Host revealing soon)';
    final passwordText = room.password.trim().isNotEmpty ? room.password.trim() : 'TBD';
    final mapName = room.map.trim().isNotEmpty ? room.map.trim() : 'Erangel';
    final startTimeFormatted = DateFormat('hh:mm a, dd MMM').format(room.startTime);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: GamerTheme.accentBlue.withOpacity(0.4), width: 1.5),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GamerTheme.accentBlue.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.vpn_key_rounded, color: GamerTheme.accentBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROOM CREDENTIALS',
                    style: TextStyle(
                      color: GamerTheme.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Slot booked badge - slots preserved at 2/2
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: GamerTheme.neonGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: GamerTheme.neonGreen, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'SLOT BOOKED (${room.joinedPlayers.length}/${room.maxSlots}) • CONFIRMED',
                      style: const TextStyle(
                        color: GamerTheme.neonGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Room ID box with COPY ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ROOM ID',
                            style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            roomIdText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GamerTheme.accentBlue,
                        foregroundColor: GamerTheme.bgDark,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: roomIdText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Room ID "$roomIdText" copied to clipboard! 📋'),
                            backgroundColor: GamerTheme.accentBlue,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('COPY ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Password box with COPY PASSWORD
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PASSWORD',
                            style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            passwordText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GamerTheme.accentOrange,
                        foregroundColor: GamerTheme.bgDark,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: passwordText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password "$passwordText" copied to clipboard! 🔑'),
                            backgroundColor: GamerTheme.accentOrange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text('COPY PASSWORD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Match details: MAP & STARTS TIME
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded, color: GamerTheme.accentBlue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('MAP', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(mapName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 28, width: 1, color: GamerTheme.borderDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, color: GamerTheme.accentOrange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('STARTS TIME', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(startTimeFormatted, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ENTER BGMI button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamerTheme.accentBlue,
                    foregroundColor: GamerTheme.bgDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.sports_esports_rounded, size: 18),
                  label: const Text('ENTER BGMI 🎮', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: roomIdText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied Room ID! Launching BGMI...'),
                        backgroundColor: GamerTheme.accentBlue,
                      ),
                    );
                    Navigator.pop(dialogCtx);
                  },
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        actions: [
          Row(
            children: [
              // Small leave room option with refund
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  if (currentUid.isNotEmpty) {
                    await _tournamentService.leaveRoom(room.id, currentUid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Left tournament slot. Entry fee (if any) refunded.')),
                      );
                    }
                  }
                },
                child: const Text('Leave Slot', style: TextStyle(color: GamerTheme.redAccent, fontSize: 11)),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GamerTheme.cardElevated,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: GamerTheme.borderLight),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// OCR Result Submission: Participant picks BGMI victory screenshot
  Future<void> _handleUploadResult(TournamentRoom room, String currentUid, String playerName) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.document_scanner_rounded, color: GamerTheme.accentBlue, size: 40),
            const SizedBox(height: 12),
            const Text(
              'SUBMIT BGMI VICTORY RESULT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pick your match ending screenshot. Our AI OCR scans for "VICTORY", "#1", or "WINNER" to verify your win and auto-claim prize coins!',
              textAlign: TextAlign.center,
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.neonGreen,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('PICK FROM GALLERY 📱', style: TextStyle(fontWeight: FontWeight.w900)),
              onPressed: () async {
                Navigator.pop(ctx);
                _processOcrUpload(room, currentUid, playerName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processOcrUpload(TournamentRoom room, String currentUid, String playerName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Scanning screenshot with ML Kit OCR...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    final candidateNames = [playerName, room.hostName];
    final result = await _ocrService.processResultScreenshot(
      roomId: room.id,
      userId: currentUid,
      candidateNames: candidateNames,
    );

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot selection cancelled.')),
      );
      return;
    }

    // Submit to room
    await _tournamentService.submitResultScreenshot(
      roomId: room.id,
      playerUid: currentUid,
      playerName: playerName,
      screenshotUrl: result.imageUrl,
      ocrText: result.recognizedText,
      isVictory: result.isVictory,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              result.isVictory ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: result.isVictory ? GamerTheme.neonGreen : GamerTheme.accentOrange,
            ),
            const SizedBox(width: 8),
            Text(
              result.isVictory ? 'VICTORY DETECTED! 🏆' : 'RESULT SUBMITTED',
              style: TextStyle(
                color: result.isVictory ? GamerTheme.neonGreen : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.localPath.isNotEmpty && File(result.localPath).existsSync()) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(result.localPath),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              result.isVictory
                  ? 'Awesome! Victory keywords verified from your screenshot. Host will confirm and transfer ${room.escrowCoins} Coins!'
                  : 'Screenshot uploaded for host verification. Host will review the match result.',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.accentBlue,
              foregroundColor: GamerTheme.bgDark,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Host Dialog to Finish Match and Transfer Escrow Coins to Winner
  void _showFinishMatchDialog(TournamentRoom room) {
    String? selectedWinnerUid;
    String? selectedWinnerName;

    // Auto-detect winner based on victory submission
    for (final entry in room.resultSubmissions.entries) {
      final data = entry.value as Map<String, dynamic>?;
      if (data?['isVictory'] == true) {
        selectedWinnerUid = entry.key;
        selectedWinnerName = data?['playerName']?.toString();
        break;
      }
    }

    if (selectedWinnerUid == null && room.joinedPlayers.isNotEmpty) {
      selectedWinnerUid = room.joinedPlayers.first;
      selectedWinnerName = selectedWinnerUid == room.hostId ? room.hostName : 'Opponent';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: GamerTheme.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.amber, width: 2),
          ),
          title: const Row(
            children: [
              Text('🏆', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CONFIRM MATCH WINNER',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total Prize Pool: ${room.escrowCoins} G-Coins\n(Escrow will transfer immediately to winner)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'SELECT WINNER:',
                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...room.joinedPlayers.map((playerUid) {
                  final isHost = playerUid == room.hostId;
                  final submission = room.resultSubmissions[playerUid] as Map<String, dynamic>?;
                  final hasSubmitted = submission != null;
                  final isVictoryVerified = submission?['isVictory'] == true;
                  final playerName = isHost ? room.hostName : (submission?['playerName'] ?? 'Player');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: selectedWinnerUid == playerUid ? GamerTheme.accentBlue.withOpacity(0.15) : GamerTheme.bgDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedWinnerUid == playerUid ? GamerTheme.accentBlue : GamerTheme.borderDark,
                        width: selectedWinnerUid == playerUid ? 1.5 : 1.0,
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: playerUid,
                      groupValue: selectedWinnerUid,
                      activeColor: GamerTheme.accentBlue,
                      onChanged: (val) {
                        setDialogState(() {
                          selectedWinnerUid = val;
                          selectedWinnerName = playerName;
                        });
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$playerName ${isHost ? "(Host)" : ""}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          if (isVictoryVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: GamerTheme.neonGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('OCR VICTORY ✓', style: TextStyle(color: GamerTheme.neonGreen, fontSize: 9, fontWeight: FontWeight.w900)),
                            )
                          else if (hasSubmitted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: GamerTheme.accentBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Screenshot ✓', style: TextStyle(color: GamerTheme.accentBlue, fontSize: 9, fontWeight: FontWeight.bold)),
                            )
                          else
                            const Text('No Screenshot', style: TextStyle(color: GamerTheme.redAccent, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text(
                  '15-Minute Rule: If participant did not upload victory screenshot, -10 trustScore is applied.',
                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: GamerTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: selectedWinnerUid == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final success = await _tournamentService.finishMatchWithWinner(
                        roomId: room.id,
                        winnerUid: selectedWinnerUid!,
                        winnerName: selectedWinnerName ?? 'Winner',
                      );
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.amber,
                            content: Text(
                              success
                                  ? '🏆 Prize of ${room.escrowCoins} Coins transferred to $selectedWinnerName!'
                                  : 'Could not complete transfer.',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }
                    },
              child: const Text('CONFIRM WINNER 💰', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid ?? 'guest';

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Top Coin Balance Bar & Rule Banner
          SliverToBoxAdapter(
            child: StreamBuilder<CoinWallet>(
              stream: _walletService.walletStream(uid),
              initialData: _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 1000),
              builder: (context, snap) {
                final wallet = snap.data ?? const CoinWallet(userId: '', coins: 1000);
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  decoration: const BoxDecoration(
                    color: GamerTheme.cardDark,
                    border: Border(bottom: BorderSide(color: GamerTheme.borderDark)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('💰', style: TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${NumberFormat("#,###").format(wallet.coins)} G-Coins',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (wallet.escrowCoins > 0)
                                    Text(
                                      '🔒 ${wallet.escrowCoins} in Escrow',
                                      style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GamerTheme.neonGreen,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.black),
                            label: const Text('EARN COINS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinStoreScreen()));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 15-Minute Rule Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: GamerTheme.bgDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_rounded, color: GamerTheme.accentBlue, size: 14),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Upload Victory Screenshot to claim prize • 15 Min Rule: No Screenshot = No Prize',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
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

        final Map<String, TournamentRoom> roomMap = {};
        for (final r in _tournamentService.rooms) {
          roomMap[r.id] = r;
        }
        for (final r in streamRooms) {
          roomMap[r.id] = r;
        }

        final rooms = roomMap.values.toList();
        rooms.sort((a, b) {
          final aTime = a.createdAt ?? a.startTime;
          final bTime = b.createdAt ?? b.startTime;
          return bTime.compareTo(aTime);
        });

        if (snapshot.connectionState == ConnectionState.waiting && rooms.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
        }

        final filtered = rooms.where((r) {
          if (filter == 'tdm') return r.roomType.toLowerCase().contains('tdm');
          if (filter == 'classic') return r.roomType.toLowerCase().contains('classic');
          if (filter == 'free') return r.entryFee.toLowerCase().contains('free') || r.entryFeeCoins == 0;
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
                    'Host your own BGMI Custom Room or Scrim and compete for G-Coins!',
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
    final isCompleted = room.isCompleted;
    final isExpired = room.isExpired;
    final hasSubmittedResult = room.resultSubmissions.containsKey(currentUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? Colors.amber.withOpacity(0.6)
              : isJoined
                  ? GamerTheme.accentBlue
                  : GamerTheme.borderDark,
          width: isCompleted || isJoined ? 1.5 : 1.0,
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
          // Winner Banner if Completed
          if (isCompleted) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'WINNER: ${room.winnerName ?? "Champion"} (+${room.escrowCoins} Coins Claimed)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Header: Host info + Type Badge
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
                      '💰 ${room.prizePoolCoins} Coins',
                      style: const TextStyle(
                        color: GamerTheme.accentBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
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
                      room.entryFeeCoins == 0 ? 'FREE' : '💰 ${room.entryFeeCoins} Coins',
                      style: const TextStyle(
                        color: GamerTheme.neonGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
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
                      style: TextStyle(
                        color: room.isFull ? const Color(0xFFFF2D55) : GamerTheme.textWhite,
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
                    color: fillPercentage >= 1.0 ? const Color(0xFFFF2D55) : GamerTheme.accentBlue,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      room.isFull ? 'Room Full (2/2)' : '${room.availableSlots} slots remaining',
                      style: TextStyle(
                        color: room.isFull ? const Color(0xFFFF2D55) : GamerTheme.textMuted,
                        fontSize: 11,
                        fontWeight: room.isFull ? FontWeight.bold : FontWeight.normal,
                      ),
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
                  isCompleted
                      ? '🏆 MATCH COMPLETED'
                      : isExpired
                          ? '⚪ EXPIRED / REFUNDED'
                          : room.isLive
                              ? '🟢 ACTIVE MATCH'
                              : '⚪ CLOSED',
                  style: TextStyle(
                    color: isCompleted
                        ? Colors.amber
                        : isExpired
                            ? GamerTheme.textMuted
                            : GamerTheme.neonGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),

                // Host Controls
                if (isHost && !isCompleted && !isExpired) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.black),
                        label: const Text('FINISH MATCH 🏆', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                        onPressed: () => _showFinishMatchDialog(room),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: GamerTheme.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              backgroundColor: GamerTheme.cardDark,
                              title: const Text('Cancel & Refund Tournament?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              content: const Text(
                                'This will return all prize pool coins to you and refund entry fees to joiners.',
                                style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: GamerTheme.redAccent),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('REFUND ALL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _tournamentService.cancelOrExpireRoom(room.id);
                            if (mounted) setState(() {});
                          }
                        },
                        child: const Text('Cancel', style: TextStyle(color: GamerTheme.redAccent, fontSize: 10)),
                      ),
                    ],
                  ),
                ] else if (isJoined && !isCompleted && !isExpired) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // SLOT BOOKED opens popup credentials dialog (slots stays intact)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: GamerTheme.accentBlue, width: 1.5),
                          backgroundColor: GamerTheme.accentBlue.withOpacity(0.12),
                          foregroundColor: GamerTheme.accentBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 14, color: GamerTheme.accentBlue),
                        label: const Text('SLOT BOOKED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                        onPressed: () => _showRoomDetailsDialog(context, room, currentUid),
                      ),
                      const SizedBox(width: 6),
                      // SUBMIT RESULT button for participants
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasSubmittedResult ? GamerTheme.neonGreen : GamerTheme.accentOrange,
                          foregroundColor: hasSubmittedResult ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(hasSubmittedResult ? Icons.done_all_rounded : Icons.file_upload_outlined, size: 14),
                        label: Text(
                          hasSubmittedResult ? 'RESULT SENT ✓' : 'RESULT 📸',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                        onPressed: () => _handleUploadResult(room, currentUid, currentGamer?.displayName ?? 'Gamer'),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: GamerTheme.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          if (currentUid.isNotEmpty) {
                            await _tournamentService.leaveRoom(room.id, currentUid);
                            if (mounted) setState(() {});
                          }
                        },
                        child: const Text('Leave', style: TextStyle(color: GamerTheme.redAccent, fontSize: 10)),
                      ),
                    ],
                  ),
                ] else if (!isCompleted && !isExpired) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: room.isFull ? GamerTheme.cardElevated : GamerTheme.accentBlue,
                      foregroundColor: room.isFull ? GamerTheme.textMuted : GamerTheme.bgDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

                            final wallet = _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 1000);
                            if (room.entryFeeCoins > 0 && wallet.coins < room.entryFeeCoins) {
                              _showNotEnoughCoinsDialog(room.entryFeeCoins, wallet.coins);
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
                                  content: Text(success ? '🎮 Slot confirmed for ${room.title}!' : 'Room is full or error occurred!'),
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
