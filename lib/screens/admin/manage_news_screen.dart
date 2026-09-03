import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageNewsScreen extends StatefulWidget {
  const ManageNewsScreen({super.key});

  @override
  State<ManageNewsScreen> createState() => _ManageNewsScreenState();
}

class _ManageNewsScreenState extends State<ManageNewsScreen> {
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
    int published = 0;
    try {
      // Sirf 1 active feed lo test ke liye - PUBG Google
      final snap = await FirebaseFirestore.instance.collection('rss_sources').where('isActive', isEqualTo: true).limit(1).get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active source')));
        }
        return;
      }
      for (var doc in snap.docs) {
        final url = doc['url'] as String;
        debugPrint('Fetching RSS: $url');
        final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('HTTP ${response.statusCode} for ${doc['name']}')));
          }
          continue;
        }
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');
        debugPrint('Found ${items.length} items in ${doc['name']}');
        for (var item in items.take(2)) {
          final title = item.getElement('title')?.innerText ?? 'No Title';
          final link = item.getElement('link')?.innerText ?? '';
          final desc = item.getElement('description')?.innerText ?? '';
          // Force unique link taake duplicate check rok na sake
          final uniqueLink = link + '#${DateTime.now().millisecondsSinceEpoch}_$published';
          await FirebaseFirestore.instance.collection('news').add({
            'title': title,
            'content': desc,
            'imageUrl': '',
            'link': uniqueLink,
            'sourceName': doc['name'],
            'category': doc['category'] ?? 'PUBG',
            'isAuto': true,
            'tag': 'AUTO',
            'createdAt': FieldValue.serverTimestamp(),
            'views': 0,
          });
          published++;
        }
      }
      _publishedCount = published;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('SUCCESS: $published news published!'), backgroundColor: Colors.green, duration: const Duration(seconds: 5)));
      }
    } catch (e, st) {
      debugPrint('SYNC ERROR $e $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 10)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
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
          'Manage News & Feeds',
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
                child: ListView.builder(
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
