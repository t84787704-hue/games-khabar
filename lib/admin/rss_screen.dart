import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
        final item = items[i];
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
