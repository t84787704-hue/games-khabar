import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../firebase_options.dart';
import '../models/news_model.dart';
import '../services/firestore_service.dart';
import '../services/bookmark_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/ad_free_service.dart';
import '../services/translation_service.dart';
import '../widgets/app_image_view.dart';
import '../widgets/native_ad_widget.dart';
import '../constants/game_categories.dart';
import 'news_detail_screen.dart';
import 'saved_news_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedNavIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  final BookmarkService _bookmarkService = BookmarkService();
  String selectedCategory = "All";
  String get _selectedCategory => selectedCategory;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    _initFirebaseAndServices();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  Future<void> _initFirebaseAndServices() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (DefaultFirebaseOptions.currentPlatform.apiKey.isNotEmpty &&
            !DefaultFirebaseOptions.currentPlatform.apiKey.contains('Dummy')) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 3));
        } else {
          await Firebase.initializeApp().timeout(const Duration(seconds: 3));
        }
      }
    } catch (_) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp().timeout(const Duration(seconds: 3));
        }
      } catch (_) {}
    }

    try {
      await BookmarkService().init().timeout(const Duration(seconds: 2));
    } catch (_) {}

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission().timeout(const Duration(seconds: 3));
      await messaging.subscribeToTopic('all_news').timeout(const Duration(seconds: 3));
    } catch (_) {}

    _firestoreService.refreshNews();
    if (mounted) {
      setState(() {});
    }
  }

  String _getCategoryDisplayName(String cat) {
    if (cat.toLowerCase() == 'all') {
      return 'category_all'.tr();
    }
    return cat;
  }

  void _navigateToDetail(NewsModel? news) {
    if (news == null) {
      debugPrint("Warning: Tried to navigate to detail with null news data");
      return;
    }
    print("Clicked news: ${news.id}");
    _firestoreService.incrementView(news.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(news: news),
      ),
    );
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
                      ? 'Saved to Bookmarks! 🔖 (Available in Saved)'
                      : 'Removed from Bookmarks',
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
          backgroundColor: bgDark,
          extendBody: false,
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: cardDark,
              border: Border(
                top: BorderSide(color: borderDark, width: 1),
              ),
            ),
        child: ValueListenableBuilder<Set<String>>(
          valueListenable: BookmarkService.bookmarkedIdsNotifier,
          builder: (context, bookmarkedIds, _) {
            final savedCount = bookmarkedIds.length;
            return BottomNavigationBar(
              currentIndex: _selectedNavIndex,
              onTap: (index) {
                setState(() {
                  _selectedNavIndex = index;
                });
              },
              backgroundColor: cardDark,
              selectedItemColor: neonGreen,
              unselectedItemColor: textGray,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.sports_esports_outlined),
                  activeIcon: const Icon(Icons.sports_esports_rounded),
                  label: 'nav_khabar'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: savedCount > 0
                      ? Badge(
                          label: Text(
                            '$savedCount',
                            style: const TextStyle(
                              color: Color(0xFF05080D),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: neonGreen,
                          child: const Icon(Icons.bookmark_border_rounded),
                        )
                      : const Icon(Icons.bookmark_border_rounded),
                  activeIcon: savedCount > 0
                      ? Badge(
                          label: Text(
                            '$savedCount',
                            style: const TextStyle(
                              color: Color(0xFF05080D),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: neonGreen,
                          child: const Icon(Icons.bookmark_rounded),
                        )
                      : const Icon(Icons.bookmark_rounded),
                  label: 'nav_saved'.tr(),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline_rounded),
                  activeIcon: const Icon(Icons.person_rounded),
                  label: 'nav_profile'.tr(),
                ),
              ],
            );
          },
        ),
      ),
      appBar: _selectedNavIndex != 0
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0A2A1F),
              elevation: 0,
              centerTitle: false,
              titleSpacing: 12,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: neonGreen,
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
                ValueListenableBuilder<DateTime?>(
                  valueListenable: AdFreeService.adFreeUntilNotifier,
                  builder: (context, adFreeUntil, _) {
                    final isAdFree = AdFreeService().isAdFree;
                    return ValueListenableBuilder<String>(
                      valueListenable: AdFreeService.remainingTimeNotifier,
                      builder: (context, remainingText, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: AdFreeService.isLoadingAdNotifier,
                          builder: (context, isLoading, _) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final isSmallScreen = screenWidth < 360;

                            if (isAdFree) {
                              return Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: neonGreen.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: neonGreen, width: 1.2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_outlined, color: neonGreen, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        isSmallScreen ? remainingText : 'Ad-Free: $remainingText',
                                        style: TextStyle(
                                          color: neonGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Center(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isLoading ? null : () => AdFreeService().showRewardedAd(context),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E2200),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.amber,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isLoading)
                                          const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.timer_outlined,
                                            color: Colors.amber,
                                            size: 14,
                                          ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isSmallScreen ? 'Ad-Free' : '1 Ghante Ad-Free - Ad Dekho',
                                          style: const TextStyle(
                                            color: Colors.amber,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search_rounded,
                    color: neonGreen,
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
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  height: 48,
                  color: const Color(0xFF0A2A1F),
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: gameCategories.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? const Color(0xFF05080D) : textWhite,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                            selectedColor: const Color(0xFF00FF88),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF00FF88) : borderDark,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
      body: _selectedNavIndex == 1
          ? SavedNewsScreen(
              onExploreTap: () {
                setState(() {
                  _selectedNavIndex = 0;
                });
              },
            )
          : _selectedNavIndex == 2
              ? const ProfileScreen()
              : StreamBuilder<List<NewsModel>>(
        initialData: _firestoreService.currentNews,
        stream: _firestoreService.getNewsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && (!snapshot.hasData || snapshot.data!.isEmpty)) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading Khabar...',
                    style: TextStyle(
                      color: textWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
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
                        backgroundColor: neonGreen,
                        foregroundColor: const Color(0xFF05080D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        setState(() {
                          _firestoreService.refreshNews();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    'No news yet',
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
          final filteredList = rawList.where((item) {
            final matchesCat = selectedCategory == 'All' ||
                item.category.trim().toLowerCase() == selectedCategory.trim().toLowerCase() ||
                item.category.trim() == selectedCategory.trim();
            final matchesSearch = _searchQuery.isEmpty ||
                item.getTitle(langCode).toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.getDescription(langCode).toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.description.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchesCat && matchesSearch;
          }).toList();

          NewsModel? featuredNews;
          if (filteredList.isNotEmpty) {
            final featuredList = filteredList.where((item) => item.isFeatured == true).toList();
            if (featuredList.isNotEmpty) {
              featuredNews = featuredList.first;
            } else {
              featuredNews = filteredList.first;
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
              return item.isFeatured != true;
            }).toList();
          }

          return RefreshIndicator(
            color: neonGreen,
            backgroundColor: cardDark,
            displacement: 40,
            strokeWidth: 2.5,
            onRefresh: () async {
              await _firestoreService.refreshNews();
            },
            child: CustomScrollView(
              clipBehavior: Clip.none,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
              if (_isSearching)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: neonGreen, width: 1),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: textWhite, fontSize: 14),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'search_hint'.tr(),
                          hintStyle: TextStyle(color: textGray, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: neonGreen, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: textGray, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                  )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
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
                          boxShadow: [
                            BoxShadow(
                              color: neonGreen.withOpacity(0.05),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AppImageView(
                                imageUrl: featuredNews!.imageUrl,
                                fit: BoxFit.cover