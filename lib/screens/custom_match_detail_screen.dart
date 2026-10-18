import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/gamer_theme.dart';
import '../services/win_proof_validator.dart';
import '../services/supabase_service.dart';

class CustomMatchDetailScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUserName;

  const CustomMatchDetailScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<CustomMatchDetailScreen> createState() => _CustomMatchDetailScreenState();
}

class _CustomMatchDetailScreenState extends State<CustomMatchDetailScreen> {
  static const Color _neonGreen = GamerTheme.neonGreen;

  Stream<Map<String, dynamic>?> _roomStream() async* {
    while (true) {
      Map<String, dynamic>? data;
      try {
        data = await SupabaseService.client
            .from('rooms')
            .select()
            .eq('id', widget.roomId)
            .maybeSingle();
      } catch (_) {}
      yield data;
      await Future.delayed(const Duration(seconds: 4));
    }
  }
  bool _isUploadingProof = false;
  File? _selectedProofImage;
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadWinProof(String accountIdName) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _isUploadingProof = true;
      });

      // 1. Upload screenshot to Supabase Storage
      final uploadedUrl = await SupabaseService.uploadFile(
        file: file,
        folder: 'win_proofs',
        bucket: SupabaseService.bucketMatchProofs,
      );

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        throw Exception('err_image_upload_failed'.tr());
      }

      // 2. Validate win proof and match player name
      final validationResult = await WinProofValidator.validate(
        imageFile: file,
        userId: widget.currentUserId,
        accountIdName: accountIdName,
        roomId: widget.roomId,
      );

      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final autoApproveAtIso = now.add(const Duration(minutes: 15)).toIso8601String();

      // 3. Update room document: Status always goes to reward_waiting (never auto block on mismatch)
      final updateData = {
        'status': 'reward_waiting',
        'proofUrl': uploadedUrl,
        'winProofUrl': uploadedUrl,
        'winProofUploadedAt': nowIso,
        'autoApproveAt': autoApproveAtIso,
        'winnerId': widget.currentUserId,
        'winnerName': widget.currentUserName,
        'proofUploadedBy': widget.currentUserId,
        'proofUploadedByName': widget.currentUserName,
        'ocrStatus': validationResult.status,
        'ocrScore': validationResult.score,
        'ocrText': validationResult.fullOcrText.length > 300
            ? validationResult.fullOcrText.substring(0, 300)
            : validationResult.fullOcrText,
        'rewardStatus': 'pending',
        'detectedScreenshotName': validationResult.detectedScreenshotName,
        'accountIdName': validationResult.accountIdName,
      };

      await SupabaseService.client.from('rooms').update(updateData).eq('id', widget.roomId).catchError((_) => null);

      // Sync to tournament_rooms collection
      try {
        await SupabaseService.client.from('tournament_rooms').update(updateData).eq('id', widget.roomId).catchError((_) => null);
      } catch (_) {}

      // 4. Add win proof message to room chat
      await SupabaseService.client.from('messages').insert({
        'roomId': widget.roomId,
        'senderId': widget.currentUserId,
        'senderName': widget.currentUserName,
        'senderInitial': widget.currentUserName.isNotEmpty ? widget.currentUserName[0].toUpperCase() : 'G',
        'message': 'msg_submitted_match_win_proof'.tr(),
        'imageUrl': uploadedUrl,
        'type': 'win_proof',
        'ocrStatus': validationResult.status,
        'ocrScore': validationResult.score,
        'ocrText': validationResult.fullOcrText,
        'detectedName': validationResult.detectedScreenshotName,
        'accountName': validationResult.accountIdName,
        'aiCheckMsg': validationResult.message,
        'timestamp': nowIso,
        'createdAt': nowIso,
        'isHost': false,
      }).catchError((_) => null);

      // 5. Add AI Bot check message to room chat
      await SupabaseService.client.from('messages').insert({
        'roomId': widget.roomId,
        'senderId': 'system',
        'senderName': 'APP BOT',
        'senderInitial': '🤖',
        'message': validationResult.message,
        'type': 'system',
        'timestamp': nowIso,
        'createdAt': nowIso,
        'isHost': false,
      }).catchError((_) => null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              validationResult.isVerified
                  ? 'msg_verified_name_matched'.tr()
                  : validationResult.message,
            ),
            backgroundColor: validationResult.isVerified ? _neonGreen : GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('CustomMatchDetailScreen: upload proof error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_failed_submit_proof'.tr(args: [e.toString()])),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProof = false;
        });
      }
    }
  }

  Future<void> _disputeResult() async {
    File? disputeImage;
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: GamerTheme.redAccent, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'title_raise_dispute_proof'.tr(),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'desc_raise_dispute_proof'.tr(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (disputeImage == null)
                      InkWell(
                        onTap: isSubmitting
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                  maxWidth: 1080,
                                );
                                if (picked != null) {
                                  setSheetState(() {
                                    disputeImage = File(picked.path);
                                  });
                                }
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: double.infinity,
                          height: 110,
                          decoration: BoxDecoration(
                            color: GamerTheme.cardDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GamerTheme.redAccent.withOpacity(0.6)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_rounded, color: GamerTheme.redAccent, size: 32),
                              const SizedBox(height: 6),
                              Text(
                                'btn_upload_defeat_screenshot'.tr(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'sub_select_defeat_screenshot'.tr(),
                                style: const TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              disputeImage!,
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.black.withOpacity(0.7),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                onPressed: isSubmitting
                                    ? null
                                    : () {
                                        setSheetState(() {
                                          disputeImage = null;
                                        });
                                      },
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
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: GamerTheme.redAccent, size: 12),
                                  const SizedBox(width: 4),
                                  Text('label_dispute_proof_selected'.tr(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Text(
                      'label_reason_for_dispute'.tr(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      enabled: !isSubmitting,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'hint_dispute_reason'.tr(),
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: GamerTheme.cardDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GamerTheme.borderDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GamerTheme.redAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GamerTheme.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (disputeImage == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('err_select_dispute_screenshot'.tr()),
                                      backgroundColor: GamerTheme.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                setSheetState(() {
                                  isSubmitting = true;
                                });

                                try {
                                  final disputeUrl = await SupabaseService.uploadFile(
                                    file: disputeImage!,
                                    folder: 'dispute_proofs',
                                    bucket: SupabaseService.bucketMatchProofs,
                                  );

                                  if (disputeUrl == null || disputeUrl.isEmpty) {
                                    throw Exception('err_dispute_image_upload_failed'.tr());
                                  }

                                  final reason = reasonController.text.trim().isNotEmpty
                                      ? reasonController.text.trim()
                                      : 'default_dispute_reason'.tr();

                                  final nowIso = DateTime.now().toIso8601String();
                                  final disputeData = {
                                    'status': 'disputed',
                                    'disputed': true,
                                    'disputedBy': widget.currentUserId,
                                    'disputedByName': widget.currentUserName,
                                    'disputeProofUrl': disputeUrl,
                                    'disputeReason': reason,
                                    'disputedAt': nowIso,
                                  };

                                  await SupabaseService.client.from('rooms').update(disputeData).eq('id', widget.roomId).catchError((_) => null);

                                  try {
                                    await SupabaseService.client.from('tournament_rooms').update(disputeData).eq('id', widget.roomId).catchError((_) => null);
                                  } catch (_) {}

                                  // Add dispute proof message into chat
                                  await SupabaseService.client.from('messages').insert({
                                    'roomId': widget.roomId,
                                    'senderId': widget.currentUserId,
                                    'senderName': widget.currentUserName,
                                    'senderInitial': widget.currentUserName.isNotEmpty ? widget.currentUserName[0].toUpperCase() : 'L',
                                    'message': reason,
                                    'imageUrl': disputeUrl,
                                    'type': 'dispute_proof',
                                    'timestamp': nowIso,
                                    'createdAt': nowIso,
                                    'isHost': false,
                                  }).catchError((_) => null);

                                  // System announcement
                                  await SupabaseService.client.from('messages').insert({
                                    'roomId': widget.roomId,
                                    'senderId': 'system',
                                    'senderName': 'APP BOT',
                                    'senderInitial': '🤖',
                                    'message': 'msg_dispute_raised_announcement'.tr(args: [widget.currentUserName]),
                                    'type': 'system',
                                    'timestamp': nowIso,
                                    'createdAt': nowIso,
                                    'isHost': false,
                                  }).catchError((_) => null);

                                  if (context.mounted) {
                                    Navigator.pop(sheetContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('msg_dispute_submitted_proof'.tr()),
                                        backgroundColor: GamerTheme.redAccent,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setSheetState(() {
                                    isSubmitting = false;
                                  });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('err_failed_submit_dispute'.tr(args: [e.toString()])),
                                        backgroundColor: GamerTheme.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text('btn_submit_dispute_proof'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Loser can remove their dispute proof
  Future<void> _removeDisputeProof({required String disputedBy}) async {
    if (disputedBy != widget.currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_cannot_delete_others_dispute'.tr()),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
      return;
    }

    try {
      final nowIso = DateTime.now().toIso8601String();
      final autoApproveTimeIso = DateTime.now().add(const Duration(minutes: 15)).toIso8601String();
      final removeDisputeData = {
        'status': 'reward_waiting',
        'disputed': false,
        'disputedBy': null,
        'disputedByName': null,
        'disputeProofUrl': null,
        'disputeReason': null,
        'disputedAt': null,
        'autoApproveAt': autoApproveTimeIso,
      };
      await SupabaseService.client.from('rooms').update(removeDisputeData).eq('id', widget.roomId).catchError((_) => null);

      try {
        await SupabaseService.client.from('tournament_rooms').update(removeDisputeData).eq('id', widget.roomId).catchError((_) => null);
      } catch (_) {}

      await SupabaseService.client.from('messages').insert({
        'roomId': widget.roomId,
        'senderId': 'system',
        'senderName': 'APP BOT',
        'senderInitial': '🤖',
        'message': 'msg_dispute_proof_removed_announcement'.tr(args: [widget.currentUserName]),
        'type': 'system',
        'timestamp': nowIso,
        'createdAt': nowIso,
        'isHost': false,
      }).catchError((_) => null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('msg_dispute_proof_removed'.tr()),
            backgroundColor: GamerTheme.cardElevated,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('err_failed_remove_dispute'.tr(args: [e.toString()])), backgroundColor: GamerTheme.redAccent),
        );
      }
    }
  }

  // Remove win proof: ONLY the person who uploaded this win proof can remove it!
  Future<void> _removeProof({required String proofUploaderId}) async {
    if (proofUploaderId != widget.currentUserId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_cannot_delete_others_win_proof'.tr()),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
      return;
    }

    try {
      final nowIso = DateTime.now().toIso8601String();
      final cancelProofData = {
        'status': 'IN_PROGRESS',
        'proofUrl': null,
        'winProofUrl': null,
        'winProofUploadedAt': null,
        'autoApproveAt': null,
        'winnerId': null,
        'winnerName': null,
        'proofUploadedBy': null,
        'proofUploadedByName': null,
        'ocrStatus': null,
        'ocrScore': 0,
        'ocrText': null,
        'detectedScreenshotName': null,
        'accountIdName': null,
        'rewardStatus': 'idle',
      };
      await SupabaseService.client.from('rooms').update(cancelProofData).eq('id', widget.roomId).catchError((_) => null);

      try {
        await SupabaseService.client.from('tournament_rooms').update(cancelProofData).eq('id', widget.roomId).catchError((_) => null);
      } catch (_) {}

      // Add system message
      await SupabaseService.client.from('messages').insert({
        'roomId': widget.roomId,
        'senderId': 'system',
        'senderName': 'APP BOT',
        'senderInitial': '🤖',
        'message': 'msg_win_proof_removed_announcement'.tr(args: [widget.currentUserName]),
        'type': 'system',
        'timestamp': nowIso,
        'createdAt': nowIso,
        'isHost': false,
      }).catchError((_) => null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('msg_win_proof_removed'.tr()),
            backgroundColor: GamerTheme.cardElevated,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing proof: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_failed_remove_proof'.tr(args: [e.toString()])),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.surfaceDark,
        elevation: 0,
        title: Text('title_custom_match_details'.tr(), style: const TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _roomStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _neonGreen));
          }
          final data = snapshot.data ?? {};
          if (data.isEmpty) {
            return Center(child: Text('err_match_not_found'.tr(), style: const TextStyle(color: Colors.white)));
          }
          final title = data['title'] ?? 'label_custom_match'.tr();
          final status = (data['status'] ?? 'OPEN').toString();
          final rewardStatus = (data['rewardStatus'] ?? 'idle').toString();
          final ocrStatus = (data['ocrStatus'] ?? '').toString();
          final isDisputed = status.toLowerCase() == 'disputed' || rewardStatus.toLowerCase() == 'disputed';
          final isCompleted = status.toLowerCase() == 'completed' || rewardStatus.toLowerCase() == 'sent';
          final isProofRejected = !isCompleted && !isDisputed &&
              (status.toLowerCase() == 'proof_rejected' ||
                  rewardStatus.toLowerCase() == 'rejected_by_app');
          final hasProof = (data['proofUrl'] != null && (data['proofUrl'] as String).isNotEmpty) ||
              (data['winProofUrl'] != null && (data['winProofUrl'] as String).isNotEmpty);
          final isRewardWaiting = !isCompleted && !isDisputed && !isProofRejected &&
              (status.toLowerCase() == 'reward_waiting' ||
                  rewardStatus.toLowerCase() == 'pending' ||
                  hasProof);
          DateTime? autoApproveAt;
          final rawAuto = data['autoApproveAt'];
          if (rawAuto is DateTime) {
            autoApproveAt = rawAuto;
          } else if (rawAuto is String) {
            autoApproveAt = DateTime.tryParse(rawAuto);
          } else if (rawAuto != null) {
            try {
              autoApproveAt = (rawAuto as dynamic).toDate();
            } catch (_) {}
          }
          final winnerId = (data['winnerId'] ?? '').toString();

          final joinedUsers = (data['joinedUsers'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];

          // Resolve host name
          String hostName = (data['hostName'] ?? '').toString().trim();
          if (hostName.isEmpty || hostName.toLowerCase() == 'host') {
            final hostId = (data['hostId'] ?? '').toString();
            for (final u in joinedUsers) {
              if (u['id'] == hostId || u['isHost'] == true) {
                final n = u['name']?.toString().trim();
                if (n != null && n.isNotEmpty && n != 'Player' && n != 'Host') {
                  hostName = n;
                  break;
                }
              }
            }
          }
          if (hostName.isEmpty || hostName.toLowerCase() == 'host') {
            hostName = 'yas';
          }
          final mapName = data['map'] ?? 'Erangel';

          // Resolve uploader's slot allocation name
          String slotName = widget.currentUserName;
          for (final u in joinedUsers) {
            if (u['id'] == widget.currentUserId) {
              final n = u['name']?.toString().trim();
              if (n != null && n.isNotEmpty && n != 'Player' && n != 'Gamer') {
                slotName = n;
                break;
              }
            }
          }

          final proofUploadedBy = (data['proofUploadedBy'] ?? data['winnerId'] ?? '').toString();
          final bool isMyWinProof = proofUploadedBy.isNotEmpty
              ? (proofUploadedBy == widget.currentUserId)
              : (winnerId == widget.currentUserId);
          final bool isMyDispute = isDisputed && data['disputedBy'] == widget.currentUserId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.teal.withOpacity(0.2)
                            : (isDisputed
                                ? GamerTheme.redAccent.withOpacity(0.2)
                                : (isProofRejected
                                    ? GamerTheme.redAccent.withOpacity(0.2)
                                    : (isRewardWaiting ? Colors.amber.withOpacity(0.2) : _neonGreen.withOpacity(0.2)))),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCompleted
                              ? Colors.tealAccent
                              : (isDisputed
                                  ? GamerTheme.redAccent
                                  : (isProofRejected
                                      ? GamerTheme.redAccent
                                      : (isRewardWaiting ? Colors.amberAccent : _neonGreen))),
                        ),
                      ),
                      child: Text(
                        isCompleted
                            ? 'status_completed_caps'.tr()
                            : (isDisputed
                                ? 'status_disputed_caps'.tr()
                                : (isProofRejected
                                    ? 'status_proof_rejected_caps'.tr()
                                    : (isRewardWaiting ? 'status_reward_waiting_caps'.tr() : status.toUpperCase()))),
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.tealAccent
                              : (isDisputed
                                  ? GamerTheme.redAccent
                                  : (isProofRejected
                                      ? GamerTheme.redAccent
                                      : (isRewardWaiting ? Colors.amberAccent : _neonGreen))),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'label_host_map_format'.tr(args: [hostName, mapName]),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (isDisputed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GamerTheme.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.redAccent.withOpacity(0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: GamerTheme.redAccent, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'heading_dispute_raised'.tr(),
                                style: const TextStyle(
                                  color: GamerTheme.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'sub_dispute_raised_review'.tr(),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isProofRejected)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: GamerTheme.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GamerTheme.redAccent.withOpacity(0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_rounded, color: GamerTheme.redAccent, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'heading_proof_rejected_mismatch'.tr(),
                                style: const TextStyle(
                                  color: GamerTheme.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'sub_proof_rejected_mismatch'.tr(),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isRewardWaiting)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                autoApproveAt != null
                                    ? () {
                                        final remaining = autoApproveAt.difference(DateTime.now());
                                        if (remaining.isNegative) return 'status_auto_approving_reward'.tr();
                                        final mins = remaining.inMinutes;
                                        final secs = remaining.inSeconds % 60;
                                        return 'status_auto_approve_in'.tr(args: [
                                          mins.toString().padLeft(2, '0'),
                                          secs.toString().padLeft(2, '0')
                                        ]);
                                      }()
                                    : 'status_awaiting_reward_confirmation'.tr(),
                                style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (!isDisputed && widget.currentUserId != winnerId)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GamerTheme.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _disputeResult,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text('btn_dispute'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'desc_reward_waiting_explanation'.tr(),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GamerTheme.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GamerTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_rounded, color: _neonGreen, size: 20),
                      const SizedBox(width: 8),
                      Text('label_your_match_id'.tr(args: [slotName]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                if (hasProof && !isCompleted) ...[
                  if (isMyWinProof) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: GamerTheme.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _removeProof(proofUploaderId: proofUploadedBy),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: GamerTheme.redAccent),
                            label: Text('btn_remove_proof'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _neonGreen,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isUploadingProof ? null : () => _pickAndUploadWinProof(slotName),
                            icon: _isUploadingProof
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.black),
                            label: Text('btn_upload_new'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Non-winner (Loser / Opponent) view:
                    if (isRewardWaiting && !isDisputed) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GamerTheme.redAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _disputeResult,
                        icon: const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.white),
                        label: Text('btn_raise_dispute_with_proof'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'sub_dispute_window_notice'.tr(),
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ),
                    ] else if (isMyDispute) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: GamerTheme.redAccent),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _removeDisputeProof(disputedBy: data['disputedBy']),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: GamerTheme.redAccent),
                        label: Text('btn_remove_dispute_proof'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GamerTheme.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GamerTheme.borderDark),
                        ),
                        child: Center(
                          child: Text(
                            'sub_win_proof_under_review'.tr(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _neonGreen,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isUploadingProof ? null : () => _pickAndUploadWinProof(slotName),
                    icon: _isUploadingProof
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(_isUploadingProof ? 'status_validating_proof'.tr() : 'btn_upload_win_proof_screenshot'.tr()),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
