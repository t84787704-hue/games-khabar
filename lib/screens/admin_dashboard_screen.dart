import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/news_model.dart';
import '../services/firestore_service.dart';
import 'add_news_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color alertRed = Color(0xFFFF4655);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'BGMI',
    'Free Fire',
    'PUBG',
    'COD',
    'Valorant',
    'Gaming News',
  ];

  Future<void> _deleteNews(
      BuildContext context, String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_rounded, color: alertRed, size: 24),
            SizedBox(width: 8),
            Text(
              'Delete Khabar?',
              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this article?',
              style: TextStyle(color: textGray, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardDark2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderDark),
              ),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action will remove it live from all users.',
              style: TextStyle(color: alertRed, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: textGray, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: alertRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService().deleteNews(docId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: cardDark,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: neonGreen, width: 1),
              ),
              content: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: neonGreen, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Khabar deleted successfully',
                    style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: alertRed,
              content: Text('Error deleting: $e',
                  style: const TextStyle(color: Colors.white)),
            ),
          );
        }
      }
    }
  }

  void _openEditScreen(NewsModel item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewsScreen(editItem: item),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: textWhite, size: 20),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: neonGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: neonGreen),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(
                  color: neonGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Manage News',
              style: TextStyle(
                color: textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Add New Khabar',
            icon: const Icon(Icons.add_circle_outline, color: neonGreen, size: 24),
            onPressed: () => Navigator.pushNamed(context, '/add-news'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: alertRed, size: 22),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: neonGreen,
        foregroundColor: const Color(0xFF05080D),
        onPressed: () {
          Navigator.pushNamed(context, '/add-news');
        },
        icon: const Icon(Icons.add, color: Color(0xFF05080D), size: 22),
        label: const Text(
          'Add New Khabar',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Manage News Quick Overview Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderDark),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: neonGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.dashboard_customize_rounded,
                        color: neonGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Live News Control Panel',
                          style: TextStyle(
                            color: textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap Edit (✏️) or Delete (🗑️) to update articles live',
                          style: TextStyle(color: textGray, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase().trim();
                });
              },
              style: const TextStyle(color: textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by title or category...',
                hintStyle: const TextStyle(color: textGray, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: textGray, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: textGray, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardDark,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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

          // Filter Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final filter = _filters[idx];
                final isSelected = _selectedFilter == filter;
                return ChoiceChip(
                  label: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF05080D) : textGray,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: neonGreen,
                  backgroundColor: cardDark,
                  side: BorderSide(
                    color: isSelected ? neonGreen : borderDark,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // News Stream from Firestore Service
          Expanded(
            child: StreamBuilder<List<NewsModel>>(
              stream: FirestoreService().getNewsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                    ),
                  );
                }

                final rawList = snapshot.data ?? [];

                // Filter by search and category
                final newsList = rawList.where((item) {
                  final matchesFilter = _selectedFilter == 'All' ||
                      item.category.toLowerCase() == _selectedFilter.toLowerCase();
                  final matchesSearch = _searchQuery.isEmpty ||
                      item.title.toLowerCase().contains(_searchQuery) ||
                      item.description.toLowerCase().contains(_searchQuery) ||
                      item.category.toLowerCase().contains(_searchQuery);
                  return matchesFilter && matchesSearch;
                }).toList();

                if (newsList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.newspaper_outlined, color: textGray, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                ? 'No matching news found'
                                : 'No news found',
                            style: const TextStyle(
                                color: textWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                ? 'Try changing your search or filter'
                                : 'Tap "Add New Khabar" to publish your first article',
                            style: const TextStyle(color: textGray, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          if (_searchQuery.isEmpty && _selectedFilter == 'All') ...[
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: neonGreen,
                                foregroundColor: const Color(0xFF05080D),
                              ),
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/add-news'),
                              icon: const Icon(Icons.add),
                              label: const Text('Add News Now',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 95),
                  itemCount: newsList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = newsList[index];

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openEditScreen(item),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardDark,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderDark),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Image.network(
                                      item.imageUrl,
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 76,
                                        height: 76,
                                        color: cardDark2,
                                        child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: textGray,
                                            size: 24),
                                      ),
                                    ),
                                    if (item.videoUrl != null && item.videoUrl!.isNotEmpty)
                                      Positioned(
                                        top: 3,
                                        left: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.75),
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(color: alertRed, width: 0.8),
                                          ),
                                          child: const Icon(Icons.play_arrow_rounded, color: alertRed, size: 10),
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.black.withOpacity(0.65),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2, horizontal: 4),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                                Icons.visibility_outlined,
                                                color: Colors.white70,
                                                size: 10),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${item.views}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: neonGreen.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.category.toUpperCase(),
                                            style: const TextStyle(
                                              color: neonGreen,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          item.timeAgo,
                                          style: const TextStyle(
                                              color: textGray, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: textWhite,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: textGray, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),

                              // Actions: Edit and Delete
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Edit Button
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 34, minHeight: 34),
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: neonGreen.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.edit_outlined,
                                          color: neonGreen, size: 18),
                                    ),
                                    onPressed: () => _openEditScreen(item),
                                    tooltip: 'Edit Khabar',
                                  ),
                                  const SizedBox(height: 4),
                                  // Delete Button
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 34, minHeight: 34),
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: alertRed.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: alertRed,
                                          size: 18),
                                    ),
                                    onPressed: () => _deleteNews(
                                        context, item.id, item.title),
                                    tooltip: 'Delete Khabar',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
