import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/gamer_theme.dart';
import '../services/block_service.dart';
import '../services/gamer_auth_service.dart';
import 'gamer_profile_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _blockService = BlockService();
  final _authService = GamerAuthService();

  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _authService.currentUid ?? '';
    final list = await _blockService.getBlockedUsers(uid);
    if (!mounted) return;
    setState(() {
      _blocked = list;
      _loading = false;
    });
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    final uid = _authService.currentUid ?? '';
    final name =
        (user['display_name'] ?? user['username'] ?? 'User').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unblock User?',
            style: TextStyle(
                color: Color(0xFF050505), fontWeight: FontWeight.bold)),
        content: Text(
            'Unblock $name? They will be able to see your profile and posts again.',
            style: const TextStyle(color: Color(0xFF65676B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF65676B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unblock',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _blockService.unblockUser(
      currentUid: uid,
      targetUid: user['id'].toString(),
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _blocked
            .removeWhere((u) => u['id'].toString() == user['id'].toString());
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unblocked $name'),
          backgroundColor: GamerTheme.accentGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to unblock'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF050505)),
        title: const Text(
          'Blocked Users',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1877F2)))
          : _blocked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE4E6EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.block_rounded,
                            size: 48, color: Color(0xFF65676B)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Blocked Users',
                        style: TextStyle(
                          color: Color(0xFF050505),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Users you block will appear here. They won\'t be able to see your posts or profile.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF65676B), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF1877F2),
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _blocked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final u = _blocked[i];
                      final name =
                          (u['display_name'] ?? u['username'] ?? 'Gamer')
                              .toString();
                      final username =
                          (u['username'] ?? 'gamer').toString();
                      final photo = (u['avatar_url'] ?? '').toString();
                      final verified = u['is_verified'] == true;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFCED0D4)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GamerProfileScreen(
                                    userId: u['id'].toString()),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFE4E6EB),
                            backgroundImage: photo.isNotEmpty
                                ? CachedNetworkImageProvider(photo)
                                : null,
                            child: photo.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Color(0xFF65676B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Color(0xFF050505),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (verified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified,
                                    color: Color(0xFF1877F2), size: 14),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '@$username',
                            style: const TextStyle(
                                color: Color(0xFF65676B), fontSize: 12),
                          ),
                          trailing: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFFEE2E2),
                              foregroundColor: const Color(0xFFDC2626),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _unblock(u),
                            child: const Text('Unblock',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}