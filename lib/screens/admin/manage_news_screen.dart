import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:xml/xml.dart';

class ManageNewsScreen extends StatefulWidget {
  const ManageNewsScreen({super.key});

  @override
  State<ManageNewsScreen> createState() => _ManageNewsScreenState();
}

class _ManageNewsScreenState extends State<ManageNewsScreen> {
  bool _isSyncing = false;

  // RSS sources
  final List<Map<String, String>> _rssSources = [
    {
      'name': 'TalkEsport',
      'url': 'https://www.talkesport.com/feed/',
      'category': 'PUBG',
    },
  ];

  Future<void> _syncRSS() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    int added = 0;
    int skipped = 0;

    try {
      for (final source in _rssSources) {
        final sourceName = source['name']!;
        final feedUrl = source['url']!;
        final category = source['category']!;

        try {
          final response = await http
              .get(
                Uri.parse(feedUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0',
                },
              )
              .timeout(const Duration(seconds: 20));

          if (response.statusCode != 200) {
            debugPrint(
              '$sourceName RSS Error: ${response.statusCode}',
            );
            continue;
          }

          final document = XmlDocument.parse(response.body);

          final items = document.findAllElements('item');

          for (final item in items) {
            final title = _getElementText(item, 'title');
            final link = _getElementText(item, 'link');
            final description = _getElementText(item, 'description');
            final pubDate = _getElementText(item, 'pubDate');

            if (title.isEmpty || link.isEmpty) {
              continue;
            }

            // Duplicate check using article URL
            final existing = await FirebaseFirestore.instance
                .collection('news')
                .where('link', isEqualTo: link)
                .limit(1)
                .get();

            if (existing.docs.isNotEmpty) {
              skipped++;
              continue;
            }

            await FirebaseFirestore.instance.collection('news').add({
              'title': title,
              'content': _cleanHtml(description),
              'imageUrl': '',
              'link': link,
              'sourceName': sourceName,
              'category': category,
              'pubDate': pubDate,
              'createdAt': FieldValue.serverTimestamp(),
              'views': 0,
            });

            added++;
          }
        } catch (e) {
          debugPrint('$sourceName RSS exception: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'RSS Sync Complete\n'
              'Added: $added | Skipped: $skipped',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('RSS Sync Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  String _getElementText(XmlElement parent, String name) {
    final element = parent.findElements(name).firstOrNull;

    if (element == null) {
      return '';
    }

    return element.innerText.trim();
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),

      appBar: AppBar(
        title: const Text('Manage News'),
        backgroundColor: const Color(0xFF1E1E24),
      ),

      body: Center(
        child: ElevatedButton(
          onPressed: _isSyncing ? null : _syncRSS,

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 20,
            ),
          ),

          child: _isSyncing
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Syncing RSS...'),
                  ],
                )
              : const Text(
                  'Sync RSS News',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}