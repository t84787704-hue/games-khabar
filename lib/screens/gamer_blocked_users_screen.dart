import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_block_service.dart';

/// Play Store compliant Blocked Users Screen.
/// 
/// Shows list of users the current user has blocked.
/// User can unblock them from here.
class GamerBlockedUsersScreen extends StatefulWidget {
  const GamerBlockedUsersScreen({super.key});

  @override
  State<GamerBlockedUsersScreen> createState() =>
      _GamerBlockedUsersScreenState();
}

class _GamerBlockedUsersScreenState extends State<GamerBlockedUsersScreen> {
  final GamerBlockService _blockService = GamerBlockService();
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    final uid = GamerAuthService().currentUid ?? '';
    if (uid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final blocked = await _blockService.getBlockedUsersWithProfiles(uid);

    if (mounted) {
      setState(() {
        _blockedUsers = blocked;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUnblock(Map<String, dynamic> blocked) async {
    final username = (blocked['username'] ?? '').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'dialog_unblock_user_title'.tr(),
          style: const TextStyle(
            color: Color(0xFF050505),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          'unblock_user_confirm_msg'.tr(args: [username]),
          style: const TextStyle(
            color: Color(0xFF65676B),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Color(0xFF65676B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'btn_unblock'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final uid = GamerAuthService().currentUid ?? '';
    final blockedId = blocked['blocked_id']?.toString() ?? '';

    final success = await _blockService.unblockUser(
      blockerId: uid,
      blockedId: blockedId,
    );

    if (mounted) {
      if (success) {
        setState(() {
          _blockedUsers.removeWhere((b) => b['blocked_id'] == blockedId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('msg_user_unblocked'.tr(args: [username])),
            backgroundColor: const Color(0xFF34A853),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_unblock_failed'.tr()),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'title_blocked_users'.tr(),
          style: const TextStyle(
            color: Color(0xFF1877F2),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1877F2)),
              )
            : _blockedUsers.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadBlockedUsers,
                    color: const Color(0xFF1877F2),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _blockedUsers.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildInfoHeader();
                        }
                        final blocked = _blockedUsers[index - 1];
                        return _buildBlockedUserCard(blocked);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1877F2), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF1877F2), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'blocked_users_info_text'.tr(),
              style: const TextStyle(
                color: Color(0xFF050505),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE7F3FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Color(0xFF1877F2),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'no_blocked_users_title'.tr(),
              style: const TextStyle(
                color: Color(0xFF050505),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'no_blocked_users_desc'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF65676B),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUserCard(Map<String, dynamic> blocked) {
    final username = (blocked['username'] ?? 'gamer').toString();
    final displayName = (blocked['display_name'] ?? 'Gamer').toString();
    final avatarUrl = (blocked['avatar_url'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCED0D4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE4E6EB),
            backgroundImage:
                avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? const Icon(
                    Icons.person,
                    color: Color(0xFF050505),
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Color(0xFF050505),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: Color(0xFF65676B),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _handleUnblock(blocked),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1877F2),
              side: const BorderSide(color: Color(0xFF1877F2)),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              minimumSize: const Size(0, 34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.lock_open_rounded, size: 14),
            label: Text(
              'btn_unblock'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
