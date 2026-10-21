import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/news_model.dart';
import '../services/supabase_store_service.dart';
import '../services/bookmark_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/ad_free_service.dart';
import '../services/translation_service.dart';
import '../widgets/app_image_view.dart';
import '../widgets/native_ad_widget.dart';
import '../constants/game_categories.dart';
import '../widgets/translated_news_title.dart';
import 'saved_news_screen.dart';
import 'profile_screen.dart';
import 'teams_screen.dart';
import 'direct_messages_screen.dart';
import 'following_screen.dart';
import 'community_wall_screen.dart';
import '../widgets/news_card.dart';
import '../widgets/streak_banner_widget.dart';
import '../services/streak_service.dart';
import '../services/price_alert_service.dart';
import '../services/countdown_service.dart';
import '../services/coin_reward_service.dart';
import 'earn_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  final SupabaseStoreService _storeService = SupabaseStoreService();
  final BookmarkService _bookmarkService = BookmarkService();
  String selectedCategory = "All";
  String get _selectedCategory => selectedCategory;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Dark Neon Theme Palette
  static const Color darkBg = Color(0xFF0A0F1D);
  static const Color cardDark = Color(0xFF131B2E);
  static const Color cardDark2 = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF1E293B);
  static const Color neonBlue = Color(0xFF00E5FF);
  static const Color neonCyan = Color(0xFF1877F2);
  static const Color neonGreen = Color(0xFF00FF88);

  Color get bgDarkTheme => ThemeService.bg;
  Color get cardDarkTheme => ThemeService.card;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  @override
  void initState() {
    super.initState();
    _initServices();
    StreakService().init();
    CoinRewardService().init();
    PriceAlertService().init();
    CountdownService().init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CoinRewardService().checkDailyLogin(context);
      _checkFirstLaunchLanguage();
    });
  }

  Future<void> _checkFirstLaunchLanguage() async {
    final shouldShow = await LanguageService.shouldShowFirstLaunchPicker();
    if (shouldShow && mounted) {
      LanguageService.showLanguageBottomSheet(
        context,
        isFirstLaunch: true,
        onLanguageChanged: () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  Future<void> _initServices() async {
    try {
      await BookmarkService().init().timeout(const Duration(seconds: 2));
    } catch (_) {}

    try {
      await NotificationService().initialize().timeout(const Duration(seconds: 3));
    } catch (_) {}

    _storeService.refreshNews();
    if (mounted) {
      setState(() {});
    }
  }

  void _navigateToDetail(NewsModel? news) {
    if (news == null) {
      debugPrint("Warning: Tried to navigate to detail with null news data");
      return;
    }
    _storeService.incrementView(news.id);

    final langCode = context.locale.languageCode;
    if (langCode != 'en' && langCode != 'ro' && !langCode.contains('roman')) {
      final currentDesc = news.getDescription(langCode);
      if (!TranslationService.isTextInLanguage(currentDesc, langCode)) {
        final baseDesc = news.descriptionMap['en']?.isNotEmpty == true
            ? news.descriptionMap['en']!
            : currentDesc;
        TranslationService.translateArticle(baseDesc, langCode).then((d) {
          if (d.isNotEmpty && TranslationService.isTextInLanguage(d, langCode)) {
            news.descriptionMap[langCode] = d;
          }
        });
      }
    }

    StreakService().recordArticleRead(news.id);
  }

  void _toggleBookmark(NewsModel news) async {
    final isSaved = await _bookmarkService.toggleBookmark(news);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cardDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isSaved ? neonGreen : borderDark, width: 1.2),
          ),
          content: Row(
            children: [
              Icon(
                isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: isSaved ? neonGreen : textGray,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSaved
                      ? 'bookmark_added'.tr()
                      : 'bookmark_removed'.tr(),
                  style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: darkBg,
          extendBody: false,
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: cardDark,
              border: Border(
                top: BorderSide(color: borderDark, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedNavIndex,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                setState(() {
                  _selectedNavIndex = index;
                });
              },
              backgroundColor: cardDark,
              selectedItemColor: neonBlue,
              unselectedItemColor: Colors.white54,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shield_outlined),
                  activeIcon: Icon(Icons.shield_rounded),
                  label: 'Teams',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    label: Text(
                      '12',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    backgroundColor: Color(0xFF1877F2),
                    child: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  activeIcon: Badge(
                    label: Text(
                      '12',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    backgroundColor: Color(0xFF1877F2),
                    child: Icon(Icons.chat_bubble_rounded),
                  ),
                  label: 'Messages',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.military_tech_outlined),
                  activeIcon: Icon(Icons.military_tech_rounded),
                  label: 'Rooms',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
          appBar: _selectedNavIndex != 0
              ? null
              : AppBar(
                  backgroundColor: darkBg,
                  elevation: 0,
                  centerTitle: false,
                  titleSpacing: 12,
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: neonBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'GK',
                          style: TextStyle(
                            color: Color(0xFF05080D),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'GAMES KHABAR',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: textWhite,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ValueListenableBuilder<int>(
                      valueListenable: CoinRewardService().coinsNotifier,
                      builder: (context, coins, _) {
                        return Center(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const EarnScreen()),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: cardDark,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: neonBlue,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: neonBlue.withOpacity(0.15),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🪙', style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$coins',
                                      style: const TextStyle(
                                        color: neonBlue,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: NotificationService().unreadCountNotifier,
                      builder: (context, unreadCount, _) {
                        return IconButton(
                          tooltip: 'tooltip_notifications'.tr(),
                          icon: Badge(
                            isLabelVisible: unreadCount > 0,
                            label: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: const Color(0xFFFF4655),
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        _isSearching ? Icons.close : Icons.search_rounded,
                        color: neonBlue,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) {
                            _searchQuery = '';
                            _searchController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(98),
                    child: Container(
                      color: darkBg,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _searchQuery.isNotEmpty ? neonBlue : borderDark,
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: textWhite, fontSize: 13),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'search_news_hint'.tr(),
                                  hintStyle: TextStyle(color: textGray, fontSize: 12),
                                  prefixIcon: const Icon(Icons.search_rounded, color: neonBlue, size: 18),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.clear_rounded, color: textGray, size: 16),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                            });
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: 44,
                            alignment: Alignment.centerLeft,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: ['All', 'PS5', 'Xbox', 'PC', 'Switch'].map((cat) {
                                  final isSelected = selectedCategory.toLowerCase() == cat.toLowerCase();
                                  final labelText = cat == 'All' ? 'category_all'.tr() : cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        labelText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected ? Colors.white : textWhite,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      selected: isSelected,
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() {
                                            selectedCategory = cat;
                                          });
                                        }
                                      },
                                      showCheckmark: false,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: cardDark,
                                      selectedColor: neonCyan,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: StadiumBorder(
                                        side: BorderSide(
                                          color: isSelected ? neonCyan : borderDark,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          body: _selectedNavIndex == 1
              ? const TeamsScreen()
              : _selectedNavIndex == 2
                  ? const DirectMessagesScreen()
                  : _selectedNavIndex == 3
                      ? const CommunityWallScreen() // Rooms / Arena screen
                      : _selectedNavIndex == 4
                          ? const ProfileScreen()
                          : StreamBuilder<List<NewsModel>>(
                              initialData: _storeService.currentNews,
                              stream: _storeService.getNewsStream(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting && (!snapshot.hasData || snapshot.data!.isEmpty)) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(neonBlue),
                                    ),
                                  );
                                }

                                if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                                          const SizedBox(height: 12),
                                          Text(
                                            "Error: ${snapshot.error}",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: textWhite, fontSize: 13),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: neonBlue,
                                              foregroundColor: const Color(0xFF05080D),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _storeService.refreshNews();
                                              });
                                            },
                                            icon: const Icon(Icons.refresh_rounded),
                                            label: Text('btn_retry'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                final List<NewsModel> rawList = snapshot.data ?? [];

                                if (rawList.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.sports_esports_outlined, color: textGray, size: 64),
                                        const SizedBox(height: 16),
                                        Text(
                                          'no_news_yet'.tr(),
                                          style: TextStyle(
                                            color: textWhite,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final langCode = context.locale.languageCode;
                                final isRtl = LanguageService.isRtlLocale(context.locale);
                                final filteredList = rawList.where((item) {
                                  bool matchesPlatform = true;
                                  final platform = selectedCategory.trim().toLowerCase();
                                  if (platform != 'all') {
                                    final cat = item.category.toLowerCase();
                                    final title = item.title.toLowerCase();
                                    final game = (item.gameName ?? '').toLowerCase();
                                    final desc = item.description.toLowerCase();

                                    if (platform == 'ps5') {
                                      matchesPlatform = cat.contains('ps5') ||
                                          cat.contains('playstation') ||
                                          title.contains('ps5') ||
                                          title.contains('playstation') ||
                                          title.contains('ps4') ||
                                          game.contains('ps5') ||
                                          desc.contains('ps5') ||
                                          desc.contains('playstation');
                                    } else if (platform == 'xbox') {
                                      matchesPlatform = cat.contains('xbox') ||
                                          title.contains('xbox') ||
                                          title.contains('game pass') ||
                                          game.contains('xbox') ||
                                          desc.contains('xbox');
                                    } else if (platform == 'pc') {
                                      matchesPlatform = cat.contains('pc') ||
                                          cat.contains('steam') ||
                                          title.contains('pc') ||
                                          title.contains('steam') ||
                                          game.contains('pc') ||
                                          desc.contains('steam') ||
                                          desc.contains(' pc ');
                                    } else if (platform == 'switch') {
                                      matchesPlatform = cat.contains('switch') ||
                                          cat.contains('nintendo') ||
                                          title.contains('switch') ||
                                          title.contains('nintendo') ||
                                          game.contains('switch') ||
                                          desc.contains('nintendo') ||
                                          desc.contains('switch');
                                    } else {
                                      matchesPlatform = cat == platform || cat.contains(platform);
                                    }
                                  }

                                  final matchesSearch = _searchQuery.isEmpty ||
                                      item.getTitle(langCode).toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                      item.getDescription(langCode).toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                      item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                      item.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                      (item.gameName?.toLowerCase().contains(_searchQuery.toLowerCase()) == true);

                                  return matchesPlatform && matchesSearch;
                                }).toList();

                                NewsModel? featuredNews;
                                if (filteredList.isNotEmpty) {
                                  final featuredList = filteredList.where((item) => item.isFeatured == true).toList();
                                  if (featuredList.isNotEmpty) {
                                    featuredNews = featuredList.first;
                                  } else {
                                    featuredNews = featuredList.first;
                                  }
                                }

                                final List<NewsModel> remainingNews;
                                if (_searchQuery.isNotEmpty) {
                                  remainingNews = filteredList;
                                } else {
                                  remainingNews = filteredList.where((item) {
                                    if (featuredNews != null && item.id == featuredNews!.id) {
                                      return false;
                                    }
                                    return true;
                                  }).toList();
                                }

                                return RefreshIndicator(
                                  color: neonBlue,
                                  backgroundColor: cardDark,
                                  displacement: 40,
                                  strokeWidth: 2.5,
                                  onRefresh: () async {
                                    await _storeService.refreshNews();
                                  },
                                  child: CustomScrollView(
                                    clipBehavior: Clip.none,
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    slivers: [
                                      if (_searchQuery.isEmpty)
                                        const SliverToBoxAdapter(
                                          child: StreakBannerWidget(),
                                        ),
                                      if (featuredNews != null && _searchQuery.isEmpty)
                                        SliverToBoxAdapter(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                            child: GestureDetector(
                                              onTap: () => _navigateToDetail(featuredNews!),
                                              child: Container(
                                                height: 200,
                                                decoration: BoxDecoration(
                                                  color: cardDark,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: borderDark),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      AppImageView(
                                                        imageUrl: featuredNews!.effectiveImageUrl,
                                                        fit: BoxFit.cover,
                                                      ),
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment.topCenter,
                                                            end: Alignment.bottomCenter,
                                                            colors: [
                                                              Colors.transparent,
                                                              Colors.black.withOpacity(0.4),
                                                              Colors.black.withOpacity(0.95),
                                                            ],
                                                            stops: const [0.0, 0.4, 1.0],
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        top: 12,
                                                        left: 12,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: neonBlue,
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            'badge_featured'.tr(),
                                                            style: const TextStyle(
                                                              color: Color(0xFF05080D),
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w900,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Positioned(
                                                        bottom: 12,
                                                        left: 12,
                                                        right: 12,
                                                        child: TranslatedNewsTitle(
                                                          news: featuredNews!,
                                                          langCode: langCode,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            color: textWhite,
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w900,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (remainingNews.isNotEmpty)
                                        SliverPadding(
                                          padding: const EdgeInsets.only(bottom: 90),
                                          sliver: SliverList(
                                            delegate: SliverChildBuilderDelegate(
                                              (context, index) {
                                                final item = remainingNews[index];
                                                return NewsCard(
                                                  news: item,
                                                  langCode: langCode,
                                                  isRtl: isRtl,
                                                  onTap: () => _navigateToDetail(item),
                                                );
                                              },
                                              childCount: remainingNews.length,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
        );
      },
    );
  }
}
