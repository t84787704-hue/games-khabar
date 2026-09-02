import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_model.dart';
import '../services/firestore_service.dart';
import '../services/auto_news_scraper.dart';
import '../widgets/app_image_view.dart';
import '../utils/admin_security.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isAdminUser()) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFFF4655),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Access Denied - Not Admin',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      }
    });
  }

  final List<String> _filters = [
    'All',
    'Auto Scraped',
    'Free Fire',
    'BGMI',
    'PUBG',
    'GTA',
    'MINECRAFT',
    'ESPORTS',
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
          side: BorderSide(color: borderDark),
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
            Text(
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
                style: TextStyle(
                  color: textWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action will remove it live from all users.',
              style: TextStyle(color: alertRed, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textGray, fontWeight: FontWeight.bold)),
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
                side: BorderSide(color: neonGreen, width: 1),
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

  Future<void> _openEditScreen(NewsModel item) async {
    final verified = await promptAdminPinDialog(context);
    if (!verified) return;
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewsScreen(editItem: item),
      ),
    );
  }

  Future<void> _openAddScreen() async {
    final verified = await promptAdminPinDialog(context);
    if (!verified) return;
    if (!mounted) return;

    Navigator.pushNamed(context, '/add-news');
  }

  void _showAddSourceDialog(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final hintCtrl = TextEditingController(text: 'Free Fire / BGMI / GTA');

    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderDark),
        ),
        title: Row(
          children: const [
            Icon(Icons.rss_feed_rounded, color: neonGreen, size: 22),
            SizedBox(width: 8),
            Text(
              'Add RSS Source',
              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: textWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Source Name (e.g. Sportskeeda / IGN)',
                  labelStyle: const TextStyle(color: textGray, fontSize: 12),
                  filled: true,
                  fillColor: cardDark2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: textWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'RSS Feed URL (https://...)',
                  labelStyle: const TextStyle(color: textGray, fontSize: 12),
                  filled: true,
                  fillColor: cardDark2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hintCtrl,
                style: const TextStyle(color: textWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Category (e.g. Free Fire / BGMI / GTA)',
                  labelStyle: const TextStyle(color: textGray, fontSize: 12),
                  filled: true,
                  fillColor: cardDark2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: borderDark),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: neonGreen,
              foregroundColor: const Color(0xFF05080D),
            ),
            onPressed: () async {
              final url = urlCtrl.text.trim();
              if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    backgroundColor: alertRed,
                    content: Text('Please enter a valid RSS feed URL starting with https://'),
                  ),
                );
                return;
              }
              await AutoNewsScraper.addFirestoreSource(
                name: nameCtrl.text.trim().isEmpty ? 'Custom RSS Feed' : nameCtrl.text.trim(),
                url: url,
                category: hintCtrl.text.trim().isEmpty ? 'Gaming News' : hintCtrl.text.trim(),
              );
              if (dCtx.mounted) Navigator.pop(dCtx);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    backgroundColor: cardDark,
                    content: Text('RSS Source Added to Firestore Successfully!', style: TextStyle(color: neonGreen)),
                  ),
                );
              }
            },
            child: const Text('Add Source', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAutoScraperSheet() {
    // Ensure 10 default sources are seeded into Firestore if collection is empty
    AutoNewsScraper.seedDefaultSourcesIfEmpty();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('scraper_sources').snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                
                // If query is ready but empty, auto seed once
                if (snapshot.connectionState == ConnectionState.active && docs.isEmpty) {
                  AutoNewsScraper.seedDefaultSourcesIfEmpty();
                }

                return Column(
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                      decoration: const BoxDecoration(
                        color: cardDark,
                        border: Border(bottom: BorderSide(color: borderDark)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: neonGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.rss_feed_rounded, color: neonGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Active RSS Sources (${docs.length})',
                                      style: const TextStyle(
                                        color: textWhite,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: neonGreen.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Firestore',
                                        style: TextStyle(
                                          color: neonGreen,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Top 10 High Search Volume Feeds (Every 30m)',
                                  style: TextStyle(color: textGray, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: textGray, size: 20),
                            onPressed: () => Navigator.pop(bCtx),
                          ),
                        ],
                      ),
                    ),

                    // Live Action & Status Banner
                    ValueListenableBuilder<bool>(
                      valueListenable: AutoNewsScraper().isScrapingNotifier,
                      builder: (context, isScraping, _) {
                        return ValueListenableBuilder<String>(
                          valueListenable: AutoNewsScraper().statusNotifier,
                          builder: (context, statusMsg, _) {
                            return Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardDark,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isScraping ? neonGreen : borderDark,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isScraping ? Icons.sync : Icons.check_circle_outline,
                                        color: isScraping ? neonGreen : textGray,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          statusMsg,
                                          style: TextStyle(
                                            color: isScraping ? neonGreen : textWhite,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isScraping)
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: neonGreen,
                                            foregroundColor: const Color(0xFF05080D),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: isScraping
                                              ? null
                                              : () async {
                                                  final added = await AutoNewsScraper().runScraper();
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        backgroundColor: cardDark,
                                                        content: Text(
                                                          'Scrape complete: $added new articles published!',
                                                          style: const TextStyle(color: neonGreen),
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                          icon: const Icon(Icons.cloud_download_rounded, size: 18),
                                          label: const Text(
                                            'Sync Feeds Now',
                                            style: TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: neonGreen,
                                          side: const BorderSide(color: neonGreen),
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () => _showAddSourceDialog(bCtx),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Add Source', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Firestore Sources List
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting && docs.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                              ),
                            )
                          : docs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.rss_feed, color: textGray, size: 40),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No RSS Sources found in Firestore',
                                        style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: neonGreen,
                                          foregroundColor: const Color(0xFF05080D),
                                        ),
                                        onPressed: () async {
                                          await AutoNewsScraper.resetDefaultSources();
                                        },
                                        child: const Text('Seed 10 Default Sources'),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  itemCount: docs.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, idx) {
                                    final doc = docs[idx];
                                    final data = doc.data();
                                    final name = data['name'] as String? ?? 'Gaming Feed';
                                    final url = data['url'] as String? ?? '';
                                    final category = (data['category'] ?? data['categoryHint'] ?? 'Gaming News') as String;
                                    final isEnabled = data['isEnabled'] as bool? ?? true;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: cardDark,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isEnabled ? borderDark : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: neonGreen.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${idx + 1}',
                                              style: const TextStyle(
                                                color: neonGreen,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: TextStyle(
                                                          color: isEnabled ? textWhite : textGray,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: neonGreen.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        category,
                                                        style: const TextStyle(
                                                          color: neonGreen,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  url,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: textGray,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Switch(
                                            value: isEnabled,
                                            activeColor: neonGreen,
                                            activeTrackColor: neonGreen.withOpacity(0.3),
                                            inactiveThumbColor: textGray,
                                            inactiveTrackColor: cardDark2,
                                            onChanged: (val) {
                                              AutoNewsScraper.toggleFirestoreSource(doc.id, val);
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: alertRed, size: 20),
                                            tooltip: 'Delete Source',
                                            onPressed: () async {
                                              await AutoNewsScraper.deleteFirestoreSource(doc.id);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),

                    // Bottom Reset Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: cardDark,
                        border: Border(top: BorderSide(color: borderDark)),
                      ),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await AutoNewsScraper.resetDefaultSources();
                              if (bCtx.mounted) {
                                ScaffoldMessenger.of(bCtx).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: cardDark,
                                    content: Text('Reset to 10 Default High Search Sources in Firestore', style: TextStyle(color: neonGreen)),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.restore, color: textGray, size: 16),
                            label: const Text('Reset 10 Sources', style: TextStyle(color: textGray, fontSize: 12)),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cardDark2,
                              foregroundColor: textWhite,
                              side: const BorderSide(color: borderDark),
                            ),
                            onPressed: () => Navigator.pop(bCtx),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
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
          icon: Icon(Icons.arrow_back_ios_new, color: textWhite, size: 20),
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
              child: Text(
                'ADMIN',
                style: TextStyle(
                  color: neonGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
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
            tooltip: 'Auto RSS Scraper',
            icon: Icon(Icons.rss_feed_rounded, color: neonGreen, size: 22),
            onPressed: _showAutoScraperSheet,
          ),
          IconButton(
            tooltip: 'Add New Khabar',
            icon: Icon(Icons.add_circle_outline, color: neonGreen, size: 24),
            onPressed: _openAddScreen,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: Icon(Icons.logout_rounded, color: alertRed, size: 22),
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
        onPressed: _openAddScreen,
        icon: const Icon(Icons.add, color: Color(0xFF05080D), size: 22),
        label: const Text(
          'Add New Khabar',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Auto RSS Scraper Quick Control Panel Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showAutoScraperSheet,
                borderRadius: BorderRadius.circular(14),
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
                        child: Icon(Icons.rss_feed_rounded, color: neonGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Auto Scraper (10 Feeds)',
                                  style: TextStyle(
                                    color: textWhite,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ValueListenableBuilder<bool>(
                                  valueListenable: AutoNewsScraper().isScrapingNotifier,
                                  builder: (context, isScraping, _) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: (isScraping ? neonGreen : Colors.green).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isScraping ? 'SYNCING...' : 'ACTIVE 30m',
                                        style: TextStyle(
                                          color: isScraping ? neonGreen : Colors.greenAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            ValueListenableBuilder<String>(
                              valueListenable: AutoNewsScraper().statusNotifier,
                              builder: (context, statusMsg, _) {
                                return Text(
                                  statusMsg == 'Idle'
                                      ? 'Sportskeeda, FF Mania, AFK, TalkEsport, GameRant, IGN & 4 more'
                                      : statusMsg,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: textGray, fontSize: 11),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: neonGreen,
                          foregroundColor: const Color(0xFF05080D),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _showAutoScraperSheet,
                        child: const Text(
                          'Sources',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
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
              style: TextStyle(color: textWhite, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by title or category...',
                hintStyle: TextStyle(color: textGray, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: textGray, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: textGray, size: 18),
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
                  borderSide: BorderSide(color: borderDark),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: neonGreen, width: 1.5),
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
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(neonGreen),
                    ),
                  );
                }

                final rawList = snapshot.data ?? [];

                // Filter by search and category
                final newsList = rawList.where((item) {
                  final bool matchesFilter;
                  if (_selectedFilter == 'All') {
                    matchesFilter = true;
                  } else if (_selectedFilter == 'Auto Scraped') {
                    matchesFilter = item.isAuto;
                  } else {
                    matchesFilter = item.category.toLowerCase() == _selectedFilter.toLowerCase();
                  }

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
                          Icon(Icons.newspaper_outlined, color: textGray, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                ? 'No matching news found'
                                : 'No news found',
                            style: TextStyle(
                                color: textWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty || _selectedFilter != 'All'
                                ? 'Try changing your search or filter'
                                : 'Tap "Add New Khabar" to publish your first article',
                            style: TextStyle(color: textGray, fontSize: 12),
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
                                    AppImageView(
                                      imageUrl: item.imageUrl,
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
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
                                          child: Icon(Icons.play_arrow_rounded, color: alertRed, size: 10),
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
                                            style: TextStyle(
                                              color: neonGreen,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (item.isAuto) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: Colors.blueAccent.withOpacity(0.4),
                                                  width: 0.8),
                                            ),
                                            child: const Text(
                                              'AUTO RSS',
                                              style: TextStyle(
                                                color: Colors.lightBlueAccent,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Text(
                                          item.timeAgo,
                                          style: TextStyle(
                                              color: textGray, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
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
                                      style: TextStyle(
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
                                      child: Icon(Icons.edit_outlined,
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
                                      child: Icon(
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
