import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../constants/gamer_theme.dart';
import '../../models/team_match_model.dart';
import '../../services/team_match_service.dart';
import '../team_match_room_screen.dart';

class AdminTeamMatchesScreen extends StatefulWidget {
  const AdminTeamMatchesScreen({super.key});

  @override
  State<AdminTeamMatchesScreen> createState() => _AdminTeamMatchesScreenState();
}

class _AdminTeamMatchesScreenState extends State<AdminTeamMatchesScreen> {
  final TeamMatchService _matchService = TeamMatchService();
  String _selectedFilter = 'All';

  final List<String> _filterOptions = [
    'All',
    'Disputed',
    'Proof Submitted',
    'Live',
    'Accepted',
    'Pending',
    'Verified',
    'Rejected',
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFFFB020);
      case 'Accepted':
        return const Color(0xFF00FF88);
      case 'Live':
        return const Color(0xFFFF4655);
      case 'Proof Submitted':
        return const Color(0xFF38BDF8);
      case 'Verified':
        return const Color(0xFF00FF88);
      case 'Disputed':
        return const Color(0xFFFF4655);
      case 'Rejected':
        return Colors.grey;
      default:
        return const Color(0xFFFF6B00);
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF131A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (c, u) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                errorWidget: (c, u, e) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image, color: Colors.white30))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerifyDecisionDialog(BuildContext context, TeamMatch match) {
    String? selectedWinner = match.team1Id;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161F2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Verify Match Winner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اسکرین شاٹ کی جانچ کے بعد فاتح ٹیم کا انتخاب کریں:',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
                ),
                const SizedBox(height: 14),

                // Team 1 Option
                RadioListTile<String>(
                  value: match.team1Id,
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFF00FF88),
                  title: Text(
                    match.team1Name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Claim: ${match.team1Claim ?? "None"}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                // Team 2 Option
                RadioListTile<String>(
                  value: match.team2Id,
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFF00FF88),
                  title: Text(
                    match.team2Name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Claim: ${match.team2Claim ?? "None"}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                // Draw Option
                RadioListTile<String>(
                  value: 'DRAW',
                  groupValue: selectedWinner,
                  activeColor: const Color(0xFFFFB020),
                  title: const Text('Draw (میچ برابر)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onChanged: (val) => setDialogState(() => selectedWinner = val),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Admin Notes (Optional)',
                    labelStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    filled: true,
                    fillColor: Color(0xFF10141D),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF88),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                if (selectedWinner == null) return;
                Navigator.pop(ctx);
                await _matchService.adminVerifyMatch(
                  matchId: match.matchId,
                  winnerTeamId: selectedWinner!,
                  adminIdentifier: 'Admin',
                  notes: notesController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Match verified & winner recorded to leaderboard!'),
                      backgroundColor: Color(0xFF00FF88),
                    ),
                  );
                }
              },
              child: const Text('Confirm Winner 🏆', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context, TeamMatch match) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cancel_outlined, color: Color(0xFFFF4655), size: 22),
            SizedBox(width: 8),
            Text('Reject Match / Proof', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              match.proofAttempts >= 1
                  ? 'یہ اس میچ کا ${match.proofAttempts + 1}واں ثبوت مسترد ہو گا۔ اگر یہ دوسرا مسترد ہوا تو میچ مستقل طور پر Rejected ہو جائے گا۔'
                  : 'کیا آپ واقعی اس ثبوت کو مسترد کرنا چاہتے ہیں؟ ٹیم کے تمام ممبران کو وجہ کے ساتھ نوٹیفکیشن جائے گا۔',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'نیا Admin Note لکھیں (Reason)',
                hintText: 'مثلاً: اسکرین شاٹ میں ID یا نتیجہ واضح نہیں ہے',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                labelStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                filled: true,
                fillColor: Color(0xFF10141D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4655),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim().isEmpty
                  ? 'اسکرین شاٹ میں ID یا نتیجہ صاف نہیں ہے'
                  : reasonController.text.trim();
              Navigator.pop(ctx);
              await _matchService.adminRejectMatch(
                match.matchId,
                'Admin',
                reason: reason,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ میچ ثبوت مسترد کر دیا گیا اور ٹیم ممبران کو اطلاع بھیج دی گئی!'),
                    backgroundColor: Color(0xFFFF4655),
                  ),
                );
              }
            },
            child: const Text('Reject Proof', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRequestNewProofDialog(BuildContext context, TeamMatch match) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.replay_rounded, color: Color(0xFFFF6B00), size: 22),
            SizedBox(width: 8),
            Text('Request New Proof', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ٹیم کو اطلاع جائے گی: "ایڈمن نے نیا ثبوت مانگا ہے، براہ کرم دوبارہ اپلوڈ کریں"۔ میچ دوبارہ Disputed/Active ہو جائے گا اور ٹیم نیا اسکرین شاٹ اپلوڈ کر سکے گی۔',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'نیا Admin Note لکھیں (Reason)',
                hintText: 'مثلاً: اسکرین شاٹ میں ID اور نتیجہ صاف نہیں ہے، براہ کرم نیا ثبوت اپلوڈ کریں۔',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                labelStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                filled: true,
                fillColor: Color(0xFF10141D),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              await _matchService.adminRequestNewProof(
                match.matchId,
                'Admin',
                reason: reason,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📸 ٹیم کو نیا ثبوت اپلوڈ کرنے کی درخواست بھیج دی گئی!'),
                    backgroundColor: Color(0xFFFF6B00),
                  ),
                );
              }
            },
            child: const Text('Send Request 📸', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Chips Row (Priority for Disputed matches)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFF131A29),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filterOptions.map((f) {
                final isSel = _selectedFilter == f;
                final isDisputed = f == 'Disputed';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      isDisputed ? '⚠️ Disputed (Priority)' : f,
                      style: TextStyle(
                        color: isSel ? Colors.black : (isDisputed ? const Color(0xFFFF4655) : Colors.white),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: isDisputed ? const Color(0xFFFF4655) : const Color(0xFF00FF88),
                    backgroundColor: const Color(0xFF1A2234),
                    onSelected: (val) {
                      setState(() => _selectedFilter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Stream List of Matches
        Expanded(
          child: StreamBuilder<List<TeamMatch>>(
            stream: _matchService.getAllMatchesStream(statusFilter: _selectedFilter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00)));
              }

              final matches = snapshot.data ?? [];

              if (matches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sports_esports_rounded, size: 48, color: Color(0xFF8B949E)),
                      const SizedBox(height: 12),
                      Text(
                        'No matches found in "$_selectedFilter"',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  final statusColor = _getStatusColor(match.status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: match.isDisputed ? const Color(0xFF1F1522) : const Color(0xFF131A29),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: match.isDisputed ? const Color(0xFFFF4655) : const Color(0xFF2A3447),
                        width: match.isDisputed ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header: Game, Mode, Status
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${match.game} • ${match.mode}',
                                style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.w900, fontSize: 11),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                match.status.toUpperCase(),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Match Teams
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    match.team1Name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text('Leader: ${match.team1LeaderName}', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('VS', style: TextStyle(color: Color(0xFFFF4655), fontWeight: FontWeight.w900, fontSize: 14)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    match.team2Name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                  Text('Leader: ${match.team2LeaderName}', style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Match Time & Dispute Banner
                        Text(
                          'Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(match.matchTime)}',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11.5),
                        ),

                        if (match.proofAttempts > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (match.proofAttempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFFB020)).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: match.proofAttempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFFB020),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.camera_alt_outlined,
                                      size: 13,
                                      color: match.proofAttempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFFB020),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Attempt ${match.proofAttempts}/2',
                                      style: TextStyle(
                                        color: match.proofAttempts >= 2 ? const Color(0xFFFF4655) : const Color(0xFFFFB020),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (match.lastProofAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Submitted: ${DateFormat('dd MMM, hh:mm a').format(match.lastProofAt!)}',
                                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10.5),
                                ),
                              ] else if (match.rejectedAt != null && !match.isProofSubmitted) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'Rejected on: ${DateFormat('dd MMM, hh:mm a').format(match.rejectedAt!)}',
                                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 10.5),
                                ),
                              ],
                            ],
                          ),
                        ],

                        // New proof submitted indicator (waiting for admin review, old note is cleared)
                        if (match.isProofSubmitted) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mark_email_unread_rounded, color: Color(0xFF38BDF8), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    match.proofAttempts >= 2
                                        ? 'نیا ثبوت موصول ہو چکا ہے (Attempt 2/2) - جائزہ لے کر Verify یا Reject کریں'
                                        : 'ثبوت موصول ہو چکا ہے (Proof Submitted) - جائزہ لے کر Verify یا Reject کریں',
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (match.adminNote != null && match.adminNote!.isNotEmpty) ...[
                          // Only show Admin Note if NOT in 'Proof Submitted' state (old note hidden when new proof uploaded)
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4655).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_outlined, color: Color(0xFFFF4655), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Admin Note: ${match.adminNote}',
                                    style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (match.disputeReason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4655).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFFF4655), size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    match.disputeReason,
                                    style: const TextStyle(color: Color(0xFFFF4655), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (match.isVerified && match.winnerName != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '🏆 Winner: ${match.winnerName} (Verified by ${match.verifiedBy})',
                            style: const TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFF2A3447), height: 1),
                        const SizedBox(height: 10),

                        // Screenshots buttons + Admin Verify/Reject Actions
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Team 1 Screenshot button
                            if (match.team1Proof != null && match.team1Proof!.isNotEmpty) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  side: const BorderSide(color: Color(0xFF38BDF8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 30),
                                ),
                                icon: const Icon(Icons.image_outlined, size: 14),
                                label: Text(
                                  match.proofAttempts > 0
                                      ? '${match.team1Name} Proof (Attempt ${match.proofAttempts}/2)'
                                      : '${match.team1Name} Proof',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _showImageDialog(
                                  context,
                                  match.team1Proof!,
                                  '${match.team1Name} Proof (Attempt ${match.proofAttempts}/2)',
                                ),
                              ),
                            ],

                            // Team 2 Screenshot button
                            if (match.team2Proof != null && match.team2Proof!.isNotEmpty) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF38BDF8),
                                  side: const BorderSide(color: Color(0xFF38BDF8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 30),
                                ),
                                icon: const Icon(Icons.image_outlined, size: 14),
                                label: Text(
                                  match.proofAttempts > 0
                                      ? '${match.team2Name} Proof (Attempt ${match.proofAttempts}/2)'
                                      : '${match.team2Name} Proof',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onPressed: () => _showImageDialog(
                                  context,
                                  match.team2Proof!,
                                  '${match.team2Name} Proof (Attempt ${match.proofAttempts}/2)',
                                ),
                              ),
                            ],

                            // Open Match Room button
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 30),
                              ),
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              label: const Text('Room & Chat', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeamMatchRoomScreen(matchId: match.matchId),
                                  ),
                                );
                              },
                            ),

                            // Verify, Request New Proof & Reject Actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Reject Button
                                if (!match.isRejected) ...[
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF4655),
                                      side: const BorderSide(color: Color(0xFFFF4655)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                    ),
                                    onPressed: () => _showRejectDialog(context, match),
                                    child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                ],

                                // 2. Request New Proof Button
                                if (!match.isVerified && match.proofAttempts < 2) ...[
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFFF6B00),
                                      side: const BorderSide(color: Color(0xFFFF6B00)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                    ),
                                    icon: const Icon(Icons.replay_rounded, size: 13),
                                    label: const Text('Request New Proof', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showRequestNewProofDialog(context, match),
                                  ),
                                  const SizedBox(width: 6),
                                ],

                                // 3. Verify Winner Button
                                if (!match.isVerified) ...[
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00FF88),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _showVerifyDecisionDialog(context, match),
                                    child: const Text('Verify Winner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
