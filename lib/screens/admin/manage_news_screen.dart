import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

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
    int skipped = 0;
    try {
      final snap = await FirebaseFirestore.instance.collection('rss_sources').where('isActive', isEqualTo: true).get();
      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koi active source ON nahi hai')));
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid URL skipped: $name'), backgroundColor: Colors.red));
            continue;
          }
          bool successForThisFeed = false;
          try {
            final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 20));
            if (response.statusCode == 200 && response.body.contains('<item>')) {
              final document = XmlDocument.parse(response.body);
              final items = document.findAllElements('item');
              for (var item in items.take(3)) {
                final title = item.getElement('title')?.innerText?? 'No Title';
                final link = item.getElement('link')?.innerText?? '';
                final desc = item.getElement('description')?.innerText?? '';
                if (title.isEmpty) continue;
                final uniqueLink = '$link#${DateTime.now().millisecondsSinceEpoch}_$published';
                await FirebaseFirestore.instance.collection('news').add({
                  'title': title, 'content': desc, 'imageUrl': '', 'link': uniqueLink,
                  'sourceName': name, 'category': category, 'isAuto': true, 'tag': 'AUTO',
                  'createdAt': FieldValue.serverTimestamp(), 'views': 0,
                });
                published++; successForThisFeed = true;
              }
            }
          } catch (e) { debugPrint('Direct XML failed: $e'); }
          if (!successForThisFeed) {
            try {
              final apiUrl = 'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(url)}';
              final jsonRes = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 20));
              if (jsonRes.statusCode == 200) {
                final jsonData = json.decode(jsonRes.body);
                if (jsonData['status'] == 'ok') {
                  final List items = jsonData['items']?? [];
                  for (var item in items.take(3)) {
                    final title = item['title']?? 'No Title';
                    final link = item['link']?? '';
                    final desc = item['description']?? '';
                    if (title.isEmpty) continue;
                    final uniqueLink = '$link#${DateTime.now().millisecondsSinceEpoch}_$published';
                    await FirebaseFirestore.instance.collection('news').add({
                      'title': title, 'content': desc, 'imageUrl': item['enclosure']?['link']?? '',
                      'link': uniqueLink, 'sourceName': name, 'category': category,
                      'isAuto': true, 'tag': 'AUTO', 'createdAt': FieldValue.serverTimestamp(), 'views': 0,
                    });
                    published++;
                  }
                }
              }
            } catch (e) { debugPrint('rss2json failed: $e'); }
          }
        } catch (e) { debugPrint('Feed error: $e'); }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _publishedCount = published;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(published > 0? 'SUCCESS: $published news published!' : '0 news - TalkEsport feed add karo'),
          backgroundColor: published > 0? Colors.green : Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _fixAllTruncatedUrls() async {
    final snap = await FirebaseFirestore.instance.collection('rss_sources').get();
    int fixed = 0;
    for (var doc in snap.docs) {
      String url = (doc.data()['url']?? '').toString();
      if (url.contains('...')) { await doc.reference.delete(); fixed++; }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $fixed broken URLs'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardDark, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: textWhite), onPressed: () => Navigator.pop(context)),
        title: const Text('Manage News & Feeds', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.cleaning_services, color: Colors.orange), onPressed: _fixAllTruncatedUrls)],
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: _isSyncing? Colors.orange : borderDark)),
          child: SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _isSyncing? null : _syncFeedsClientSide,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12)),
            child: _isSyncing? const Text('Syncing...') : Text(_publishedCount > 0? 'Sync Feeds Now ($_publishedCount)' : 'Sync Feeds Now'),
          )),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('rss_sources').snapshots(), builder: (context, snap) {
          final docs = snap.data?.docs?? [];
          return ListView.builder(itemCount: docs.length, itemBuilder: (context, idx) {
            final data = docs[idx].data() as Map<String, dynamic>;
            final isActive = (data['isActive']?? false) as bool;
            return ListTile(title: Text(data['name']?? 'Feed', style: const TextStyle(color: textWhite)), subtitle: Text(data['url']?? '', style: TextStyle(color: data['url'].toString().contains('...')? Colors.red : textGray, fontSize: 11)), trailing: Switch(value: isActive, activeColor: neonGreen, onChanged: (v) => FirebaseFirestore.instance.collection('rss_sources').doc(docs[idx].id).update({'isActive': v})));
          });
        })),
      ]),
    );
  }
}