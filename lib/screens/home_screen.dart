import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/news_model.dart';
import '../services/firestore_service.dart';
import 'news_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedCategory = 'All';
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  final List<String> _categories = [
    'All',
    'BGMI',
    'Free Fire',
    'PUBG',
    'COD',
    'Valorant',
    'Gaming News',
  ];

  // 6 Fallback dummy gaming articles if Firestore has 0 documents
  final List<NewsModel> _fallbackNews = [
    NewsModel(
      id: 'dummy-1',
      title: 'BGMI 3.2 Update: New Map, Mecha Fusion Mode & Futuristic Weapons',
      description:
          'Battlegrounds Mobile India (BGMI) rolls out the massive 3.2 update featuring robotic suits, new weapon attachments, enhanced 90/120 FPS performance, and exciting Royale Pass rewards.',
      category: 'BGMI',
      imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '15m ago',
      views: 1240,
    ),
    NewsModel(
      id: 'dummy-2',
      title: 'Free Fire MAX World Series Tournament 2024 Announced with \$2M Prize Pool',
      description:
          'Garena unveils official roadmap and qualifying tournament slots for Free Fire World Series with regional qualifiers and exclusive in-game character bundles.',
      category: 'Free Fire',
      imageUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '1h ago',
      views: 980,
    ),
    NewsModel(
      id: 'dummy-3',
      title: 'PUBG Mobile 3.4 Vampire Blood Moon Mode & Flying Steed Details',
      description:
          'The upcoming PUBG Mobile 3.4 version brings gothic vampire powers, transformed werewolf mechanics, and magical mounts across Erangel and Livik.',
      category: 'PUBG',
      imageUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '3h ago',
      views: 750,
    ),
    NewsModel(
      id: 'dummy-4',
      title: 'Call of Duty Warzone Mobile Season 4: Rebirth Island & Ranked Play',
      description:
          'Activision drops Season 4 with significant optimization passes for mid-range chipsets, Rebirth Island Resurgence mode, and shared Battle Pass progression.',
      category: 'COD',
      imageUrl: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '5h ago',
      views: 620,
    ),
    NewsModel(
      id: 'dummy-5',
      title: 'Valorant Mobile Closed Beta Regional Rollout Dates Confirmed',
      description:
          'Riot Games starts regional technical testing for Valorant Mobile with intuitive touch controls, gyro aiming support, and customized mobile maps.',
      category: 'Valorant',
      imageUrl: 'https://images.unsplash.com/photo-1612287233207-6f81c9535032?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '8h ago',
      views: 1430,
    ),
    NewsModel(
      id: 'dummy-6',
      title: 'GTA 6 Official Release Window & Vice City Map Size Comparisons',
      description:
          'Rockstar Games re-confirms Autumn 2025 release window for Grand Theft Auto VI, highlighting next-gen AI simulations and expanded Leonida state map.',
      category: 'Gaming News',
      imageUrl: 'https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=1000&q=80',
      timeAgo: '12h ago',
      views: 2890,
    ),
  ];

  void _navigateToDetail(NewsModel news) {
    if (!news.id.startsWith('dummy')) {
      _firestoreService.incrementView(news.id);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(news: news),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        centerTitle: false,
        title: GestureDetector(
          onLongPress: () {
            // Hidden admin access on long press
            Navigator.pushNamed(context, '/admin-login');
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Green GK Logo Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: neonGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'GK',
                  style: TextStyle(
                    color: Color(0xFF05080D),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'GAMES KHABAR',
                style: TextStyle(
                  color: textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search_rounded,
              color: neonGreen,
              size: 24,
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
        ],
      ),
      body: StreamBuilder<List<NewsModel>>(
        stream: _firestoreService.getNewsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
              ),
            );
          }

          final List<NewsModel> rawList =
              (snapshot.hasData && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : _fallbackNews;

          // Filter by category and search
          final filteredList = rawList.where((item) {
            final matchesCat = _selectedCategory == 'All' ||
                item.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
                _selectedCategory.toLowerCase().contains(item.category.toLowerCase());
            final matchesSearch = _searchQuery.isEmpty ||
                item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.description.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchesCat && matchesSearch;
          }).toList();

          final featuredNews = filteredList.isNotEmpty ? filteredList.first : null;
          final remainingNews = filteredList.length > 1 ? filteredList.sublist(1) : <NewsModel>[];

          // IGN Mixed Layout split: first 2 large horizontal, rest 2-column grid
          final horizontalCards = remainingNews.take(2).toList();
          final gridCards = remainingNews.skip(2).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Search field (if search toggle is open)
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
                        style: const TextStyle(color: textWhite, fontSize: 14),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search gaming news, BGMI, Free Fire...',
                          hintStyle: const TextStyle(color: textGray, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: neonGreen, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: textGray, size: 18),
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

              // Category Filter Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? neonGreen.withOpacity(0.12) : cardDark,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? neonGreen : borderDark,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? neonGreen : textGray,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Featured News Card (IGN Full-Width Hero)
              if (featuredNews != null && _searchQuery.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: GestureDetector(
                      onTap: () => _navigateToDetail(featuredNews),
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
                              CachedNetworkImage(
                                imageUrl: featuredNews.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: cardDark2),
                                errorWidget: (_, __, ___) => Container(
                                  color: cardDark2,
                                  child: const Icon(Icons.videogame_asset, color: textGray, size: 48),
                                ),
                              ),
                              // IGN Dramatic Black Gradient Overlay
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
                              // Featured Badge Top Left
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: neonGreen,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'FEATURED',
                                        style: TextStyle(
                                          color: Color(0xFF05080D),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    if (featuredNews.videoUrl != null && featuredNews.videoUrl!.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF4655),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 2),
                                            Text(
                                              'VIDEO',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Title & Time Overlay
                              Positioned(
                                bottom: 12,
                                left: 12,
                                right: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      featuredNews.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: textWhite,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          featuredNews.category.toUpperCase(),
                                          style: const TextStyle(
                                            color: neonGreen,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text('•', style: TextStyle(color: textGray, fontSize: 11)),
                                        const SizedBox(width: 8),
                                        Text(
                                          featuredNews.timeAgo,
                                          style: const TextStyle(color: textGray, fontSize: 11),
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
                    ),
                  ),
                ),

              // "LATEST NEWS" Heading with Green Line
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: neonGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCategory == 'All' ? 'LATEST NEWS' : _selectedCategory.toUpperCase(),
                        style: const TextStyle(
                          color: textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${filteredList.length} articles',
                        style: const TextStyle(color: textGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Layout 1: First 2 Cards - Large Horizontal Card (IGN style)
              if (horizontalCards.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = horizontalCards[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _navigateToDetail(item),
                            borderRadius: BorderRadius.circular(12),
                            splashColor: neonGreen.withOpacity(0.15),
                            highlightColor: neonGreen.withOpacity(0.08),
                            child: Container(
                              height: 110,
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderDark),
                              ),
                              child: Row(
                                children: [
                                  // Left Image (120px)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                                    child: SizedBox(
                                      width: 120,
                                      height: double.infinity,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl: item.imageUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: cardDark2),
                                            errorWidget: (_, __, ___) => Container(
                                              color: cardDark2,
                                              child: const Icon(Icons.videogame_asset, color: textGray),
                                            ),
                                          ),
                                          if (item.videoUrl != null && item.videoUrl!.isNotEmpty)
                                            Center(
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.65),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
                                                ),
                                                child: const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Color(0xFFFF4655),
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Right Content
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: neonGreen.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: neonGreen.withOpacity(0.5)),
                                                ),
                                                child: Text(
                                                  item.category.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: neonGreen,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                item.timeAgo,
                                                style: const TextStyle(color: textGray, fontSize: 10),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            item.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: textWhite,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              height: 1.25,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.visibility_outlined, color: textGray, size: 12),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${item.views}',
                                                style: const TextStyle(color: textGray, fontSize: 10),
                                              ),
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
                        ),
                      );
                    },
                    childCount: horizontalCards.length,
                  ),
                ),

              // Layout 2: Rest of News - 2 Columns Grid (IGN Style)
              if (gridCards.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = gridCards[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _navigateToDetail(item),
                            borderRadius: BorderRadius.circular(12),
                            splashColor: neonGreen.withOpacity(0.15),
                            highlightColor: neonGreen.withOpacity(0.08),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderDark),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Image
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 10,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CachedNetworkImage(
                                            imageUrl: item.imageUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(color: cardDark2),
                                            errorWidget: (_, __, ___) => Container(
                                              color: cardDark2,
                                              child: const Icon(Icons.videogame_asset, color: textGray),
                                            ),
                                          ),
                                          if (item.videoUrl != null && item.videoUrl!.isNotEmpty)
                                            Positioned(
                                              bottom: 6,
                                              right: 6,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.8),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFFFF4655), width: 1),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: const [
                                                    Icon(Icons.play_arrow_rounded, color: Color(0xFFFF4655), size: 12),
                                                    SizedBox(width: 2),
                                                    Text(
                                                      'VIDEO',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Details below
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Category Dot + Category Name
                                          Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: neonGreen,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  item.category.toUpperCase(),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: neonGreen,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          // Title (max 2 lines)
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: textWhite,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                height: 1.25,
                                              ),
                                            ),
                                          ),
                                          // Time Ago
                                          Text(
                                            item.timeAgo,
                                            style: const TextStyle(color: textGray, fontSize: 10),
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
                      },
                      childCount: gridCards.length,
                    ),
                  ),
                ),

              if (filteredList.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Center(
                      child: Column(
                        children: const [
                          Icon(Icons.search_off_rounded, color: textGray, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'No articles found',
                            style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
