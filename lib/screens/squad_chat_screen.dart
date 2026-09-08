import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/lfg_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/squad_members_bottom_sheet.dart';

class SquadChatScreen extends StatefulWidget {
  final String postId;
  final SquadPost? squad;

  const SquadChatScreen({
    super.key,
    required this.postId,
    this.squad,
  });

  @override
  State<SquadChatScreen> createState() => _SquadChatScreenState();
}

// Alias to maintain compatibility with existing usages
typedef ChatScreen = SquadChatScreen;

class _SquadChatScreenState extends State<SquadChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _ensureChatDocExists();
  }

  /// Auto-create chats/{postId} document with members: [all squad member uids] if it doesn't exist
  Future<void> _ensureChatDocExists() async {
    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.postId);
      final chatDoc = await chatRef.get();
      if (!chatDoc.exists || (chatDoc.data()?['members'] == null)) {
        DocumentSnapshot postDoc = await FirebaseFirestore.instance.collection('lfg_posts').doc(widget.postId).get();
        if (!postDoc.exists) {
          postDoc = await FirebaseFirestore.instance.collection('squads').doc(widget.postId).get();
        }

        List<String> members = [];
        String title = 'Squad Chat';
        String mode = 'Classic Squad';
        String inGameUid = '';
        String leaderUid = '';

        if (postDoc.exists) {
          final data = postDoc.data() as Map<String, dynamic>? ?? {};
          leaderUid = (data['ownerId'] ?? data['userId'] ?? '').toString();
          final rawMembers = List<dynamic>.from(data['members'] ?? []);
          members = rawMembers.map((e) => e.toString()).toList();
          if (leaderUid.isNotEmpty && !members.contains(leaderUid)) {
            members.insert(0, leaderUid);
          }
          title = data['ownerBgmiName'] ?? data['displayName'] ?? 'Squad Chat';
          mode = data['mode'] ?? 'Classic Squad';
          inGameUid = data['bgmiUid'] ?? data['inGameUid'] ?? data['gameId'] ?? '';
        } else if (widget.squad != null) {
          members = List<String>.from(widget.squad!.members);
          leaderUid = widget.squad!.ownerId.isNotEmpty ? widget.squad!.ownerId : widget.squad!.userId;
          if (leaderUid.isNotEmpty && !members.contains(leaderUid)) {
            members.insert(0, leaderUid);
          }
          title = widget.squad!.displayName.isNotEmpty ? "${widget.squad!.displayName}'s Squad" : 'Squad Chat';
          mode = widget.squad!.mode;
          inGameUid = widget.squad!.inGameUid;
        }

        await chatRef.set({
          'postId': widget.postId,
          'members': members,
          'leaderUid': leaderUid,
          'title': title,
          'mode': mode,
          'inGameUid': inGameUid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[SquadChatScreen] Error ensuring chat doc: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: GamerTheme.neonGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLeaveSquad(String leaderUid, List<String> members) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '';
    if (currentUid.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Squad?', style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to leave this squad? You will be removed from the squad and chat.',
          style: TextStyle(color: GamerTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LEAVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLeaving = true);
    try {
      final user = await GamerAuthService().getUserProfile(currentUid);
      final memberName = user?.displayName ?? 'Teammate';
      await LfgService().leaveSquad(
        postId: widget.postId,
        memberUid: currentUid,
        leaderUid: leaderUid,
        memberName: memberName,
      );
      if (mounted) {
        Navigator.pop(context); // Close chat
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You left the squad'),
            backgroundColor: GamerTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _handleEndSquad(String leaderUid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Squad?', style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to end this squad? The squad will be closed and permanently removed.',
          style: TextStyle(color: GamerTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('END SQUAD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLeaving = true);
    try {
      await LfgService().deletePermanently(widget.postId, leaderUid);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Squad ended'),
            backgroundColor: GamerTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to end squad: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid;
    if (currentUid == null || currentUid.isEmpty) return;

    _textController.clear();
    setState(() => _isSending = true);

    try {
      final user = await GamerAuthService().getUserProfile(currentUid);
      final senderName = user?.displayName.isNotEmpty == true
          ? user!.displayName
          : (FirebaseAuth.instance.currentUser?.displayName ?? 'Gamer');
      final senderUsername = user?.username.isNotEmpty == true
          ? user!.username
          : senderName.toLowerCase().replaceAll(' ', '');
      final senderAvatar = user?.photoUrl ?? (FirebaseAuth.instance.currentUser?.photoURL ?? '');

      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.postId);

      await chatRef.collection('messages').add({
        'senderId': currentUid,
        'senderUid': currentUid,
        'senderName': senderName,
        'senderUsername': senderUsername,
        'senderAvatar': senderAvatar,
        'text': text,
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await chatRef.set({
        'lastMessage': '$senderName: $text',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Opens dialog for submitting a Win Proof message in squad chat
  void _openSubmitWinProofSheet() {
    final currentGamer = GamerAuthService().currentGamer;
    final inGameUidController = TextEditingController(text: currentGamer?.gameId ?? '');
    final noteController = TextEditingController(text: 'Match Won! Victory proof submitted.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit Win Proof 🏆',
                      style: TextStyle(color: GamerTheme.textWhite, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Claim 100 Coins reward from Squad Host',
                      style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'IN-GAME CHARACTER UID',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: inGameUidController,
              style: const TextStyle(color: GamerTheme.textWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. 512938472',
                hintStyle: const TextStyle(color: GamerTheme.textMuted),
                filled: true,
                fillColor: GamerTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'VICTORY NOTE / DETAILS',
              style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteController,
              style: const TextStyle(color: GamerTheme.textWhite, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Chicken Dinner / Match Won',
                hintStyle: const TextStyle(color: GamerTheme.textMuted),
                filled: true,
                fillColor: GamerTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18, color: Colors.black),
                label: const Text('SUBMIT WIN PROOF', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                onPressed: () async {
                  final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '';
                  if (currentUid.isEmpty) return;
                  final user = await GamerAuthService().getUserProfile(currentUid);
                  final senderName = user?.displayName ?? 'Teammate';
                  final senderUsername = user?.username ?? 'gamer';
                  final senderAvatar = user?.photoUrl ?? '';
                  final inGameUid = inGameUidController.text.trim();
                  final note = noteController.text.trim();

                  Navigator.pop(ctx);

                  final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.postId);
                  await chatRef.collection('messages').add({
                    'senderId': currentUid,
                    'senderUid': currentUid,
                    'senderName': senderName,
                    'senderUsername': senderUsername,
                    'senderAvatar': senderAvatar,
                    'type': 'win_proof',
                    'status': 'pending',
                    'inGameUid': inGameUid,
                    'text': note.isNotEmpty ? note : 'Match Won! Victory proof submitted.',
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  await chatRef.set({
                    'lastMessage': '$senderName submitted Win Proof 🏆',
                    'lastMessageTime': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles "Reward 100 Coins" on win_proof message card
  Future<void> _handleReward100Coins({
    required BuildContext context,
    required String messageDocId,
    required String hostId,
    required String winnerId,
    required String winnerTag,
    required String squadId,
  }) async {
    final cleanTag = winnerTag.trim().startsWith('@')
        ? winnerTag.trim().substring(1)
        : winnerTag.trim();

    // 3. Show confirm dialog "100 Coins dena hai @fua ko?"
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.5)),
        ),
        title: const Row(
          children: [
            Text('🪙', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Reward Winner',
              style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          '100 Coins dena hai @$cleanTag ko?',
          style: const TextStyle(color: GamerTheme.textWhite, fontSize: 14.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('HAAN, REWARD', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final firestore = FirebaseFirestore.instance;
    final hostRef = firestore.collection('users').doc(hostId);
    final winnerRef = firestore.collection('users').doc(winnerId);
    final messageRef = firestore
        .collection('chats')
        .doc(squadId)
        .collection('messages')
        .doc(messageDocId);

    try {
      // Run Firestore transaction
      await firestore.runTransaction((transaction) async {
        // Get host doc users/hostId and winner doc users/winnerId
        final hostDoc = await transaction.get(hostRef);
        final winnerDoc = await transaction.get(winnerRef);

        final hostData = hostDoc.data() ?? {};
        final winnerData = winnerDoc.data() ?? {};

        final int hostCoins = (hostData['coins'] as num?)?.toInt() ?? 100;
        final int winnerCoins = (winnerData['coins'] as num?)?.toInt() ?? 100;

        // Check if host.coins >= 100 else show "Not enough coins"
        if (hostCoins < 100) {
          throw 'Not enough coins';
        }

        // host.coins = host.coins - 100
        final updatedHostCoins = hostCoins - 100;
        // winner.coins = winner.coins + 100
        final updatedWinnerCoins = winnerCoins + 100;

        transaction.set(hostRef, {
          'coins': updatedHostCoins,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(winnerRef, {
          'coins': updatedWinnerCoins,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Create doc in 'coin_transactions' collection { from: hostId, to: winnerId, amount: 100, squadId, timestamp }
        final txRef = firestore.collection('coin_transactions').doc();
        transaction.set(txRef, {
          'from': hostId,
          'to': winnerId,
          'amount': 100,
          'squadId': squadId,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update win_proof message status to 'rewarded'
        transaction.update(messageRef, {
          'status': 'rewarded',
          'rewardedAt': FieldValue.serverTimestamp(),
          'rewardedBy': hostId,
        });
      });

      // Send chat system message: "Host rewarded 100 coins to @fua"
      await firestore
          .collection('chats')
          .doc(squadId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'senderUid': 'system',
        'senderName': 'System',
        'text': 'Host rewarded 100 coins to @$cleanTag',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully rewarded 100 coins to @$cleanTag!'),
            backgroundColor: GamerTheme.neonGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RewardCoins] Error: $e');
      if (context.mounted) {
        final isInsufficient = e.toString().contains('Not enough coins');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isInsufficient ? 'Not enough coins' : 'Transaction failed: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Builds the Win Proof message card
  Widget _buildWinProofCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String messageDocId,
    required bool isOwner,
    required String currentUid,
  }) {
    final senderUid = (data['senderId'] ?? data['senderUid']) as String? ?? '';
    final senderName = data['senderName'] as String? ?? 'Gamer';
    final senderUsername = (data['senderUsername'] ?? data['username'] ?? data['senderTag'] ?? data['tag'] ?? senderName).toString().trim();
    final senderAvatar = data['senderAvatar'] as String? ?? '';
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final inGameUid = (data['inGameUid'] ?? data['bgmiUid'] ?? data['gameId'] ?? '').toString();
    final proofUrl = (data['proofUrl'] ?? data['imageUrl'] ?? '').toString();
    final text = (data['text'] as String? ?? '').trim();
    final isPending = status == 'pending';
    final isRewarded = status == 'rewarded';

    final cleanTag = senderUsername.startsWith('@') ? senderUsername.substring(1) : senderUsername;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161C26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRewarded
              ? GamerTheme.neonGreen.withOpacity(0.8)
              : const Color(0xFFFFD700).withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isRewarded ? GamerTheme.neonGreen : const Color(0xFFFFD700)).withOpacity(0.12),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Trophy + "MATCH WIN PROOF" + Status Chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isRewarded ? GamerTheme.neonGreen : const Color(0xFFFFD700)).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 20,
                  color: isRewarded ? GamerTheme.neonGreen : const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MATCH WIN PROOF',
                      style: TextStyle(
                        color: GamerTheme.textWhite,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      isRewarded ? 'Reward Paid • 100 G-Coins' : 'Pending Host Verification',
                      style: TextStyle(
                        color: isRewarded ? GamerTheme.neonGreen : const Color(0xFFFFD700),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isRewarded ? GamerTheme.neonGreen : const Color(0xFFFFA500)).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRewarded ? GamerTheme.neonGreen : const Color(0xFFFFA500),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRewarded ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                      size: 12,
                      color: isRewarded ? GamerTheme.neonGreen : const Color(0xFFFFA500),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isRewarded ? 'REWARDED' : 'PENDING',
                      style: TextStyle(
                        color: isRewarded ? GamerTheme.neonGreen : const Color(0xFFFFA500),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Teammate Details Row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GamerTheme.bgDark.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GamerTheme.borderDark),
            ),
            child: Row(
              children: [
                GamerAvatar(
                  photoUrl: senderAvatar,
                  displayName: senderName,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              senderName,
                              style: const TextStyle(
                                color: GamerTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '@$cleanTag',
                            style: const TextStyle(
                              color: GamerTheme.accentCyan,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Character UID: ${inGameUid.isNotEmpty ? inGameUid : (senderUid.isNotEmpty ? senderUid : "Not specified")}',
                        style: const TextStyle(
                          color: GamerTheme.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: GamerTheme.textWhite,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          if (proofUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                proofUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],

          // 2. In squad_chat_screen.dart, in win_proof message card:
          // If isOwner == true and message status == pending, show Row with 2 buttons:
          // - COPY UID button
          // - "Reward 100 Coins" button
          if (isOwner && isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // COPY UID button
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GamerTheme.neonGreen,
                      side: const BorderSide(color: GamerTheme.neonGreen, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text(
                      'COPY UID',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final uidToCopy = inGameUid.isNotEmpty ? inGameUid : senderUid;
                      _copyToClipboard(uidToCopy, 'Winner UID');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // "Reward 100 Coins" button
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Text('🪙', style: TextStyle(fontSize: 14)),
                    label: const Text(
                      'Reward 100 Coins',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: () => _handleReward100Coins(
                      context: context,
                      messageDocId: messageDocId,
                      hostId: currentUid,
                      winnerId: senderUid,
                      winnerTag: cleanTag,
                      squadId: widget.postId,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(widget.postId).snapshots(),
      builder: (context, chatSnap) {
        final chatData = chatSnap.data?.data() as Map<String, dynamic>? ?? {};
        final leaderUid = (chatData['leaderUid'] ?? widget.squad?.ownerId ?? widget.squad?.userId ?? '').toString();
        final isOwner = currentUid.isNotEmpty && (leaderUid == currentUid || (widget.squad != null && (widget.squad!.ownerId == currentUid || widget.squad!.userId == currentUid)));
        final rawMembers = List<dynamic>.from(chatData['members'] ?? widget.squad?.members ?? []);
        final members = rawMembers.map((e) => e.toString()).toList();
        final isMember = members.contains(currentUid) || isOwner;

        final title = chatData['title'] as String? ??
            widget.squad?.title ??
            (widget.squad?.displayName.isNotEmpty == true
                ? "${widget.squad!.displayName}'s Squad"
                : 'Squad Chat');
        final mode = chatData['mode'] as String? ?? widget.squad?.mode ?? 'Classic Squad';
        final inGameUid = chatData['inGameUid'] as String? ?? widget.squad?.inGameUid ?? '';
        final memberCount = members.length;

        return Scaffold(
          backgroundColor: GamerTheme.bgDark,
          appBar: AppBar(
            backgroundColor: GamerTheme.cardDark,
            elevation: 1,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: GamerTheme.textWhite, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: GamerTheme.textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: GamerTheme.accentCyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GamerTheme.accentCyan, width: 0.8),
                      ),
                      child: Text(
                        mode,
                        style: const TextStyle(
                          color: GamerTheme.accentCyan,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$memberCount/4 members',
                      style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    if (inGameUid.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copyToClipboard(inGameUid, 'Leader BGMI UID'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'UID: $inGameUid',
                              style: const TextStyle(color: GamerTheme.neonGreen, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.copy_rounded, size: 10, color: GamerTheme.neonGreen),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // End Squad for host / Leave Squad button for non-owner members
                  if (isOwner)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _isLeaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                            )
                          : TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.power_settings_new_rounded, size: 16),
                              label: const Text(
                                'END SQUAD',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _handleEndSquad(leaderUid),
                            ),
                    )
                  else if (isMember)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _isLeaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                            )
                          : TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.exit_to_app_rounded, size: 16),
                              label: const Text(
                                'LEAVE',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _handleLeaveSquad(leaderUid, members),
                            ),
                    ),

                  // Squad Members bottom sheet button
                  IconButton(
                    tooltip: 'Squad Members',
                    icon: const Icon(Icons.people_alt_rounded, color: GamerTheme.accentCyan),
                    onPressed: () async {
                      SquadPost? currentSquad = widget.squad;
                      if (currentSquad == null) {
                        final doc = await FirebaseFirestore.instance.collection('lfg_posts').doc(widget.postId).get();
                        if (doc.exists) {
                          currentSquad = SquadPost.fromFirestore(doc);
                        }
                      }
                      if (currentSquad != null && mounted) {
                        SquadMembersBottomSheet.show(context, currentSquad);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Messages list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .doc(widget.postId)
                        .collection('messages')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: GamerTheme.accentCyan),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum_outlined, size: 48, color: GamerTheme.textMuted.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              const Text(
                                'Squad chat is ready!\nSay hello to your teammates.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final messageDocId = docs[index].id;
                          final senderUid = (data['senderId'] ?? data['senderUid']) as String? ?? '';
                          final senderName = data['senderName'] as String? ?? 'Gamer';
                          final senderAvatar = data['senderAvatar'] as String? ?? '';
                          final text = data['text'] as String? ?? '';
                          final type = data['type'] as String? ?? 'text';
                          final isMe = senderUid == currentUid;
                          final isSystem = type == 'system' || senderUid == 'system';

                          if (isSystem) {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: GamerTheme.cardElevated.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: GamerTheme.borderDark),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 14, color: GamerTheme.accentCyan),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        text,
                                        style: const TextStyle(
                                          color: GamerTheme.textMuted,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // 2. Win Proof message card
                          if (type == 'win_proof') {
                            return _buildWinProofCard(
                              context: context,
                              data: data,
                              messageDocId: messageDocId,
                              isOwner: isOwner,
                              currentUid: currentUid,
                            );
                          }

                          // Standard text message
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  GamerAvatar(
                                    photoUrl: senderAvatar,
                                    displayName: senderName,
                                    radius: 14,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? GamerTheme.accentCyan.withOpacity(0.18)
                                          : GamerTheme.cardElevated,
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(14),
                                        topRight: const Radius.circular(14),
                                        bottomLeft: Radius.circular(isMe ? 14 : 2),
                                        bottomRight: Radius.circular(isMe ? 2 : 14),
                                      ),
                                      border: Border.all(
                                        color: isMe
                                            ? GamerTheme.accentCyan.withOpacity(0.5)
                                            : GamerTheme.borderDark,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        if (!isMe)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(
                                              senderName,
                                              style: const TextStyle(
                                                color: GamerTheme.accentOrange,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          text,
                                          style: const TextStyle(
                                            color: GamerTheme.textWhite,
                                            fontSize: 13.5,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Input Bar with Win Proof Claim Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    color: GamerTheme.cardDark,
                    border: Border(top: BorderSide(color: GamerTheme.borderDark)),
                  ),
                  child: Row(
                    children: [
                      // Trophy icon button for submitting win proof
                      IconButton(
                        tooltip: 'Submit Win Proof',
                        icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 24),
                        onPressed: _openSubmitWinProofSheet,
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: GamerTheme.bgDark,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: GamerTheme.borderLight.withOpacity(0.4)),
                          ),
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(color: GamerTheme.textWhite, fontSize: 13.5),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: const InputDecoration(
                              hintText: 'Message squad teammates...',
                              hintStyle: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: GamerTheme.accentCyan,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
