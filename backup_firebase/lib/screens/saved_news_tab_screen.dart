import 'package:flutter/material.dart';
import '../models/gaming_news_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/gaming_news_service.dart';
import '../widgets/news_post_card.dart';

class SavedNewsTabScreen extends StatelessWidget {
  final VoidCallback? onExploreTap;

  const SavedNewsTabScreen({super.key, this.onExploreTap});

  @override
  Widget build(BuildContext context) {
    final currentUid = GamerAuthService().currentUid ?? '';
    final newsService = GamingNewsService();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141923),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: Color(0xFF00FF88),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SAVED ARTICLES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: currentUid.isEmpty
          ? _buildLoginPrompt(context)
          : StreamBuilder<List<GamingNewsModel>>(
              stream: newsService.getSavedNewsStream(currentUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00FF88)),
                  );
                }

                final savedList = snapshot.data ?? [];
                if (savedList.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: savedList.length,
                  itemBuilder: (context, index) {
                    return NewsPostCard(news: savedList[index]);
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F29),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF262E3D), width: 1.5),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 48,
                color: Color(0xFF8B9BB4),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Saved Articles',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the bookmark icon on any gaming news article to read it later offline.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8B9BB4),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text(
                'Explore Gaming News',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              onPressed: onExploreTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFF8B9BB4)),
            const SizedBox(height: 16),
            const Text(
              'Sign in to view saved articles',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
