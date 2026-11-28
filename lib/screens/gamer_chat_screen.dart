// ===============================================================================
// GAMER CHAT SCREEN — Adaptive Day/Night Theme with UTC Presence, Profile Tap & Delete
// File: lib/screens/gamer_chat_screen.dart
// ===============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../models/chat_model.dart';
import '../services/direct_message_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import 'gamer_profile_screen.dart';

class GamerChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhoto;
  final bool otherUserVerified;

  const GamerChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto = '',
    this.otherUserVerified = false,
  });

  @override
  State<GamerChatScreen> createState() => _GamerChatScreenState();
}

class _GamerChatScreenState extends State<GamerChatScreen>
    with WidgetsBindingObserver {
  final _dmService = DirectMessageService();
  final _authService = GamerAuthService();
  final _messageController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  bool _initialLoad = true;
  bool _isOtherUserOnline = false;
  DateTime? _latestPartnerMessageUtc;
  Set<String> _myAliases = {};
  String _effectiveMyId = '';
  String _effectiveOtherId = '';
  String _otherUserPhoto = '';
  Stream<List<ChatMessage>>? _chatStream;
  Timer? _presencePollTimer;

  // Optimistic messages, locally deleted message IDs, reply target & reaction overrides
  final List<_OptimisticMessage> _optimisticMessages = [];
  final Set<String> _deletedMessageIds = {};
  final Map<String, Map<String, List<String>>> _optimisticReactionsByMsgId = {};
  ChatMessage? _replyingToMessage;
  int _tempIdCounter = 0;
  int _lastMarkedUnreadCount = 0;

  static const List<String> _quickReactionEmojis = [
    '👍',
    '❤️',
    '😂',
    '🔥',
    '😢',
    '🙏',
  ];
  static const List<String> _extendedReactionEmojis = [
    '👍',
    '❤️',
    '😂',
    '🔥',
    '😢',
    '🙏',
    '😮',
    '🎉',
    '💯',
    '👏',
    '🎮',
    '🏆',
    '⚡',
    '😎',
    '🤝',
    '🫡',
    '💀',
    '👑',
  ];

  static const Color neonBlue = Color(0xFF1877F2);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonGreen = Color(0xFF00FF88);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    _effectiveMyId = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    _effectiveOtherId = widget.otherUserId;
    _otherUserPhoto = DirectMessageService.normalizeAvatarUrl(widget.otherUserPhoto);
    _chatStream = _dmService.getMessagesStream(
      userId1: _effectiveMyId,
      userId2: _effectiveOtherId,
    );
    _dmService.updateUserPresence(userId: _effectiveMyId, force: true);
    _initIds();
    _fetchOtherUserStatus();
    _markAsRead();

    _presencePollTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _dmService.updateUserPresence(userId: _effectiveMyId);
      _fetchOtherUserStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dmService.updateUserPresence(userId: _effectiveMyId, force: true);
      _fetchOtherUserStatus();
    }
  }

  Future<void> _openOtherUserProfile() async {
    String targetUserId = _effectiveOtherId.trim().isNotEmpty
        ? _effectiveOtherId.trim()
        : widget.otherUserId.trim();
    if (targetUserId.isEmpty) return;

    final resolved = await _dmService.resolveToTableId(targetUserId);
    if (resolved.isNotEmpty) {
      targetUserId = resolved;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamerProfileScreen(userId: targetUserId),
      ),
    );
  }

  Future<void> _fetchOtherUserStatus() async {
    try {
      final targetId = _effectiveOtherId.isNotEmpty
          ? _effectiveOtherId
          : widget.otherUserId;
      final status = await _dmService.fetchUserPresenceStatus(
        targetId,
        latestMessageUtc: _latestPartnerMessageUtc,
      );

      if (mounted) {
        final online = status['isOnline'] == true ||
            DirectMessageService.isTimestampRecentlyActive(
              _latestPartnerMessageUtc,
            );
        final fetchedPhoto = DirectMessageService.normalizeAvatarUrl(
          status['photo']?.toString(),
        );
        final shouldUpdatePhoto =
            fetchedPhoto.isNotEmpty && fetchedPhoto != _otherUserPhoto;
        if (_isOtherUserOnline != online || shouldUpdatePhoto) {
          setState(() {
            _isOtherUserOnline = online;
            if (shouldUpdatePhoto) {
              _otherUserPhoto = fetchedPhoto;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _initIds() async {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;

    if (sourceUid.isNotEmpty) {
      final myAliases = await _dmService.getUserAliases(sourceUid);
      final myTableId = await _dmService.resolveToTableId(sourceUid);
      final otherTableId = await _dmService.resolveToTableId(widget.otherUserId);
      if (mounted) {
        setState(() {
          _myAliases = myAliases;
          if (myTableId.isNotEmpty) {
            _effectiveMyId = myTableId;
            _myAliases.add(myTableId);
            _myAliases.add(myTableId.toLowerCase());
          }
          if (otherTableId.isNotEmpty) _effectiveOtherId = otherTableId;
          _chatStream = _dmService.getMessagesStream(
            userId1: _effectiveMyId,
            userId2: _effectiveOtherId,
          );
        });
        _fetchOtherUserStatus();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _presencePollTimer?.cancel();
    _messageController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final myUid = _effectiveMyId.isNotEmpty
        ? _effectiveMyId
        : (myGamerUid.isNotEmpty ? myGamerUid : myAuthUid);
    if (myUid.isEmpty) return;
    await _dmService.markAsRead(
      currentUserId: myUid,
      otherUserId: _effectiveOtherId.isNotEmpty
          ? _effectiveOtherId
          : widget.otherUserId,
    );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent + 200;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  bool _isMessageFromMe(String senderId, String myUid) {
    final sLower = senderId.toLowerCase();
    return _myAliases.any((a) => a.toLowerCase() == sLower) ||
        sLower == _effectiveMyId.toLowerCase() ||
        sLower == myUid.toLowerCase() ||
        sLower == SupabaseService.toUuid(myUid).toLowerCase();
  }

  ChatMessage _applyOptimisticReactions(ChatMessage msg) {
    if (msg.id.isEmpty) return msg;
    final override = _optimisticReactionsByMsgId[msg.id];
    if (override == null) return msg;
    return msg.copyWith(reactions: override);
  }

  /// Combines server stream messages with pending/confirmed/failed optimistic messages,
  /// deduplicating any optimistic item that has already arrived in the server snapshot.
  List<ChatMessage> _mergeMessagesWithOptimistic(
    List<ChatMessage> serverMessages,
    String myUid,
  ) {
    final filteredServer = serverMessages
        .where((m) => m.id.isEmpty || !_deletedMessageIds.contains(m.id))
        .map(_applyOptimisticReactions)
        .toList();

    if (_optimisticMessages.isEmpty) {
      return filteredServer;
    }

    final serverIds = <String>{};
    for (final m in filteredServer) {
      if (m.id.isNotEmpty) {
        serverIds.add(m.id.toLowerCase());
      }
    }

    // Track which server messages have already matched an optimistic message without a serverId
    final matchedServerIndices = <int>{};
    final remainingOptimistic = <ChatMessage>[];

    for (final opt in List<_OptimisticMessage>.from(_optimisticMessages)) {
      if (_deletedMessageIds.contains(opt.tempId) ||
          (opt.serverId != null && _deletedMessageIds.contains(opt.serverId))) {
        _optimisticMessages.removeWhere((item) => item.tempId == opt.tempId);
        continue;
      }

      // 1. Direct match by confirmed Supabase row ID
      if (opt.serverId != null &&
          opt.serverId!.isNotEmpty &&
          serverIds.contains(opt.serverId!.toLowerCase())) {
        _optimisticMessages.removeWhere((item) => item.tempId == opt.tempId);
        continue;
      }

      // 2. Heuristic match when server poll arrives before or without select() ID
      if (!opt.hasFailed) {
        int matchedIndex = -1;
        final optImgUrl = opt.message.resolvedImageUrl;
        for (int i = filteredServer.length - 1; i >= 0; i--) {
          if (matchedServerIndices.contains(i)) continue;
          final srv = filteredServer[i];
          if (!_isMessageFromMe(srv.senderId, myUid)) continue;
          final srvImgUrl = srv.resolvedImageUrl;
          final isSameImage = optImgUrl.isNotEmpty &&
              srvImgUrl.isNotEmpty &&
              srvImgUrl == optImgUrl;
          final isSameText = !opt.isImageMessage &&
              srvImgUrl.isEmpty &&
              srv.message.trim().isNotEmpty &&
              srv.message.trim() == opt.message.message.trim();
          if (!isSameText && !isSameImage) continue;
          final diffSeconds =
              srv.createdAt.difference(opt.message.createdAt).inSeconds.abs();
          if (diffSeconds <= 25) {
            matchedIndex = i;
            break;
          }
        }
        if (matchedIndex != -1) {
          matchedServerIndices.add(matchedIndex);
          _optimisticMessages.removeWhere((item) => item.tempId == opt.tempId);
          continue;
        }
      }

      remainingOptimistic.add(_applyOptimisticReactions(opt.displayMessage));
    }

    if (remainingOptimistic.isEmpty) {
      return filteredServer;
    }

    final combined = <ChatMessage>[
      ...filteredServer,
      ...remainingOptimistic,
    ];
    combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return combined;
  }

  _OptimisticMessage? _findOptimisticForMessage(ChatMessage m) {
    for (final opt in _optimisticMessages) {
      if (opt.tempId == m.id ||
          (opt.serverId != null &&
              opt.serverId!.isNotEmpty &&
              opt.serverId == m.id)) {
        return opt;
      }
    }
    return null;
  }

  String _resolveReplySenderName(ChatMessage target, String myUid) {
    if (_isMessageFromMe(target.senderId, myUid)) {
      return 'You';
    }
    return widget.otherUserName;
  }

  String _resolveReplySnippetText(ChatMessage target) {
    final cleanText = target.message.trim();
    final imgUrl = target.resolvedImageUrl;
    if (cleanText.isNotEmpty &&
        cleanText != imgUrl &&
        !cleanText.startsWith('http://') &&
        !cleanText.startsWith('https://')) {
      return cleanText;
    }
    if (target.hasImage) {
      return '📷 Photo';
    }
    return cleanText;
  }

  void _startReplyToMessage(ChatMessage m) {
    setState(() {
      _replyingToMessage = m;
    });
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() {
    if (_replyingToMessage == null) return;
    setState(() {
      _replyingToMessage = null;
    });
  }

  Future<void> _toggleReaction(ChatMessage m, String emoji) async {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;
    if (myUid.isEmpty) return;

    final currentReactions = <String, List<String>>{};
    final baseMap = _optimisticReactionsByMsgId[m.id] ?? m.reactions;
    baseMap.forEach((k, v) {
      currentReactions[k] = List<String>.from(v);
    });

    final myAliasesLower = <String>{
      myUid.toLowerCase(),
      SupabaseService.toUuid(myUid).toLowerCase(),
      ..._myAliases.map((a) => a.toLowerCase()),
    };

    final existingUsers = currentReactions[emoji] ?? <String>[];
    final alreadyReactedWithSame =
        existingUsers.any((u) => myAliasesLower.contains(u.toLowerCase()));

    for (final key in currentReactions.keys.toList()) {
      currentReactions[key]!.removeWhere(
        (u) => myAliasesLower.contains(u.toLowerCase()),
      );
      if (currentReactions[key]!.isEmpty) {
        currentReactions.remove(key);
      }
    }

    if (!alreadyReactedWithSame) {
      currentReactions.putIfAbsent(emoji, () => <String>[]).add(myUid);
    }

    final opt = _findOptimisticForMessage(m);
    setState(() {
      if (m.id.isNotEmpty) {
        _optimisticReactionsByMsgId[m.id] = currentReactions;
      }
      if (opt != null) {
        opt.message = opt.message.copyWith(reactions: currentReactions);
        if (opt.serverId != null && opt.serverId!.isNotEmpty) {
          _optimisticReactionsByMsgId[opt.serverId!] = currentReactions;
        }
      }
    });

    final targetServerId = (opt?.serverId != null && opt!.serverId!.isNotEmpty)
        ? opt.serverId!
        : m.id;
    if (targetServerId.isEmpty || targetServerId.startsWith('temp_')) {
      return;
    }

    await _dmService.toggleMessageReaction(
      message: m.copyWith(id: targetServerId, reactions: baseMap),
      emoji: emoji,
      currentUserId: myUid,
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;
    if (myUid.isEmpty) return;

    final targetOtherId =
        _effectiveOtherId.isNotEmpty ? _effectiveOtherId : widget.otherUserId;

    if (_myAliases.any((a) => a.toLowerCase() == targetOtherId.toLowerCase()) ||
        myUid.toLowerCase() == targetOtherId.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('cannot_message_self'.tr()),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
      return;
    }

    final replyTarget = _replyingToMessage;
    final replyToId = replyTarget?.id;
    final replyToText =
        replyTarget != null ? _resolveReplySnippetText(replyTarget) : null;
    final replyToSenderId = replyTarget?.senderId;
    final replyToSenderName = replyTarget != null
        ? _resolveReplySenderName(replyTarget, myUid)
        : null;
    final replyToImageUrl =
        (replyTarget != null && replyTarget.resolvedImageUrl.isNotEmpty)
            ? replyTarget.resolvedImageUrl
            : null;

    final nowLocal = DateTime.now();
    final tempId =
        'temp_${nowLocal.microsecondsSinceEpoch}_${++_tempIdCounter}';
    final optimisticMsg = ChatMessage(
      id: tempId,
      senderId: myUid,
      receiverId: targetOtherId,
      message: text,
      createdAt: nowLocal,
      isRead: false,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSenderId: replyToSenderId,
      replyToSenderName: replyToSenderName,
      replyToImageUrl: replyToImageUrl,
    );

    final entry = _OptimisticMessage(
      tempId: tempId,
      message: optimisticMsg,
    );

    // 1. Immediately clear input & reply state, append optimistic bubble, and scroll to bottom
    _messageController.clear();
    setState(() {
      _replyingToMessage = null;
      _optimisticMessages.add(entry);
    });
    _scrollToBottom();

    // 2. Persist to Supabase in the background
    await _persistOptimisticMessage(entry, myUid, targetOtherId);
  }

  /// Allows picking and sending up to 10 images at once from the gallery.
  Future<void> _pickAndSendImage() async {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;
    if (myUid.isEmpty) return;

    final targetOtherId =
        _effectiveOtherId.isNotEmpty ? _effectiveOtherId : widget.otherUserId;

    if (_myAliases.any((a) => a.toLowerCase() == targetOtherId.toLowerCase()) ||
        myUid.toLowerCase() == targetOtherId.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('cannot_message_self'.tr()),
          backgroundColor: const Color(0xFFFF4655),
        ),
      );
      return;
    }

    try {
      List<XFile> pickedList = [];
      try {
        pickedList = await _imagePicker.pickMultiImage(
          imageQuality: 82,
          maxWidth: 1600,
        );
      } catch (_) {
        final single = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 82,
          maxWidth: 1600,
        );
        if (single != null) {
          pickedList = [single];
        }
      }

      if (pickedList.isEmpty) return;

      if (pickedList.length > 10) {
        pickedList = pickedList.take(10).toList();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You can send up to 10 images at once. Sending the first 10 images.',
              ),
              backgroundColor: neonBlue,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      final validFiles = <File>[];
      for (final xfile in pickedList) {
        final f = File(xfile.path);
        if (await f.exists()) {
          validFiles.add(f);
        }
      }
      if (validFiles.isEmpty) return;

      final captionText = _messageController.text.trim();
      if (captionText.isNotEmpty) {
        _messageController.clear();
      }

      final replyTarget = _replyingToMessage;
      final replyToId = replyTarget?.id;
      final replyToText =
          replyTarget != null ? _resolveReplySnippetText(replyTarget) : null;
      final replyToSenderId = replyTarget?.senderId;
      final replyToSenderName = replyTarget != null
          ? _resolveReplySenderName(replyTarget, myUid)
          : null;
      final replyToImageUrl =
          (replyTarget != null && replyTarget.resolvedImageUrl.isNotEmpty)
              ? replyTarget.resolvedImageUrl
              : null;

      final baseNow = DateTime.now();
      final batchEntries = <_OptimisticMessage>[];

      for (int i = 0; i < validFiles.length; i++) {
        final itemTime = baseNow.add(Duration(milliseconds: i * 15));
        final tempId =
            'temp_img_${itemTime.microsecondsSinceEpoch}_${++_tempIdCounter}';
        final isFirstInBatch = i == 0;
        final optimisticMsg = ChatMessage(
          id: tempId,
          senderId: myUid,
          receiverId: targetOtherId,
          message: isFirstInBatch ? captionText : '',
          createdAt: itemTime,
          isRead: false,
          replyToId: isFirstInBatch ? replyToId : null,
          replyToText: isFirstInBatch ? replyToText : null,
          replyToSenderId: isFirstInBatch ? replyToSenderId : null,
          replyToSenderName: isFirstInBatch ? replyToSenderName : null,
          replyToImageUrl: isFirstInBatch ? replyToImageUrl : null,
        );

        batchEntries.add(
          _OptimisticMessage(
            tempId: tempId,
            message: optimisticMsg,
            localImageFile: validFiles[i],
            isSending: true,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _replyingToMessage = null;
        _optimisticMessages.addAll(batchEntries);
      });
      _scrollToBottom();

      // Upload and persist all selected images concurrently (up to 10)
      await Future.wait(
        batchEntries.map(
          (entry) => _persistOptimisticMessage(entry, myUid, targetOtherId),
        ),
      );
    } catch (e) {
      debugPrint('[GamerChatScreen] Multi-image picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not select images.'),
            backgroundColor: Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  Future<void> _persistOptimisticMessage(
    _OptimisticMessage entry,
    String myUid,
    String targetOtherId,
  ) async {
    String? uploadedImageUrl = entry.uploadedImageUrl;

    // Upload local image file to Supabase Storage first if this is an image message
    if (entry.localImageFile != null &&
        (uploadedImageUrl == null || uploadedImageUrl.isEmpty)) {
      uploadedImageUrl = await _dmService.uploadChatImage(
        file: entry.localImageFile!,
        senderId: myUid,
      );
      if (!mounted) return;
      if (uploadedImageUrl == null || uploadedImageUrl.isEmpty) {
        setState(() {
          entry.isSending = false;
          entry.hasFailed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to upload image. Tap the image to retry.',
            ),
            backgroundColor: const Color(0xFFFF4655),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _retryFailedMessage(entry),
            ),
          ),
        );
        return;
      }
      entry.uploadedImageUrl = uploadedImageUrl;
      entry.message = entry.message.copyWith(
        imageUrl: uploadedImageUrl,
        message: entry.message.message.trim().isNotEmpty
            ? entry.message.message.trim()
            : uploadedImageUrl,
      );
    }

    final persisted = await _dmService.sendMessageReturningRecord(
      senderId: myUid,
      receiverId: targetOtherId,
      message: entry.message.message,
      messageType: (uploadedImageUrl != null && uploadedImageUrl.isNotEmpty)
          ? 'image'
          : 'text',
      imageUrl: uploadedImageUrl,
      replyToId: entry.message.replyToId,
      replyToText: entry.message.replyToText,
      replyToSenderId: entry.message.replyToSenderId,
      replyToSenderName: entry.message.replyToSenderName,
      replyToImageUrl: entry.message.replyToImageUrl,
      clientCreatedAt: entry.message.createdAt,
    );

    if (!mounted) return;

    if (persisted != null) {
      setState(() {
        entry.isSending = false;
        entry.hasFailed = false;
        final resolvedImg = persisted.resolvedImageUrl.isNotEmpty
            ? persisted.resolvedImageUrl
            : uploadedImageUrl;
        if (persisted.id.isNotEmpty) {
          final existingOptimisticReaction =
              _optimisticReactionsByMsgId[entry.tempId];
          if (existingOptimisticReaction != null) {
            _optimisticReactionsByMsgId[persisted.id] =
                existingOptimisticReaction;
          }
          entry.serverId = persisted.id;
          entry.message = entry.message.copyWith(
            id: persisted.id,
            senderId: persisted.senderId.isNotEmpty
                ? persisted.senderId
                : entry.message.senderId,
            receiverId: persisted.receiverId.isNotEmpty
                ? persisted.receiverId
                : entry.message.receiverId,
            imageUrl: resolvedImg,
            createdAt: persisted.createdAt,
          );
        } else if (resolvedImg != null && resolvedImg.isNotEmpty) {
          entry.message = entry.message.copyWith(imageUrl: resolvedImg);
        }
      });
      _fetchOtherUserStatus();
    } else {
      setState(() {
        entry.isSending = false;
        entry.hasFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entry.isImageMessage
                ? 'Failed to send image. Tap the image to retry.'
                : 'Failed to send message. Tap the message to retry.',
          ),
          backgroundColor: const Color(0xFFFF4655),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _retryFailedMessage(entry),
          ),
        ),
      );
    }
  }

  Future<void> _retryFailedMessage(_OptimisticMessage entry) async {
    if (entry.isSending) return;
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;
    final targetOtherId =
        _effectiveOtherId.isNotEmpty ? _effectiveOtherId : widget.otherUserId;

    setState(() {
      entry.isSending = true;
      entry.hasFailed = false;
    });

    await _persistOptimisticMessage(entry, myUid, targetOtherId);
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Color(0xFFFF4655)),
            const SizedBox(width: 8),
            Text(
              'Delete Message?',
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final msgId = message.id;
      final opt = _findOptimisticForMessage(message);

      setState(() {
        if (msgId.isNotEmpty) {
          _deletedMessageIds.add(msgId);
        }
        if (opt != null) {
          _deletedMessageIds.add(opt.tempId);
          if (opt.serverId != null && opt.serverId!.isNotEmpty) {
            _deletedMessageIds.add(opt.serverId!);
          }
          _optimisticMessages.removeWhere((item) => item.tempId == opt.tempId);
        }
      });

      final serverTargetId = (opt?.serverId != null && opt!.serverId!.isNotEmpty)
          ? opt.serverId!
          : (!msgId.startsWith('temp_') ? msgId : '');

      if (serverTargetId.isNotEmpty) {
        bool deleted = false;
        try {
          await SupabaseService.client
              .from('direct_messages')
              .delete()
              .eq('id', serverTargetId);
          deleted = true;
        } catch (_) {}

        if (!deleted) {
          try {
            await SupabaseService.client
                .from('messages')
                .delete()
                .eq('id', serverTargetId);
            deleted = true;
          } catch (_) {}
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Color(0xFFFF4655),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[GamerChatScreen] Delete message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  bool _hasMyReactionForEmoji(ChatMessage m, String emoji) {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;
    final myAliasesLower = <String>{
      myUid.toLowerCase(),
      SupabaseService.toUuid(myUid).toLowerCase(),
      ..._myAliases.map((a) => a.toLowerCase()),
    };
    final users =
        (_optimisticReactionsByMsgId[m.id] ?? m.reactions)[emoji] ?? const [];
    return users.any((u) => myAliasesLower.contains(u.toLowerCase()));
  }

  void _showExtendedEmojiReactionPicker(ChatMessage m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeService.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: ThemeService.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'React with Emoji',
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: _extendedReactionEmojis.map((emoji) {
                  final isSelected = _hasMyReactionForEmoji(m, emoji);
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleReaction(m, emoji);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? neonBlue.withOpacity(0.25)
                            : ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? neonCyan : ThemeService.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 23),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage m, bool isMyMsg) {
    final opt = _findOptimisticForMessage(m);
    final rawText = m.message.trim();
    final imageUrl = m.resolvedImageUrl.isNotEmpty
        ? m.resolvedImageUrl
        : (opt?.uploadedImageUrl ?? '');
    final localFile = opt?.localImageFile;
    final hasImage = localFile != null || imageUrl.isNotEmpty;
    final hasCopyableText = rawText.isNotEmpty &&
        rawText != imageUrl &&
        !(hasImage &&
            (rawText.startsWith('http://') || rawText.startsWith('https://')));

    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeService.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeService.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Quick Emoji Reaction Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ..._quickReactionEmojis.map((emoji) {
                      final isSelected = _hasMyReactionForEmoji(m, emoji);
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _toggleReaction(m, emoji);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? neonBlue.withOpacity(0.28)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: neonCyan, width: 1.2)
                                : null,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    }),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showExtendedEmojiReactionPicker(m);
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: ThemeService.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: ThemeService.border),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: ThemeService.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: neonCyan),
              title: Text(
                'Reply',
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _startReplyToMessage(m);
              },
            ),
            if (opt != null && opt.hasFailed)
              ListTile(
                leading: const Icon(Icons.refresh_rounded, color: neonCyan),
                title: Text(
                  'Retry Sending',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _retryFailedMessage(opt);
                },
              ),
            if (hasImage)
              ListTile(
                leading:
                    const Icon(Icons.fullscreen_rounded, color: neonCyan),
                title: Text(
                  'View Full Image',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFullScreenImageViewer(
                    imageUrl: imageUrl,
                    localFile: localFile,
                  );
                },
              ),
            if (hasCopyableText)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: neonCyan),
                title: Text(
                  'Copy Text',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: m.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard!'),
                      backgroundColor: neonBlue,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            if (isMyMsg)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFFF4655),
                ),
                title: const Text(
                  'Delete Message',
                  style: TextStyle(
                    color: Color(0xFFFF4655),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return DateFormat('hh:mm a').format(dt);
  }

  String _formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('dd MMMM yyyy').format(dt);
  }

  Widget _buildDatePill(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeService.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(ThemeService.isDarkMode ? 0.3 : 0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: ThemeService.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  void _checkRecentPartnerActivityFromMessages(
    List<ChatMessage> messages,
    String myUid,
  ) {
    if (messages.isEmpty) return;
    DateTime? latestPartnerUtc;
    int unreadPartnerCount = 0;
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      final sLower = m.senderId.toLowerCase();
      final isMyMsg = _myAliases.any((a) => a.toLowerCase() == sLower) ||
          sLower == _effectiveMyId.toLowerCase() ||
          sLower == myUid.toLowerCase() ||
          sLower == SupabaseService.toUuid(myUid).toLowerCase();
      if (!isMyMsg) {
        latestPartnerUtc ??= m.createdAt.toUtc();
        if (!m.isRead) {
          unreadPartnerCount++;
        }
      }
    }

    if (unreadPartnerCount > 0 &&
        unreadPartnerCount != _lastMarkedUnreadCount) {
      _lastMarkedUnreadCount = unreadPartnerCount;
      unawaited(_markAsRead());
    } else if (unreadPartnerCount == 0) {
      _lastMarkedUnreadCount = 0;
    }

    if (latestPartnerUtc != null) {
      _latestPartnerMessageUtc = latestPartnerUtc;
      if (DirectMessageService.isTimestampRecentlyActive(latestPartnerUtc) &&
          !_isOtherUserOnline) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isOtherUserOnline) {
            setState(() {
              _isOtherUserOnline = true;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: ThemeService.textPrimary, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: InkWell(
              onTap: _openOtherUserProfile,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: ThemeService.cardSecondary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ThemeService.border,
                              width: 1.2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildPartnerAvatar(
                              _otherUserPhoto.isNotEmpty
                                  ? _otherUserPhoto
                                  : widget.otherUserPhoto,
                              widget.otherUserName,
                              40,
                            ),
                          ),
                        ),
                        if (_isOtherUserOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: neonGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ThemeService.card,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: neonGreen.withOpacity(0.6),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.otherUserName,
                                  style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.otherUserVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  color: neonCyan,
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isOtherUserOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: _isOtherUserOnline
                                  ? neonGreen
                                  : ThemeService.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _chatStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _initialLoad &&
                        _optimisticMessages.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(color: neonCyan),
                      );
                    }

                    final serverMessages = snapshot.data ?? [];
                    _checkRecentPartnerActivityFromMessages(
                      serverMessages,
                      myUid,
                    );
                    final messages = _mergeMessagesWithOptimistic(
                      serverMessages,
                      myUid,
                    );

                    if (_initialLoad &&
                        (snapshot.hasData || _optimisticMessages.isNotEmpty)) {
                      _initialLoad = false;
                      _scrollToBottom(animate: false);
                    }

                    if (messages.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[i];
                        final isMyMsg = _isMessageFromMe(m.senderId, myUid);

                        bool showDate = false;
                        if (i == 0) {
                          showDate = true;
                        } else {
                          final prev = messages[i - 1];
                          final prevDay = DateTime(
                            prev.createdAt.year,
                            prev.createdAt.month,
                            prev.createdAt.day,
                          );
                          final curDay = DateTime(
                            m.createdAt.year,
                            m.createdAt.month,
                            m.createdAt.day,
                          );
                          if (prevDay != curDay) showDate = true;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDate)
                              _buildDatePill(_formatDateDivider(m.createdAt)),
                            _buildMessageBubble(m, isMyMsg),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _openOtherUserProfile,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThemeService.border),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 46,
                  color: neonCyan,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openOtherUserProfile,
              child: Text(
                widget.otherUserName,
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'say_hi_start_chat'.tr(),
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenImageViewer({
    String? imageUrl,
    File? localFile,
  }) {
    final cleanUrl = (imageUrl ?? '').trim();
    if (cleanUrl.isEmpty && localFile == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: Center(
                  child: localFile != null
                      ? Image.file(
                          localFile,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 56,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: cleanUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(color: neonCyan),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 56,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(dialogCtx).padding.top + 12,
                right: 16,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatImageContent({
    required String imageUrl,
    required File? localFile,
    required bool isUploading,
    required bool hasFailed,
  }) {
    final maxWidth = MediaQuery.of(context).size.width * 0.68;

    Widget imageChild;
    if (localFile != null) {
      imageChild = Image.file(
        localFile,
        width: maxWidth,
        height: 215,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImageErrorPlaceholder(maxWidth),
      );
    } else {
      imageChild = CachedNetworkImage(
        imageUrl: imageUrl,
        width: maxWidth,
        height: 215,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: maxWidth,
          height: 215,
          color: ThemeService.cardSecondary,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: neonCyan,
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _buildImageErrorPlaceholder(maxWidth),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          imageChild,
          if (isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (hasFailed)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tap to retry upload',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageErrorPlaceholder(double width) {
    return Container(
      width: width,
      height: 160,
      color: ThemeService.cardSecondary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: ThemeService.textSecondary,
            size: 30,
          ),
          const SizedBox(height: 6),
          Text(
            'Unable to load image',
            style: TextStyle(
              color: ThemeService.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotedReplyBoxInBubble(ChatMessage m, bool isMyMsg) {
    final senderLabel = (m.replyToSenderName ?? '').trim().isNotEmpty
        ? m.replyToSenderName!.trim()
        : ((m.replyToSenderId != null &&
                _isMessageFromMe(
                  m.replyToSenderId!,
                  _effectiveMyId,
                ))
            ? 'You'
            : widget.otherUserName);
    final snippet = (m.replyToText ?? '').trim().isNotEmpty
        ? m.replyToText!.trim()
        : ((m.replyToImageUrl ?? '').trim().isNotEmpty ? '📷 Photo' : 'Message');
    final replyImg = (m.replyToImageUrl ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isMyMsg
            ? Colors.black.withOpacity(0.22)
            : ThemeService.cardSecondary.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMyMsg ? neonCyan : neonBlue,
            width: 3,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  senderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMyMsg ? neonCyan : neonBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isMyMsg
                        ? Colors.white.withOpacity(0.88)
                        : ThemeService.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (replyImg.isNotEmpty &&
              (replyImg.startsWith('http://') ||
                  replyImg.startsWith('https://'))) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: replyImg,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReactionsRow(ChatMessage m, bool isMyMsg) {
    final reactionsMap = _optimisticReactionsByMsgId[m.id] ?? m.reactions;
    if (reactionsMap.isEmpty) return const SizedBox.shrink();

    final nonEmptyEntries =
        reactionsMap.entries.where((e) => e.value.isNotEmpty).toList();
    if (nonEmptyEntries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 2),
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        alignment: isMyMsg ? WrapAlignment.end : WrapAlignment.start,
        children: nonEmptyEntries.map((entry) {
          final emoji = entry.key;
          final count = entry.value.length;
          final iReacted = _hasMyReactionForEmoji(m, emoji);
          return GestureDetector(
            onTap: () => _toggleReaction(m, emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: iReacted
                    ? neonBlue.withOpacity(0.28)
                    : ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: iReacted ? neonCyan : ThemeService.border,
                  width: iReacted ? 1.2 : 0.9,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        color: iReacted
                            ? Colors.white
                            : ThemeService.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage m, bool isMyMsg) {
    final opt = isMyMsg ? _findOptimisticForMessage(m) : null;
    final hasFailed = opt != null && opt.hasFailed;
    final isUploadingImage =
        opt != null && opt.isSending && opt.isImageMessage;
    final localFile = opt?.localImageFile;
    final imageUrl = m.resolvedImageUrl.isNotEmpty
        ? m.resolvedImageUrl
        : (opt?.uploadedImageUrl ?? '');
    final hasImage = localFile != null || imageUrl.isNotEmpty;

    final rawText = m.message.trim();
    final hasCaption = rawText.isNotEmpty &&
        rawText != imageUrl &&
        !(hasImage &&
            (rawText.startsWith('http://') || rawText.startsWith('https://')));

    final reactionsMap = _optimisticReactionsByMsgId[m.id] ?? m.reactions;
    final hasReactions = reactionsMap.values.any((list) => list.isNotEmpty);

    return Align(
      alignment: isMyMsg ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMyMsg ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: hasFailed
                ? () => _retryFailedMessage(opt!)
                : (hasImage
                    ? () => _openFullScreenImageViewer(
                          imageUrl: imageUrl,
                          localFile: localFile,
                        )
                    : () => _showMessageOptions(m, isMyMsg)),
            onLongPress: () => _showMessageOptions(m, isMyMsg),
            child: Container(
              margin: EdgeInsets.only(
                top: 5,
                bottom: hasReactions ? 1 : 5,
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: hasImage
                  ? const EdgeInsets.fromLTRB(6, 6, 6, 8)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMyMsg ? null : ThemeService.card,
                gradient: isMyMsg
                    ? LinearGradient(
                        colors: hasFailed
                            ? const [Color(0xFFB91C1C), Color(0xFFEF4444)]
                            : const [Color(0xFF1877F2), Color(0xFF00A3FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasFailed
                      ? const Color(0xFFFF4655)
                      : (isMyMsg
                          ? neonCyan.withOpacity(0.5)
                          : ThemeService.border),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isMyMsg
                        ? (hasFailed
                            ? const Color(0xFFFF4655).withOpacity(0.22)
                            : neonCyan.withOpacity(0.18))
                        : Colors.black.withOpacity(
                            ThemeService.isDarkMode ? 0.2 : 0.04,
                          ),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.isReply) _buildQuotedReplyBoxInBubble(m, isMyMsg),
                  if (hasImage)
                    _buildChatImageContent(
                      imageUrl: imageUrl,
                      localFile: localFile,
                      isUploading: isUploadingImage,
                      hasFailed: hasFailed,
                    ),
                  if (hasCaption)
                    Padding(
                      padding: hasImage
                          ? const EdgeInsets.fromLTRB(8, 8, 8, 2)
                          : EdgeInsets.zero,
                      child: Text(
                        m.message,
                        style: TextStyle(
                          color:
                              isMyMsg ? Colors.white : ThemeService.textPrimary,
                          fontSize: 13.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: hasImage
                        ? const EdgeInsets.symmetric(horizontal: 6)
                        : EdgeInsets.zero,
                    child: Align(
                      alignment: isMyMsg
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasFailed) ...[
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Failed • Tap to retry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else
                            Text(
                              _formatTime(m.createdAt),
                              style: TextStyle(
                                color: isMyMsg
                                    ? Colors.white70
                                    : ThemeService.textSecondary
                                        .withOpacity(0.8),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasReactions) _buildReactionsRow(m, isMyMsg),
        ],
      ),
    );
  }

  Widget _buildReplyingToBanner() {
    final target = _replyingToMessage;
    if (target == null) return const SizedBox.shrink();

    final myAuthUid = _authService.currentUid ?? '';
    final myGamerUid = _authService.currentGamer?.uid ?? '';
    final sourceUid = myGamerUid.isNotEmpty ? myGamerUid : myAuthUid;
    final myUid = _effectiveMyId.isNotEmpty ? _effectiveMyId : sourceUid;

    final senderName = _resolveReplySenderName(target, myUid);
    final snippetText = _resolveReplySnippetText(target);
    final targetOpt = _findOptimisticForMessage(target);
    final replyImgUrl = target.resolvedImageUrl.isNotEmpty
        ? target.resolvedImageUrl
        : (targetOpt?.uploadedImageUrl ?? '');
    final replyLocalFile = targetOpt?.localImageFile;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neonCyan.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: neonCyan,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.reply_rounded,
            color: neonCyan,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $senderName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: neonCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  snippetText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (replyLocalFile != null) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                replyLocalFile,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
              ),
            ),
          ] else if (replyImgUrl.isNotEmpty) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: replyImgUrl,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(width: 4),
          InkWell(
            onTap: _cancelReply,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                color: ThemeService.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: ThemeService.bg,
        border: Border(top: BorderSide(color: ThemeService.border, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToMessage != null) _buildReplyingToBanner(),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThemeService.border),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Send Images (Up to 10)',
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: neonCyan,
                    size: 21,
                  ),
                  onPressed: _pickAndSendImage,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: ThemeService.card,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _inputFocusNode,
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontSize: 13.5,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: _replyingToMessage != null
                          ? 'Type a reply...'
                          : 'Type message...',
                      hintStyle: TextStyle(
                        color: ThemeService.textSecondary.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1877F2), Color(0xFF00E5FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: neonCyan.withOpacity(0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerAvatar(String rawPhotoUrl, String name, double size) {
    final normalized = DirectMessageService.normalizeAvatarUrl(rawPhotoUrl);
    if (normalized.isEmpty) {
      return _buildInitials(name, size);
    }

    if (normalized.startsWith('preset:')) {
      final presetId =
          normalized.replaceFirst('preset:', '').trim().toLowerCase();
      IconData iconData = Icons.sports_esports_rounded;
      List<Color> gradientColors = const [Color(0xFF1E3A8A), Color(0xFF00E5FF)];

      switch (presetId) {
        case 'helmet':
          iconData = Icons.sports_motorsports_rounded;
          gradientColors = const [Color(0xFF1877F2), Color(0xFF00E5FF)];
          break;
        case 'controller':
        case 'skull':
          iconData = Icons.gamepad_rounded;
          gradientColors = const [Color(0xFF6D28D9), Color(0xFFEC4899)];
          break;
        case 'ninja':
        case 'shield':
          iconData = Icons.shield_rounded;
          gradientColors = const [Color(0xFF047857), Color(0xFF10B981)];
          break;
        case 'crown':
        case 'trophy':
          iconData = Icons.emoji_events_rounded;
          gradientColors = const [Color(0xFFB45309), Color(0xFFFBBF24)];
          break;
        case 'crosshair':
          iconData = Icons.gps_fixed_rounded;
          gradientColors = const [Color(0xFFBE123C), Color(0xFFFB7185)];
          break;
        default:
          iconData = Icons.sports_esports_rounded;
          gradientColors = const [Color(0xFF1E3A8A), Color(0xFF00E5FF)];
      }

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            iconData,
            color: Colors.white,
            size: size * 0.52,
          ),
        ),
      );
    }

    if (normalized.startsWith('data:image')) {
      try {
        final commaIdx = normalized.indexOf(',');
        if (commaIdx != -1) {
          final b64 = normalized.substring(commaIdx + 1).trim();
          final bytes = base64Decode(b64);
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitials(name, size),
          );
        }
      } catch (_) {
        return _buildInitials(name, size);
      }
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: normalized,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _buildInitials(name, size),
        errorWidget: (_, __, ___) => _buildInitials(name, size),
      );
    }

    return _buildInitials(name, size);
  }

  Widget _buildInitials(String name, double size) {
    final trimmed = name.trim();
    final initials = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      color: ThemeService.cardSecondary,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: neonCyan,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _OptimisticMessage {
  final String tempId;
  ChatMessage message;
  final File? localImageFile;
  String? uploadedImageUrl;
  String? serverId;
  bool isSending;
  bool hasFailed;

  _OptimisticMessage({
    required this.tempId,
    required this.message,
    this.localImageFile,
    this.uploadedImageUrl,
    this.serverId,
    this.isSending = true,
    this.hasFailed = false,
  });

  bool get isImageMessage =>
      localImageFile != null ||
      (uploadedImageUrl != null && uploadedImageUrl!.isNotEmpty) ||
      message.hasImage;

  ChatMessage get displayMessage =>
      (serverId != null && serverId!.isNotEmpty)
          ? message.copyWith(id: serverId)
          : message;
}
