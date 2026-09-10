import 'dart:io';
import 'dart:ui';
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
import '../widgets/coin_history_sheet.dart';
import '../constants/tournament_game_categories.dart';
import '../services/ad_free_service.dart';
import 'redeem_rewards_screen.dart';

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

  String _selectedCategory = 'All Games';

  static final List<Map<String, String>> _gameCategories = [
    {'name': 'All Games', 'icon': '🎮'},
    ...kExactGameCategories.map((name) => {
      'name': name,
      'icon': getGameConfig(name).icon,
    }),
  ];

  String _getCategoryIcon(String category) {
    if (category == 'All Games') return '🎮';
    return getGameConfig(category).icon;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tournamentService.addListener(_onTournamentServiceChanged);
    _walletService.addListener(_onTournamentServiceChanged);
    _tournamentService.fetchRooms();

    final uid = _authService.currentGamer?.uid ?? _authService.currentUid ?? 'guest';
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
    _walletService.removeListener(_onTournamentServiceChanged);
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

  void _openHostRoomSheet({String? preselectedGame}) {
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to host tournament rooms!')),
      );
      return;
    }

    final wallet = _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 1000);

    final availableGames = kExactGameCategories;

    final initialConfig = getGameConfig(preselectedGame ?? 'BGMI');
    String selectedGame = (preselectedGame != null && availableGames.contains(preselectedGame))
        ? preselectedGame
        : 'BGMI';
    String selectedMode = initialConfig.defaultMode;
    String selectedMap = initialConfig.defaultMap;
    String selectedPlatform = initialConfig.platform;
    String selectedRegion = 'Asia / India';
    int maxSlots = initialConfig.defaultSlots;
    const int entryFeeCoins = 0;
    const int prizePoolCoins = 500;
    DateTime selectedStartTime = DateTime.now().add(const Duration(minutes: 30));

    final titleController = TextEditingController(text: '$selectedGame $selectedMode Match');
    final roomIdController = TextEditingController();
    final passController = TextEditingController();
    final rulesController = TextEditingController(
      text: 'Fair play only. No emulators or hacks allowed. Take victory screenshot for proof.',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isLobbyCode = selectedGame == 'Valorant' ||
              selectedGame == 'Counter-Strike 2' ||
              selectedGame == 'Fortnite' ||
              selectedGame == 'Apex Legends' ||
              selectedGame == 'League of Legends' ||
              selectedGame == 'Roblox';

          final isLinkOnly = selectedGame == 'Ludo King' ||
              selectedGame == '8 Ball Pool' ||
              selectedGame == 'Clash Royale' ||
              selectedGame == 'Brawl Stars';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                  const SizedBox(height: 16),

                  // FIELD 1: SELECT GAME (Dropdown with Icons - 20 Games + Others)
                  const Text('1. SELECT GAME', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: GamerTheme.bgDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.borderDark),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedGame,
                        isExpanded: true,
                        dropdownColor: GamerTheme.cardDark,
                        items: availableGames.map((g) {
                          final dummy = TournamentRoom(id: '', hostId: '', hostName: '', title: '', startTime: DateTime.now(), gameType: g);
                          return DropdownMenuItem(
                            value: g,
                            child: Row(
                              children: [
                                Text(dummy.gameIcon, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 10),
                                Text(g, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setSheetState(() {
                            selectedGame = val;
                            final cfg = getGameConfig(selectedGame);
                            selectedMode = cfg.defaultMode;
                            selectedMap = cfg.defaultMap;
                            selectedPlatform = cfg.platform;
                            maxSlots = cfg.defaultSlots;
                            titleController.text = '$selectedGame $selectedMode Match';
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // FIELD 2: SELECT MODE & MAP
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('2. SELECT MODE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
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
                                  value: getGameConfig(selectedGame).modes.contains(selectedMode)
                                      ? selectedMode
                                      : getGameConfig(selectedGame).defaultMode,
                                  isExpanded: true,
                                  dropdownColor: GamerTheme.cardDark,
                                  items: getGameConfig(selectedGame).modes
                                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12))))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setSheetState(() {
                                      selectedMode = v;
                                      titleController.text = '$selectedGame $selectedMode Match';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MAP / TABLE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
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
                                  value: getGameConfig(selectedGame).maps.contains(selectedMap)
                                      ? selectedMap
                                      : getGameConfig(selectedGame).defaultMap,
                                  isExpanded: true,
                                  dropdownColor: GamerTheme.cardDark,
                                  items: getGameConfig(selectedGame).maps
                                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12))))
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

                  // FIELD 3: PLATFORM & SERVER / REGION
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('3. PLATFORM', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
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
                                  value: selectedPlatform,
                                  isExpanded: true,
                                  dropdownColor: GamerTheme.cardDark,
                                  items: ['Mobile', 'PC', 'Console', 'Cross-Platform']
                                      .map((p) => DropdownMenuItem(
                                            value: p,
                                            child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setSheetState(() => selectedPlatform = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SERVER / REGION', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
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
                                  value: selectedRegion,
                                  isExpanded: true,
                                  dropdownColor: GamerTheme.cardDark,
                                  items: ['Asia / India', 'Middle East', 'Europe', 'North America', 'South East Asia', 'Global']
                                      .map((r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                          ))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setSheetState(() => selectedRegion = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // FIELD 4: ROOM TITLE
                  const Text('4. ROOM TITLE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. $selectedGame $selectedMode Match',
                      hintStyle: const TextStyle(color: GamerTheme.textMuted),
                      filled: true,
                      fillColor: GamerTheme.bgDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // FIELD 5: MAX PLAYERS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('5. MAX PLAYERS (SLOTS)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                      Text('$maxSlots Players', style: const TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [2, 4, 8, 10, 16, 32, 50, 100].map((slots) {
                      final isSelected = maxSlots == slots;
                      return ChoiceChip(
                        label: Text('$slots', style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: GamerTheme.accentBlue,
                        backgroundColor: GamerTheme.bgDark,
                        onSelected: (val) {
                          setSheetState(() {
                            maxSlots = slots;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // FIELD 6: ENTRY FEE (FREE ONLY)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('6. ENTRY FEE (PER PLAYER)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                      Text('FREE (0 Coins)', style: TextStyle(color: GamerTheme.neonGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: GamerTheme.bgDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: GamerTheme.neonGreen, size: 18),
                        SizedBox(width: 8),
                        Text('FREE ENTRY (0 Coins for all participants)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // FIELD 7: PRIZE POOL (ADMIN WALLET ESCROW)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('7. PRIZE POOL (SPONSORED)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                      Text('💰 500 Coins', style: TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: GamerTheme.bgDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_rounded, color: GamerTheme.accentBlue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('💰 500 G-Coins Prize Pool sponsored by Admin Wallet (Free for host & players)', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // FIELD 8: START DATE + TIME
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('8. START DATE & TIME', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                      Text(
                        DateFormat('EEE, dd MMM • hh:mm a').format(selectedStartTime),
                        style: const TextStyle(color: GamerTheme.accentOrange, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.timer_outlined, size: 14, color: GamerTheme.accentBlue),
                        label: const Text('+15m', style: TextStyle(fontSize: 12, color: Colors.white)),
                        backgroundColor: GamerTheme.bgDark,
                        onPressed: () => setSheetState(() => selectedStartTime = DateTime.now().add(const Duration(minutes: 15))),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.timer_outlined, size: 14, color: GamerTheme.accentBlue),
                        label: const Text('+30m', style: TextStyle(fontSize: 12, color: Colors.white)),
                        backgroundColor: GamerTheme.bgDark,
                        onPressed: () => setSheetState(() => selectedStartTime = DateTime.now().add(const Duration(minutes: 30))),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.timer_outlined, size: 14, color: GamerTheme.accentBlue),
                        label: const Text('+1h', style: TextStyle(fontSize: 12, color: Colors.white)),
                        backgroundColor: GamerTheme.bgDark,
                        onPressed: () => setSheetState(() => selectedStartTime = DateTime.now().add(const Duration(hours: 1))),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month_rounded, size: 14, color: GamerTheme.accentOrange),
                        label: const Text('Pick Date/Time', style: TextStyle(fontSize: 12, color: Colors.white)),
                        backgroundColor: GamerTheme.bgDark,
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: ctx,
                            initialDate: selectedStartTime,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null && ctx.mounted) {
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(selectedStartTime),
                            );
                            if (time != null) {
                              setSheetState(() {
                                selectedStartTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // FIELD 9 & 10: DYNAMIC CREDENTIALS (Room ID / Lobby Code / Invite Link & Password)
                  if (isLinkOnly) ...[
                    const Text('9. INVITE LINK / ROOM CODE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: roomIdController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. https://ludoking.app/room/1234 or Code (or leave TBD)',
                        hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                        filled: true,
                        fillColor: GamerTheme.bgDark,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('ℹ️ Invite link or room code will be revealed to joined players.', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                  ] else if (isLobbyCode) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('9. LOBBY CODE / PARTY CODE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: roomIdController,
                                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g. #VALO-7892 (or leave TBD)',
                                  hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
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
                              const Text('PASSWORD (OPTIONAL)', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: passController,
                                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Optional PIN',
                                  hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
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
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('9. IN-GAME ROOM ID', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: roomIdController,
                                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 582910 (or leave TBD)',
                                  hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
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
                              const Text('10. ROOM PASSWORD', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: passController,
                                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 1234',
                                  hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
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
                  ],

                  const SizedBox(height: 14),

                  // FIELD 11: RULES
                  const Text('11. MATCH RULES', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: rulesController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Fair play only. No emulators or hacks allowed.',
                      hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: GamerTheme.bgDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
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
                        final roomTitle = titleController.text.trim().isNotEmpty
                            ? titleController.text.trim()
                            : '$selectedGame $selectedMode Match';

                        final room = TournamentRoom(
                          id: '',
                          hostId: currentGamer.uid,
                          hostName: currentGamer.displayName,
                          hostAvatar: currentGamer.photoUrl,
                          gameType: selectedGame,
                          gameMode: selectedMode,
                          roomType: selectedMode,
                          title: roomTitle,
                          map: selectedMap,
                          platform: selectedPlatform,
                          serverRegion: selectedRegion,
                          rules: rulesController.text.trim().isNotEmpty
                              ? rulesController.text.trim()
                              : 'Fair play only. No emulators or hacks allowed.',
                          entryFee: 'FREE',
                          prize: '💰 500 Coins Prize',
                          prizePoolCoins: 500,
                          entryFeeCoins: 0,
                          escrowCoins: 500,
                          status: 'OPEN',
                          roomId: roomIdController.text.trim(),
                          password: isLinkOnly ? '' : passController.text.trim(),
                          startTime: selectedStartTime,
                          maxSlots: maxSlots,
                          totalSlots: maxSlots,
                          joinedPlayers: [currentGamer.uid],
                          joinedPlayerNames: {currentGamer.uid: currentGamer.displayName},
                          isRoomRevealed: roomIdController.text.trim().isNotEmpty,
                        );

                        await _tournamentService.publishRoom(room);

                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {
                          _selectedCategory = selectedGame;
                        });
                        await _tournamentService.fetchRooms();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🎉 $selectedGame Tournament is LIVE! 500 Coins Admin Escrow.'),
                              backgroundColor: GamerTheme.accentBlue,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'HOST FREE TOURNAMENT 🎮 (500 COINS PRIZE)',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8),
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

  void _showRoomDetailsDialog(BuildContext context, TournamentRoom room, String currentUid) {
    final hasRoomId = room.roomId.trim().isNotEmpty && room.roomId.trim().toUpperCase() != 'TBD';
    final hasPassword = room.password.trim().isNotEmpty && room.password.trim().toUpperCase() != 'TBD';
    final isLinkOnly = room.isLinkOnlyGame;
    final isHost = room.hostId == currentUid;
    final mapName = room.map.trim().isNotEmpty ? room.map.trim() : 'Default';
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
              child: Text(room.gameIcon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GamerTheme.cardElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: GamerTheme.borderLight.withOpacity(0.3)),
                        ),
                        child: Text(
                          room.gameType,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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
            if (isHost) ...[
              IconButton(
                tooltip: 'Edit Credentials',
                icon: const Icon(Icons.edit_note_rounded, color: GamerTheme.accentBlue, size: 22),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _showEditCredentialsDialog(context, room);
                },
              ),
            ],
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Slot booked badge - slots preserved at 2/2 or actual
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

              // Orange Warning if ID is TBD
              if (!hasRoomId) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: GamerTheme.accentOrange, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'TBD (Revealed shortly) - Host will update 15 mins before start',
                          style: TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Room ID or Invite Link box with COPY
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: !hasRoomId ? GamerTheme.accentOrange.withOpacity(0.4) : GamerTheme.borderDark),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLinkOnly ? 'INVITE LINK' : 'ROOM ID',
                            style: const TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            hasRoomId ? room.roomId : 'TBD (Revealed shortly)',
                            style: TextStyle(
                              color: hasRoomId ? Colors.white : GamerTheme.accentOrange,
                              fontSize: hasRoomId ? 15 : 13,
                              fontWeight: FontWeight.w900,
                              fontFamily: hasRoomId ? 'monospace' : null,
                              letterSpacing: hasRoomId ? 1 : 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasRoomId ? GamerTheme.accentBlue : GamerTheme.cardElevated,
                        foregroundColor: hasRoomId ? GamerTheme.bgDark : GamerTheme.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: hasRoomId
                          ? () {
                              Clipboard.setData(ClipboardData(text: room.roomId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${isLinkOnly ? "Invite link" : "Room ID"} "${room.roomId}" copied to clipboard! 📋'),
                                  backgroundColor: GamerTheme.accentBlue,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(isLinkOnly ? 'COPY LINK' : 'COPY ID', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),

              // Password box with COPY PASSWORD (Hidden for Ludo / 8 Ball Pool)
              if (!isLinkOnly) ...[
                const SizedBox(height: 10),
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
                              hasPassword ? room.password : 'TBD',
                              style: TextStyle(
                                color: hasPassword ? Colors.white : GamerTheme.accentOrange,
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
                          backgroundColor: hasPassword ? GamerTheme.accentOrange : GamerTheme.cardElevated,
                          foregroundColor: hasPassword ? GamerTheme.bgDark : GamerTheme.textMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: hasPassword
                            ? () {
                                Clipboard.setData(ClipboardData(text: room.password));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Password "${room.password}" copied to clipboard! 🔑'),
                                    backgroundColor: GamerTheme.accentOrange,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('COPY PASSWORD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
              ],

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
                                Text(
                                  '$mapName (${room.gameMode})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
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

              // Dynamic Game Launch Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamerTheme.accentBlue,
                    foregroundColor: GamerTheme.bgDark,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: Text(room.gameIcon, style: const TextStyle(fontSize: 16)),
                  label: Text(room.launchAppLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  onPressed: () {
                    if (hasRoomId) {
                      Clipboard.setData(ClipboardData(text: room.roomId));
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(hasRoomId ? 'Copied credentials! Launching ${room.gameType}...' : 'Launching ${room.gameType}...'),
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
              if (isHost) ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: GamerTheme.accentBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('EDIT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _showEditCredentialsDialog(context, room);
                  },
                ),
              ] else ...[
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
              ],
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

  void _showEditCredentialsDialog(BuildContext context, TournamentRoom room) {
    final isLinkOnly = room.isLinkOnlyGame;
    final idController = TextEditingController(text: room.roomId);
    final passController = TextEditingController(text: room.password);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GamerTheme.accentBlue, width: 1.5),
        ),
        title: Row(
          children: [
            Text(room.gameIcon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'UPDATE ${isLinkOnly ? "INVITE LINK" : "CREDENTIALS"}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLinkOnly ? 'INVITE LINK / ROOM CODE' : 'ROOM ID',
              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: idController,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: isLinkOnly ? 'e.g. https://ludoking.app/room/123 or Code' : 'e.g. 582910',
                hintStyle: const TextStyle(color: GamerTheme.textMuted),
                filled: true,
                fillColor: GamerTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (!isLinkOnly) ...[
              const SizedBox(height: 12),
              const Text('PASSWORD', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: passController,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'e.g. 1234',
                  hintStyle: const TextStyle(color: GamerTheme.textMuted),
                  filled: true,
                  fillColor: GamerTheme.bgDark,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.accentBlue,
              foregroundColor: GamerTheme.bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newId = idController.text.trim();
              final newPass = isLinkOnly ? '' : passController.text.trim();
              await _tournamentService.updateRoomCredentials(
                roomId: room.id,
                inGameRoomId: newId,
                password: newPass,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Credentials updated and revealed to players!'),
                    backgroundColor: GamerTheme.accentBlue,
                  ),
                );
              }
            },
            child: const Text('SAVE & REVEAL 🔓', style: TextStyle(fontWeight: FontWeight.w900)),
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
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
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

    final candidateNames = room.joinedPlayers.map((uid) => room.getPlayerName(uid)).where((n) => n.isNotEmpty).toSet().toList();
    if (!candidateNames.contains(playerName)) candidateNames.add(playerName);
    if (!candidateNames.contains(room.hostName)) candidateNames.add(room.hostName);
    final result = await _ocrService.processResultScreenshot(
      roomId: room.id,
      userId: currentUid,
      userName: playerName,
      room: room,
      candidateNames: candidateNames,
    );

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot selection cancelled.')),
      );
      return;
    }

    // Submit to room with detected winners
    await _tournamentService.submitResultScreenshot(
      roomId: room.id,
      playerUid: currentUid,
      playerName: playerName,
      screenshotUrl: result.imageUrl,
      ocrText: result.recognizedText,
      isVictory: result.isVictory,
      detectedWinnerUids: result.detectedWinnerUids,
      detectedWinnerNames: result.detectedWinnerNames,
    );

    // AUTOMATED WINNER REWARD DISTRIBUTION:
    // If OCR detects victory, automatically divide escrow prize among all winning team members without host intervention
    if (result.isVictory) {
      final winnerUids = result.detectedWinnerUids.isNotEmpty ? result.detectedWinnerUids : [currentUid];
      final winnerNames = result.detectedWinnerNames.isNotEmpty ? result.detectedWinnerNames : [playerName];
      final totalPrize = room.escrowCoins > 0 ? room.escrowCoins : room.prizePoolCoins;
      final sharePerMember = (totalPrize / winnerUids.length).floor();

      // Trigger automatic payout directly from escrow
      final autoDistributed = await _tournamentService.finishMatchWithWinner(
        roomId: room.id,
        winnerUids: winnerUids,
        winnerNames: winnerNames,
      );

      if (!mounted) return;
      setState(() {});

      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.75),
        builder: (ctx) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: GamerTheme.cardDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.amber, width: 2),
            ),
            title: const Row(
              children: [
                Text('🏆', style: TextStyle(fontSize: 26)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'VICTORY AUTO-DETECTED!',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GamerTheme.neonGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: GamerTheme.neonGreen, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          autoDistributed
                              ? 'Escrow prize automatically divided & sent to winning team!'
                              : 'Victory verified! Escrow prize assigned.',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '💰 Total Escrow Prize: $totalPrize G-Coins',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '👥 Winning Team (${winnerUids.length} members):',
                  style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  winnerNames.join(', '),
                  style: const TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  '💎 Share Per Winner: $sharePerMember G-Coins each',
                  style: const TextStyle(color: GamerTheme.neonGreen, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('AWESOME! 💰', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: GamerTheme.cardDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: GamerTheme.accentOrange,
              ),
              SizedBox(width: 8),
              Text(
                'PROOF SUBMITTED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: const Text(
            'Screenshot uploaded. Victory was not auto-detected from this image. If you won, please make sure the screenshot clearly displays the VICTORY banner.',
            style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.accentBlue,
                foregroundColor: GamerTheme.bgDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper to display screenshot image from network URL or local file path
  Widget _buildScreenshotImage(String pathOrUrl, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return Image.network(
        pathOrUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: GamerTheme.cardDark,
          child: const Icon(Icons.broken_image, color: GamerTheme.textMuted, size: 20),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: GamerTheme.cardDark,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: GamerTheme.accentBlue),
              ),
            ),
          );
        },
      );
    } else {
      final file = File(pathOrUrl);
      return Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: GamerTheme.cardDark,
          child: const Icon(Icons.image_not_supported, color: GamerTheme.textMuted, size: 20),
        ),
      );
    }
  }

  /// Full-screen zoomable screenshot viewer for Host verification
  void _openFullScreenScreenshotViewer({
    required BuildContext context,
    required String screenshotUrl,
    required String playerName,
    required bool isVictory,
    String? ocrText,
    VoidCallback? onVerify,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              // Zoomable interactive screenshot
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 6.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  child: _buildScreenshotImage(
                    screenshotUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Top Bar with Close button & Player title
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.88),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(ctx),
                        tooltip: 'Close',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$playerName\'s Victory Proof',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isVictory ? '🏆 OCR VICTORY DETECTED' : '📸 MATCH SCREENSHOT',
                                  style: TextStyle(
                                    color: isVictory ? GamerTheme.neonGreen : GamerTheme.accentOrange,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '• Pinch or drag to zoom',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom action bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.92),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ocrText != null && ocrText.trim().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: GamerTheme.cardDark.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GamerTheme.borderDark),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.document_scanner_rounded, color: GamerTheme.accentBlue, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ocrText.replaceAll('\n', ' ').trim().length > 70
                                      ? '${ocrText.replaceAll('\n', ' ').trim().substring(0, 70)}...'
                                      : ocrText.replaceAll('\n', ' ').trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('BACK', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          if (onVerify != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.check_circle_rounded, size: 18),
                                label: const Text(
                                  'VERIFIED - SELECT WINNER',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                                onPressed: () {
                                  onVerify();
                                  Navigator.pop(ctx);
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Host Dialog to Finish Match and Transfer Escrow Coins Equally to Winning Team Members
  void _showFinishMatchDialog(TournamentRoom room) {
    final Set<String> selectedWinnerUids = {};
    final Map<String, String> selectedWinnerNames = {};
    final Set<String> verifiedUids = {};
    final List<String> extraTeammates = [];
    final TextEditingController extraTeammateController = TextEditingController();

    // Auto-detect winners based on victory submission & team members
    bool autoDetected = false;
    for (final entry in room.resultSubmissions.entries) {
      final data = entry.value as Map<String, dynamic>?;
      if (data?['isVictory'] == true) {
        final submitterUid = entry.key;
        final submitterName = data?['playerName']?.toString() ?? 'Player';
        selectedWinnerUids.add(submitterUid);
        selectedWinnerNames[submitterUid] = submitterName;

        // A) If stored detectedWinnerUids exist and match valid team bounds, use them
        final detUids = List<String>.from(data?['detectedWinnerUids'] ?? []);
        final detNames = List<String>.from(data?['detectedWinnerNames'] ?? []);
        final totalJoined = room.joinedPlayers.length;
        final maxTeamWinners = totalJoined > 1 ? (totalJoined ~/ 2).clamp(1, 4) : 1;

        if (detUids.isNotEmpty && detUids.length <= maxTeamWinners) {
          selectedWinnerUids.clear();
          selectedWinnerNames.clear();
          for (int i = 0; i < detUids.length; i++) {
            selectedWinnerUids.add(detUids[i]);
            selectedWinnerNames[detUids[i]] = i < detNames.length ? detNames[i] : room.getPlayerName(detUids[i]);
          }
        } else {
          // B) Submitter + teammate only from submitter's OWN slot group (Team 1 or Team 2), never opposing team!
          if (maxTeamWinners > 1 && room.joinedPlayers.isNotEmpty) {
            final sIdx = room.joinedPlayers.indexOf(submitterUid);
            if (sIdx != -1) {
              final teamIdx = sIdx ~/ maxTeamWinners;
              final start = teamIdx * maxTeamWinners;
              final end = (start + maxTeamWinners).clamp(0, totalJoined);
              for (int i = start; i < end; i++) {
                if (selectedWinnerUids.length >= maxTeamWinners) break;
                final pUid = room.joinedPlayers[i];
                selectedWinnerUids.add(pUid);
                selectedWinnerNames[pUid] = room.getPlayerName(pUid);
              }
            }
          }
        }

        // C) Invariant check: selected winners can never be all players in room!
        if (selectedWinnerUids.length >= totalJoined && totalJoined > 1) {
          final trimmed = selectedWinnerUids.take(maxTeamWinners).toList();
          selectedWinnerUids.clear();
          selectedWinnerUids.addAll(trimmed);
        }
        autoDetected = true;
        break;
      }
    }

    if (selectedWinnerUids.isEmpty && room.joinedPlayers.isNotEmpty) {
      final firstUid = room.joinedPlayers.first;
      selectedWinnerUids.add(firstUid);
      selectedWinnerNames[firstUid] = firstUid == room.hostId ? room.hostName : 'Opponent';
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            final int totalWinners = selectedWinnerUids.length;
            final int sharePerWinner = totalWinners > 0 ? (room.escrowCoins ~/ totalWinners) : 0;

            return AlertDialog(
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
                      'CONFIRM WINNING TEAM',
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
                    // Escrow Summary Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('💰', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Total Escrow Prize: ${room.escrowCoins} G-Coins',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: GamerTheme.bgDark.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '👥 Winners: $totalWinners ${totalWinners == 1 ? "member" : "team members"}',
                                  style: const TextStyle(color: GamerTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '💎 Share: $sharePerWinner Coins each',
                                  style: const TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Escrow coins will be divided EQUALLY among all checked team members.',
                            style: TextStyle(color: GamerTheme.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    if (autoDetected) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: GamerTheme.neonGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: GamerTheme.neonGreen, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Winning team auto-detected by ML Kit OCR!',
                                style: TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'CHECK WINNING PLAYERS (EQUAL SPLIT):',
                      style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    // List joined players with checkboxes
                    ...room.joinedPlayers.map((playerUid) {
                      final isHost = playerUid == room.hostId;
                      final submission = room.resultSubmissions[playerUid] as Map<String, dynamic>?;
                      final hasSubmitted = submission != null;
                      final isVictoryVerified = submission?['isVictory'] == true;
                      final playerName = isHost ? room.hostName : (submission?['playerName'] ?? 'Player');
                      final screenshotUrl = (submission?['screenshotUrl'] ?? submission?['imageUrl'] ?? submission?['localPath'])?.toString() ?? '';
                      final hasScreenshot = hasSubmitted && screenshotUrl.isNotEmpty;
                      final isVerified = verifiedUids.contains(playerUid);
                      final isSelected = selectedWinnerUids.contains(playerUid);

                      void openProof() {
                        setDialogState(() {
                          verifiedUids.add(playerUid);
                        });
                        _openFullScreenScreenshotViewer(
                          context: ctx,
                          screenshotUrl: screenshotUrl,
                          playerName: playerName,
                          isVictory: isVictoryVerified,
                          ocrText: submission?['ocrText']?.toString(),
                          onVerify: () {
                            setDialogState(() {
                              selectedWinnerUids.add(playerUid);
                              selectedWinnerNames[playerUid] = playerName;
                              verifiedUids.add(playerUid);
                            });
                          },
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? GamerTheme.accentBlue.withOpacity(0.15) : GamerTheme.bgDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? GamerTheme.accentBlue : GamerTheme.borderDark,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                selectedWinnerUids.remove(playerUid);
                                selectedWinnerNames.remove(playerUid);
                              } else {
                                selectedWinnerUids.add(playerUid);
                                selectedWinnerNames[playerUid] = playerName;
                              }
                            });
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: GamerTheme.accentBlue,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedWinnerUids.add(playerUid);
                                      selectedWinnerNames[playerUid] = playerName;
                                    } else {
                                      selectedWinnerUids.remove(playerUid);
                                      selectedWinnerNames.remove(playerUid);
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$playerName ${isHost ? "(Host)" : ""}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isSelected)
                                      Text(
                                        '+$sharePerWinner Coins',
                                        style: const TextStyle(color: GamerTheme.neonGreen, fontSize: 10, fontWeight: FontWeight.bold),
                                      )
                                    else if (isVerified)
                                      const Text('Verified Proof ✓', style: TextStyle(color: GamerTheme.neonGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (hasScreenshot) ...[
                                // Clickable OCR VICTORY badge
                                InkWell(
                                  onTap: openProof,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isVictoryVerified ? GamerTheme.neonGreen.withOpacity(0.2) : GamerTheme.accentBlue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isVictoryVerified ? GamerTheme.neonGreen.withOpacity(0.6) : GamerTheme.accentBlue.withOpacity(0.6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isVictoryVerified ? 'OCR VICTORY ✓' : 'Screenshot ✓',
                                          style: TextStyle(
                                            color: isVictoryVerified ? GamerTheme.neonGreen : GamerTheme.accentBlue,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.touch_app_rounded, size: 10, color: Colors.white70),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Eye Icon Button
                                IconButton(
                                  icon: Icon(
                                    Icons.remove_red_eye_rounded,
                                    color: isVerified ? GamerTheme.neonGreen : GamerTheme.accentBlue,
                                    size: 20,
                                  ),
                                  tooltip: 'View Screenshot (Zoom)',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: openProof,
                                ),
                                const SizedBox(width: 4),
                                // Thumbnail
                                GestureDetector(
                                  onTap: openProof,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isVerified ? GamerTheme.neonGreen : Colors.amber,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _buildScreenshotImage(screenshotUrl, width: 34, height: 34, fit: BoxFit.cover),
                                  ),
                                ),
                              ] else ...[
                                const Text('No Screenshot', style: TextStyle(color: GamerTheme.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    // Extra Teammates added from screenshot
                    if (extraTeammates.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'TEAMMATES FROM SCREENSHOT:',
                        style: TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ...extraTeammates.map((eUid) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: GamerTheme.accentOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_add_alt_1_rounded, size: 16, color: GamerTheme.accentOrange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'UID: $eUid',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Text(
                                        '+$sharePerWinner Coins (Equal share)',
                                        style: const TextStyle(color: GamerTheme.neonGreen, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: GamerTheme.redAccent),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  onPressed: () {
                                    setDialogState(() {
                                      extraTeammates.remove(eUid);
                                      selectedWinnerUids.remove(eUid);
                                      selectedWinnerNames.remove(eUid);
                                    });
                                  },
                                ),
                              ],
                            ),
                          )),
                    ],
                    // Input field to add teammate UID from screenshot
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: GamerTheme.bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GamerTheme.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.add_circle_outline_rounded, size: 14, color: GamerTheme.accentBlue),
                              SizedBox(width: 4),
                              Text(
                                'Add Teammate UID from Screenshot:',
                                style: TextStyle(color: GamerTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 36,
                                  child: TextField(
                                    controller: extraTeammateController,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Enter teammate UID / Name...',
                                      hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      filled: true,
                                      fillColor: GamerTheme.cardDark,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GamerTheme.accentBlue,
                                  foregroundColor: GamerTheme.bgDark,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  final text = extraTeammateController.text.trim();
                                  if (text.isNotEmpty) {
                                    setDialogState(() {
                                      if (!extraTeammates.contains(text) && !selectedWinnerUids.contains(text)) {
                                        extraTeammates.add(text);
                                        selectedWinnerUids.add(text);
                                        selectedWinnerNames[text] = 'Teammate ($text)';
                                      }
                                      extraTeammateController.clear();
                                    });
                                  }
                                },
                                child: const Text('+ ADD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                  onPressed: selectedWinnerUids.isEmpty
                      ? null
                      : () async {
                          // Check if any selected joined player uploaded screenshot but was not verified
                          bool needsVerification = false;
                          String unverifiedUid = '';
                          for (final wUid in selectedWinnerUids) {
                            final sub = room.resultSubmissions[wUid] as Map<String, dynamic>?;
                            final sUrl = (sub?['screenshotUrl'] ?? sub?['imageUrl'] ?? sub?['localPath'])?.toString() ?? '';
                            if (sUrl.isNotEmpty && !verifiedUids.contains(wUid)) {
                              needsVerification = true;
                              unverifiedUid = wUid;
                              break;
                            }
                          }

                          if (needsVerification) {
                            final sub = room.resultSubmissions[unverifiedUid] as Map<String, dynamic>?;
                            final sUrl = (sub?['screenshotUrl'] ?? sub?['imageUrl'] ?? sub?['localPath'])?.toString() ?? '';
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.amber,
                                content: Text(
                                  '⚠️ Please inspect and verify the victory screenshot before confirming!',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                                duration: Duration(seconds: 3),
                              ),
                            );
                            _openFullScreenScreenshotViewer(
                              context: ctx,
                              screenshotUrl: sUrl,
                              playerName: selectedWinnerNames[unverifiedUid] ?? 'Winner',
                              isVictory: sub?['isVictory'] == true,
                              ocrText: sub?['ocrText']?.toString(),
                              onVerify: () {
                                setDialogState(() {
                                  verifiedUids.add(unverifiedUid);
                                });
                              },
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final winnersList = selectedWinnerUids.toList();
                          final winnerNamesList = winnersList.map((uid) => selectedWinnerNames[uid] ?? uid).toList();

                          final success = await _tournamentService.finishMatchWithWinner(
                            roomId: room.id,
                            winnerUids: winnersList,
                            winnerNames: winnerNamesList,
                          );
                          if (mounted) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.amber,
                                content: Text(
                                  success
                                      ? '🏆 Prize of ${room.escrowCoins} Coins divided equally ($sharePerWinner Coins each) among ${winnersList.length} members!'
                                      : 'Could not complete transfer.',
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    totalWinners > 1 ? 'CONFIRM TEAM ($totalWinners) 💰' : 'CONFIRM WINNER 💰',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentGamer?.uid ?? _authService.currentUid ?? 'guest';

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      extendBody: false,
      extendBodyBehindAppBar: false,
      body: SafeArea(
        top: true,
        bottom: true,
        child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Top Coin Balance Bar & Rule Banner
          SliverToBoxAdapter(
            child: ListenableBuilder(
              listenable: _walletService,
              builder: (context, _) {
                final wallet = _walletService.currentWallet ?? const CoinWallet(userId: '', coins: 1000);
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
                          GestureDetector(
                            onTap: () => CoinHistorySheet.show(context, userId: uid),
                            child: Row(
                              children: [
                                const Text('💰', style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${NumberFormat("#,###").format(wallet.coins)} G-Coins',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.history_rounded, size: 14, color: Colors.white54),
                                      ],
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
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFD700),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(Icons.card_giftcard_rounded, size: 14, color: Colors.black),
                                label: const Text('REDEEM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RedeemRewardsScreen()));
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GamerTheme.neonGreen,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 18+ Compliance & 15-Minute Rule Banner
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
                                '🔞 18+ Skill-Based • No Gambling • Sponsored by Ads • Upload Victory Screenshot',
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
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _gameCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final item = _gameCategories[idx];
                    final name = item['name']!;
                    final icon = item['icon']!;
                    final isSelected = _selectedCategory == name;
                    final isFree = name == 'Free Entry';

                    return ChoiceChip(
                      avatar: Text(icon, style: const TextStyle(fontSize: 14)),
                      label: Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: isFree ? GamerTheme.neonGreen : GamerTheme.accentBlue,
                      backgroundColor: GamerTheme.cardDark,
                      side: BorderSide(
                        color: isSelected
                            ? (isFree ? GamerTheme.neonGreen : GamerTheme.accentBlue)
                            : GamerTheme.borderDark,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedCategory = name;
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
        body: _buildRoomsList(category: _selectedCategory),
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GamerTheme.accentBlue,
        foregroundColor: GamerTheme.bgDark,
        elevation: 6,
        icon: const Icon(Icons.add_moderator_rounded, color: GamerTheme.bgDark),
        label: const Text('HOST ROOM', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        onPressed: () => _openHostRoomSheet(preselectedGame: _selectedCategory != 'All Games' ? _selectedCategory : null),
      ),
    );
  }

  Widget _buildRoomsList({required String category}) {
    final localRooms = _tournamentService.rooms;

    return StreamBuilder<List<TournamentRoom>>(
      stream: _tournamentService.getLiveRoomsStream(gameName: category == 'All Games' ? null : category),
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
          if (category == 'All Games') {
            return true;
          }
          final cat = category.toLowerCase().trim();
          final gName = r.gameName.toLowerCase().trim();
          final gType = r.gameType.toLowerCase().trim();
          return gName == cat || gType == cat;
        }).toList();

        if (filtered.isEmpty) {
          final isAll = category == 'All Games';
          final isFree = category == 'Free Entry';
          final icon = isAll ? '🏆' : (isFree ? '🆓' : _getCategoryIcon(category));
          final title = isAll ? 'No Active Custom Rooms' : 'No Active $category Rooms';
          final subtitle = isAll
              ? 'Host your own multiplayer tournament room and compete for G-Coins!'
              : 'Be the first to host a $category tournament match and win G-Coins!';

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
                    child: Text(icon, style: const TextStyle(fontSize: 40)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(color: GamerTheme.textWhite, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: GamerTheme.textMuted, fontSize: 13),
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
                    label: Text(
                      isAll || isFree ? 'Host First Room' : 'Host $category Room',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: () => _openHostRoomSheet(preselectedGame: (!isAll && !isFree) ? category : null),
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
            _WinnerCelebrationBanner(
              winnerName: room.winnerName ?? "Champion",
              prizeCoins: room.prizePoolCoins > 0 ? room.prizePoolCoins : (room.escrowCoins > 0 ? room.escrowCoins : 100),
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
                            '${room.map} • ${room.gameMode}',
                            style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          if (room.platform.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Text('•', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10)),
                            const SizedBox(width: 6),
                            Text(
                              room.platform,
                              style: const TextStyle(color: GamerTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(room.gameIcon, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        room.gameType,
                        style: const TextStyle(
                          color: GamerTheme.accentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
                      room.isFull ? 'Room Full (${room.joinedPlayers.length}/${room.maxSlots})' : '${room.availableSlots} slots remaining',
                      style: TextStyle(
                        color: room.isFull ? const Color(0xFFFF2D55) : GamerTheme.textMuted,
                        fontSize: 11,
                        fontWeight: room.isFull ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      'Starts: ${DateFormat('hh:mm a, dd MMM').format(room.startTime)}',
                      style: const TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Revealed Room ID & Password or Invite Link (If joined or host)
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
                  Icon(room.isLinkOnlyGame ? Icons.link_rounded : Icons.vpn_key_rounded, color: GamerTheme.accentBlue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      room.isLinkOnlyGame
                          ? 'Link: ${room.roomId}'
                          : 'ID: ${room.roomId}${room.password.isNotEmpty ? "  |  Pass: ${room.password}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final textToCopy = room.isLinkOnlyGame
                          ? room.roomId
                          : (room.password.isNotEmpty ? 'Room: ${room.roomId} Pass: ${room.password}' : room.roomId);
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${room.credentialLabel} copied!')),
                      );
                    },
                    child: Text(room.copyLabel, style: const TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.w900, fontSize: 11)),
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
                      // WIN PROOF button for participants (Only if room has prize/reward)
                      if (room.prizePoolCoins > 0 || room.escrowCoins > 0) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasSubmittedResult ? GamerTheme.neonGreen : GamerTheme.accentOrange,
                            foregroundColor: hasSubmittedResult ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(hasSubmittedResult ? Icons.done_all_rounded : Icons.emoji_events_rounded, size: 14),
                          label: Text(
                            hasSubmittedResult ? 'WIN PROOF SENT ✓' : 'WIN PROOF 🏆',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                          onPressed: () => _handleUploadResult(room, currentUid, currentGamer?.displayName ?? 'Gamer'),
                        ),
                        const SizedBox(width: 4),
                      ],
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

                            // Mandatory Rewarded Ad Viewing to Join Tournament (100% Free Entry)
                            // "Ad dekhega tabhi join hoga. Isi se tumhari earning hogi."
                            await AdFreeService().showRewardedAdForAction(
                              context: context,
                              actionTitle: 'Watch 1 Ad to Join Room',
                              onRewardEarned: () async {
                                final success = await _tournamentService.joinRoom(
                                  roomId: room.id,
                                  hostUid: room.hostId,
                                  playerUid: currentGamer.uid,
                                  playerName: currentGamer.displayName,
                                );

                                if (context.mounted) {
                                  if (success) {
                                    await _walletService.recordTournamentJoinedAndCheckReferral(currentGamer.uid);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('🎮 Ad Verified! Slot confirmed for ${room.title}! (Entry 100% FREE)'),
                                        backgroundColor: GamerTheme.neonGreen,
                                      ),
                                    );
                                    // Immediately show Room Details & Credentials dialog
                                    _showRoomDetailsDialog(context, room, currentGamer.uid);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Room is full or error occurred!'),
                                        backgroundColor: GamerTheme.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
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

class _WinnerCelebrationBanner extends StatefulWidget {
  final String winnerName;
  final int prizeCoins;

  const _WinnerCelebrationBanner({
    required this.winnerName,
    required this.prizeCoins,
  });

  @override
  State<_WinnerCelebrationBanner> createState() => _WinnerCelebrationBannerState();
}

class _WinnerCelebrationBannerState extends State<_WinnerCelebrationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.22).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutBack),
    );
    _glowAnim = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF92400E), Color(0xFFB45309), Color(0xFFD97706)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'WINNER: ${widget.winnerName} (+${widget.prizeCoins} Coins Claimed)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // Animated Bouncing Coin & Glowing Prize Badge
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade400.withOpacity(0.25 + 0.25 * _glowAnim.value),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.shade200.withOpacity(_glowAnim.value),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.4 * _glowAnim.value),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 3),
                      Text(
                        '+${widget.prizeCoins}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
