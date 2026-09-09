import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../services/cloudinary_service.dart';
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

  /// Auto-creates both squads/{postId} and chats/{postId} parent documents if missing
  Future<void> _ensureChatDocExists() async {
    try {
      final squadRef = FirebaseFirestore.instance.collection('squads').doc(widget.postId);
      final squadDoc = await squadRef.get();
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.postId);
      final chatDoc = await chatRef.get();

      DocumentSnapshot postDoc = await FirebaseFirestore.instance.collection('lfg_posts').doc(widget.postId).get();
      if (!postDoc.exists) {
        postDoc = squadDoc;
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '';
      final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';

      List<String> members = [];
      String title = 'Squad Chat';
      String mode = 'Classic Squad';
      String inGameUid = '';
      String leaderUid = '';

      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>? ?? {};
        leaderUid = (data['hostId'] ?? data['ownerId'] ?? data['userId'] ?? '').toString();
        final rawMembers = List<dynamic>.from(data['members'] ?? []);
        members = rawMembers.map((e) => e.toString()).toList();
        if (leaderUid.isNotEmpty && !members.contains(leaderUid)) {
          members.insert(0, leaderUid);
        }
        title = data['ownerBgmiName'] ?? data['displayName'] ?? data['title'] ?? 'Squad Chat';
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

      if (leaderUid.isEmpty) {
        leaderUid = currentUid.isNotEmpty ? currentUid : 'gamer';
      }
      if (members.isEmpty && leaderUid.isNotEmpty) {
        members.add(leaderUid);
      }

      // 1. Ensure parent document in 'squads' collection exists
      if (!squadDoc.exists) {
        final squadData = {
          'squadId': widget.postId,
          'id': widget.postId,
          'postId': widget.postId,
          'hostId': leaderUid,
          'userId': leaderUid,
          'ownerId': leaderUid,
          'hostEmail': currentEmail,
          'ownerEmail': currentEmail,
          'createdAt': FieldValue.serverTimestamp(),
          'members': members,
          'memberCount': members.isNotEmpty ? members.length : 1,
          'membersCount': members.isNotEmpty ? members.length : 1,
          'isActive': true,
          'displayName': title,
          'title': title,
          'mode': mode,
          'inGameUid': inGameUid,
          'bgmiUid': inGameUid,
          'bgmiUidToCopy': inGameUid,
          'game': 'BGMI',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await squadRef.set(squadData, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('lfg_posts').doc(widget.postId).set(squadData, SetOptions(merge: true));
      }

      // 2. Ensure parent document in 'chats' collection exists
      if (!chatDoc.exists || (chatDoc.data()?['members'] == null)) {
        await chatRef.set({
          'chatId': widget.postId,
          'postId': widget.postId,
          'squadId': widget.postId,
          'members': members,
          'leaderUid': leaderUid,
          'ownerId': leaderUid,
          'hostId': leaderUid,
          'title': title,
          'mode': mode,
          'inGameUid': inGameUid,
          'bgmiUidToCopy': inGameUid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'isActive': true,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[SquadChatScreen] Error ensuring squad and chat docs: $e');
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

  /// Uploads proof screenshot to Cloudinary using folder match_proofs
  Future<String?> _uploadProofScreenshot(File imageFile, String uid, String squadId) async {
    return await CloudinaryService.uploadFile(file: imageFile, folder: 'match_proofs');
  }

  /// Opens dialog for submitting a Win Proof message in squad chat
  Future<void> _openSubmitWinProofSheet() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '';
    if (currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first to submit win proof.'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    // 1. Fetch live user profile to get verified character UID (gameUid)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
    final userData = userDoc.data() ?? {};
    final characterUid = (userData['bgmiUid'] ?? userData['gameId'] ?? userData['inGameId'] ?? userData['gameUid'] ?? '').toString().trim();

    // Validate: Character UID must be equal to current user's Firestore profile gameUid, don't allow typing any UID.
    if (characterUid.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: GamerTheme.cardElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: GamerTheme.redAccent.withOpacity(0.5)),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: GamerTheme.accentOrange, size: 24),
              SizedBox(width: 8),
              Text(
                'Character UID Missing',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Pehle apni Profile mein Character UID (Game ID) add karen taake victory proof submit kar sakein. Kisi aur ka UID allow nahi hai.',
            style: TextStyle(color: GamerTheme.textMuted, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Theek Hai', style: TextStyle(color: GamerTheme.accentCyan)),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    File? proofImage;
    bool isSubmitting = false;
    final noteController = TextEditingController(text: 'Match Won! Victory proof submitted.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submit Win Proof 🏆',
                              style: TextStyle(color: GamerTheme.textWhite, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Host approval required • 100 Coins reward',
                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Character UID (Read-only, auto-filled from user profile)
                  const Row(
                    children: [
                      Text(
                        'CHARACTER UID',
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.lock_rounded, size: 12, color: GamerTheme.neonGreen),
                      SizedBox(width: 4),
                      Text(
                        '(Verified from Profile)',
                        style: TextStyle(color: GamerTheme.neonGreen, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: GamerTheme.bgDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.borderDark),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_rounded, color: GamerTheme.accentCyan, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            characterUid,
                            style: const TextStyle(
                              color: GamerTheme.textWhite,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const Text(
                          'READ-ONLY',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Required Screenshot Upload
                  Row(
                    children: [
                      const Text(
                        'VICTORY SCREENSHOT',
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GamerTheme.redAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'REQUIRED',
                          style: TextStyle(color: GamerTheme.redAccent, fontSize: 9.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  GestureDetector(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                            if (picked != null) {
                              setModalState(() {
                                proofImage = File(picked.path);
                              });
                            }
                          },
                    child: proofImage == null
                        ? Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: GamerTheme.bgDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFFD700), size: 36),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to Upload Victory Screenshot',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Chicken Dinner / Results Screen (Required)',
                                  style: TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  proofImage!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: isSubmitting ? null : () => setModalState(() => proofImage = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: GamerTheme.neonGreen, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Screenshot Attached',
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'VICTORY NOTE / DETAILS',
                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: GamerTheme.textWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Chicken Dinner / Match Won',
                      hintStyle: const TextStyle(color: GamerTheme.textMuted),
                      filled: true,
                      fillColor: GamerTheme.bgDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // SUBMIT BUTTON (Disabled after 1 click, preventing double submission spam)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (proofImage != null && !isSubmitting)
                            ? const Color(0xFFFFD700)
                            : Colors.grey.shade800,
                        foregroundColor: (proofImage != null && !isSubmitting) ? Colors.black : Colors.white54,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        isSubmitting
                            ? 'SUBMITTING PROOF...'
                            : (proofImage == null ? 'ATTACH SCREENSHOT TO SUBMIT' : 'SUBMIT WIN PROOF'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      onPressed: (isSubmitting || proofImage == null)
                          ? null
                          : () async {
                              // Immediately disable button after 1 click to prevent double submission spam
                              setModalState(() => isSubmitting = true);

                              try {
                                final user = await GamerAuthService().getUserProfile(currentUid);
                                final senderName = user?.displayName ?? 'Teammate';
                                final senderUsername = user?.username ?? 'gamer';
                                final senderAvatar = user?.photoUrl ?? '';
                                final note = noteController.text.trim();

                                // Upload screenshot to Cloudinary
                                File pickedFile = proofImage!;
                                String? url = await CloudinaryService.uploadFile(file: pickedFile, folder: 'match_proofs');
                                if (url == null) {
                                  if (mounted) {
                                    setModalState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Screenshot upload failed. Please try again.'),
                                        backgroundColor: GamerTheme.redAccent,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final firestore = FirebaseFirestore.instance;
                                final proofDocRef = firestore.collection('win_proofs').doc();
                                final proofId = proofDocRef.id;

                                // 1. Save to win_proofs collection with status='pending', submittedBy=auth.uid, createdAt=serverTimestamp
                                // NEVER set status='rewarded' from app
                                await proofDocRef.set({
                                  'id': proofId,
                                  'squadId': widget.postId,
                                  'submittedBy': currentUid,
                                  'userId': currentUid,
                                  'inGameUid': characterUid,
                                  'characterUid': characterUid,
                                  'proofImageUrl': url,
                                  'proofUrl': url,
                                  'imageUrl': url,
                                  'note': note.isNotEmpty ? note : 'Match Won! Victory proof submitted.',
                                  'status': 'pending', // NEVER set status='rewarded' from app
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'senderName': senderName,
                                  'senderUsername': senderUsername,
                                  'senderAvatar': senderAvatar,
                                });

                                // Update rate limit timestamp on user profile
                                await firestore.collection('users').doc(currentUid).set({
                                  'lastWinProofAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                                // Add win proof message to squad chat
                                final chatRef = firestore.collection('chats').doc(widget.postId);
                                await chatRef.collection('messages').doc(proofId).set({
                                  'proofId': proofId,
                                  'senderId': currentUid,
                                  'senderUid': currentUid,
                                  'senderName': senderName,
                                  'senderUsername': senderUsername,
                                  'senderAvatar': senderAvatar,
                                  'type': 'win_proof',
                                  'status': 'pending', // Shows "PENDING APPROVAL"
                                  'submittedBy': currentUid,
                                  'inGameUid': characterUid,
                                  'characterUid': characterUid,
                                  'proofImageUrl': url,
                                  'proofUrl': url,
                                  'imageUrl': url,
                                  'text': note.isNotEmpty ? note : 'Match Won! Victory proof submitted.',
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                                await chatRef.set({
                                  'lastMessage': '$senderName submitted Win Proof 🏆',
                                  'lastMessageTime': FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('🏆 Win proof submit ho gaya! Host approval ka intezar karen.'),
                                      backgroundColor: GamerTheme.accentBlue,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                  Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
                                }
                              } catch (e) {
                                debugPrint('Error submitting win proof: $e');
                                if (mounted) {
                                  setModalState(() => isSubmitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Submission failed: $e'),
                                      backgroundColor: GamerTheme.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Handles "Reject" on win_proof message card (Host only)
  Future<void> _handleRejectWinProof({
    required BuildContext context,
    required String messageDocId,
    required String winnerTag,
    required String squadId,
  }) async {
    final cleanTag = winnerTag.trim().startsWith('@')
        ? winnerTag.trim().substring(1)
        : winnerTag.trim();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: GamerTheme.redAccent.withOpacity(0.5)),
        ),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: GamerTheme.redAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Reject Win Proof',
              style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Kya aap @$cleanTag ka win proof reject karna chahte hain?',
          style: const TextStyle(color: GamerTheme.textWhite, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('HAAN, REJECT', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? GamerAuthService().currentUid ?? '';
    final firestore = FirebaseFirestore.instance;
    final messageRef = firestore.collection('chats').doc(squadId).collection('messages').doc(messageDocId);
    final proofRef = firestore.collection('win_proofs').doc(messageDocId);

    try {
      final batch = firestore.batch();
      batch.update(messageRef, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': currentUid,
      });
      batch.set(proofRef, {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': currentUid,
      }, SetOptions(merge: true));
      await batch.commit();

      // System notification message in squad chat
      await firestore.collection('chats').doc(squadId).collection('messages').add({
        'senderId': 'system',
        'senderUid': 'system',
        'senderName': 'System',
        'text': 'Host rejected win proof submitted by @$cleanTag',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Win proof from @$cleanTag was rejected.'),
            backgroundColor: GamerTheme.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[RejectProof] Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Handles "Reward 100 Coins" on win_proof message card (Host only)
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

    // Show confirm dialog "100 Coins dena hai @fua ko?"
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
      // Run Firestore transaction to deduct coins from host and add 100 to winner via FieldValue.increment
      await firestore.runTransaction((transaction) async {
        final hostDoc = await transaction.get(hostRef);
        final hostData = hostDoc.data() ?? {};
        final int hostCoins = (hostData['coins'] as num?)?.toInt() ?? 100;

        if (hostCoins < 100) {
          throw 'Not enough coins';
        }

        // Deduct 100 from host, increment 100 for winner using FieldValue.increment
        transaction.update(hostRef, {
          'coins': FieldValue.increment(-100),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(winnerRef, {
          'coins': FieldValue.increment(100),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create doc in 'coin_transactions' collection
        final txRef = firestore.collection('coin_transactions').doc();
        transaction.set(txRef, {
          'from': hostId,
          'to': winnerId,
          'amount': 100,
          'squadId': squadId,
          'type': 'win_reward',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update win_proof message status to 'rewarded'
        transaction.update(messageRef, {
          'status': 'rewarded',
          'rewardedAt': FieldValue.serverTimestamp(),
          'rewardedBy': hostId,
        });

        // Also update win_proofs collection
        final winProofRef = firestore.collection('win_proofs').doc(messageDocId);
        transaction.set(winProofRef, {
          'status': 'rewarded',
          'rewardedAt': FieldValue.serverTimestamp(),
          'rewardedBy': hostId,
        }, SetOptions(merge: true));
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
        'text': 'Host rewarded 100 coins to @$cleanTag 🏆',
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

  /// Opens full screen proof image with InteractiveViewer pinch-to-zoom and close button
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: imageUrl.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(imageUrl.split(',').last),
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(color: GamerTheme.neonGreen),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
                            ),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(dialogContext).padding.top + 10,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the Win Proof message card
  Widget _buildWinProofCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String messageDocId,
    required bool isOwner,
    required String currentUid,
  }) {
    final senderUid = (data['senderId'] ?? data['senderUid'] ?? data['submittedBy']) as String? ?? '';
    final senderName = data['senderName'] as String? ?? 'Gamer';
    final senderUsername = (data['senderUsername'] ?? data['username'] ?? data['senderTag'] ?? data['tag'] ?? senderName).toString().trim();
    final senderAvatar = data['senderAvatar'] as String? ?? '';
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final inGameUid = (data['inGameUid'] ?? data['characterUid'] ?? data['bgmiUid'] ?? data['gameId'] ?? '').toString();
    final proofUrl = (data['proofImageUrl'] ?? data['proofUrl'] ?? data['imageUrl'] ?? '').toString();
    final text = (data['text'] ?? data['note'] as String? ?? '').trim();
    final isPending = status == 'pending';
    final isRewarded = status == 'rewarded';
    final isRejected = status == 'rejected';

    final cleanTag = senderUsername.startsWith('@') ? senderUsername.substring(1) : senderUsername;

    final Color statusColor = isRewarded
        ? GamerTheme.neonGreen
        : (isRejected ? GamerTheme.redAccent : const Color(0xFFFFD700));

    final String statusLabel = isRewarded
        ? 'REWARDED'
        : (isRejected ? 'REJECTED' : 'PENDING APPROVAL');

    final IconData statusIcon = isRewarded
        ? Icons.check_circle_rounded
        : (isRejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded);

    final String statusSubtitle = isRewarded
        ? 'REWARDED • 100 G-Coins Paid'
        : (isRejected ? 'REJECTED • Proof Not Approved' : 'PENDING APPROVAL • Awaiting Host');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161C26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.12),
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
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 20,
                  color: statusColor,
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
                      statusSubtitle,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
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
                        'Character UID: ${inGameUid.isNotEmpty ? inGameUid : (senderUid.isNotEmpty ? senderUid : "Verified Profile UID")}',
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
            GestureDetector(
              onTap: () => _showFullScreenImage(context, proofUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: proofUrl.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(proofUrl.split(',').last),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      )
                    : Image.network(
                        proofUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
              ),
            ),
          ],

          // Only Squad Host can see Approve/Reject buttons when status is Pending
          if (isOwner && isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // COPY UID button
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GamerTheme.neonGreen,
                      side: const BorderSide(color: GamerTheme.neonGreen, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 13),
                    label: const Text(
                      'COPY UID',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      final uidToCopy = inGameUid.isNotEmpty ? inGameUid : senderUid;
                      _copyToClipboard(uidToCopy, 'Winner UID');
                    },
                  ),
                ),
                const SizedBox(width: 6),
                // REJECT button
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GamerTheme.redAccent,
                      side: const BorderSide(color: GamerTheme.redAccent, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text(
                      'REJECT',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _handleRejectWinProof(
                      context: context,
                      messageDocId: messageDocId,
                      winnerTag: cleanTag,
                      squadId: widget.postId,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // APPROVE button
                Expanded(
                  flex: 4,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Text('🪙', style: TextStyle(fontSize: 13)),
                    label: const Text(
                      'APPROVE',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11.5,
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
