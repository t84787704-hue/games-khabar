import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/team_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/team_service.dart';
import '../services/team_match_service.dart';

class SendTeamMatchChallengeDialog extends StatefulWidget {
  final TeamModel opponentTeam;
  final List<TeamModel> myTeams;

  const SendTeamMatchChallengeDialog({
    super.key,
    required this.opponentTeam,
    required this.myTeams,
  });

  static Future<void> show(
    BuildContext context, {
    required TeamModel opponentTeam,
    required List<TeamModel> myTeams,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendTeamMatchChallengeDialog(
        opponentTeam: opponentTeam,
        myTeams: myTeams,
      ),
    );
  }

  @override
  State<SendTeamMatchChallengeDialog> createState() => _SendTeamMatchChallengeDialogState();
}

class _SendTeamMatchChallengeDialogState extends State<SendTeamMatchChallengeDialog> {
  final TeamMatchService _matchService = TeamMatchService();

  late String _selectedMyTeamId;
  String _selectedGame = 'BGMI';
  String _selectedMode = '4v4';
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 2)));
  bool _isSending = false;

  final List<String> _games = ['BGMI', 'Free Fire', 'PUBG', 'COD'];
  final List<String> _modes = ['1v1', '2v2', '4v4', 'Squad'];

  @override
  void initState() {
    super.initState();
    if (widget.myTeams.isNotEmpty) {
      _selectedMyTeamId = widget.myTeams.first.id;
    } else {
      _selectedMyTeamId = '';
    }
    if (_games.contains(widget.opponentTeam.game)) {
      _selectedGame = widget.opponentTeam.game;
    }
  }

  TeamModel? get selectedMyTeam {
    try {
      return widget.myTeams.firstWhere((t) => t.id == _selectedMyTeamId);
    } catch (_) {
      return widget.myTeams.isNotEmpty ? widget.myTeams.first : null;
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF6B00),
            surface: Color(0xFF161B22),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFF6B00),
            surface: Color(0xFF161B22),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitChallenge() async {
    final myTeam = selectedMyTeam;
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentGamer = GamerAuthService().currentGamer;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    if (myTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('چیلنج بھیجنے کے لیے پہلے اپنی ٹیم بنائیں!'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
      return;
    }

    if (myTeam.id == widget.opponentTeam.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('آپ اپنی ہی ٹیم کو چیلنج نہیں بھیج سکتے!'),
          backgroundColor: Color(0xFFFF4655),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    final finalMatchDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final result = await _matchService.sendChallenge(
      team1Id: myTeam.id,
      team1Name: myTeam.name,
      team1LeaderId: myTeam.leaderId,
      team1LeaderName: myTeam.leaderName,
      team1Avatar: myTeam.logo.isNotEmpty ? myTeam.logo : myTeam.leaderAvatar,
      team1Members: myTeam.members,
      team2Id: widget.opponentTeam.id,
      team2Name: widget.opponentTeam.name,
      team2LeaderId: widget.opponentTeam.leaderId,
      team2LeaderName: widget.opponentTeam.leaderName,
      team2Avatar: widget.opponentTeam.logo.isNotEmpty ? widget.opponentTeam.logo : widget.opponentTeam.leaderAvatar,
      team2Members: widget.opponentTeam.members,
      game: _selectedGame,
      mode: _selectedMode,
      matchTime: finalMatchDateTime,
      entryFee: 'Free (مفت)',
    );

    setState(() => _isSending = false);

    if (mounted) {
      final isSuccess = result['success'] == true;
      final errorMsg = result['error'] as String? ?? 'چیلنج بھیجنے میں خرابی پیش آئی';

      if (isSuccess) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚔️ چیلنج کامیابی سے ${widget.opponentTeam.name} کو بھیج دیا گیا!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFFF6B00),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        // Show the specific error (e.g. already active challenge)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF4655),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final opponent = widget.opponentTeam;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF131A29),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF2A3447), width: 1.5)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('⚔️', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SEND TEAM CHALLENGE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'ٹیم vs ٹیم مقابلے کا چیلنج بھیجیں',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF1E293B), height: 1),
            const SizedBox(height: 16),

            // Opponent Team Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2234),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF4655).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF4655), width: 1.5),
                      image: opponent.logo.isNotEmpty
                          ? DecorationImage(image: NetworkImage(opponent.logo), fit: BoxFit.cover)
                          : null,
                      color: const Color(0xFF26334D),
                    ),
                    child: opponent.logo.isEmpty
                        ? const Center(child: Icon(Icons.shield_rounded, color: Colors.white70, size: 22))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'مخالف ٹیم (Opponent Team)',
                          style: TextStyle(color: Color(0xFFFF4655), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${opponent.name} [${opponent.tag}]',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        Text(
                          'Leader: ${opponent.leaderName} • Game: ${opponent.game}',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Select My Team
            if (widget.myTeams.isNotEmpty) ...[
              const Text(
                'آپ کی ٹیم (Select Your Team):',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A3447)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.myTeams.any((t) => t.id == _selectedMyTeamId)
                        ? _selectedMyTeamId
                        : widget.myTeams.first.id,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF161F2E),
                    items: widget.myTeams.map((t) {
                      return DropdownMenuItem<String>(
                        value: t.id,
                        child: Text(
                          '${t.name} [${t.tag}]',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMyTeamId = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Game Selection
            const Text(
              'گیم کا انتخاب (Game):',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _games.map((g) {
                final isSel = _selectedGame == g;
                return ChoiceChip(
                  label: Text(g, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  selected: isSel,
                  selectedColor: const Color(0xFFFF6B00),
                  backgroundColor: const Color(0xFF1A2234),
                  onSelected: (val) {
                    if (val) setState(() => _selectedGame = g);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Mode Selection
            const Text(
              'میچ کا موڈ (Match Mode):',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _modes.map((m) {
                final isSel = _selectedMode == m;
                return ChoiceChip(
                  label: Text(m, style: TextStyle(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  selected: isSel,
                  selectedColor: const Color(0xFF00FF88),
                  backgroundColor: const Color(0xFF1A2234),
                  onSelected: (val) {
                    if (val) setState(() => _selectedMode = m);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Date & Time Picker
            const Text(
              'میچ کا وقت اور تاریخ (Date & Time):',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2A3447)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFFF6B00)),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161F2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2A3447)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF00FF88)),
                          const SizedBox(width: 8),
                          Text(
                            _selectedTime.format(context),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Free Fair Play Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF88).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF00FF88), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'انٹری: بالکل مفت (Free) — خالص اسکلز اور لیڈر بورڈ رینکنگ کے لیے',
                      style: TextStyle(color: Color(0xFF00FF88), fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Send Challenge Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _submitChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.flash_on_rounded, size: 20, color: Colors.black),
                label: Text(
                  _isSending ? 'Sending Challenge...' : 'CHALLENGE TEAM NOW ⚔️',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
