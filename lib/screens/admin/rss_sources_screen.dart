import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
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
    int published = 0;
    int skipped = 0;
    try {
      final snap = await FirebaseFirestore.instance
         .collection('rss_sources')
         .where('isActive', isEqualTo: true)
         .get();

      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Koi active source nahi hai - ek ko ON karo')),
          );
        }
        setState(() => _isSyncing = false);
        return;
      }

      for (var doc in snap.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          String url = (data['url']?? '').toString().trim();
          String name = (data['name']?? 'Unknown').toString();
          String category = (data['category']?? 'PUBG').toString();

          if (url.contains('...') || url.length < 20) {
            skipped++;
            continue;
          }

          bool successForThisFeed = false;

          // TRY 1: Direct XML
          try {
            final response = await http.get(
              Uri.parse(url),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                'Accept': 'application/rss+xml, application/xml, text/xml, */*'
              },
            ).timeout(const Duration(seconds: 15));

            if (response.statusCode == 200 && response.body.contains('<item>')) {
              final document = XmlDocument.parse(response.body);
              final items = document.findAllElements('item');
              if (items.isNotEmpty) {
                for (var item in items.take(3)) {
                  final title = item.getElement('title')?.innerText?? 'No Title';
                  final link = item.getElement('link')?.innerText?? '';
                  final desc = item.getElement('description')?.innerText?? '';
                  if (title.isEmpty || title == 'No Title') continue;
                  final uniqueLink = '$link#${DateTime.now().millisecondsSinceEpoch}_$published';
                  await FirebaseFirestore.instance.collection('news').add({
                    'title': title,
                    'content': desc,
                    'imageUrl': '',
                    'link': uniqueLink,
                    'sourceName': name,
                    'category': category,
                    'isAuto': true,
                    'tag': 'AUTO',
                    'createdAt': FieldValue.serverTimestamp(),
                    'views': 0,
                  });
                  published++;
                  successForThisFeed = true;
                }
              }
            }
          } catch (e) {
            debugPrint('Direct XML failed: $e');
          }

          // TRY 2: rss2json fallback - ye block nahi hota
          if (!successForThisFeed) {
            try {
              final apiUrl = 'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(url)}';
              final jsonRes = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 20));
              if (jsonRes.statusCode == 200) {
                final jsonData = json.decode(jsonRes.body);
                if (jsonData['status'] == 'ok') {
                  final List items = jsonData['items']?? [];
                  for (var item in items.take(3)) {
                    final title = (item['title']?? '').toString();
                    final link = (item['link']?? '').toString();
                    final desc = (item['description']?? '').toString();
                    if (title.isEmpty) continue;
                    final uniqueLink = '$link#${DateTime.now().millisecondsSinceEpoch}_$published';
                    await FirebaseFirestore.instance.collection('news').add({
                      'title': title,
                      'content': desc,
                      'imageUrl': item['enclosure']?['link']?? item['thumbnail']?? '',
                      'link': uniqueLink,
                      'sourceName': name,
                      'category': category,
                      'isAuto': true,
                      'tag': 'AUTO',
                      'createdAt': FieldValue.serverTimestamp(),
                      'views': 0,
                    });
                    published++;
                  }
                }
              }
            } catch (e) {
              debugPrint('rss2json failed: $e');
            }
          }
        } catch (e) {
          debugPrint('Feed error: $e');
        }
        await Future.delayed(const Duration(milliseconds: 600));
      }

      _publishedCount = published;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(published > 0? 'SUCCESS: $published news published!' : '0 news - TalkEsport ON karo'),
            backgroundColor: published > 0? Colors.green : Colors.orange,
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

  Future<void> _fixTruncatedUrls() async {
    final snap = await FirebaseFirestore.instance.collection('rss_sources').get();
    int deleted = 0;
    for (var doc in snap.docs) {
      String url = (doc.data()['url']?? '').toString();
      if (url.contains('...')) {
        await doc.reference.delete();
        deleted++;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $deleted broken URLs'), backgroundColor: Colors.green),
      );
    }
  }

  void _showAddSourceDialog(BuildContext ctx) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final hintCtrl = TextEditingController(text: 'PUBG');
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: cardDark,
        title: const Text('Add RSS Source', style: TextStyle(color: textWhite)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: const TextStyle(color: textWhite), decoration: const InputDecoration(labelText: 'Source Name')),
          const SizedBox(height: 12),
          TextField(controller: urlCtrl, style: const TextStyle(color: textWhite), decoration: const InputDecoration(labelText: 'RSS URL https://...')),
          const SizedBox(height: 12),
          TextField(controller: hintCtrl, style: const TextStyle(color: textWhite), decoration: const InputDecoration(labelText: 'Category')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: neonGreen),
            onPressed: () async {
              final url = urlCtrl.text.trim();
              if (url.isEmpty) return;
              await AutoNewsScraper.addFirestoreSource(name: nameCtrl.text.trim().isEmpty? 'Custom RSS' : nameCtrl.text.trim(), url: url, category: hintCtrl.text.trim());
              if (dCtx.mounted) Navigator.pop(dCtx);
            },
            child: const Text('Add Source'),
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
        title: const Text('Active RSS Sources', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.cleaning_services, color: Colors.orange), onPressed: _fixTruncatedUrls),
          IconButton(icon: const Icon(Icons.add, color: neonGreen), onPressed: () => _showAddSourceDialog(context)),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('rss_sources').snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs?? [];
          return Column(children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _isSyncing? Colors.orange : borderDark)),
              child: Row(children: [
                Expanded(child: ElevatedButton(onPressed: _isSyncing? null : _syncFeedsClientSide, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: Text(_isSyncing? 'Syncing...' : _publishedCount > 0? 'Sync Feeds Now ($_publishedCount)' : 'Sync Feeds Now'))),
                const SizedBox(width: 10),
                OutlinedButton.icon(onPressed: () => _showAddSourceDialog(context), icon: const Icon(Icons.add), label: const Text('Add Source')),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final data = docs[idx].data();
                  final name = data['name']?? 'Feed';
                  final url = data['url']?? '';
                  final isEnabled = (data['isActive']?? true) as bool;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: textWhite, fontWeight: FontWeight.bold)), Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textGray, fontSize: 11))])),
                      Switch(value: isEnabled, activeColor: neonGreen, onChanged: (val) => AutoNewsScraper.toggleFirestoreSource(docs[idx].id, val))
                    ]),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}