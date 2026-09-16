import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/gamer_theme.dart';
import '../services/win_proof_validator.dart';
import '../services/cloudinary_service.dart';

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

      // 1. Upload screenshot to Cloudinary
      final uploadedUrl = await CloudinaryService.uploadFile(
        file: file,
        folder: 'win_proofs',
      );

      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        throw Exception('Image upload failed');
      }

      // 2. Validate win proof and match player name
      final validationResult = await WinProofValidator.validate(
        imageFile: file,
        userId: widget.currentUserId,
        accountIdName: accountIdName,
        roomId: widget.roomId,
      );

      final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);

      final now = DateTime.now();
      final autoApproveAt = Timestamp.fromDate(now.add(const Duration(minutes: 15)));

      // 3. Update room document: Status always goes to reward_waiting (never auto block on mismatch)
      await roomRef.update({
        'status': 'reward_waiting',
        'proofUrl': uploadedUrl,
        'winProofUrl': uploadedUrl,
        'winProofUploadedAt': FieldValue.serverTimestamp(),
        'autoApproveAt': autoApproveAt,
        'winnerId': widget.currentUserId,
        'winnerName': widget.currentUserName,
        'ocrStatus': validationResult.status,
        'ocrScore': validationResult.score,
        'ocrText': validationResult.fullOcrText.length > 300
            ? validationResult.fullOcrText.substring(0, 300)
            : validationResult.fullOcrText,
        'rewardStatus': 'pending',
        'detectedScreenshotName': validationResult.detectedScreenshotName,
        'accountIdName': validationResult.accountIdName,
      });

      // Sync to tournament_rooms collection
      try {
        await FirebaseFirestore.instance.collection('tournament_rooms').doc(widget.roomId).set({
          'status': 'reward_waiting',
          'winProofUrl': uploadedUrl,
          'winProofUploadedAt': FieldValue.serverTimestamp(),
          'autoApproveAt': autoApproveAt,
          'winnerId': widget.currentUserId,
          'winnerName': widget.currentUserName,
          'rewardStatus': 'pending',
        }, SetOptions(merge: true));
      } catch (_) {}

      // 4. Add win proof message to room chat
      await roomRef.collection('messages').add({
        'senderId': widget.currentUserId,
        'senderName': widget.currentUserName,
        'senderInitial': widget.currentUserName.isNotEmpty ? widget.currentUserName[0].toUpperCase() : 'G',
        'message': 'Submitted Match Win Proof',
        'imageUrl': uploadedUrl,
        'type': 'win_proof',
        'ocrStatus': validationResult.status,
        'ocrScore': validationResult.score,
        'ocrText': validationResult.fullOcrText,
        'detectedName': validationResult.detectedScreenshotName,
        'accountName': validationResult.accountIdName,
        'aiCheckMsg': validationResult.message,
        'timestamp': FieldValue.serverTimestamp(),
        'isHost': false,
      });

      // 5. Add AI Bot check message to room chat
      await roomRef.collection('messages').add({
        'senderId': 'system',
        'senderName': 'APP BOT',
        'senderInitial': '🤖',
        'message': validationResult.message,
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'isHost': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              validationResult.isVerified
                  ? '✅ Verified - Name Matched'
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
            content: Text('Failed to submit proof: $e'),
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
    try {
      final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
      await roomRef.update({
        'status': 'disputed',
        'rewardStatus': 'disputed',
        'disputedAt': FieldValue.serverTimestamp(),
        'disputedBy': widget.currentUserId,
        'disputedByName': widget.currentUserName,
      });

      try {
        await FirebaseFirestore.instance.collection('tournament_rooms').doc(widget.roomId).update({
          'status': 'disputed',
          'rewardStatus': 'disputed',
        });
      } catch (_) {}

      await roomRef.collection('messages').add({
        'senderId': 'system',
        'senderName': 'DISPUTE BOT',
        'senderInitial': '⚠️',
        'message': '⚠️ Dispute Raised by ${widget.currentUserName}! Under review by Admin. Loser claims winner screenshot is fake/wrong.',
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'isHost': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Dispute raised! Match result is now under review by Admin.'),
            backgroundColor: GamerTheme.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to raise dispute: $e'), backgroundColor: GamerTheme.redAccent),
        );
      }
    }
  }

  Future<void> _removeProof() async {
    try {
      final roomRef = FirebaseFirestore.instance.collection('rooms').doc(widget.roomId);
      await roomRef.update({
        'status': 'IN_PROGRESS',
        'proofUrl': FieldValue.delete(),
        'winProofUrl': FieldValue.delete(),
        'winProofUploadedAt': FieldValue.delete(),
        'autoApproveAt': FieldValue.delete(),
        'winnerId': FieldValue.delete(),
        'winnerName': FieldValue.delete(),
        'ocrStatus': FieldValue.delete(),
        'ocrScore': 0,
        'ocrText': FieldValue.delete(),
        'detectedScreenshotName': FieldValue.delete(),
        'accountIdName': FieldValue.delete(),
        'rewardStatus': 'idle',
      });

      try {
        await FirebaseFirestore.instance.collection('tournament_rooms').doc(widget.roomId).update({
          'status': 'IN_PROGRESS',
          'winProofUrl': FieldValue.delete(),
          'winProofUploadedAt': FieldValue.delete(),
          'autoApproveAt': FieldValue.delete(),
          'winnerId': FieldValue.delete(),
          'winnerName': FieldValue.delete(),
          'rewardStatus': 'idle',
        });
      } catch (_) {}

      // Add system message
      await roomRef.collection('messages').add({
        'senderId': 'system',
        'senderName': 'APP BOT',
        'senderInitial': '🤖',
        'message': '🗑️ Rejected win proof was removed. You can now upload a new screenshot.',
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'isHost': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Rejected proof removed. You can upload a new screenshot now.'),
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
            content: Text('Failed to remove proof: $e'),
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
        title: const Text('Custom Match Details', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rooms').doc(widget.roomId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _neonGreen));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Match not found', style: TextStyle(color: Colors.white)));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final title = data['title'] ?? 'Custom Match';
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
          final autoApproveAt = (data['autoApproveAt'] as Timestamp?)?.toDate();
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
                            ? 'COMPLETED'
                            : (isDisputed
                                ? '⚠️ DISPUTED'
                                : (isProofRejected
                                    ? '❌ PROOF REJECTED'
                                    : (isRewardWaiting ? 'REWARD WAITING' : status.toUpperCase()))),
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
                  'Host: $hostName • $mapName',
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
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: GamerTheme.redAccent, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠️ DISPUTE RAISED - UNDER REVIEW',
                                style: TextStyle(
                                  color: GamerTheme.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Dispute Raised! Under review by Admin. Loser claims winner screenshot is fake/wrong.',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
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
                    child: const Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: GamerTheme.redAccent, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROOF REJECTED - NAME MISMATCH',
                                style: TextStyle(
                                  color: GamerTheme.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Uploaded screenshot does not match player ID. Please remove the rejected proof or upload a new valid screenshot.',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
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
                                        if (remaining.isNegative) return 'Auto-Approving Reward...';
                                        final mins = remaining.inMinutes;
                                        final secs = remaining.inSeconds % 60;
                                        return 'Auto-Approve in ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
                                      }()
                                    : 'Awaiting Reward Confirmation',
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('⚠️ Dispute', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Winner has uploaded proof. Awaiting confirmation. Once reward sent, room will complete and auto delete in 5 mins.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
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
                      Text('Your Match ID: $slotName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (hasProof && !isCompleted) ...[
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
                          onPressed: _removeProof,
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: GamerTheme.redAccent),
                          label: const Text('🗑️ Remove Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                          label: const Text('📷 Upload New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
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
                    label: Text(_isUploadingProof ? 'Validating Proof...' : 'Upload Win Proof Screenshot'),
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
