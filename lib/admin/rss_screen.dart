import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
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
    int count = 0;

    try {
      var sources = await FirebaseFirestore.instance
          .collection('rss_sources')
          .where('isActive', isEqualTo: true)
          .get();

      if (sources.docs.isEmpty) {
        sources = await FirebaseFirestore.instance
            .collection('scraper_sources')
            .where('isEnabled', isEqualTo: true)
            .get();
      }

      if (sources.docs.isEmpty) {
        await AutoNewsScraper.seedDefaultSourcesIfEmpty();
        sources = await FirebaseFirestore.instance
            .collection('rss_sources')
            .where('isActive', isEqualTo: true)
            .get();
      }

      for (var doc in sources.docs) {
        final url = doc['url'] as String? ?? '';
        if (url.isEmpty) continue;

        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
          if (res.statusCode != 200) continue;
          final document = XmlDocument.parse(res.body);
          final items = document.findAllElements('item').take(5);

          for (var item in items) {
            String getText(String tag) =>
                item.findElements(tag).isEmpty ? '' : item.findElements(tag).first.innerText.trim();

            final link = getText('link').isNotEmpty ? getText('link') : getText('guid');
            if (link.isEmpty) continue;

            final dup = await FirebaseFirestore.instance
                .collection('news')
                .where('link', isEqualTo: link)
                .limit(1)
                .get();
            if (dup.docs.isNotEmpty) continue;

            String imageUrl = '';
            final enclosure = item.findElements('enclosure');
            if (enclosure.isNotEmpty) imageUrl = enclosure.first.getAttribute('url') ?? '';
            if (imageUrl.isEmpty) {
              final mediaContent = item.findElements('media:content');
              if (mediaContent.isNotEmpty) imageUrl = mediaContent.first.getAttribute('url') ?? '';
            }

            final cleanContent = getText('description').replaceAll(RegExp(r'<[^>]*>'), '').trim();

            await FirebaseFirestore.instance.collection('news').add({
              'title': getText('title').isNotEmpty ? getText('title') : 'Gaming News',
              'content': cleanContent.isNotEmpty ? cleanContent : 'Gaming news content update.',
              'imageUrl': imageUrl.isNotEmpty
                  ? imageUrl
                  : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop',
              'link': link,
              'sourceName': doc['name'] ?? 'Gaming Source',
              'category': doc['category'] ?? 'General',
              'isAuto': true,
              'tag': 'AUTO',
              'createdAt': FieldValue.serverTimestamp(),
              'views': 0,
            });
            count++;
          }
        } catch (e) {
          debugPrint('RSS fail $url $e');
        }
      }

      _publishedCount = count;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count news published!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                        : Text(
                            _publishedCount > 0
                                ? 'Sync Feeds Now ($_publishedCount)'
                                : 'Sync Feeds Now',
                          ),
                  ),
                ),
              ),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: neonGreen,
                            foregroundColor: Colors.black,
                          ),
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
