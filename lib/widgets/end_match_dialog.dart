import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class EndMatchBottomSheet extends StatefulWidget {
  final String activeMatchId;
  final String myTeamId;
  final String opponentId;
  final String myTeamName;
  final String opponentName;

  const EndMatchBottomSheet({
    super.key,
    required this.activeMatchId,
    required this.myTeamId,
    required this.opponentId,
    this.myTeamName = 'My Team',
    this.opponentName = 'Opponent',
  });

  static Future<bool?> show(
    BuildContext context, {
    required String activeMatchId,
    required String myTeamId,
    required String opponentId,
    String myTeamName = 'My Team',
    String opponentName = 'Opponent',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EndMatchBottomSheet(
        activeMatchId: activeMatchId,
        myTeamId: myTeamId,
        opponentId: opponentId,
        myTeamName: myTeamName,
        opponentName: opponentName,
      ),
    );
  }

  @override
  State<EndMatchBottomSheet> createState() => _EndMatchBottomSheetState();
}

class _EndMatchBottomSheetState extends State<EndMatchBottomSheet> {
  String? _selectedResult; // 'win', 'loss', 'draw'
  File? _pickedImage;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null) {
        setState(() {
          _pickedImage = File(picked.path);
        });
      }
    } catch (e) {
      debugPrint('[EndMatchDialog] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  Future<void> _updateTeamStatsInDb({
    required String teamId,
    required int addW,
    required int addL,
    required int addD,
    required int addPts,
  }) async {
    // 1. Supabase teams table
    try {
      final tUuid = SupabaseService.toUuid(teamId);
      final res = await SupabaseService.client
          .from('teams')
          .select('wins, losses, draws, points')
          .eq('id', tUuid)
          .maybeSingle();

      if (res != null) {
        final currentWins = (res['wins'] as num?)?.toInt() ?? 0;
        final currentLosses = (res['losses'] as num?)?.toInt() ?? 0;
        final currentDraws = (res['draws'] as num?)?.toInt() ?? 0;
        final currentPoints = (res['points'] as num?)?.toInt() ?? 0;

        await SupabaseService.client.from('teams').update({
          'wins': currentWins + addW,
          'losses': currentLosses + addL,
          'draws': currentDraws + addD,
          'points': currentPoints + addPts,
        }).eq('id', tUuid);
      }
    } catch (e) {
      debugPrint('[EndMatchDialog] Supabase team stats update error: $e');
    }

    // 2. Firestore teams collection
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('teams').doc(teamId);
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.update({
          'wins': FieldValue.increment(addW),
          'losses': FieldValue.increment(addL),
          'draws': FieldValue.increment(addD),
          'points': FieldValue.increment(addPts),
        });
      }
    } catch (e) {
      debugPrint('[EndMatchDialog] Firestore team stats update error: $e');
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedResult == null || _pickedImage == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Ensure bucket 'match_proofs' exists if possible
      try {
        await SupabaseService.client.storage.createBucket(
          'match_proofs',
          const BucketOptions(public: true),
        );
      } catch (_) {}

      // 2. Upload image to 'match_proofs' with fallback to screenshots
      String? proofUrl;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${widget.activeMatchId}_$timestamp.jpg';

      try {
        await SupabaseService.client.storage.from('match_proofs').upload(
              fileName,
              _pickedImage!,
              fileOptions: const FileOptions(upsert: true),
            );
        proofUrl = SupabaseService.client.storage
            .from('match_proofs')
            .getPublicUrl(fileName);
      } catch (e) {
        debugPrint('[EndMatchDialog] match_proofs client.storage upload error: $e, trying REST upload');
        proofUrl = await SupabaseService.uploadFile(
          file: _pickedImage!,
          bucket: 'match_proofs',
          customFileName: fileName,
        );
      }

      // 3. Determine winner id
      final myUuid = SupabaseService.toUuid(widget.myTeamId);
      final opponentUuid = SupabaseService.toUuid(widget.opponentId);
      String? winnerTeamId;
      if (_selectedResult == 'win') {
        winnerTeamId = myUuid;
      } else if (_selectedResult == 'loss') {
        winnerTeamId = opponentUuid;
      } else {
        winnerTeamId = null; // draw
      }

      // 4. Update active_matches table in Supabase to under_review with proof_status pending
      try {
        await SupabaseService.client.from('active_matches').update({
          'status': 'under_review',
          'proof_status': 'pending',
          if (winnerTeamId != null) 'winner_team_id': winnerTeamId,
          if (proofUrl != null) 'proof_url': proofUrl,
          'result': _selectedResult,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', widget.activeMatchId);
      } catch (e) {
        debugPrint('[EndMatchDialog] Update with proof_status failed: $e, fallback status under_review');
        await SupabaseService.client.from('active_matches').update({
          'status': 'under_review',
          if (winnerTeamId != null) 'winner_team_id': winnerTeamId,
          if (proofUrl != null) 'proof_url': proofUrl,
          'result': _selectedResult,
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', widget.activeMatchId);
      }

      // Note: Team points update has been removed from user side as instructed.
      // Points/Win/Loss are now verified and updated by Admin on Accept in Admin Panel.

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[EndMatchDialog] Error submitting proof: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting proof: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _selectedResult != null && _pickedImage != null && !_isSubmitting;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131A29),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4655).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.military_tech_rounded, color: Color(0xFFFF4655), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match Khatam - Winning Proof',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Match ka result aur screenshot submit karein',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Result selection label
            const Text(
              'Select Result (Nateeja):',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            // Radio options
            _buildResultOption(
              label: 'We Won (Hum Jeete)',
              sublabel: 'Winner +1 Win, +3 Points',
              value: 'win',
              color: const Color(0xFF00FF88),
              icon: Icons.emoji_events_rounded,
            ),
            const SizedBox(height: 8),
            _buildResultOption(
              label: 'We Lost (Hum Hare)',
              sublabel: 'Opponent +1 Win, +3 Points',
              value: 'loss',
              color: const Color(0xFFFF4655),
              icon: Icons.thumb_down_rounded,
            ),
            const SizedBox(height: 8),
            _buildResultOption(
              label: 'Draw',
              sublabel: 'Dono Teams +1 Draw, +1 Point',
              value: 'draw',
              color: const Color(0xFFFFB800),
              icon: Icons.handshake_rounded,
            ),
            const SizedBox(height: 20),

            // Upload proof screenshot section
            const Text(
              'Winning Proof Screenshot:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 10),

            if (_pickedImage == null)
              InkWell(
                onTap: _isSubmitting ? null : _pickImage,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2436),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A3447), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF1877F2), size: 32),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload Proof Screenshot',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Scoreboard ya result screen ka screenshot select karein',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2436),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.6), width: 1.5),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _pickedImage!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 16),
                            SizedBox(width: 6),
                            Text('Screenshot Selected', style: TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _isSubmitting ? null : _pickImage,
                          icon: const Icon(Icons.sync_rounded, size: 14, color: Colors.white70),
                          label: const Text('Change', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: canSubmit ? _handleSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Submitting Proof...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      )
                    : const Text(
                        'Submit Proof',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultOption({
    required String label,
    required String sublabel,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedResult == value;

    return InkWell(
      onTap: _isSubmitting ? null : () => setState(() => _selectedResult = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : const Color(0xFF1B2436),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF2A3447),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : const Color(0xFF8B949E), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      color: isSelected ? color.withOpacity(0.9) : const Color(0xFF8B949E),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedResult,
              onChanged: _isSubmitting ? null : (v) => setState(() => _selectedResult = v),
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }
}
