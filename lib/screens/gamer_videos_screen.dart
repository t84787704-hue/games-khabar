import 'package:flutter/material.dart';
import '../constants/gamer_theme.dart';
import '../models/gamer_post_model.dart';
import '../services/gamer_social_service.dart';
import '../widgets/post_card.dart';
import '../widgets/tiktok_upload_progress_banner.dart';
import 'publish_video_screen.dart';

/// Dedicated Facebook Watch-Style Gaming Videos Screen
class GamerVideosScreen extends StatefulWidget {
  const GamerVideosScreen({super.key});

  @override
  State<GamerVideosScreen> createState() => _GamerVideosScreenState();
}

class _GamerVideosScreenState extends State<GamerVideosScreen> {
  final GamerSocialService _socialService = GamerSocialService();
  String _selectedTag = 'All';

  final List<String> _filterTags = [
    'All',
    'BGMI',
    'Free Fire',
    'COD Mobile',
    'Valorant',
    'GTA V',
    'General',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.surfaceDark,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.ondemand_video_rounded, color: GamerTheme.accentOrange, size: 26),
            SizedBox(width: 8),
            Text(
              'Videos',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // Facebook-style quick publish video button in header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PublishVideoScreen()),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: GamerTheme.blueOrangeGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: GamerTheme.accentBlue.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.video_call_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Publish Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PublishVideoScreen()),
          );
        },
        backgroundColor: GamerTheme.accentBlue,
        icon: const Icon(Icons.video_call_rounded, color: Colors.white),
        label: const Text(
          'Post Video (Max 3m)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Background Upload Progress Banner (TikTok style)
          const SliverToBoxAdapter(
            child: TikTokUploadProgressBanner(),
          ),

          // Facebook-Style "Publish a Video" Quick Action Banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GamerTheme.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GamerTheme.borderDark),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: GamerTheme.accentOrange.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: GamerTheme.accentOrange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share your best gaming moments',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Upload clips up to 3 minutes • 720p HD',
                          style: TextStyle(
                            color: GamerTheme.neonGreen.withOpacity(0.9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PublishVideoScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.cardElevated,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: GamerTheme.accentBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Upload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),

          // Game Category Filter Chips
          SliverToBoxAdapter(
            child: Container(
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _filterTags.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tag = _filterTags[index];
                  final isSelected = _selectedTag == tag;
                  return InkWell(
                    onTap: () => setState(() => _selectedTag = tag),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? GamerTheme.accentBlue : GamerTheme.cardDark,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? GamerTheme.accentBlue : GamerTheme.borderDark,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: isSelected ? Colors.white : GamerTheme.textGray,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Stream of Videos
          StreamBuilder<List<GamerPost>>(
            stream: _socialService.getVideosStream(
              gameTag: _selectedTag == 'All' ? null : _selectedTag,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: GamerTheme.accentBlue),
                  ),
                );
              }

              final videoPosts = snapshot.data ?? [];

              if (videoPosts.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: GamerTheme.cardDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: GamerTheme.borderDark),
                            ),
                            child: const Icon(
                              Icons.ondemand_video_rounded,
                              size: 48,
                              color: GamerTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Videos Published Yet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Publish your first gaming clutch or funny clip!\nMaximum duration: 3 minutes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: GamerTheme.textMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const PublishVideoScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GamerTheme.accentBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.video_call_rounded, size: 20),
                            label: const Text(
                              'Publish Video Now',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = videoPosts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: PostCard(
                        key: ValueKey('video_${post.postId}'),
                        post: post,
                      ),
                    );
                  },
                  childCount: videoPosts.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
