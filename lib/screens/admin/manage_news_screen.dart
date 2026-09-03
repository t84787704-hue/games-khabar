import 'dart:convert';
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
      final snap = await FirebaseFirestore.instance
          .collection('rss_sources')
          .where('isActive', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Koi active source nahi hai'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      for (var doc in snap.docs) {
        final data = doc.data();
        String url = (data['url'] ?? '').toString().trim();
        String name = (data['name'] ?? 'Unknown').toString();
        String category = (data['category'] ?? 'PUBG').toString();

        if (url.contains('...') || url.length < 20) {
          debugPrint('SKIPPING invalid URL for $name: $url');
          try {
            await doc.reference.delete();
          } catch (_) {}
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid URL removed for $name'),
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          continue;
        }

        bool successForThisFeed = false;

        // 1. Try direct XML first with User-Agent
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/rss+xml, application/xml, text/xml, */*',
            },
          ).timeout(const Duration(seconds: 20));

          if (response.statusCode == 200 && response.body.contains('<item')) {
            final document = XmlDocument.parse(response.body);
            final items = document.findAllElements('item');
            for (var item in items.take(3)) {
              final title = item.getElement('title')?.innerText.trim() ?? 'No Title';
              final link = item.getElement('link')?.innerText.trim() ?? '';
              final desc = item.getElement('description')?.innerText.trim() ?? '';
              if (title.isEmpty) continue;

              final uniqueLink = '$link#${DateTime.now().millisecondsSinceEpoch}_$published';

              String imageUrl = '';
              final enclosure = item.getElement('enclosure');
              if (enclosure != null && enclosure.getAttribute('url') != null) {
                imageUrl = enclosure.getAttribute('url')!;
              }

              try {
                await FirebaseFirestore.instance.collection('news').add({
                  'title': title,
                  'content': desc,
                  'imageUrl': imageUrl,
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
              } on FirebaseException catch (fe) {
                if (fe.code == 'permission-denied') {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Firestore Permission Denied! Update Firestore Rules in Firebase Console.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 10),
                      ),
                    );
                  }
                  return;
                }
                rethrow;
              }
            }
          }
        } catch (e) {
          debugPrint('Direct XML failed for $name: $e');
        }

        // 2. Fallback to rss2json if direct XML failed (e.g. TalkEsport blocked by Cloudflare)
        if (!successForThisFeed) {
          debugPrint('Trying rss2json fallback for $name ($url)...');
          try {
            final apiUrl = 'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(url)}';
            final jsonRes = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 20));
            if (jsonRes.statusCode == 200) {
              final jsonData = json.decode(jsonRes.body);
              if (jsonData['status'] == 'ok') {
                final List items = jsonData['items'] ?? [];
                for (var item in items.take(3)) {
                  final title = (item['title'] ?? 'No Title').toString().trim();
                  final link = (item['link'] ?? '').toString().trim();
                  final desc = (item['description'] ?? '').toString().trim();
                  if (title.isEmpty) continue;

                  final uniqueLink = '$link#${DateTime.now().millisecondsSinceEpoch}_$published';

                  String imageUrl = '';
                  if (item['enclosure'] != null && item['enclosure'] is Map && item['enclosure']['link'] != null) {
                    imageUrl = item['enclosure']['link'].toString();
                  } else if (item['thumbnail'] != null) {
                    imageUrl = item['thumbnail'].toString();
                  }

                  try {
                    await FirebaseFirestore.instance.collection('news').add({
                      'title': title,
                      'content': desc,
                      'imageUrl': imageUrl,
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
                  } on FirebaseException catch (fe) {
                    if (fe.code == 'permission-denied') {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Firestore Permission Denied! Update Firestore Rules in Firebase Console.'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 10),
                          ),
                        );
                      }
                      return;
                    }
                    rethrow;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('rss2json failed for $name: $e');
          }
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      _publishedCount = published;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(published > 0
                ? 'SUCCESS: $published news published!'
                : '0 news - Saare feeds up to date hain ya URL galat hai'),
            backgroundColor: published > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('SYNC ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
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
