import 'package:flutter/material.dart';
import '../models/news_model.dart';
import '../services/bookmark_service.dart';
import '../widgets/app_image_view.dart';
import 'news_detail_screen.dart';

class SavedNewsScreen extends StatefulWidget {
  final VoidCallback? onExploreTap;

  const SavedNewsScreen({super.key, this.onExploreTap});

  @override
  State<SavedNewsScreen> createState() => _SavedNewsScreenState();
}

class _SavedNewsScreenState extends State<SavedNewsScreen> {
  final BookmarkService _bookmarkService = BookmarkService();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color alertRed = Color(0xFFFF4655);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToDetail(NewsModel news) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(news: news),
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark, width: 1.5),
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep_rounded, color: alertRed, size: 24),
            SizedBox(width: 10),
            Text(
              'Clear All Bookmarks?',
              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove all saved articles from your local storage?',
          style: TextStyle(color: textGray, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: alertRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _bookmarkService.clearAllBookmarks();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: cardDark2,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: borderDark),
                    ),
                    content: const Text(
                      'All saved articles removed',
                      style: TextStyle(color: textWhite),
                    ),
                  ),
                );
              }
            },
            child: const Text('Clear All', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: neonGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: neonGreen.withOpacity(0.4), width: 1),
              ),
              child: const Icon(Icons.bookmark_rounded, color: neonGreen, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Saved Articles',
              style: TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<List<NewsModel>>(
            valueListenable: BookmarkService.bookmarksListNotifier,
            builder: (context, savedList, _) {
              if (savedList.isEmpty) return const SizedBox.shrink();
              return Row(
                children: [
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
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: textGray, size: 22),
                    tooltip: 'Clear All',
                    onPressed: () => _confirmClearAll(context),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<NewsModel>>(
        valueListenable: BookmarkService.bookmarksListNotifier,
        builder: (context, savedList, _) {
          if (savedList.isEmpty) {
            return _buildEmptyState();
          }

          // Extract unique categories in saved list
          final categories = ['All', ...savedList.map((e) => e.category).toSet()];

          // Filter by category & search query
          final filtered = savedList.where((item) {
            final matchesCat = _selectedCategory == 'All' ||
                item.category.toLowerCase() == _selectedCategory.toLowerCase();
            final matchesSearch = _searchQuery.isEmpty ||
                item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.description.toLowerCase().contains(_searchQuery.toLowerCase());
            return matchesCat && matchesSearch;
          }).toList();

          return Column(
            children: [
              // Search field (if active)
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: textWhite, fontSize: 14),
                    autofocus: true,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search saved articles...',
                      hintStyle: const TextStyle(color: textGray, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: neonGreen, size: 20),
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
                      filled: true,
                      fillColor: cardDark,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: neonGreen, width: 1.5),
                      ),
                    ),
                  ),
                ),

              // Categories Horizontal List (if more than 1 category)
              if (categories.length > 2)
                Container(
                  height: 48,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: neonGreen,
                        backgroundColor: cardDark,
                        side: BorderSide(
                          color: isSelected ? neonGreen : borderDark,
                          width: 1,
                        ),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF0A0A0F) : textWhite,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      );
                    },
                  ),
                ),

              // Header summary
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'Article' : 'Articles'} Saved Locally',
                      style: const TextStyle(
                        color: textGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.offline_pin_rounded, color: neonGreen, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      'Available Offline',
                      style: TextStyle(
                        color: neonGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Articles List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_off_rounded, color: textGray, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'No saved articles match your search',
                              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildSavedCard(item);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSavedCard(NewsModel item) {
    return Dismissible(
      key: Key('bookmark_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: alertRed.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.delete_outline_rounded, color: textWhite, size: 24),
            SizedBox(width: 6),
            Text(
              'Remove',
              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        _bookmarkService.removeBookmark(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: cardDark2,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: borderDark),
            ),
            content: Text(
              'Removed "${item.title.length > 25 ? '${item.title.substring(0, 22)}...' : item.title}"',
              style: const TextStyle(color: textWhite, fontSize: 12),
            ),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: neonGreen,
              onPressed: () {
                _bookmarkService.toggleBookmark(item);
              },
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _navigateToDetail(item),
        child: Container(
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderDark, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
                child: SizedBox(
                  width: 110,
                  height: 105,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppImageView(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                      ),
                      if (item.videoUrl != null && item.videoUrl!.isNotEmpty)
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Center(
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.play_arrow_rounded, color: neonGreen, size: 18),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Article Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category & Time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: neonGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: neonGreen.withOpacity(0.3), width: 0.8),
                            ),
                            child: Text(
                              item.category.toUpperCase(),
                              style: const TextStyle(
                                color: neonGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
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
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Action bar: View details & Remove
                      Row(
                        children: [
                          const Icon(Icons.touch_app_outlined, color: textGray, size: 12),
                          const SizedBox(width: 4),
                          const Text(
                            'Tap to read',
                            style: TextStyle(color: textGray, fontSize: 11),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              await _bookmarkService.removeBookmark(item.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: cardDark2,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(color: borderDark),
                                    ),
                                    content: const Text(
                                      'Removed from Saved',
                                      style: TextStyle(color: textWhite, fontSize: 12),
                                    ),
                                    action: SnackBarAction(
                                      label: 'UNDO',
                                      textColor: neonGreen,
                                      onPressed: () {
                                        _bookmarkService.toggleBookmark(item);
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: cardDark2,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderDark, width: 0.8),
                              ),
                              child: const Icon(
                                Icons.bookmark_remove_rounded,
                                color: alertRed,
                                size: 16,
                              ),
                            ),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing bookmark illustration container
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: borderDark, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: neonGreen.withOpacity(0.08),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.bookmark_border_rounded,
                  color: neonGreen,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Saved Articles Yet',
              style: TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Save your favorite gaming news, BGMI updates, and esports guides to read them anytime, even offline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textGray,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Explore News Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: neonGreen,
                foregroundColor: const Color(0xFF05080D),
                elevation: 4,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: widget.onExploreTap,
              icon: const Icon(Icons.sports_esports_rounded, size: 20),
              label: const Text(
                'Explore Latest News',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
