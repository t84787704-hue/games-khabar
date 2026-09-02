import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webfeed/webfeed.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auto_news_scraper.dart';

class RssScreen extends StatefulWidget {
  const RssScreen({super.key});

  @override
  State<RssScreen> createState() => _RssScreenState();
}

class _RssScreenState extends State<RssScreen> {
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  bool _isSyncing = false;
  int _publishedCount = 0;

  Future<void> _syncFeedsClientSide() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _publishedCount = 0;
    });

    try {
      var sourcesSnap = await FirebaseFirestore.instance
          .collection('rss_sources')
          .where('isActive', isEqualTo: true)
          .get();

      if (sourcesSnap.docs.isEmpty) {
        sourcesSnap = await FirebaseFirestore.instance
            .collection('scraper_sources')
            .where('isEnabled', isEqualTo: true)
            .get();
      }

      if (sourcesSnap.docs.isEmpty) {
        await AutoNewsScraper.seedDefaultSourcesIfEmpty();
        sourcesSnap = await FirebaseFirestore.instance
            .collection('rss_sources')
            .where('isActive', isEqualTo: true)
            .get();
      }

      if (sourcesSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active RSS sources found')),
          );
        }
        return;
      }

      for (var doc in sourcesSnap.docs) {
        final source = doc.data();
        final url = source['url'] as String? ?? '';
        final sourceName = source['name'] ?? 'Unknown';
        final category = source['category'] ?? 'General';

        if (url.isEmpty) continue;

        try {
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) continue;

          final feed = RssFeed.parse(response.body);
          if (feed.items == null) continue;

          for (var item in feed.items!.take(5)) {
            if (item.link == null || item.link!.isEmpty) continue;

            final existing = await FirebaseFirestore.instance
                .collection('news')
                .where('link', isEqualTo: item.link)
                .limit(1)
                .get();
            if (existing.docs.isNotEmpty) continue;

            String imageUrl = '';
            if (item.enclosure?.url != null) imageUrl = item.enclosure!.url!;
            if (imageUrl.isEmpty && item.media?.contents?.isNotEmpty == true) {
              imageUrl = item.media!.contents!.first.url ?? '';
            }
            if (imageUrl.isEmpty && item.media?.thumbnails?.isNotEmpty == true) {
              imageUrl = item.media!.thumbnails!.first.url ?? '';
            }
            if (imageUrl.isEmpty) {
              imageUrl = 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop';
            }

            final cleanDesc = (item.description ?? item.content?.value ?? '')
                .replaceAll(RegExp(r'<[^>]*>'), '')
                .trim();

            await FirebaseFirestore.instance.collection('news').add({
              'title': item.title ?? 'No Title',
              'content': cleanDesc.isNotEmpty ? cleanDesc : 'Stay tuned for more gaming updates.',
              'description': cleanDesc.isNotEmpty ? cleanDesc : 'Stay tuned for more gaming updates.',
              'imageUrl': imageUrl,
              'link': item.link,
              'sourceUrl': item.link,
              'sourceName': sourceName,
              'sourceLogo': source['logo'] ?? '',
              'category': category,
              'isAuto': true,
              'tag': 'AUTO',
              'isVerified': true,
              'createdAt': FieldValue.serverTimestamp(),
              'publishedAt': item.pubDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
              'views': 0,
            });
            _publishedCount++;
          }
        } catch (e) {
          debugPrint('Failed for $url : $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_publishedCount news published successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark,
        elevation: 0,
        title: const Text(
          'Active RSS Sources',
          style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('rss_sources').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isSyncing ? Colors.orange : borderDark),
                ),
                child: Center(
                  child: ElevatedButton(
                    onPressed: _isSyncing ? null : _syncFeedsClientSide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSyncing
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Syncing...'),
                            ],
                          )
                        : Text('Sync Feeds Now ($_publishedCount)'),
                  ),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: neonGreen, foregroundColor: Colors.black),
                          onPressed: () async => await AutoNewsScraper.seedDefaultSourcesIfEmpty(),
                          child: const Text('Seed Default RSS Sources'),
                        ),
                      )
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, idx) {
                          final data = docs[idx].data();
                          return ListTile(
                            title: Text(data['name'] ?? 'Feed', style: const TextStyle(color: textWhite)),
                            subtitle: Text(data['url'] ?? '', style: const TextStyle(color: textGray, fontSize: 12)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
