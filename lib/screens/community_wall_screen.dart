import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/community_post_model.dart';
import '../services/community_service.dart';
import '../services/theme_service.dart';

class CommunityWallScreen extends StatefulWidget {
  const CommunityWallScreen({super.key});

  @override
  State<CommunityWallScreen> createState() => _CommunityWallScreenState();
}

class _CommunityWallScreenState extends State<CommunityWallScreen> {
  final CommunityService _communityService = CommunityService();
  final TextEditingController _postController = TextEditingController();
  final List<String> _filters = ['All', 'BGMI', 'GTA VI', 'Valorant'];
  String _selectedFilter = 'All';
  String _selectedGameForPost = 'BGMI';
  bool _isPosting = false;

  Color get bgDark => ThemeService.bg;
  Color get cardDark => ThemeService.card;
  Color get cardDark2 => ThemeService.cardSecondary;
  Color get borderDark => ThemeService.border;
  Color get neonGreen => ThemeService.primaryGreen;
  Color get textWhite => ThemeService.textPrimary;
  Color get textGray => ThemeService.textSecondary;

  @override
  void initState() {
    super.initState();
    _communityService.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: isError ? const Color(0xFFFF4655) : neonGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF161B22),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? const Color(0xFFFF4655) : neonGreen,
            width: 1.2,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitPost() async {
    final text = _postController.text.trim();

    if (text.isEmpty) {
      _showSnackBar('Apna squad ya tip share karne ke liye kuch likhein.', isError: true);
      return;
    }

    if (text.length > 200) {
      _showSnackBar('Text 200 characters se zyada nahi ho sakta.', isError: true);
      return;
    }

    if (_communityService.hasBadWords(text)) {
      _showSnackBar('Tehzeeb se likho', isError: true);
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final postGame = _selectedFilter == 'All' ? _selectedGameForPost : _selectedFilter;
      await _communityService.createPost(
        text: text,
        gameName: postGame,
      );
      _postController.clear();
      _showSnackBar('Post community wall par share ho gaya! 🎉');
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      _showSnackBar(msg.isNotEmpty ? msg : 'Post karne mein masla aya.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  void _promptEditGamerTag() {
    final nameController = TextEditingController(text: _communityService.userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: neonGreen.withOpacity(0.4)),
        ),
        title: Row(
          children: [
            Icon(Icons.sports_esports, color: neonGreen, size: 22),
            const SizedBox(width: 8),
            Text(
              'Gamer Tag Badlein',
              style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: TextField(
          controller: nameController,
          maxLength: 25,
          style: TextStyle(color: textWhite),
          decoration: InputDecoration(
            hintText: 'Apna Gamer Tag likhein',
            hintStyle: TextStyle(color: textGray),
            counterStyle: TextStyle(color: textGray),
            filled: true,
            fillColor: cardDark2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: neonGreen),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: neonGreen,
              foregroundColor: const Color(0xFF05080D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await _communityService.setUserName(newName);
                if (mounted) setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmReport(CommunityPostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFF4655), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.flag_rounded, color: Color(0xFFFF4655), size: 22),
            SizedBox(width: 8),
            Text(
              'Report Post?',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Kya aap is post ko inappropriate report karna chahte hain?\nAgar kisi post ko 3 reports mil jayen toh woh khud-ba-khud auto-hide ho jati hai.',
          style: TextStyle(color: textGray, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final autoHidden = await _communityService.reportPost(post.id, post.reportCount);
              if (autoHidden) {
                _showSnackBar('Post ko 3 reports milne par auto-hide kar diya gaya hai.');
              } else {
                _showSnackBar('Report darj ho gayi hai. Shukriya.');
              }
            },
            child: const Text('Report Karein', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Abhi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m pehle';
    if (diff.inHours < 24) return '${diff.inHours}h pehle';
    if (diff.inDays < 7) return '${diff.inDays}d pehle';
    return DateFormat('dd MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2A1F),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 14,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: neonGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.forum_rounded, color: neonGreen, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Community Wall',
                  style: TextStyle(
                    color: textWhite,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Squad & Tips',
                  style: TextStyle(
                    color: neonGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Gamer Tag / VIP profile badge button
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: _promptEditGamerTag,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cardDark2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _communityService.isUserVIP ? const Color(0xFFFFD700) : borderDark,
                      width: _communityService.isUserVIP ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_communityService.isUserVIP) ...[
                        const Text('👑', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 105),
                        child: Text(
                          _communityService.userName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _communityService.isUserVIP ? const Color(0xFFFFD700) : textWhite,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.edit, size: 11, color: textGray),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: "Community Wall - Squad & Tips" + Subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3.5,
                        height: 18,
                        decoration: BoxDecoration(
                          color: neonGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Community Wall - Squad & Tips',
                        style: TextStyle(
                          color: textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Apna squad banayein, gameplay tips share karein',
                    style: TextStyle(color: textGray, fontSize: 12.5),
                  ),
                ],
              ),
            ),

            // Filters: All, BGMI, GTA VI, Valorant
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF05080D) : textWhite,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: neonGreen,
                        backgroundColor: cardDark,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? neonGreen : borderDark,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedFilter = filter;
                              if (filter != 'All') {
                                _selectedGameForPost = filter;
                              }
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Composer Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderDark, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author & Game Selector Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: neonGreen.withOpacity(0.2),
                          child: Icon(Icons.person, color: neonGreen, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _communityService.userName,
                          style: TextStyle(
                            color: textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (_communityService.isUserVIP) ...[
                          const SizedBox(width: 4),
                          const Text('👑', style: TextStyle(fontSize: 12)),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cardDark2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderDark),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFilter == 'All' ? _selectedGameForPost : _selectedFilter,
                              dropdownColor: cardDark,
                              icon: Icon(Icons.arrow_drop_down, color: neonGreen, size: 18),
                              isDense: true,
                              style: TextStyle(color: neonGreen, fontWeight: FontWeight.bold, fontSize: 11),
                              onChanged: _selectedFilter == 'All'
                                  ? (newVal) {
                                      if (newVal != null) {
                                        setState(() {
                                          _selectedGameForPost = newVal;
                                        });
                                      }
                                    }
                                  : null,
                              items: ['BGMI', 'GTA VI', 'Valorant'].map((game) {
                                return DropdownMenuItem<String>(
                                  value: game,
                                  child: Text(game),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Post Input Field (Max 200 chars)
                    TextField(
                      controller: _postController,
                      maxLength: 200,
                      maxLines: 3,
                      minLines: 2,
                      style: TextStyle(color: textWhite, fontSize: 13, height: 1.3),
                      decoration: InputDecoration(
                        hintText: 'Apna squad ya tip share karo...',
                        hintStyle: TextStyle(color: textGray.withOpacity(0.7), fontSize: 13),
                        filled: true,
                        fillColor: cardDark2,
                        counterStyle: TextStyle(
                          color: (_postController.text.length > 200) ? const Color(0xFFFF4655) : textGray,
                          fontSize: 10,
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: neonGreen, width: 1.2),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),

                    // Composer Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Max 200 chars • Friendly community',
                          style: TextStyle(color: textGray.withOpacity(0.6), fontSize: 10),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: neonGreen,
                            foregroundColor: const Color(0xFF05080D),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isPosting ? null : _submitPost,
                          icon: _isPosting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF05080D),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 14),
                          label: Text(
                            _isPosting ? 'Posting...' : 'Post',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // StreamBuilder for community posts list
            StreamBuilder<List<CommunityPostModel>>(
              stream: _communityService.streamPosts(selectedFilter: _selectedFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: neonGreen,
                        ),
                      ),
                    ),
                  );
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderDark),
                            ),
                            child: Icon(Icons.chat_bubble_outline_rounded, color: neonGreen, size: 36),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _selectedFilter == 'All'
                                ? 'No community posts yet'
                                : 'No posts for $_selectedFilter yet',
                            style: TextStyle(
                              color: textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Apna squad requirement ya game tip uper share karein!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textGray, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 36),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isLiked = _communityService.isPostLiked(post.id);

                    return Container(
                      decoration: BoxDecoration(
                        color: cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: post.isVIP ? neonGreen.withOpacity(0.3) : borderDark,
                          width: post.isVIP ? 1.2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Author Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: post.isVIP
                                      ? const Color(0xFFFFD700).withOpacity(0.2)
                                      : neonGreen.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: post.isVIP ? const Color(0xFFFFD700) : neonGreen.withOpacity(0.5),
                                    width: 1.2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    post.userName.isNotEmpty ? post.userName[0].toUpperCase() : 'G',
                                    style: TextStyle(
                                      color: post.isVIP ? const Color(0xFFFFD700) : neonGreen,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            post.userName,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: textWhite,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (post.isVIP) ...[
                                          const SizedBox(width: 4),
                                          const Text('👑', style: TextStyle(fontSize: 13)),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTime(post.createdAt),
                                      style: TextStyle(color: textGray, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cardDark2,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderDark),
                                ),
                                child: Text(
                                  post.gameName,
                                  style: TextStyle(
                                    color: neonGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Post Text
                          Text(
                            post.text,
                            style: TextStyle(
                              color: textWhite,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),

                          const SizedBox(height: 10),
                          Divider(color: borderDark.withOpacity(0.5), height: 1),
                          const SizedBox(height: 6),

                          // Action Buttons: Like & Report
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () async {
                                  await _communityService.likePost(post.id);
                                  if (mounted) setState(() {});
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                        size: 17,
                                        color: isLiked ? const Color(0xFFFF4655) : textGray,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${post.likes}',
                                        style: TextStyle(
                                          color: isLiked ? const Color(0xFFFF4655) : textGray,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              InkWell(
                                onTap: () => _confirmReport(post),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.flag_outlined, size: 16, color: textGray),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Report',
                                        style: TextStyle(color: textGray, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
