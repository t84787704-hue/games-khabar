import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auto_news_scraper.dart';

class RssSourcesScreen extends StatefulWidget {
  const RssSourcesScreen({super.key});

  @override
  State<RssSourcesScreen> createState() => _RssSourcesScreenState();
}

class _RssSourcesScreenState extends State<RssSourcesScreen> {
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color bgDark = Color(0xFF0A0A0F);
  static const Color cardDark = Color(0xFF1E1E24);
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color alertRed = Color(0xFFFF4655);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  bool _isSyncing = false;
  int _publishedCount = 0;

  Future<void> _syncFeedsClientSide() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    int count = 0;
    try {
      var snap = await FirebaseFirestore.instance.collection('rss_sources').where('isActive', isEqualTo: true).limit(1).get();
      if (snap.docs.isEmpty) {
        snap = await FirebaseFirestore.instance.collection('scraper_sources').where('isEnabled', isEqualTo: true).limit(1).get();
      }
      if (snap.docs.isEmpty) {
        await AutoNewsScraper.seedDefaultSourcesIfEmpty();
        snap = await FirebaseFirestore.instance.collection('rss_sources').where('isActive', isEqualTo: true).limit(1).get();
      }
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active source')));
        }
        return;
      }
      final doc = snap.docs.first;
      final rssUrl = (doc.data()['url'] as String?)?.trim() ?? 'https://www.sportskeeda.com/rss/bgmi';
      // Use rss2json to avoid XML block
      final apiUrl = 'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(rssUrl)}';
      final res = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (data['status'] != 'ok') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('RSS API Error: ${data['message']}')));
        }
        return;
      }
      final items = data['items'] as List;
      for (var i = 0; i < 1 && i < items.length; i++) {
        // force only 1 for test
        final item = items[i];
        // MAKE LINK UNIQUE FOR TESTING - so duplicate check never blocks
        final uniqueLink = (item['link'] ?? '') + '?test=${DateTime.now().millisecondsSinceEpoch}';
        await FirebaseFirestore.instance.collection('news').add({
          'title': item['title'] ?? 'Test News',
          'content': item['description'] ?? '',
          'description': item['description'] ?? '',
          'imageUrl': item['enclosure']?['link'] ?? item['thumbnail'] ?? 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop',
          'link': uniqueLink,
          'sourceUrl': uniqueLink,
          'sourceName': doc.data()['name'] ?? 'Sportskeeda BGMI',
          'category': 'BGMI',
          'isAuto': true,
          'tag': 'AUTO',
          'isVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
          'publishedAt': DateTime.now().toIso8601String(),
          'views': 0,
        });
        count++;
      }
      _publishedCount = count;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SUCCESS: $count news published! (Test mode)'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 10)));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
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
        title: const Row(
          children: [
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
                    content: Text('RSS Source Added Successfully!', style: TextStyle(color: neonGreen)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: neonGreen),
            tooltip: 'Add Source',
            onPressed: () => _showAddSourceDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('rss_sources').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              // Client Side Sync Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isSyncing ? Colors.orange : borderDark,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isSyncing ? Icons.sync : Icons.rss_feed,
                          color: _isSyncing ? Colors.orange : neonGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isSyncing
                                ? 'Syncing feeds directly from client...'
                                : 'Client-Side Auto RSS Engine',
                            style: TextStyle(
                              color: _isSyncing ? Colors.orange : textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSyncing ? null : _syncFeedsClientSide,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
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
                                      Text(
                                        'Syncing...',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  )
                                : Text(
                                    _publishedCount > 0
                                        ? 'Sync Feeds Now ($_publishedCount)'
                                        : 'Sync Feeds Now',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
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
                          onPressed: () => _showAddSourceDialog(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Source', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sources List
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.rss_feed, color: textGray, size: 40),
                            const SizedBox(height: 12),
                            const Text(
                              'No RSS Sources in Firestore',
                              style: TextStyle(color: textWhite, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: neonGreen,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () async => await AutoNewsScraper.seedDefaultSourcesIfEmpty(),
                              child: const Text('Seed 10 Default Sources'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final doc = docs[idx];
                          final data = doc.data();
                          final name = data['name'] as String? ?? 'Gaming Feed';
                          final url = data['url'] as String? ?? '';
                          final isEnabled = (data['isActive'] ?? data['isEnabled']) as bool? ?? true;

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
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: textWhite,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        url,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: textGray, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isEnabled,
                                  activeColor: neonGreen,
                                  onChanged: (val) => AutoNewsScraper.toggleFirestoreSource(doc.id, val),
                                ),
                              ],
                            ),
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
