import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  NewsCategory _selectedCategory = NewsCategory.ALL;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color bgOuter = Color(0xFF05080D);
  static const Color bgScaffold = Color(0xFF0A0E13);
  static const Color cardBg = Color(0xFF151A23);
  static const Color cardBg2 = Color(0xFF1A2230);
  static const Color borderColor = Color(0xFF222C3A);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color alertRed = Color(0xFFFF4655);
  static const Color newsBlue = Color(0xFF3B82F6);
  static const Color reviewPurple = Color(0xFFA855F7);
  static const Color trailerOrange = Color(0xFFF97316);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9CA3AF);

  // Fallback dummy news items if Firestore is empty or connecting for the first time
  final List<NewsModel> _fallbackNews = [
    NewsModel(
      id: 'dummy-1',
      title: 'BGMI 3.4 Update: Vampire Blood Moon Mode, New Flying Horse & Release Date',
      description: 'BGMI 3.4 update is arriving with exciting vampire themed mode, supernatural powers, flying horse vehicle, and new weapon balances. Download the update from Play Store.',
      category: NewsCategory.NEWS,
      imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '10 min pehle',
      views: 340,
    ),
    NewsModel(
      id: 'dummy-2',
      title: 'Free Fire World Series Tournament 2024 - Pakistan Squads Qualified',
      description: 'Free Fire announced official registrations and prize pool details for the upcoming World Series championships with exclusive custom bundles.',
      category: NewsCategory.FREE,
      imageUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '1 ghanta pehle',
      views: 520,
      isFree: true,
      originalPrice: '100% FREE',
    ),
    NewsModel(
      id: 'dummy-3',
      title: 'PUBG Mobile 3.2 120 FPS Support Officially Released on Android',
      description: 'Players can now experience ultra smooth 120 frames per second gameplay on supported flagship Snapdragon and Dimensity devices.',
      category: NewsCategory.NEWS,
      imageUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '3 ghante pehle',
      views: 890,
    ),
  ];

  Color _getCategoryColor(NewsCategory category) {
    switch (category) {
      case NewsCategory.FREE:
        return neonGreen;
      case NewsCategory.NEWS:
        return newsBlue;
      case NewsCategory.REVIEW:
        return reviewPurple;
      case NewsCategory.TRAILER:
        return trailerOrange;
      case NewsCategory.DISCOUNT:
        return alertRed;
      case NewsCategory.LOW_MB:
        return neonGreen;
      default:
        return newsBlue;
    }
  }

  void _openDetailSheet(NewsModel newsItem) {
    if (!newsItem.id.startsWith('dummy')) {
      _firestoreService.incrementView(newsItem.id);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F141E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final categoryColor = _getCategoryColor(newsItem.category);
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: categoryColor),
                        ),
                        child: Text(
                          newsItem.category.badgeName,
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: textWhite, size: 20),
                        style: IconButton.styleFrom(backgroundColor: cardBg2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    newsItem.title,
                    style: const TextStyle(
                      color: textWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: neonGreen, size: 14),
                      const SizedBox(width: 4),
                      const Text(
                        'Games Khabar Team',
                        style: TextStyle(color: neonGreen, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: textGray, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(newsItem.timeAgo, style: const TextStyle(color: textGray, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: textGray, fontSize: 12)),
                      const SizedBox(width: 8),
                      const Icon(Icons.visibility_outlined, color: textGray, size: 13),
                      const SizedBox(width: 4),
                      Text('${newsItem.views} views', style: const TextStyle(color: textGray, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      newsItem.imageUrl,
                      width: double.infinity,
                      height: 210,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 210,
                        color: cardBg2,
                        child: const Icon(Icons.videogame_asset, color: textGray, size: 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    newsItem.description,
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 14.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 30),
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
    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        centerTitle: false,
        title: GestureDetector(
          onLongPress: () {
            // Hidden entry to Admin Login on 2-second long press
            Navigator.pushNamed(context, '/admin-login');
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: neonGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'GK',
                    style: TextStyle(
                      color: bgOuter,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Games Khabar',
                    style: TextStyle(
                      color: neonGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'URDU GAMING NEWS & FREE GAMES',
                    style: TextStyle(
                      color: textGray,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<NewsModel>>(
          stream: _firestoreService.getNewsStream(),
          builder: (context, snapshot) {
            // State 1: Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                ),
              );
            }

            // If error or empty, fallback gracefully to the 3 dummy cards
            final List<NewsModel> rawList = (snapshot.hasData && snapshot.data!.isNotEmpty)
                ? snapshot.data!
                : _fallbackNews;

            // Filter data by category and search query
            final filteredNews = rawList.where((item) {
              final matchesCategory = _selectedCategory == NewsCategory.ALL || item.category == _selectedCategory;
              final matchesSearch = _searchQuery.isEmpty ||
                  item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  item.description.toLowerCase().contains(_searchQuery.toLowerCase());
              return matchesCategory && matchesSearch;
            }).toList();

            final freeGames = rawList.where((item) =>
                item.isFree || item.category == NewsCategory.FREE || item.category == NewsCategory.DISCOUNT).toList();

            final heroItem = rawList.isNotEmpty ? rawList.first : null;

            return CustomScrollView(
              slivers: [
                // Search Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: textWhite, fontSize: 13),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Game khabar search karo... BGMI, Free Fire, PUBG',
                          hintStyle: const TextStyle(color: textGray, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: textGray, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: textGray, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),

                // Category Filter Chips
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: NewsCategory.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final cat = NewsCategory.values[idx];
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat.displayName),
                          selected: isSelected,
                          selectedColor: neonGreen,
                          backgroundColor: cardBg,
                          labelStyle: TextStyle(
                            color: isSelected ? bgOuter : textGray,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(
                            color: isSelected ? neonGreen : borderColor,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),

                // Hero Featured Card
                if (_searchQuery.isEmpty && _selectedCategory == NewsCategory.ALL && heroItem != null)
                  SliverToBoxAdapter(
                    child: GestureDetector(
                      onTap: () => _openDetailSheet(heroItem),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  heroItem.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: cardBg2,
                                    child: const Icon(Icons.videogame_asset, color: textGray, size: 48),
                                  ),
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
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: alertRed,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.bolt, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'BREAKING',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 14,
                                  left: 14,
                                  right: 14,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        heroItem.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: textWhite,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, color: textGray, size: 12),
                                          const SizedBox(width: 4),
                                          Text(heroItem.timeAgo, style: const TextStyle(color: textGray, fontSize: 11)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.visibility_outlined, color: textGray, size: 12),
                                          const SizedBox(width: 4),
                                          Text('${heroItem.views} views', style: const TextStyle(color: textGray, fontSize: 11)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Aaj FREE Hai Horizontal Section
                if (_searchQuery.isEmpty && (_selectedCategory == NewsCategory.ALL || _selectedCategory == NewsCategory.FREE) && freeGames.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text(
                            'Aaj FREE Hai 🔥',
                            style: TextStyle(
                              color: textWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 175,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: freeGames.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (ctx, idx) {
                              final game = freeGames[idx];
                              return GestureDetector(
                                onTap: () => _openDetailSheet(game),
                                child: Container(
                                  width: 165,
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                        child: Image.network(
                                          game.imageUrl,
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            height: 100,
                                            color: cardBg2,
                                            child: const Icon(Icons.videogame_asset, color: textGray),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              game.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: textWhite,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              game.isFree ? '100% FREE' : (game.originalPrice ?? 'DISCOUNT'),
                                              style: const TextStyle(
                                                color: neonGreen,
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
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Taza Khabrain Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: neonGreen, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(
                          _selectedCategory == NewsCategory.ALL ? 'Taza Khabrain' : _selectedCategory.displayName,
                          style: const TextStyle(color: textWhite, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(width: 8),
                        Text('• ${filteredNews.length} posts', style: const TextStyle(color: textGray, fontSize: 13)),
                      ],
                    ),
                  ),
                ),

                // News Vertical List
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final item = filteredNews[idx];
                      final categoryColor = _getCategoryColor(item.category);
                      return GestureDetector(
                        onTap: () => _openDetailSheet(item),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  item.imageUrl,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 86,
                                    height: 86,
                                    color: cardBg2,
                                    child: const Icon(Icons.videogame_asset, color: textGray, size: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: categoryColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: categoryColor.withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        item.category.badgeName,
                                        style: TextStyle(color: categoryColor, fontSize: 9, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: textWhite,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, color: textGray, size: 11),
                                        const SizedBox(width: 3),
                                        Text(item.timeAgo, style: const TextStyle(color: textGray, fontSize: 10)),
                                        const SizedBox(width: 8),
                                        const Text('•', style: TextStyle(color: textGray, fontSize: 10)),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.visibility_outlined, color: textGray, size: 11),
                                        const SizedBox(width: 3),
                                        Text('${item.views}', style: const TextStyle(color: textGray, fontSize: 10)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: filteredNews.length,
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 90),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
