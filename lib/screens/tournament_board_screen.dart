import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
export 'gamer_rooms_screen.dart';

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

  // Cache for host usernames fetched from users collection to avoid repeated reads
  final Map<String, String> _hostNameCache = {};

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
    _wallet_service.addListener(_onTournamentServiceChanged);
    _tournament_service.fetchRooms();

    final uid = _auth_service.currentGamer?.uid ?? _auth_service.currentUid ?? 'guest';
    _wallet_service.getOrCreateWallet(uid);
  }

  void _onTournamentServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tournamentService.removeListener(_onTournamentServiceChanged);
    _wallet_service.removeListener(_onTournamentServiceChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Ensure host display name is loaded into cache (reads users collection once per hostId)
  Future<void> _ensureHostNameLoaded(String hostId) async {
    if (hostId.isEmpty) return;
    if (_hostNameCache.containsKey(hostId)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(hostId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final username = (data['username'] ?? data['displayName'] ?? data['name'])?.toString().trim() ?? '';
        if (username.isNotEmpty) {
          _hostNameCache[hostId] = username;
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}
    // fallback to generic label
    _hostNameCache[hostId] = 'Host';
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

  // ... rest of file unchanged until _buildRoomCard

  Widget _buildRoomCard(TournamentRoom room) {
    final currentGamer = _authService.currentGamer;
    final currentUid = currentGamer?.uid ?? '';
    final isJoined = room.joinedPlayers.contains(currentUid);
    final isHost = room.hostId == currentUid;
    final fillPercentage = (room.joinedPlayers.length / room.maxSlots).clamp(0.0, 1.0);
    final isCompleted = room.isCompleted;
    final isExpired = room.isExpired;
    final hasSubmittedResult = room.resultSubmissions.containsKey(currentUid);

    // Compute host display name: prefer room.hostName if it's meaningful, otherwise use cached username
    final String hostDisplayRaw = (room.hostName.trim().isNotEmpty && room.hostName.trim() != room.map.trim())
        ? room.hostName.trim()
        : (_hostNameCache[room.hostId] ?? '');

    if (hostDisplayRaw.isEmpty && room.hostId.isNotEmpty) {
      // fire-and-forget load (will call setState when name fetched)
      _ensureHostNameLoaded(room.hostId);
    }

    final hostDisplay = hostDisplayRaw.isNotEmpty ? hostDisplayRaw : (room.hostName.trim().isNotEmpty ? room.hostName.trim() : 'Host');

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
                    displayName: hostDisplay,
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
                            'Host: ${hostDisplay}',
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
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ... rest of existing widget tree remains unchanged (omitted here for brevity)
        ],
      ),
    );
  }

  // The file continues with many other helper methods and UI code unchanged.
}
