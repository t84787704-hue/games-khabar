import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  // NAYA GNEWS WALA SYNC - RSS KHATAM
  Future<void> _syncFeedsClientSide() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    int published = 0;

    const String apiKey = "7393192ee1c618b90783514125719bc1";
    List<String> topics = ["PUBG Mobile", "BGMI", "Free Fire", "Valorant", "COD Mobile"];

    try {
      for (String q in topics) {
        final String url =
            "https://gnews.io/api/v4/search?q=${Uri.encodeComponent(q)}&lang=en&max=3&apikey=$apiKey";

        try {
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final List articles = data['articles']?? [];

            for (var art in articles) {
              final title = (art['title']?? '').toString().trim();
              final desc = (art['description']?? '').toString().trim();
              final image = (art['image']?? '').toString().trim();
              final link = (art['url']?? '').toString().trim();
              final sourceName = art['source']?['name']?? 'GNews';

              if (title.isEmpty) continue;

              String category = "PUBG";
              if (q.toLowerCase().contains("bgmi")) category = "BGMI";
              else if (q.toLowerCase().contains("free fire")) category = "Free Fire";
              else if (q.toLowerCase().contains("valorant")) category = "Valorant";
              else if (q.toLowerCase().contains("cod")) category = "COD";

              final uniqueLink = '$link#${DateTime.now().millisecondsSinceEpoch}_$published';

              await FirebaseFirestore.instance.collection('news').add({
                'title': title,
                'content': desc,
                'imageUrl': image,
                'link': uniqueLink,
                'sourceName': sourceName,
                'category': category,
                'isAuto': true,
                'tag': 'GNEWS_AUTO',
                'createdAt': FieldValue.serverTimestamp(),
                'views': 0,
              });
              published++;
            }
          }
        } catch (e) {
          debugPrint('GNews failed for $q: $e');
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _publishedCount = published;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(published > 0? 'SUCCESS: $published news published!' : '0 news - API limit'),
            backgroundColor: published > 0? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
        title: const Text('Manage News & Feeds', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderDark)),
            child: Center(
              child: ElevatedButton(
                onPressed: _isSyncing? null : _syncFeedsClientSide,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                child: _isSyncing
                   ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 10), Text('Syncing GNews...')])
                    : Text(_publishedCount > 0? 'Sync GNews Now ($_publishedCount)' : 'Sync GNews Now'),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('news').orderBy('createdAt', descending: true).limit(20).snapshots(),
              builder: (context, newsSnap) {
                final newsDocs = newsSnap.data?.docs?? [];
                if (newsDocs.isEmpty) return const Center(child: Text('Koi news nahi', style: TextStyle(color: textGray)));
                return ListView.builder(
                  itemCount: newsDocs.length,
                  itemBuilder: (context, idx) {
                    final data = newsDocs[idx].data();
                    return ListTile(
                      title: Text(data['title']?? '', style: const TextStyle(color: textWhite, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${data['category']?? ''} - ${data['sourceName']?? ''}', style: const TextStyle(color: textGray, fontSize: 11)),
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