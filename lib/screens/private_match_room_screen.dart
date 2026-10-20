import "dart:io";
import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:image_picker/image_picker.dart";
import "package:intl/intl.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:cached_network_image/cached_network_image.dart";
import "package:easy_localization/easy_localization.dart";
import "../services/supabase_service.dart";
import "../models/team_model.dart";
import "../services/team_service.dart";
import "../widgets/end_match_dialog.dart";

class PrivateMatchRoomScreen extends StatefulWidget {
  final String matchId;
  final String myTeamId;
  final String myTeamName;
  final String opponentId;
  final String opponentName;

  const PrivateMatchRoomScreen({
    super.key,
    required this.matchId,
    required this.myTeamId,
    required this.myTeamName,
    required this.opponentId,
    required this.opponentName,
  });

  @override
  State<PrivateMatchRoomScreen> createState() => _PrivateMatchRoomScreenState();
}

class _PrivateMatchRoomScreenState extends State<PrivateMatchRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _showScrollDownButton = false;
  int _newMessagesCountWhileScrolled = 0;
  String _myTeamName = '';
  String _opponentName = '';
  List<Map<String, dynamic>> _messages = [];
  Timer? _pollTimer;
  StreamSubscription? _streamSub;
  StreamSubscription? _roomInfoSub;

  Map<String, dynamic>? _roomInfo;
  bool _isRoomInfoLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _myTeamName = widget.myTeamName.isNotEmpty ? widget.myTeamName : 'my_team_fallback'.tr();
    _opponentName = widget.opponentName.isNotEmpty ? widget.opponentName : 'opponent_team_fallback'.tr();

    if (widget.matchId.trim().isEmpty) {
      _isLoading = false;
      _isRoomInfoLoading = false;
      _errorMessage = 'match_not_found_title'.tr();
      return;
    }

    _resolveTeamNames();
    _markAsRead();
    _fetchMessages(initial: true);
    _subscribeToStream();
    _subscribeToRoomInfo();

    _scrollController.addListener(_onScroll);

    Timer(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _fetchMessages(silent: true);
    });
  }

  void _subscribeToRoomInfo() {
    final cleanId = widget.matchId.trim();
    if (cleanId.isEmpty) {
      if (mounted) setState(() => _isRoomInfoLoading = false);
      return;
    }
    try {
      _roomInfoSub = SupabaseService.client
          .from('match_room_info')
          .stream(primaryKey: ['id'])
          .eq('match_id', cleanId)
          .listen(
        (data) {
          if (!mounted) return;
          final newRoomInfo = (data.isNotEmpty) ? data.first : null;

          final oldId = _roomInfo?['id']?.toString() ?? '';
          final newId = newRoomInfo?['id']?.toString() ?? '';
          final oldUpdated = _roomInfo?['updated_at']?.toString() ?? '';
          final newUpdated = newRoomInfo?['updated_at']?.toString() ?? '';

          if (oldId == newId &&
              oldUpdated == newUpdated &&
              _roomInfo != null &&
              newRoomInfo != null) {
            return;
          }

          if (_roomInfo == null && newRoomInfo == null) {
            if (_isRoomInfoLoading) {
              setState(() => _isRoomInfoLoading = false);
            }
            return;
          }

          setState(() {
            _roomInfo = newRoomInfo;
            _isRoomInfoLoading = false;
          });
        },
        onError: (err) {
          debugPrint("[PrivateMatchRoom] room info stream error: $err");
          if (mounted && _isRoomInfoLoading) {
            setState(() => _isRoomInfoLoading = false);
          }
        },
      );
    } catch (e) {
      debugPrint("[PrivateMatchRoom] room info subscribe error: $e");
      if (mounted) setState(() => _isRoomInfoLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final isNearBottom =
          _scrollController.position.maxScrollExtent - _scrollController.offset < 120;
      if (isNearBottom && _showScrollDownButton) {
        setState(() {
          _showScrollDownButton = false;
          _newMessagesCountWhileScrolled = 0;
        });
      } else if (!isNearBottom && !_showScrollDownButton) {
        setState(() => _showScrollDownButton = true);
      }
    }
  }

  Future<void> _markAsRead() async {
    final cleanId = widget.matchId.trim();
    if (cleanId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          "last_read_match_$cleanId", DateTime.now().toUtc().toIso8601String());
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _streamSub?.cancel();
    _roomInfoSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveTeamNames() async {
    final teamService = TeamService();
    if ((_myTeamName == 'my_team_fallback'.tr() || _myTeamName.isEmpty) &&
        widget.myTeamId.isNotEmpty) {
      final t = await teamService.getTeam(widget.myTeamId);
      if (t != null && mounted) setState(() => _myTeamName = t.name);
    }
    if ((_opponentName == 'opponent_team_fallback'.tr() || _opponentName.isEmpty) &&
        widget.opponentId.isNotEmpty) {
      final t = await teamService.getTeam(widget.opponentId);
      if (t != null && mounted) setState(() => _opponentName = t.name);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _subscribeToStream() {
    final cleanId = widget.matchId.trim();
    if (cleanId.isEmpty) return;
    try {
      _streamSub = SupabaseService.client
          .from("match_messages")
          .stream(primaryKey: ["id"])
          .eq("match_id", cleanId)
          .listen(
        (data) {
          if (mounted && data.isNotEmpty) {
            _mergeMessages(data);
          }
        },
        onError: (err) {
          debugPrint("[PrivateMatchRoom] stream error: $err");
        },
      );
    } catch (e) {
      debugPrint("[PrivateMatchRoom] stream subscribe exception: $e");
    }
  }

  Future<void> _fetchMessages(
      {bool silent = false, bool initial = false}) async {
    final cleanId = widget.matchId.trim();
    if (cleanId.isEmpty) {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'match_not_found_title'.tr();
        });
      }
      return;
    }

    try {
      final res = await SupabaseService.client
          .from("match_messages")
          .select()
          .eq("match_id", cleanId)
          .order("created_at", ascending: true);

      if (res is List && mounted) {
        final list = List<Map<String, dynamic>>.from(res);
        _errorMessage = null;
        _mergeMessages(list, shouldScrollToBottom: initial);
      }
    } catch (e) {
      debugPrint("[PrivateMatchRoom] fetch error: $e");
      if (mounted && _messages.isEmpty) {
        setState(() {
          _errorMessage = 'failed_load_messages'.tr();
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mergeMessages(List<Map<String, dynamic>> incoming,
      {bool shouldScrollToBottom = false}) {
    final map = <String, Map<String, dynamic>>{};

    for (final m in _messages) {
      final id = m["id"]?.toString() ?? "";
      if (id.startsWith("temp_")) {
        map[id] = m;
      }
    }

    for (final m in incoming) {
      final id = m["id"]?.toString() ?? "";
      if (id.isNotEmpty) {
        map.removeWhere((k, v) =>
            k.startsWith("temp_") &&
            (v["message"] == m["message"] ||
                (v["_local_path"] != null && m["message_type"] == "image")));
        map[id] = m;
      }
    }

    final combined = map.values.toList();
    combined.sort((a, b) => (a["created_at"] ?? "")
        .toString()
        .compareTo((b["created_at"] ?? "").toString()));

    final bool countChanged = combined.length != _messages.length;
    final bool contentChanged = !_areListsEqual(_messages, combined);

    if (countChanged || contentChanged) {
      final myTeamUuid =
          SupabaseService.toUuid(widget.myTeamId).toLowerCase();
      final myTeamRaw = widget.myTeamId.toLowerCase();

      if (combined.length > _messages.length && _messages.isNotEmpty) {
        final newLast = combined.last;
        final sender =
            (newLast["sender_team_id"] ?? "").toString().toLowerCase();
        final isFromOpponent = sender != myTeamUuid && sender != myTeamRaw;
        if (isFromOpponent && _showScrollDownButton) {
          _newMessagesCountWhileScrolled +=
              (combined.length - _messages.length);
        }
      }

      setState(() {
        _messages = combined;
        _isLoading = false;
      });

      _markAsRead();

      if (shouldScrollToBottom || (countChanged && !_showScrollDownButton)) {
        _scrollToBottom();
      }
    } else if (_isLoading) {
      setState(() => _isLoading = false);
    }
  }

  bool _areListsEqual(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i]["id"] != b[i]["id"] || a[i]["message"] != b[i]["message"]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final cleanId = widget.matchId.trim();
    final myUuid = SupabaseService.toUuid(widget.myTeamId).toLowerCase();
    final isUidShare = msg.contains("ROOM UID");

    final tempId = "temp_${DateTime.now().millisecondsSinceEpoch}";
    final optimisticMsg = {
      "id": tempId,
      "match_id": cleanId,
      "sender_team_id": myUuid,
      "sender_team_name":
          _myTeamName.isNotEmpty ? _myTeamName : widget.myTeamName,
      "message": msg,
      "message_type": isUidShare ? "uid_share" : "text",
      "created_at": DateTime.now().toUtc().toIso8601String(),
      "_is_pending": true,
    };

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();

    final payload = {
      "match_id": cleanId,
      "sender_team_id": myUuid,
      "message": msg,
      "message_type": isUidShare ? "uid_share" : "text",
      "created_at": DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final res = await SupabaseService.client
          .from("match_messages")
          .insert(payload)
          .select()
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m["id"] == tempId);
          if (idx != -1) {
            _messages[idx] = Map<String, dynamic>.from(res);
          }
        });
      }
      _fetchMessages(silent: true);
      _scrollToBottom();
    } catch (e) {
      debugPrint("[PrivateMatchRoom] Error inserting message: $e");
      try {
        final fallbackRes = await SupabaseService.client
            .from("match_messages")
            .insert({
              "match_id": cleanId,
              "sender_team_id": myUuid,
              "message": msg,
              "created_at": DateTime.now().toUtc().toIso8601String(),
            })
            .select()
            .maybeSingle();

        if (fallbackRes != null && mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m["id"] == tempId);
            if (idx != -1) {
              _messages[idx] = Map<String, dynamic>.from(fallbackRes);
            }
          });
        }
        _fetchMessages(silent: true);
        _scrollToBottom();
      } catch (err2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('msg_send_error'.tr(args: [err2.toString()])),
                backgroundColor: const Color(0xFFFF4655)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final file = File(picked.path);
      if (!await file.exists()) return;

      final cleanId = widget.matchId.trim();
      final myUuid = SupabaseService.toUuid(widget.myTeamId).toLowerCase();
      final tempId = "temp_${DateTime.now().millisecondsSinceEpoch}";

      final optimistic = {
        "id": tempId,
        "match_id": cleanId,
        "sender_team_id": myUuid,
        "sender_team_name":
            _myTeamName.isNotEmpty ? _myTeamName : widget.myTeamName,
        "message": file.path,
        "message_type": "image",
        "created_at": DateTime.now().toUtc().toIso8601String(),
        "_is_pending": true,
        "_local_path": file.path,
      };

      setState(() {
        _messages.add(optimistic);
        _isUploadingImage = true;
      });
      _scrollToBottom();

      final publicUrl = await SupabaseService.uploadFile(
        file: file,
        bucket: "match_proofs",
        folder: "match_chat",
      );

      if (publicUrl == null || publicUrl.isEmpty) {
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m["id"] == tempId);
            _isUploadingImage = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('img_upload_failed'.tr()),
                backgroundColor: const Color(0xFFFF4655)),
          );
        }
        return;
      }

      final payload = {
        "match_id": cleanId,
        "sender_team_id": myUuid,
        "message": publicUrl,
        "message_type": "image",
        "created_at": DateTime.now().toUtc().toIso8601String(),
      };

      final res = await SupabaseService.client
          .from("match_messages")
          .insert(payload)
          .select()
          .maybeSingle();

      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m["id"] == tempId);
          if (idx != -1) {
            _messages[idx] = res != null
                ? Map<String, dynamic>.from(res)
                : {
                    ...optimistic,
                    "message": publicUrl,
                    "_is_pending": false,
                  };
          }
          _isUploadingImage = false;
        });
        _fetchMessages(silent: true);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("[PrivateMatchRoom] Error picking/uploading image: $e");
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('photo_send_error'.tr(args: [e.toString()])),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A29),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFF2A3447),
                    borderRadius: BorderRadius.circular(2)),
              ),
              Text('send_screenshot_photo_title'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFF1877F2),
                    label: 'gallery_label'.tr(),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFF00FF88),
                    label: 'camera_label'.tr(),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption(
      {required IconData icon,
      required Color color,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0E16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A3447)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(String id) async {
    if (id.isEmpty) return;
    setState(() {
      _messages.removeWhere((m) => m["id"]?.toString() == id);
    });
    try {
      await SupabaseService.client.from("match_messages").delete().eq("id", id);
      _fetchMessages(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('msg_deleted_success'.tr()),
              duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint("[PrivateMatchRoom] Error deleting msg: $e");
    }
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded,
                color: Color(0xFFFF4655), size: 22),
            const SizedBox(width: 8),
            Text('clear_chat_title'.tr(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        content: Text(
          'clear_chat_confirm_desc'.tr(),
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('btn_cancel'.tr(),
                style: const TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final cleanId = widget.matchId.trim();
              setState(() {
                _messages.clear();
              });
              try {
                await SupabaseService.client
                    .from("match_messages")
                    .delete()
                    .eq("match_id", cleanId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('chat_cleared_success'.tr()),
                        backgroundColor: const Color(0xFF2E7D32)),
                  );
                }
              } catch (e) {
                debugPrint("[PrivateMatchRoom] Error clearing chat: $e");
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4655),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text('clear_chat_btn'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg, bool isMyTeam) {
    final msgText = msg["message"]?.toString() ?? "";
    final msgId = msg["id"]?.toString() ?? "";
    final isImage =
        msg["message_type"] == "image" || msg["_local_path"] != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131A29),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFF2A3447),
                  borderRadius: BorderRadius.circular(2)),
            ),
            if (!isImage)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                title: Text('copy_text_label'.tr(),
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msgText));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('text_copied'.tr()),
                      duration: const Duration(seconds: 1)));
                },
              ),
            if (isMyTeam) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFFF4655)),
                title: Text('delete_msg_label'.tr(),
                    style: const TextStyle(
                        color: Color(0xFFFF4655),
                        fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msgId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullScreenImageDialog(BuildContext context, String imageUrl,
      {String? localPath}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.95),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: localPath != null && File(localPath).existsSync()
                    ? Image.file(File(localPath))
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF1877F2))),
                        errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 60),
                      ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) return 'today_label'.tr();
    if (msgDate == yesterday) return 'yesterday_label'.tr();
    return DateFormat("dd MMMM, yyyy").format(dt);
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat("hh:mm a").format(dt);
    } catch (_) {
      return "";
    }
  }

  Future<void> _saveRoomInfo(String roomId, String password) async {
    try {
      final cleanId = widget.matchId.trim();
      final myTeamUuid = SupabaseService.toUuid(widget.myTeamId);
      final myUid = SupabaseService.client.auth.currentUser?.id;

      if (myUid == null || myUid.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('login_required_error'.tr()),
              backgroundColor: const Color(0xFFFF4655)));
        }
        return;
      }

      final payload = {
        'match_id': cleanId,
        'team_id': myTeamUuid,
        'room_id': roomId,
        'room_password': password,
        'shared_by_uid': myUid,
        'shared_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await SupabaseService.client
          .from('match_room_info')
          .upsert(payload, onConflict: 'match_id,team_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('room_info_saved'.tr()),
              backgroundColor: const Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      debugPrint("[PrivateMatchRoom] Save room info error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('room_info_save_failed'.tr(args: [e.toString()])),
              backgroundColor: const Color(0xFFFF4655)),
        );
      }
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'just_now_label'.tr();
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just_now_label'.tr();
      if (diff.inMinutes < 60) return 'min_ago_label'.tr(args: [diff.inMinutes.toString()]);
      if (diff.inHours < 24) return 'hr_ago_label'.tr(args: [diff.inHours.toString()]);
      if (diff.inDays < 7) {
        return 'days_ago_label'.tr(args: [diff.inDays.toString()]);
      }
      return DateFormat("dd MMM, hh:mm a").format(dt);
    } catch (_) {
      return 'just_now_label'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.matchId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0E16),
        appBar: AppBar(
          backgroundColor: const Color(0xFF131A29),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('team_dm_button'.tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFFF4655)),
                const SizedBox(height: 12),
                Text(
                  'match_not_found_title'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'match_not_found_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                  onPressed: () => Navigator.pop(context),
                  child: Text('go_back_btn'.tr(), style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final title = "$_myTeamName VS $_opponentName - ${'private_room_title'.tr()}";
    final myTeamUuid = SupabaseService.toUuid(widget.myTeamId).toLowerCase();
    final myTeamRaw = widget.myTeamId.toLowerCase();
    final oppUuid = SupabaseService.toUuid(widget.opponentId).toLowerCase();
    final oppRaw = widget.opponentId.toLowerCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131A29),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('private_room_header_subtitle'.tr(),
                style: const TextStyle(
                    color: Color(0xFFFFD600),
                    fontWeight: FontWeight.w600,
                    fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white70, size: 20),
            tooltip: 'refresh_chat_menu'.tr(),
            onPressed: () => _fetchMessages(silent: false),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: Colors.white70, size: 20),
            color: const Color(0xFF131A29),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == "clear") {
                _confirmClearChat();
              } else if (val == "refresh") {
                _fetchMessages(silent: false);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: "refresh",
                child: Row(
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text('refresh_chat_menu'.tr(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "clear",
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_rounded,
                        color: Color(0xFFFF4655), size: 18),
                    const SizedBox(width: 8),
                    Text('clear_chat_title'.tr(),
                        style: const TextStyle(
                            color: Color(0xFFFF4655),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Top info banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF131A29),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: Color(0xFFFFD600), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'private_chat_disclaimer'.tr(),
                          style: const TextStyle(
                              color: Color(0xFF8B949E), fontSize: 11)),
                    ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: _isLoading && _messages.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF1877F2)))
                    : _errorMessage != null && _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.cloud_off_rounded, size: 44, color: Color(0xFFFFB020)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2)),
                                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                                    label: Text('btn_retry'.tr(), style: const TextStyle(color: Colors.white)),
                                    onPressed: () {
                                      setState(() {
                                        _isLoading = true;
                                        _errorMessage = null;
                                      });
                                      _fetchMessages(initial: true);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                        onRefresh: () => _fetchMessages(silent: false),
                        color: const Color(0xFF1877F2),
                        backgroundColor: const Color(0xFF131A29),
                        child: _messages.isEmpty
                            ? ListView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                      height: MediaQuery.of(context)
                                              .size
                                              .height *
                                          0.15),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                color: const Color(
                                                    0xFF131A29),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFF2A3447))),
                                            child: const Icon(
                                                Icons
                                                    .chat_bubble_outline_rounded,
                                                color:
                                                    Color(0xFF8B949E),
                                                size: 36),
                                          ),
                                          const SizedBox(height: 12),
                                          Text('no_messages_yet_title'.tr(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Text(
                                              'no_messages_yet_desc'.tr(),
                                              textAlign:
                                                  TextAlign.center,
                                              style: const TextStyle(
                                                  color:
                                                      Color(0xFF8B949E),
                                                  fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                    16, 12, 16, 16),
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final m = _messages[index];
                                  final msgText =
                                      m["message"]?.toString() ?? "";
                                  final senderTeamId =
                                      (m["sender_team_id"] ?? "")
                                          .toString()
                                          .toLowerCase();
                                  final isMyTeam = (senderTeamId ==
                                          myTeamUuid ||
                                      senderTeamId == myTeamRaw);
                                  final isOppTeam = (senderTeamId ==
                                          oppUuid ||
                                      senderTeamId == oppRaw);
                                  final isPending =
                                      m["_is_pending"] == true;
                                  final isUidShare =
                                      msgText.contains("ROOM UID");
                                  final isImage = m["message_type"] ==
                                          "image" ||
                                      m["_local_path"] != null ||
                                      (msgText.startsWith("http") &&
                                          (msgText.contains(
                                                  "/match_proofs/") ||
                                              msgText.endsWith(".jpg") ||
                                              msgText.endsWith(".png") ||
                                              msgText.endsWith(".jpeg") ||
                                              msgText.endsWith(".webp")));

                                  final createdAtStr =
                                      m["created_at"]?.toString() ?? "";
                                  final msgDt =
                                      DateTime.tryParse(createdAtStr) ??
                                          DateTime.now();
                                  final timeStr = _formatTime(createdAtStr);

                                  bool showDateDivider = false;
                                  if (index == 0) {
                                    showDateDivider = true;
                                  } else {
                                    final prevCreatedAtStr =
                                        _messages[index - 1]
                                                ["created_at"]
                                            ?.toString() ??
                                            "";
                                    final prevDt =
                                        DateTime.tryParse(prevCreatedAtStr);
                                    if (prevDt == null ||
                                        prevDt.toLocal().year !=
                                            msgDt.toLocal().year ||
                                        prevDt.toLocal().month !=
                                            msgDt.toLocal().month ||
                                        prevDt.toLocal().day !=
                                            msgDt.toLocal().day) {
                                      showDateDivider = true;
                                    }
                                  }

                                  String senderTeamName =
                                      m["sender_team_name"]?.toString() ??
                                          "";
                                  if (senderTeamName.isEmpty) {
                                    if (isMyTeam) {
                                      senderTeamName =
                                          _myTeamName.isNotEmpty
                                              ? _myTeamName
                                              : widget.myTeamName;
                                    } else if (isOppTeam) {
                                      senderTeamName =
                                          _opponentName.isNotEmpty
                                              ? _opponentName
                                              : widget.opponentName;
                                    } else {
                                      senderTeamName =
                                          widget.opponentName;
                                    }
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (showDateDivider)
                                        Center(
                                          child: Container(
                                            margin: const EdgeInsets
                                                .symmetric(vertical: 14),
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 12,
                                                vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                  0xFF131A29),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      12),
                                              border: Border.all(
                                                  color: const Color(
                                                      0xFF2A3447)),
                                            ),
                                            child: Text(
                                              _formatDateDivider(
                                                  msgDt.toLocal()),
                                              style: const TextStyle(
                                                  color:
                                                      Color(0xFF8B949E),
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      GestureDetector(
                                        onLongPress: () =>
                                            _showMessageOptions(
                                                m, isMyTeam),
                                        child: isUidShare
                                            ? Container(
                                                margin: const EdgeInsets
                                                    .only(bottom: 12),
                                                padding:
                                                    const EdgeInsets.all(
                                                        12),
                                                decoration:
                                                    BoxDecoration(
                                                  color: const Color(
                                                      0xFF241D05),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(12),
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFFFD600),
                                                      width: 1.5),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                            Icons
                                                                .sports_esports_rounded,
                                                            color: Color(
                                                                0xFFFFD600),
                                                            size: 18),
                                                        const SizedBox(
                                                            width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            "ROOM UID & PASSWORD • $senderTeamName",
                                                            style: const TextStyle(
                                                                color: Color(
                                                                    0xFFFFD600),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize:
                                                                    12),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (isPending) ...[
                                                          const SizedBox(
                                                              width: 12,
                                                              height: 12,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                strokeWidth:
                                                                    1.5,
                                                                color: Color(
                                                                    0xFFFFD600),
                                                              )),
                                                        ],
                                                        IconButton(
                                                          icon: const Icon(
                                                              Icons
                                                                  .copy_rounded,
                                                              color: Color(
                                                                  0xFFFFD600),
                                                              size: 16),
                                                          onPressed: () {
                                                            Clipboard.setData(
                                                                ClipboardData(
                                                                    text:
                                                                        msgText));
                                                            ScaffoldMessenger.of(
                                                                    context)
                                                                .showSnackBar(SnackBar(
                                                                    content: Text(
                                                                        'room_uid_pass_copied'.tr()),
                                                                    backgroundColor:
                                                                        const Color(
                                                                            0xFF1877F2),
                                                                    duration: const Duration(
                                                                        seconds:
                                                                            2)));
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(
                                                        height: 6),
                                                    SelectableText(msgText,
                                                        style: const TextStyle(
                                                            color: Colors
                                                                .white,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold,
                                                            fontSize: 14,
                                                            letterSpacing:
                                                                0.5)),
                                                    const SizedBox(
                                                        height: 4),
                                                    Align(
                                                      alignment: Alignment
                                                          .centerRight,
                                                      child: Text(timeStr,
                                                          style: const TextStyle(
                                                              color: Color(
                                                                  0xFFFFD600),
                                                              fontSize:
                                                                  10)),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : isImage
                                                ? Align(
                                                    alignment: isMyTeam
                                                        ? Alignment
                                                            .centerRight
                                                        : Alignment
                                                            .centerLeft,
                                                    child: Container(
                                                      margin: const EdgeInsets
                                                          .only(bottom: 10),
                                                      constraints: BoxConstraints(
                                                          maxWidth: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.72),
                                                      padding:
                                                          const EdgeInsets
                                                              .all(6),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: isMyTeam
                                                            ? const Color(
                                                                0xFF1877F2)
                                                            : const Color(
                                                                0xFF131A29),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    14),
                                                        border: Border.all(
                                                            color: isMyTeam
                                                                ? Colors
                                                                    .transparent
                                                                : const Color(
                                                                    0xFF2A3447)),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            isMyTeam
                                                                ? CrossAxisAlignment
                                                                    .end
                                                                : CrossAxisAlignment
                                                                    .start,
                                                        children: [
                                                          Padding(
                                                            padding: const EdgeInsets
                                                                .only(
                                                                left: 4,
                                                                right: 4,
                                                                bottom: 4),
                                                            child: Text(
                                                                senderTeamName,
                                                                style: TextStyle(
                                                                    color: isMyTeam
                                                                        ? Colors
                                                                            .white70
                                                                        : const Color(
                                                                            0xFFFFD600),
                                                                    fontSize:
                                                                        10.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold)),
                                                          ),
                                                          ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            child: InkWell(
                                                              onTap: () => _showFullScreenImageDialog(
                                                                  context,
                                                                  msgText,
                                                                  localPath: m[
                                                                          "_local_path"]
                                                                      ?.toString()),
                                                              child: Stack(
                                                                children: [
                                                                  m["_local_path"] !=
                                                                              null &&
                                                                          File(m["_local_path"]
                                                                                  .toString())
                                                                              .existsSync()
                                                                      ? Image
                                                                          .file(File(m["_local_path"].toString()),
                                                                              height: 200,
                                                                              width: double.infinity,
                                                                              fit: BoxFit.cover)
                                                                      : CachedNetworkImage(
                                                                          imageUrl:
                                                                              msgText,
                                                                          height:
                                                                              200,
                                                                          width:
                                                                              double.infinity,
                                                                          fit:
                                                                              BoxFit.cover,
                                                                          placeholder:
                                                                              (_, __) => Container(
                                                                            height: 200,
                                                                            color: const Color(0xFF0B0E16),
                                                                            child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                                                          ),
                                                                          errorWidget:
                                                                              (_, __, ___) => Container(
                                                                            height: 120,
                                                                            color: const Color(0xFF0B0E16),
                                                                            child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white30, size: 36)),
                                                                          ),
                                                                        ),
                                                                  if (isPending)
                                                                    Positioned.fill(
                                                                      child:
                                                                          Container(
                                                                        color:
                                                                            Colors.black45,
                                                                        child:
                                                                            const Center(
                                                                          child:
                                                                              CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(timeStr,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white70,
                                                                      fontSize:
                                                                          9.5)),
                                                              if (isPending) ...[
                                                                const SizedBox(
                                                                    width: 4),
                                                                const Icon(
                                                                    Icons
                                                                        .access_time_rounded,
                                                                    size:
                                                                        10,
                                                                    color: Colors
                                                                        .white70),
                                                              ],
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : Align(
                                                    alignment: isMyTeam
                                                        ? Alignment
                                                            .centerRight
                                                        : Alignment
                                                            .centerLeft,
                                                    child: Container(
                                                      margin: const EdgeInsets
                                                          .only(bottom: 8),
                                                      constraints: BoxConstraints(
                                                          maxWidth: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.75),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 14,
                                                          vertical: 10),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: isMyTeam
                                                            ? const Color(
                                                                0xFF1877F2)
                                                            : const Color(
                                                                0xFF131A29),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                                    12),
                                                        border: Border.all(
                                                            color: isMyTeam
                                                                ? Colors
                                                                    .transparent
                                                                : const Color(
                                                                    0xFF2A3447)),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            isMyTeam
                                                                ? CrossAxisAlignment
                                                                    .end
                                                                : CrossAxisAlignment
                                                                    .start,
                                                        children: [
                                                          Text(senderTeamName,
                                                              style: TextStyle(
                                                                  color: isMyTeam
                                                                      ? Colors
                                                                          .white70
                                                                      : const Color(
                                                                          0xFFFFD600),
                                                                  fontSize:
                                                                      10.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                          const SizedBox(
                                                              height: 3),
                                                          Text(msgText,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      13.5)),
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(timeStr,
                                                                  style: TextStyle(
                                                                      color: isMyTeam
                                                                          ? Colors.white60
                                                                          : const Color(0xFF8B949E),
                                                                      fontSize: 9.5)),
                                                              if (isPending) ...[
                                                                const SizedBox(
                                                                    width: 4),
                                                                const Icon(
                                                                    Icons
                                                                        .access_time_rounded,
                                                                    size:
                                                                        10,
                                                                    color: Colors
                                                                        .white60),
                                                              ],
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
              ),

              // Input
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
                color: const Color(0xFF131A29),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: _isUploadingImage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFFFD600)))
                            : const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: Color(0xFFFFD600),
                                size: 24),
                        tooltip: 'send_screenshot_photo_title'.tr(),
                        onPressed:
                            _isUploadingImage ? null : _showImagePickerSheet,
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                              color: const Color(0xFF0B0E16),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: const Color(0xFF2A3447))),
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13.5),
                            decoration: InputDecoration(
                                hintText: 'type_message_input_hint'.tr(),
                                hintStyle: const TextStyle(
                                    color: Color(0xFF8B949E), fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10)),
                            onSubmitted: (val) => _sendMessage(val),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                            color: Color(0xFF1877F2), shape: BoxShape.circle),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 18),
                          onPressed: () =>
                              _sendMessage(_messageController.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showScrollDownButton)
            Positioned(
              bottom: 74,
              right: 16,
              child: InkWell(
                onTap: () {
                  _scrollToBottom();
                  setState(() {
                    _showScrollDownButton = false;
                    _newMessagesCountWhileScrolled = 0;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1877F2),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_downward_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _newMessagesCountWhileScrolled > 0
                            ? 'new_messages_scroll_label'.tr(args: [_newMessagesCountWhileScrolled.toString()])
                            : 'scroll_down_btn'.tr(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
