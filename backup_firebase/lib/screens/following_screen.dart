import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/news_model.dart';
import '../services/firestore_service.dart';
import '../services/following_service.dart';
import '../services/price_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../widgets/news_card.dart';
import '../widgets/price_tracker_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final FollowingService _followingService = FollowingService();
  final FirestoreService _firestoreService = FirestoreService();
  final PriceService _priceService = PriceService();
  final TextEditingController _customGameController = TextEditingController();
  bool _isAddingCustom = false;

  Color get bgDark => ThemeService.bg;
  Color get cardDark => ThemeService.card;
  Color get cardDark2 => ThemeService.cardSecondary;
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  @override
  void initState() {
    super.initState();
    _followingService.init();
  }

  @override
  void dispose() {
    _customGameController.dispose();
    super.dispose();
  }

  void _navigateToDetail(NewsModel news) {
    _firestoreService.incrementView(news.id);
  }

  void _addCustomGame() {
    final text = _customGameController.text.trim();
    if (text.isNotEmpty) {
      _followingService.toggleFollow(text);
      _customGameController.clear();
      setState(() {
        _isAddingCustom = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final isRtl = LanguageService.isRtlLocale(context.locale);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2A1F),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: neonGreen.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: neonGreen.withOpacity(0.4)),
              ),
              child: Icon(Icons.favorite_rounded, color: neonGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'FOLLOWING',
              style: TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<Set<String>>(
            valueListenable: FollowingService.followedGamesNotifier,
            builder: (context, followed, _) {
              if (followed.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () {
                  _followingService.setFollowedGames({});
                },
                icon: Icon(Icons.clear_all_rounded, color: textGray, size: 16),
                label: Text(
                  'Clear',
                  style: TextStyle(color: textGray, fontSize: 12),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: FollowingService.followedGamesNotifier,
        builder: (context, followedGames, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header & Selector section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Games to Follow',
                            style: TextStyle(
                              color: textWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${followedGames.length} followed',
                            style: TextStyle(
                              color: neonGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap games to follow their latest news, updates and patches.',
                        style: TextStyle(color: textGray, fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      // Games Choice Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...FollowingService.popularGames.map((game) {
                            final isFollowed = _followingService.isFollowing(game);
                            return FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isFollowed ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                    size: 14,
                                    color: isFollowed ? const Color(0xFF05080D) : neonGreen,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    game,
                                    style: TextStyle(
                                      color: isFollowed ? const Color(0xFF05080D) : textWhite,
                                      fontWeight: isFollowed ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              selected: isFollowed,
                              selectedColor: neonGreen,
                              backgroundColor: cardDark,
                              checkmarkColor: const Color(0xFF05080D),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isFollowed ? neonGreen : borderDark,
                                  width: isFollowed ? 1.5 : 1,
                                ),
                              ),
                              onSelected: (_) {
                                _followingService.toggleFollow(game);
                              },
                            );
                          }),

                          // Add Custom Game Button
                          ActionChip(
                            avatar: Icon(
                              _isAddingCustom ? Icons.close : Icons.add,
                              size: 16,
                              color: neonGreen,
                            ),
                            label: Text(
                              _isAddingCustom ? 'Cancel' : 'Add Other Game',
                              style: TextStyle(
                                color: neonGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: cardDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: neonGreen.withOpacity(0.5)),
                            ),
                            onPressed: () {
                              setState(() {
                                _isAddingCustom = !_isAddingCustom;
                              });
                            },
                          ),
                        ],
                      ),

                      // Custom game textfield if expanded
                      if (_isAddingCustom) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: neonGreen, width: 1.2),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customGameController,
                                  autofocus: true,
                                  style: TextStyle(color: textWhite, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Enter game name (e.g. Hollow Knight, FIFA)',
                                    hintStyle: TextStyle(color: textGray, fontSize: 12),
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _addCustomGame(),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.check, color: neonGreen),
                                onPressed: _addCustomGame,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      Divider(color: borderDark, thickness: 1),
                      const SizedBox(height: 8),

                      // Section Title
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: neonGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Followed Games Feed',
                            style: TextStyle(
                              color: textWhite,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // News Stream for Followed Games
              StreamBuilder<List<NewsModel>>(
                initialData: _firestoreService.currentNews,
                stream: _firestoreService.getNewsStream(),
                builder: (context, snapshot) {
                  final allNews = snapshot.data ?? [];
                  final followedList = _followingService.filterNews(allNews);

                  if (followedGames.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: cardDark,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: borderDark),
                                ),
                                child: Icon(
                                  Icons.sports_esports_outlined,
                                  size: 40,
                                  color: neonGreen,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Games Followed Yet',
                                style: TextStyle(
                                  color: textWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Select your favorite games above to get an exclusive news feed tailored just for you.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textGray, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: neonGreen,
                                  foregroundColor: const Color(0xFF05080D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                ),
                                icon: const Icon(Icons.flash_on_rounded, size: 18),
                                label: const Text(
                                  'Follow Top 5 Games',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                onPressed: () {
                                  _followingService.setFollowedGames({
                                    'GTA VI',
                                    'Call of Duty',
                                    'Fall Guys',
                                    'VALORANT',
                                    'Fortnite',
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (followedList.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.feed_outlined, color: textGray, size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'No recent stories for followed games',
                                style: TextStyle(
                                  color: textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try following more games from the list above.',
                                style: TextStyle(color: textGray, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = followedList[index];
                        return NewsCard(
                          news: item,
                          langCode: langCode,
                          isRtl: isRtl,
                          onTap: () => _navigateToDetail(item),
                        );
                      },
                      childCount: followedList.length,
                    ),
                  );
                },
              ),

              // Price Tracker Section for Followed Paid Games
              Builder(
                builder: (context) {
                  final followedPaidGames =
                      followedGames.where((g) => _priceService.isPaidGame(g)).toList();
                  if (followedPaidGames.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox(height: 16));
                  }

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 15,
                            decoration: BoxDecoration(
                              color: neonGreen,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Price Tracker - Sasta Hua Alert',
                            style: TextStyle(
                              color: textWhite,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: neonGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${followedPaidGames.length} Tracked',
                              style: TextStyle(
                                color: neonGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // PriceTrackerCard for each followed paid game
              Builder(
                builder: (context) {
                  final followedPaidGames =
                      followedGames.where((g) => _priceService.isPaidGame(g)).toList();
                  if (followedPaidGames.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final game = followedPaidGames[index];
                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _priceService.streamGamePrice(game),
                          builder: (context, priceSnap) {
                            final data = priceSnap.data?.data();
                            final currentPrice = (data?['currentPrice'] as num?)?.toDouble() ??
                                _getDefaultCurrentPrice(game);
                            final originalPrice = (data?['originalPrice'] as num?)?.toDouble() ??
                                _getDefaultOriginalPrice(game);
                            final lowestPrice = (data?['lowestPrice'] as num?)?.toDouble() ??
                                _getDefaultLowestPrice(game);
                            final priceHistory =
                                (data?['priceHistory'] as List<dynamic>?) ?? [];
                            final store = data?['store'] as String? ?? 'Steam';
                            final dealUrl = data?['dealUrl'] as String?;
                            final discountPercent =
                                (data?['discountPercent'] as num?)?.toInt();

                            return PriceTrackerCard(
                              gameName: game,
                              currentPrice: currentPrice,
                              originalPrice: originalPrice,
                              lowestPrice: lowestPrice,
                              priceHistory: priceHistory,
                              store: store,
                              dealUrl: dealUrl,
                              discountPercent: discountPercent,
                            );
                          },
                        );
                      },
                      childCount: followedPaidGames.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          );
        },
      ),
    );
  }

  double _getDefaultCurrentPrice(String game) {
    final lower = game.toLowerCase();
    if (lower.contains('gta')) return 69.99;
    if (lower.contains('elden')) return 59.99;
    if (lower.contains('cyberpunk')) return 29.99;
    if (lower.contains('god of war')) return 24.99;
    if (lower.contains('fc') || lower.contains('fifa')) return 69.99;
    if (lower.contains('call of duty') || lower.contains('cod')) return 69.99;
    if (lower.contains('tekken')) return 49.99;
    if (lower.contains('counter-strike') || lower.contains('cs')) return 14.99;
    if (lower.contains('palworld')) return 29.99;
    if (lower.contains('helldivers')) return 39.99;
    if (lower.contains('minecraft')) return 29.99;
    return 49.99;
  }

  double _getDefaultOriginalPrice(String game) {
    final lower = game.toLowerCase();
    if (lower.contains('cyberpunk') || lower.contains('god of war')) return 59.99;
    if (lower.contains('tekken')) return 69.99;
    final curr = _getDefaultCurrentPrice(game);
    return (curr * 1.3).roundToDouble();
  }

  double _getDefaultLowestPrice(String game) {
    final lower = game.toLowerCase();
    if (lower.contains('cyberpunk')) return 19.99;
    if (lower.contains('god of war')) return 19.99;
    if (lower.contains('elden')) return 35.99;
    final curr = _getDefaultCurrentPrice(game);
    return (curr * 0.65).roundToDouble();
  }
}
