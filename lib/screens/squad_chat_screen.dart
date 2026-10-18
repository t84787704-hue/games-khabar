// ═══════════════════════════════════════════════════════════════════════════════
// SQUAD CHAT SCREEN — Fully Fixed Chat Input & Localized
// ═══════════════════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../services/supabase_service.dart';
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

  Stream<Map<String, dynamic>?> _chatStream() async* {
    while (true) {
      Map<String, dynamic>? data;
      try {
        data = await SupabaseService.client
            .from('chats')
            .select()
            .eq('id', widget.postId)
            .maybeSingle();
        if (data == null) {
          data = await SupabaseService.client
              .from('chats')
              .select()
              .eq('postId', widget.postId)
              .maybeSingle();
        }
      } catch (_) {}
      yield data;
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Stream<List<Map<String, dynamic>>> _messagesStream() async* {
    while (true) {
      List<Map<String, dynamic>> list = [];
      try {
        final res = await SupabaseService.client
            .from('messages')
            .select()
            .or('chatId.eq.${widget.postId},squadId.eq.${widget.postId}')
            .order('createdAt', ascending: true);
        list = List<Map<String, dynamic>>.from(res);
      } catch (_) {}
      yield list;
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<void> _ensureChatDocExists() async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      Map<String, dynamic>? postData;
      try {
        postData = await SupabaseService.client
            .from('lfg_posts')
            .select()
            .eq('id', widget.postId)
            .maybeSingle();
      } catch (_) {}
      if (postData == null) {
        try {
          postData = await SupabaseService.client
              .from('squads')
              .select()
              .eq('id', widget.postId)
              .maybeSingle();
        } catch (_) {}
      }

      final currentUid = GamerAuthService().currentUid ?? '';
      final currentEmail = GamerAuthService().currentUser?.email ?? '';

      List<String> members = [];
      String title = 'اسکواڈ چیٹ';
      String mode = 'کلاسک اسکواڈ';
      String inGameUid = '';
      String leaderUid = '';

      if (postData != null) {
        leaderUid = (postData['hostId'] ?? postData['ownerId'] ?? postData['userId'] ?? '').toString();
        final rawMembers = List<dynamic>.from(postData['members'] ?? []);
        members = rawMembers.map((e) => e.toString()).toList();
        if (leaderUid.isNotEmpty && !members.contains(leaderUid)) {
          members.insert(0, leaderUid);
        }
        title = postData['ownerBgmiName'] ?? postData['displayName'] ?? postData['title'] ?? 'اسکواڈ چیٹ';
        mode = postData['mode'] ?? 'کلاسک اسکواڈ';
        inGameUid = (postData['gameUid'] ?? postData['inGameUid'] ?? postData['bgmiUid'] ?? '').toString();
      } else if (widget.squad != null) {
        leaderUid = widget.squad!.userId;
        members = List<String>.from(widget.squad!.members);
        title = widget.squad!.title;
        mode = widget.squad!.mode;
        inGameUid = widget.squad!.inGameUid;
      }

      if (currentUid.isNotEmpty && !members.contains(currentUid) && leaderUid.isEmpty) {
        members.add(currentUid);
      }

      final squadData = {
        'id': widget.postId,
        'postId': widget.postId,
        'squadId': widget.postId,
        'ownerId': leaderUid,
        'hostId': leaderUid,
        'userId': leaderUid,
        'leaderUid': leaderUid,
        'ownerEmail': currentEmail,
        'hostEmail': currentEmail,
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
        'updatedAt': nowIso,
      };

      await SupabaseService.client.from('squads').upsert(squadData).catchError((_) => null);
      await SupabaseService.client.from('lfg_posts').upsert(squadData).catchError((_) => null);

      await SupabaseService.client.from('chats').upsert({
        'id': widget.postId,
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
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'isActive': true,
      }).catchError((_) => null);
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
        content: Text('$label کلپ بورڈ پر کاپی ہو گیا!'),
        backgroundColor: GamerTheme.neonGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleLeaveSquad(String leaderUid, List<String> members) async {
    final currentUid = GamerAuthService().currentUid ?? "";
    if (currentUid.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GamerTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('اسکواڈ چھوڑیں؟', style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold)),
        content: const Text(
          'کیا آپ واقعی یہ اسکواڈ چھوڑنا چاہتے ہیں؟ آپ چیٹ سے ہٹ جائیں گے۔',
          style: TextStyle(color: GamerTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('منسوخ', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('چھوڑ دیں', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLeaving = true);
    try {
      final user = await GamerAuthService().getUserProfile(currentUid);
      final memberName = user?.displayName ?? 'ٹیم کا ساتھی';
      await LfgService().leaveSquad(
        postId: widget.postId,
        memberUid: currentUid,
        leaderUid: leaderUid,
        memberName: memberName,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('آپ اسکواڈ سے نکل گئے ہیں'),
            backgroundColor: GamerTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('چھوڑنے میں ناکامی: $e'), backgroundColor: Colors.redAccent),
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
        title: const Text('اسکواڈ ختم کریں؟', style: TextStyle(color: GamerTheme.textWhite, fontWeight: FontWeight.bold)),
        content: const Text(
          'کیا آپ واقعی اسکواڈ ختم کرنا چاہتے ہیں؟ یہ مستقل طور پر بند ہو جائے گا۔',
          style: TextStyle(color: GamerTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('منسوخ', style: TextStyle(color: GamerTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('اسکواڈ ختم کریں', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            content: Text('اسکواڈ ختم کر دیا گیا'),
            backgroundColor: GamerTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('اسکواڈ ختم کرنے میں ناکامی: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUid = GamerAuthService().currentUid;
    if (currentUid == null || currentUid.isEmpty) return;

    _textController.clear();
    setState(() => _isSending = true);

    try {
      final user = await GamerAuthService().getUserProfile(currentUid);
      final senderName = user?.displayName.isNotEmpty == true
          ? user!.displayName
          : "Gamer";
      final senderUsername = user?.username.isNotEmpty == true
          ? user!.username
          : senderName.toLowerCase().replaceAll(' ', '');
      final senderAvatar = user?.photoUrl ?? "";

      final nowIso = DateTime.now().toIso8601String();
      final msgId = SupabaseService.toUuid('${DateTime.now().millisecondsSinceEpoch}_$currentUid');

      await SupabaseService.client.from('messages').insert({
        'id': msgId,
        'chatId': widget.postId,
        'squadId': widget.postId,
        'senderId': currentUid,
        'senderUid': currentUid,
        'senderName': senderName,
        'senderUsername': senderUsername,
        'senderAvatar': senderAvatar,
        'senderFrame': user?.activeFrame ?? '',
        'senderBadge': user?.activeBadge ?? '',
        'senderChatColor': user?.chatColor ?? '',
        'text': text,
        'type': 'text',
        'createdAt': nowIso,
      }).catchError((_) => null);

      await SupabaseService.client.from('chats').upsert({
        'id': widget.postId,
        'postId': widget.postId,
        'lastMessage': '$senderName:$text',
        'lastMessageTime': nowIso,
        'updatedAt': nowIso,
      }).catchError((_) => null);
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('بھیجنے میں ناکامی: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openSubmitWinProofSheet() async {
    final currentUid = GamerAuthService().currentUid ?? '';
    if (currentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جیت کا ثبوت دینے کے لیے پہلے لاگ ان کریں۔'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }

    final userData = await SupabaseService.getUser(currentUid) ?? {};
    final characterUid = (userData['bgmiUid'] ?? userData['gameId'] ?? userData['inGameId'] ?? userData['gameUid'] ?? '').toString().trim();

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
              Expanded(
                child: Text(
                  'کریکٹر آئی ڈی موجود نہیں',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'ثبوت جمع کرانے سے پہلے اپنی پروفائل میں کریکٹر آئی ڈی (گیم UID) ایڈ کریں۔',
            style: TextStyle(color: GamerTheme.textMuted, fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ٹھیک ہے', style: TextStyle(color: GamerTheme.accentCyan)),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    File? proofImage;
    bool isSubmitting = false;
    final noteController = TextEditingController(text: 'میچ جیت گئے! فتح کا ثبوت پیش کر دیا گیا۔');

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
                              'جیت کا ثبوت جمع کریں 🏆',
                              style: TextStyle(color: GamerTheme.textWhite, fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'ہوسٹ کی منظوری درکار ہے • 100 کوائنز انعام',
                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  const Row(
                    children: [
                      Text(
                        'کریکٹر UID',
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.lock_rounded, size: 12, color: GamerTheme.neonGreen),
                      SizedBox(width: 4),
                      Text(
                        '(پروفائل سے تصدیق شدہ)',
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
                          'صرف پڑھنے کے لیے',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Row(
                    children: [
                      Text(
                        'فتح کا اسکرین شاٹ',
                        style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GamerTheme.redAccent,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                        child: Text(
                          'لازمی',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
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
                                  'اسکرین شاٹ اپلوڈ کرنے کے لیے ٹیپ کریں',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'چکن ڈنر / رزلٹ اسکرین (لازمی)',
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
                                        'اسکرین شاٹ منسلک ہو گیا',
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
                    'جیت کی تفصیلات / نوٹ',
                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: GamerTheme.textWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'چکن ڈنر / میچ جیت گئے',
                      hintStyle: const TextStyle(color: GamerTheme.textMuted),
                      filled: true,
                      fillColor: GamerTheme.bgDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                    ),
                  ),
                  const SizedBox(height: 22),

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
                            ? 'ثبوت جمع ہو رہا ہے...'
                            : (proofImage == null ? 'اسکرین شاٹ منسلک کریں' : 'جیت کا ثبوت بھیجیں'),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      onPressed: (isSubmitting || proofImage == null)
                          ? null
                          : () async {
                              setModalState(() => isSubmitting = true);

                              try {
                                final user = await GamerAuthService().getUserProfile(currentUid);
                                final senderName = user?.displayName ?? 'ٹیم کا ساتھی';
                                final senderUsername = user?.username ?? 'gamer';
                                final senderAvatar = user?.photoUrl ?? '';
                                final note = noteController.text.trim();

                                File pickedFile = proofImage!;
                                String? url = await SupabaseService.uploadFile(
                                  file: pickedFile,
                                  folder: 'match_proofs',
                                  bucket: SupabaseService.bucketMatchProofs,
                                );
                                if (url == null) {
                                  if (mounted) {
                                    setModalState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('اسکرین شاٹ اپلوڈ نہ ہو سکا۔ دوبارہ کوشش کریں۔'),
                                        backgroundColor: GamerTheme.redAccent,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                final proofId = SupabaseService.toUuid('${DateTime.now().millisecondsSinceEpoch}_$currentUid');
                                final nowIso = DateTime.now().toIso8601String();

                                await SupabaseService.client.from('win_proofs').insert({
                                  'id': proofId,
                                  'squadId': widget.postId,
                                  'submittedBy': currentUid,
                                  'userId': currentUid,
                                  'inGameUid': characterUid,
                                  'characterUid': characterUid,
                                  'proofImageUrl': url,
                                  'proofUrl': url,
                                  'imageUrl': url,
                                  'note': note.isNotEmpty ? note : 'میچ جیت گئے!',
                                  'status': 'pending',
                                  'createdAt': nowIso,
                                  'senderName': senderName,
                                  'senderUsername': senderUsername,
                                  'senderAvatar': senderAvatar,
                                }).catchError((_) => null);

                                await SupabaseService.client.from('users').update({
                                  'lastWinProofAt': nowIso,
                                }).or('id.eq.$currentUid,uid.eq.$currentUid').catchError((_) => null);

                                await SupabaseService.client.from('messages').insert({
                                  'id': proofId,
                                  'chatId': widget.postId,
                                  'squadId': widget.postId,
                                  'senderId': currentUid,
                                  'senderUid': currentUid,
                                  'senderName': senderName,
                                  'senderUsername': senderUsername,
                                  'senderAvatar': senderAvatar,
                                  'type':
