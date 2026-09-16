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

      // 3. Update room document: Set status to reward_waiting & rewardStatus to pending
      await roomRef.update({
        'status': 'reward_waiting',
        'proofUrl': uploadedUrl,
        'winProofUrl': uploadedUrl,
        'winProofUploadedAt': FieldValue.serverTimestamp(),
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
          final status = data['status'] ?? 'OPEN';
          final joinedUsers = (data['joinedUsers'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];

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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Status: $status', style: const TextStyle(color: _neonGreen, fontSize: 14)),
                const SizedBox(height: 12),
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
            ),
          );
        },
      ),
    );
  }
}
