import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  static const Color cardDark2 = Color(0xFF15151A);
  static const Color borderDark = Color(0xFF2E2E38);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFF9E9EA7);

  bool _isSyncing = false;

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
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isSyncing
                          ? null
                          : () async {
                              setState(() => _isSyncing = true);
                              try {
                                final functions = FirebaseFunctions.instance;
                                // if you deployed in asia-south1, add region: FirebaseFunctions.instanceFor(region: 'asia-south1')
                                final callable = functions.httpsCallable('manualSyncFeeds');
                                final result = await callable.call();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Success: ${result.data['count'] ?? 'News synced'} news published'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('Sync error: $e');
                                if (context.mounted) {
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
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: _isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Sync Feeds Now'),
                    ),
                  ],
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
