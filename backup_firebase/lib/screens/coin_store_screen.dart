// Gamers ID Coin Store - In-App Rewards & Customization
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_wallet_model.dart';
import '../models/coin_transaction_model.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';

class CoinStoreScreen extends StatefulWidget {
  const CoinStoreScreen({super.key});

  @override
  State<CoinStoreScreen> createState() => _CoinStoreScreenState();
}

class _CoinStoreScreenState extends State<CoinStoreScreen> with SingleTickerProviderStateMixin {
  final CoinWalletService _walletService = CoinWalletService();
  final GamerAuthService _authService = GamerAuthService();

  late TabController _tabController;
  Timer? _countdownTimer;
  Duration _timeUntilNextClaim = Duration.zero;
  bool _isClaimingDaily = false;
  bool _isWatchingAd = false;
  bool _isProcessingPurchase = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    final uid = _authService.currentUid ?? 'guest';
    _walletService.getOrCreateWallet(uid).then((wallet) {
      if (mounted) {
        _updateCountdown(wallet);
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final w = _walletService.currentWallet;
      if (w != null && mounted) {
        _updateCountdown(w);
      }
    });
  }

  void _updateCountdown(CoinWallet wallet) {
    setState(() {
      _timeUntilNextNext(wallet);
    });
  }

  void _timeUntilNextNext(CoinWallet wallet) {
    if (wallet.lastDailyBonusClaim == null) {
      _timeUntilNextClaim = Duration.zero;
      return;
    }
    final nextAvailable = wallet.lastDailyBonusClaim!.add(const Duration(hours: 24));
    final diff = nextAvailable.difference(DateTime.now());
    _timeUntilNextClaim = diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _handleClaimDaily(String uid) async {
    if (_isClaimingDaily) return;
    setState(() => _isClaimingDaily = true);

    int remainingSeconds = 5;
    Timer? adTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          adTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remainingSeconds > 1) {
              setDialogState(() => remainingSeconds--);
            } else {
              t.cancel();
              Navigator.pop(dialogCtx);
              _walletService.claimDailyBonus(uid).then((success) {
                if (mounted) {
                  setState(() => _isClaimingDaily = false);
                  if (success) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        backgroundColor: GamerTheme.neonGreen,
                        content: Row(
                          children: [
                            Text('🎁', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 10),
                            Text(
                              '+50 G-Coins Claimed! Daily Login Streak Bonus.',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
              });
            }
          });

          return AlertDialog(
            backgroundColor: GamerTheme.bgDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: GamerTheme.accentOrange, width: 2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentOrange.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: GamerTheme.accentOrange, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'DAILY BONUS AD',
                    style: TextStyle(
                      color: GamerTheme.accentOrange,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${remainingSeconds}s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GamerTheme.borderLight),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ondemand_video_rounded, color: GamerTheme.accentOrange, size: 44),
                        SizedBox(height: 8),
                        Text(
                          'Sponsor Gaming Network',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Watch 5s ad to claim 50 G-Coins...',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (5 - remainingSeconds) / 5.0,
                  backgroundColor: GamerTheme.borderDark,
                  color: GamerTheme.accentOrange,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      adTimer?.cancel();
      if (mounted) setState(() => _isClaimingDaily = false);
    });
  }

  Future<void> _handleWatchAd(String uid) async {
    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);

    int remainingSeconds = 5;
    Timer? adTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          adTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (remainingSeconds > 1) {
              setDialogState(() => remainingSeconds--);
            } else {
              t.cancel();
              Navigator.pop(dialogCtx);
              _walletService.rewardAdCoins(uid);
              if (mounted) {
                setState(() => _isWatchingAd = false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    backgroundColor: GamerTheme.neonGreen,
                    content: Row(
                      children: [
                        Text('⚡', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Text(
                          '+50 G-Coins Added! Rewarded Video Ad completed.',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }
          });

          return AlertDialog(
            backgroundColor: GamerTheme.bgDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: GamerTheme.accentBlue, width: 2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentBlue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: GamerTheme.accentBlue, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'REWARDED AD SPONSOR',
                    style: TextStyle(
                      color: GamerTheme.accentBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${remainingSeconds}s',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GamerTheme.borderLight),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smart_display_rounded, color: GamerTheme.accentBlue, size: 44),
                        SizedBox(height: 8),
                        Text(
                          'Streaming Gaming Sponsor',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Watch 5s to earn +50 G-Coins...',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: (5 - remainingSeconds) / 5.0,
                  backgroundColor: GamerTheme.borderDark,
                  color: GamerTheme.accentBlue,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      adTimer?.cancel();
      if (mounted) setState(() => _isWatchingAd = false);
    });
  }

  Future<void> _handlePurchaseItem({
    required String uid,
    required String itemId,
    required String itemName,
    required String category,
    required int costCoins,
    Map<String, dynamic>? metadata,
  }) async {
    if (_isProcessingPurchase) return;

    final currentCoins = _walletService.currentWallet?.coins ?? 0;
    if (currentCoins < costCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: GamerTheme.redAccent,
          content: Text(
            '⚠️ Insufficient G-Coins! You have $currentCoins, but need $costCoins. Watch Rewarded Ads to earn coins!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          action: SnackBarAction(
            label: 'WATCH AD',
            textColor: Colors.white,
            onPressed: () => _handleWatchAd(uid),
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.bgDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GamerTheme.borderLight),
        ),
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_rounded, color: GamerTheme.accentOrange, size: 22),
            const SizedBox(width: 8),
            Text(
              'Unlock $itemName?',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This in-app item costs $costCoins G-Coins.',
              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GamerTheme.cardElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GamerTheme.borderDark),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Your Balance:', style: TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                  Text(
                    '💰 $currentCoins G-Coins',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.accentOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('UNLOCK ($costCoins COINS)'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingPurchase = true);
    final result = await _walletService.purchaseStoreItem(
      userId: uid,
      itemId: itemId,
      itemName: itemName,
      category: category,
      costCoins: costCoins,
      metadata: metadata,
    );
    if (mounted) {
      setState(() => _isProcessingPurchase = false);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GamerTheme.neonGreen,
            content: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$itemName unlocked & applied to your profile!',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GamerTheme.redAccent,
            content: Text(result['error'] ?? 'Purchase failed.'),
          ),
        );
      }
    }
  }

  Future<void> _handleEquipItem({
    required String uid,
    required String field,
    required dynamic value,
    required String name,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        field: value,
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GamerTheme.accentBlue,
            content: Text('$name equipped successfully! ✨'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: GamerTheme.redAccent, content: Text('Error: $e')),
        );
      }
    }
  }

  // Feed Boost Dialog: Select post to boost
  Future<void> _showFeedBoostDialog(String uid, int costCoins, int hours) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: GamerTheme.bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomCtx) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('authorId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            final posts = snapshot.data?.docs ?? [];
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.rocket_launch_rounded, color: GamerTheme.accentOrange, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'SELECT POST TO BOOST',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: GamerTheme.textMuted),
                        onPressed: () => Navigator.pop(bottomCtx),
                      ),
                    ],
                  ),
                  const Text(
                    'Your post will be highlighted with a BOOSTED badge at the top of the Community Feed.',
                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (posts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: GamerTheme.cardDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'You haven\'t published any community posts yet.\nCreate a post from the Feed tab first!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          final data = post.data() as Map<String, dynamic>? ?? {};
                          final content = (data['text'] ?? data['content'] ?? data['title'] ?? 'Community Post').toString();
                          final isAlreadyBoosted = data['isBoosted'] == true;

                          return Container(
                            decoration: BoxDecoration(
                              color: GamerTheme.cardDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAlreadyBoosted ? GamerTheme.accentOrange : GamerTheme.borderDark,
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: GamerTheme.accentOrange.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.article_rounded, color: GamerTheme.accentOrange, size: 20),
                              ),
                              title: Text(
                                content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              subtitle: isAlreadyBoosted
                                  ? const Text('🚀 Currently Active Boost', style: TextStyle(color: GamerTheme.accentOrange, fontSize: 11))
                                  : null,
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GamerTheme.accentOrange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.pop(bottomCtx);
                                  _handlePurchaseItem(
                                    uid: uid,
                                    itemId: post.id,
                                    itemName: '$hours-Hour Feed Boost',
                                    category: 'feed_boost',
                                    costCoins: costCoins,
                                    metadata: {
                                      'postId': post.id,
                                      'durationHours': hours,
                                    },
                                  );
                                },
                                child: Text('$costCoins 🪙'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUid ?? 'guest';

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.bgDark,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'COIN STORE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: GamerTheme.neonGreen,
          labelColor: GamerTheme.neonGreen,
          unselectedLabelColor: GamerTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          tabs: const [
            Tab(text: 'FRAMES & BADGES 👑'),
            Tab(text: 'FEED BOOST 🚀'),
            Tab(text: 'VIP ROOMS 🌟'),
            Tab(text: 'SPOTLIGHT ⭐'),
            Tab(text: 'CHAT COLORS 🎨'),
            Tab(text: 'EARN COINS 📺'),
          ],
        ),
      ),
      body: StreamBuilder<CoinWallet>(
        stream: _walletService.walletStream(uid),
        builder: (context, snapshot) {
          final wallet = snapshot.data ?? _walletService.currentWallet ?? CoinWallet.empty(uid);

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
              final activeFrame = userData['activeFrame'] as String? ?? '';
              final unlockedFrames = List<String>.from(userData['unlockedFrames'] ?? []);
              final activeBadge = userData['activeBadge'] as String? ?? '';
              final unlockedBadges = List<String>.from(userData['unlockedBadges'] ?? []);
              final activeChatColor = userData['chatColor'] as String? ?? '#00FF66';
              final unlockedChatColors = List<String>.from(userData['unlockedChatColors'] ?? []);
              final vipPassUntil = (userData['vipTournamentPassUntil'] as Timestamp?)?.toDate();
              final spotlightUntil = (userData['leaderboardSpotlightUntil'] as Timestamp?)?.toDate();

              return Column(
                children: [
                  // Top Balance Banner
                  _buildStoreHeader(wallet, uid),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFramesAndBadgesTab(uid, wallet, activeFrame, unlockedFrames, activeBadge, unlockedBadges),
                        _buildFeedBoostTab(uid, wallet),
                        _buildVipRoomsTab(uid, wallet, vipPassUntil),
                        _buildSpotlightTab(uid, wallet, spotlightUntil),
                        _buildChatColorsTab(uid, wallet, activeChatColor, unlockedChatColors),
                        _buildEarnCoinsTab(uid, wallet),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStoreHeader(CoinWallet wallet, String uid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: GamerTheme.cardDark,
        border: Border(bottom: BorderSide(color: GamerTheme.borderDark)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('💰', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BALANCE',
                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(wallet.coins)} G-Coins',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: () => _handleWatchAd(uid),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: GamerTheme.neonGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: Colors.black, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'EARN +50 📺',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Frames & Badges
  Widget _buildFramesAndBadgesTab(
    String uid,
    CoinWallet wallet,
    String activeFrame,
    List<String> unlockedFrames,
    String activeBadge,
    List<String> unlockedBadges,
  ) {
    final frames = [
      {
        'id': 'neon_fire',
        'name': 'Neon Fire Frame',
        'cost': 250,
        'emoji': '🔥',
        'color': Colors.deepOrangeAccent,
        'desc': 'Fiery animated glow perimeter around your profile avatar.',
      },
      {
        'id': 'royal_crown',
        'name': 'Royal Sovereign Crown',
        'cost': 500,
        'emoji': '👑',
        'color': Colors.amber,
        'desc': '24K pure gold crown frame reserved for tournament kings.',
      },
      {
        'id': 'cyber_glitch',
        'name': 'Cyber Matrix Frame',
        'cost': 350,
        'emoji': '⚡',
        'color': GamerTheme.neonGreen,
        'desc': 'Futuristic cyberpunk neon grid border for pro gamers.',
      },
      {
        'id': 'cosmic_void',
        'name': 'Cosmic Nebula Frame',
        'cost': 400,
        'emoji': '🌌',
        'color': Colors.purpleAccent,
        'desc': 'Deep galaxy pulsar ring with animated starlight shimmer.',
      },
    ];

    final badges = [
      {
        'id': 'pro_elite',
        'name': 'Pro Gamer Elite Badge',
        'cost': 400,
        'icon': Icons.verified_rounded,
        'color': GamerTheme.accentBlue,
        'desc': 'Verified Elite tag displayed on profile, squad posts & comments.',
      },
      {
        'id': 'kd_assassin',
        'name': 'K/D Assassin Badge',
        'cost': 600,
        'icon': Icons.dangerous_rounded,
        'color': GamerTheme.redAccent,
        'desc': 'Special lethal mark for high-frag aggressive rushers.',
      },
      {
        'id': 'room_champion',
        'name': 'Custom Room Champion',
        'cost': 500,
        'icon': Icons.emoji_events_rounded,
        'color': Colors.amber,
        'desc': 'Prestige champion trophy badge displayed beside your gamertag.',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'AVATAR PROFILE FRAMES',
          style: TextStyle(
            color: GamerTheme.neonGreen,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Stand out in tournament rooms and leaderboards with animated profile frames.',
          style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...frames.map((item) {
          final id = item['id'] as String;
          final name = item['name'] as String;
          final cost = item['cost'] as int;
          final color = item['color'] as Color;
          final emoji = item['emoji'] as String;
          final desc = item['desc'] as String;
          final isUnlocked = unlockedFrames.contains(id);
          final isEquipped = activeFrame == id;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GamerTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEquipped ? color : (isUnlocked ? GamerTheme.borderLight : GamerTheme.borderDark),
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 3),
                    color: GamerTheme.cardElevated,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          if (isEquipped) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(desc, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isEquipped)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleEquipItem(uid: uid, field: 'activeFrame', value: '', name: 'Frame removed'),
                    child: const Text('REMOVE', style: TextStyle(fontSize: 11)),
                  )
                else if (isUnlocked)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleEquipItem(uid: uid, field: 'activeFrame', value: id, name: name),
                    child: const Text('EQUIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.cardElevated,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handlePurchaseItem(
                      uid: uid,
                      itemId: id,
                      itemName: name,
                      category: 'frame',
                      costCoins: cost,
                    ),
                    child: Text('$cost 🪙', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        const Text(
          'PROFILE PRESTIGE BADGES',
          style: TextStyle(
            color: GamerTheme.accentBlue,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Verified badges to showcase your gamer reputation in all match lobbies.',
          style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...badges.map((item) {
          final id = item['id'] as String;
          final name = item['name'] as String;
          final cost = item['cost'] as int;
          final color = item['color'] as Color;
          final icon = item['icon'] as IconData;
          final desc = item['desc'] as String;
          final isUnlocked = unlockedBadges.contains(id);
          final isEquipped = activeBadge == id;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GamerTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEquipped ? color : (isUnlocked ? GamerTheme.borderLight : GamerTheme.borderDark),
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          if (isEquipped) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(desc, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isEquipped)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleEquipItem(uid: uid, field: 'activeBadge', value: '', name: 'Badge removed'),
                    child: const Text('REMOVE', style: TextStyle(fontSize: 11)),
                  )
                else if (isUnlocked)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleEquipItem(uid: uid, field: 'activeBadge', value: id, name: name),
                    child: const Text('EQUIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.cardElevated,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handlePurchaseItem(
                      uid: uid,
                      itemId: id,
                      itemName: name,
                      category: 'badge',
                      costCoins: cost,
                    ),
                    child: Text('$cost 🪙', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 2: Feed Boost
  Widget _buildFeedBoostTab(String uid, CoinWallet wallet) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A153A), Color(0xFF161026)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rocket_launch_rounded, color: Colors.purpleAccent, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'COMMUNITY FEED BOOST',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Promote your squad recruitments, gameplay clips, and tournament announcements straight to the top of everyone\'s feed!',
                style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildBoostPackageCard(
          title: '24-Hour Feed Boost',
          hours: 24,
          coins: 300,
          color: Colors.purpleAccent,
          icon: Icons.bolt_rounded,
          perks: [
            'Pinned near top of Community Feed',
            'Neon "🚀 BOOSTED" badge on post',
            '3x Higher Squad invitations',
          ],
          onTap: () => _showFeedBoostDialog(uid, 300, 24),
        ),
        const SizedBox(height: 14),
        _buildBoostPackageCard(
          title: '48-Hour Ultra Boost',
          hours: 48,
          coins: 500,
          color: GamerTheme.accentOrange,
          icon: Icons.local_fire_department_rounded,
          perks: [
            'Top pinned in Feed & Trending clips',
            'Golden glowing card border',
            'Maximum profile visits & squad requests',
          ],
          onTap: () => _showFeedBoostDialog(uid, 500, 48),
        ),
      ],
    );
  }

  Widget _buildBoostPackageCard({
    required String title,
    required int hours,
    required int coins,
    required Color color,
    required IconData icon,
    required List<String> perks,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  '$coins G-Coins',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...perks.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: color, size: 14),
                    const SizedBox(width: 8),
                    Text(p, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.rocket_launch_rounded, size: 16),
              label: Text(
                'BOOST MY POST ($coins COINS)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
              onPressed: onTap,
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: VIP Tournament Rooms
  Widget _buildVipRoomsTab(String uid, CoinWallet wallet, DateTime? vipUntil) {
    final isVipActive = vipUntil != null && vipUntil.isAfter(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C2411), Color(0xFF14120B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'VIP TOURNAMENT PASS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  if (isVipActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('ACTIVE VIP', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isVipActive
                    ? 'Your VIP Pass is active until ${DateFormat('dd MMM yyyy, hh:mm a').format(vipUntil)}! Enjoy priority slots.'
                    : 'Get guaranteed entry into high-demand BGMI custom rooms, bypass waiting queues, and compete in VIP-only prize matches.',
                style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildVipPlanCard(
          title: '7-Day VIP Room Pass',
          days: 7,
          coins: 450,
          isCurrent: isVipActive,
          perks: [
            'Priority slot reservation in fast-filling BGMI rooms',
            'Golden VIP Crown badge beside your gamer tag',
            'Entry into weekly High-Tier VIP rooms',
          ],
          onBuy: () => _handlePurchaseItem(
            uid: uid,
            itemId: 'vip_7_days',
            itemName: '7-Day VIP Room Pass',
            category: 'vip_pass',
            costCoins: 450,
            metadata: {'durationDays': 7},
          ),
        ),
        const SizedBox(height: 14),
        _buildVipPlanCard(
          title: '30-Day VIP Season Pass',
          days: 30,
          coins: 1000,
          isCurrent: false,
          perks: [
            'All VIP room perks for 30 full days',
            'Special VIP Chat role & custom sound effects',
            'Bypass room full locks for instant join',
          ],
          onBuy: () => _handlePurchaseItem(
            uid: uid,
            itemId: 'vip_30_days',
            itemName: '30-Day VIP Season Pass',
            category: 'vip_pass',
            costCoins: 1000,
            metadata: {'durationDays': 30},
          ),
        ),
      ],
    );
  }

  Widget _buildVipPlanCard({
    required String title,
    required int days,
    required int coins,
    required bool isCurrent,
    required List<String> perks,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Text(
                '$coins 🪙',
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...perks.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 8),
                    Text(p, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onBuy,
              child: Text(
                isCurrent ? 'EXTEND VIP ($coins COINS)' : 'GET VIP PASS ($coins COINS)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 4: Leaderboard Spotlight
  Widget _buildSpotlightTab(String uid, CoinWallet wallet, DateTime? spotlightUntil) {
    final isSpotlightActive = spotlightUntil != null && spotlightUntil.isAfter(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF14243A), Color(0xFF0C1420)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.flare_rounded, color: GamerTheme.accentBlue, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'LEADERBOARD SPOTLIGHT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  if (isSpotlightActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: GamerTheme.neonGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('LIVE IN SPOTLIGHT', style: TextStyle(color: GamerTheme.neonGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isSpotlightActive
                    ? 'Your profile is currently showcased in the Leaderboard Spotlight banner until ${DateFormat('dd MMM, hh:mm a').format(spotlightUntil)}!'
                    : 'Showcase your player card at the top banner of the Leaderboard tab. Get seen by hundreds of esports clans and top players.',
                style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSpotlightCard(
          title: '24-Hour Leaderboard Spotlight',
          coins: 350,
          hours: 24,
          isCurrent: isSpotlightActive,
          perks: [
            'Featured in top banner on Leaderboard',
            'Golden halo border around your avatar',
            'High visibility for clan recruitments',
          ],
          onBuy: () => _handlePurchaseItem(
            uid: uid,
            itemId: 'spotlight_24h',
            itemName: '24-Hour Leaderboard Spotlight',
            category: 'spotlight',
            costCoins: 350,
            metadata: {'durationHours': 24},
          ),
        ),
        const SizedBox(height: 14),
        _buildSpotlightCard(
          title: '3-Day Leaderboard Super Spotlight',
          coins: 700,
          hours: 72,
          isCurrent: false,
          perks: [
            '72 hours continuous spotlight placement',
            'Maximum profile visits and squad requests',
            'Prestige Star badge in player listings',
          ],
          onBuy: () => _handlePurchaseItem(
            uid: uid,
            itemId: 'spotlight_72h',
            itemName: '3-Day Leaderboard Spotlight',
            category: 'spotlight',
            costCoins: 700,
            metadata: {'durationHours': 72},
          ),
        ),
      ],
    );
  }

  Widget _buildSpotlightCard({
    required String title,
    required int coins,
    required int hours,
    required bool isCurrent,
    required List<String> perks,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GamerTheme.accentBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star_border_rounded, color: GamerTheme.accentBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '$coins 🪙',
                style: const TextStyle(color: GamerTheme.accentBlue, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...perks.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: GamerTheme.accentBlue, size: 14),
                    const SizedBox(width: 8),
                    Text(p, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onBuy,
              child: Text(
                isCurrent ? 'EXTEND SPOTLIGHT ($coins COINS)' : 'CLAIM SPOTLIGHT ($coins COINS)',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 5: Exclusive Chat Colors
  Widget _buildChatColorsTab(String uid, CoinWallet wallet, String activeColor, List<String> unlockedColors) {
    final colors = [
      {'hex': '#00FF66', 'name': 'Neon Toxic Green', 'cost': 200, 'color': const Color(0xFF00FF66)},
      {'hex': '#BF00FF', 'name': 'Cyber Neon Purple', 'cost': 200, 'color': const Color(0xFFBF00FF)},
      {'hex': '#FFD700', 'name': 'Imperial Gold', 'cost': 200, 'color': const Color(0xFFFFD700)},
      {'hex': '#FF2A4D', 'name': 'Crimson Flame', 'cost': 200, 'color': const Color(0xFFFF2A4D)},
      {'hex': '#00E5FF', 'name': 'Glacier Cyan', 'cost': 200, 'color': const Color(0xFF00E5FF)},
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'EXCLUSIVE CHAT THEMES',
          style: TextStyle(
            color: GamerTheme.neonGreen,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Customize your message color and player tag in BGMI match chat and community groups.',
          style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // Live Chat Preview Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GamerTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GamerTheme.borderDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LIVE CHAT PREVIEW', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GamerTheme.bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(int.parse(activeColor.replaceFirst('#', '0xFF'))),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Color(int.parse(activeColor.replaceFirst('#', '0xFF'))).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Color(int.parse(activeColor.replaceFirst('#', '0xFF'))),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You (Pro Player)',
                            style: TextStyle(
                              color: Color(int.parse(activeColor.replaceFirst('#', '0xFF'))),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Need 1 rusher for Custom Room BGMI! Join slot 4 🔥',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...colors.map((c) {
          final hex = c['hex'] as String;
          final name = c['name'] as String;
          final cost = c['cost'] as int;
          final color = c['color'] as Color;
          final isUnlocked = unlockedColors.contains(hex);
          final isEquipped = activeColor == hex;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GamerTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEquipped ? color : (isUnlocked ? GamerTheme.borderLight : GamerTheme.borderDark),
                width: isEquipped ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(hex, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                if (isEquipped)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  )
                else if (isUnlocked)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleEquipItem(uid: uid, field: 'chatColor', value: hex, name: name),
                    child: const Text('EQUIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.cardElevated,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handlePurchaseItem(
                      uid: uid,
                      itemId: hex,
                      itemName: name,
                      category: 'chat_color',
                      costCoins: cost,
                      metadata: {'colorHex': hex},
                    ),
                    child: Text('$cost 🪙', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 6: Earn G-Coins
  Widget _buildEarnCoinsTab(String uid, CoinWallet wallet) {
    final canClaimDaily = _timeUntilNextClaim == Duration.zero;
    final inviteCode = _walletService.getReferralCode(uid);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Daily Login Bonus
        _buildEarnActionCard(
          icon: Icons.calendar_today_rounded,
          iconColor: GamerTheme.neonGreen,
          badge: '+50 COINS',
          badgeColor: GamerTheme.neonGreen,
          title: 'Daily Check-In Reward',
          subtitle: canClaimDaily
              ? 'Watch 1 sponsored ad to claim your 50 G-Coins daily bonus.'
              : 'Next daily claim available in ${_formatDuration(_timeUntilNextClaim)}',
          buttonText: _isClaimingDaily ? 'WATCHING...' : (canClaimDaily ? 'CLAIM 50 COINS 🎁' : _formatDuration(_timeUntilNextClaim)),
          buttonColor: canClaimDaily ? GamerTheme.neonGreen : GamerTheme.cardElevated,
          textColor: canClaimDaily ? Colors.black : GamerTheme.textMuted,
          onTap: canClaimDaily ? () => _handleClaimDaily(uid) : null,
        ),
        const SizedBox(height: 12),

        // Rewarded Video Ad
        _buildEarnActionCard(
          icon: Icons.play_circle_filled_rounded,
          iconColor: GamerTheme.accentOrange,
          badge: '+50 COINS EACH',
          badgeColor: GamerTheme.accentOrange,
          title: 'Watch Sponsored Rewarded Ads',
          subtitle: 'Support the community and earn 50 G-Coins for each completed 5s sponsor video.',
          buttonText: _isWatchingAd ? 'STREAMING AD...' : 'WATCH AD (+50 COINS) 📺',
          buttonColor: GamerTheme.accentOrange,
          textColor: Colors.white,
          onTap: _isWatchingAd ? null : () => _handleWatchAd(uid),
        ),
        const SizedBox(height: 12),

        // Refer Friends
        _buildEarnActionCard(
          icon: Icons.people_alt_rounded,
          iconColor: GamerTheme.accentBlue,
          badge: '+200 COINS',
          badgeColor: GamerTheme.accentBlue,
          title: 'Squad Referral Bonus',
          subtitle: 'Share code $inviteCode with your squad. Both earn +200 G-Coins after 5 matches!',
          buttonText: 'SHARE CODE ($inviteCode) 🚀',
          buttonColor: GamerTheme.accentBlue,
          textColor: Colors.white,
          onTap: () {
            Share.share(
              'Join My Gamer ID for free skill tournaments! Use code: $inviteCode. Play 5 matches to earn +200 G-Coins! 🎮💰',
            );
          },
        ),
        const SizedBox(height: 24),

        // Transaction History
        const Text(
          'STORE & REWARD HISTORY',
          style: TextStyle(
            color: GamerTheme.accentBlue,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<CoinTransaction>>(
          stream: _walletService.transactionsStream(uid),
          builder: (context, txSnap) {
            final txList = txSnap.data ?? [];
            if (txList.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: GamerTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GamerTheme.borderDark),
                ),
                child: const Center(
                  child: Text('No store transactions yet.', style: TextStyle(color: GamerTheme.textMuted, fontSize: 13)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: txList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tx = txList[index];
                final isPositive = tx.amount > 0;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isPositive ? GamerTheme.neonGreen.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPositive ? Icons.add_circle_rounded : Icons.shopping_bag_rounded,
                          color: isPositive ? GamerTheme.neonGreen : Colors.redAccent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(tx.timestamp),
                              style: const TextStyle(color: GamerTheme.textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${NumberFormat('#,###').format(tx.amount)}',
                        style: TextStyle(
                          color: isPositive ? GamerTheme.neonGreen : Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildEarnActionCard({
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required Color buttonColor,
    required Color textColor,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GamerTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTap,
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
