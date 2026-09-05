import 'package:flutter/material.dart';
import '../models/gaming_news_model.dart';
import '../services/gaming_news_service.dart';
import '../services/ad_free_service.dart';
import '../widgets/gaming_news_card.dart';
import '../widgets/gaming_ad_banner.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final GamingNewsService _newsService = GamingNewsService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String _searchQuery = '';
  String _selectedFilter = 'All';
  bool _showSearchBar = true;

  final List<String> _filters = [
    'All',
    'PS5',
    'Xbox',
    'PC',
    'Switch',
    'Open World',
    'Driving Games',
    'Racing Games',
  ];

  @override
  void initState() {
    super.initState();
    // Initial sync
    _newsService.syncRssNews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFilterSelected(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  List<GamingNewsModel> _filterArticles(List<GamingNewsModel> allArticles) {
    return allArticles.where((article) {
      // Category / Platform filter
      if (_selectedFilter != 'All') {
        final platformMatch =
            article.platform.toLowerCase().contains(_selectedFilter.toLowerCase());
        final categoryMatch =
            article.category.toLowerCase().contains(_selectedFilter.toLowerCase());
        if (!platformMatch && !categoryMatch) {
          return false;
        }
      }

      // Search Query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesEn = article.titleEn.toLowerCase().contains(query);
        final matchesUr = article.titleUr.toLowerCase().contains(query);
        final matchesCategory = article.category.toLowerCase().contains(query);
        final matchesPlatform = article.platform.toLowerCase().contains(query);
        final matchesSummary = article.summary.toLowerCase().contains(query);

        if (!matchesEn && !matchesUr && !matchesCategory && !matchesPlatform && !matchesSummary) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14), // Dark #0B0F14 as specified
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: Left "GK GAMES K..." green badge + Right "1 Ghante Ad-Free - Ad Dekho" yellow button + Search icon
            _buildHeader(context),

            // 2. Search Bar: "Search gaming news, updates, games..."
            if (_showSearchBar) _buildSearchBar(),

            // 3. Top Filter Chips Row (horizontal scroll)
            _buildFilterChips(),

            const SizedBox(height: 6),

            // 4. News List with Section Header & Pull to Refresh
            Expanded(
              child: StreamBuilder<List<GamingNewsModel>>(
                stream: _newsService.getGamingNewsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                    );
                  }

                  final allArticles = snapshot.data ?? [];
                  final filteredArticles = _filterArticles(allArticles);

                  return RefreshIndicator(
                    color: const Color(0xFF00FF88),
                    backgroundColor: const Color(0xFF141923),
                    onRefresh: () async {
                      await _newsService.syncRssNews();
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        // Section Header: "LATEST NEWS" with "285 articles" count on right
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 16,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF88),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const Text(
                                  'LATEST NEWS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${filteredArticles.length} articles',
                                  style: const TextStyle(
                                    color: Color(0xFF8B9BB4),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Empty Search State
                        if (filteredArticles.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_off_rounded,
                                    size: 52,
                                    color: Color(0xFF8B9BB4),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No gaming news found',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No results matching "$_searchQuery"'
                                        : 'Try another category or refresh',
                                    style: const TextStyle(
                                      color: Color(0xFF8B9BB4),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          // News List with AdMob Banners inserted every 4 articles
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                // Insert ad banner after item 2 and then every 4 items
                                final isAdPosition = (index > 0 && index % 4 == 0);
                                final actualIndex = index - (index ~/ 4);

                                if (isAdPosition) {
                                  return const GamingAdBanner();
                                }

                                if (actualIndex >= filteredArticles.length) {
                                  return const SizedBox.shrink();
                                }

                                final news = filteredArticles[actualIndex];
                                return GamingNewsCard(news: news);
                              },
                              childCount: filteredArticles.length + (filteredArticles.length ~/ 4),
                            ),
                          ),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 30),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header widget matching the screenshot
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F14),
      ),
      child: Row(
        children: [
          // Left: "GK GAMES K..." green badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GK',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 5),
                Text(
                  'GAMES KHABAR',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Right: "1 Ghante Ad-Free - Ad Dekho" yellow button
          ValueListenableBuilder<DateTime?>(
            valueListenable: AdFreeService.adFreeUntilNotifier,
            builder: (context, adFreeUntil, _) {
              final isAdFree = AdFreeService().isAdFree;
              final remaining = AdFreeService().remainingFormatted;

              return InkWell(
                onTap: () {
                  AdFreeService().showRewardedAd(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isAdFree ? const Color(0xFF182A20) : const Color(0xFFFFB703),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAdFree ? const Color(0xFF00FF88) : const Color(0xFFFF9500),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAdFree ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
                        size: 14,
                        color: isAdFree ? const Color(0xFF00FF88) : Colors.black,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isAdFree
                            ? 'Ad-Free ($remaining)'
                            : '1 Ghante Ad-Free - Ad Dekho',
                        style: TextStyle(
                          color: isAdFree ? const Color(0xFF00FF88) : Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 6),

          // Search icon
          IconButton(
            icon: Icon(
              _showSearchBar ? Icons.search : Icons.search_outlined,
              color: _showSearchBar ? const Color(0xFF00FF88) : Colors.white,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (_showSearchBar) {
                  _searchFocusNode.requestFocus();
                } else {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
    );
  }

  /// Search Bar with "Search gaming news, updates, games..."
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF141923),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262E3D), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: const TextStyle(color: Colors.white, fontSize: 13.5),
        onChanged: (val) {
          setState(() {
            _searchQuery = val.trim();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search gaming news, updates, games...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF8B9BB4),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF8B9BB4), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// Top Filter Chips Row (horizontal scroll)
  Widget _buildFilterChips() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _onFilterSelected(filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF00FF88) : const Color(0xFF1A1F29),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00FF88) : const Color(0xFF283244),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00FF88).withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
