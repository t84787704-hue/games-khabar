import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/squad_service.dart';
import '../widgets/squad_card.dart';

class SquadFinderScreen extends StatefulWidget {
  const SquadFinderScreen({super.key});

  @override
  State<SquadFinderScreen> createState() => _SquadFinderScreenState();
}

class _SquadFinderScreenState extends State<SquadFinderScreen> {
  final SquadService _squadService = SquadService();
  final GamerAuthService _authService = GamerAuthService();

  // Guard to prevent duplicate rapid posting
  bool _isPosting = false;

  // Local list to immediately display created posts without waiting for Firestore stream
  final List<SquadPost> _localSquads = [];

  // Top Filter bar state
  String _filterGame = 'All';
  String _filterMode = 'All';
  String _filterTier = 'All';
  String _filterKd = 'Any';

  final List<String> _gameFilterOptions = ['All', 'PUBG Mobile', 'BGMI', 'Free Fire', 'COD Mobile', 'Valorant'];
  final List<String> _modeFilterOptions = ['All', 'TPP', 'FPP', 'Rank Push', 'Classic Squad'];
  final List<String> _tierFilterOptions = ['All', 'Ace', 'Conqueror', 'Crown', 'Diamond'];
  final List<String> _kdFilterOptions = ['Any', '2.0+', '3.0+', '4.0+', '5.0+'];

  // Create Squad Card State
  String _cardGame = 'PUBG Mobile';
  String _cardMode = 'TPP'; // TPP / FPP
  String _cardTier = 'Ace'; // Ace / Conqueror / Crown
  String _cardRole = 'Entry Fragger'; // Entry Fragger / IGL / Support
  bool _cardMicRequired = true; // ON
  String _cardLanguage = 'English'; // English

  late final TextEditingController _uidController;
  String? _uidErrorText;

  @override
  void initState() {
    super.initState();
    _uidController = TextEditingController();
    _loadSavedUidForGame(_cardGame);
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUidForGame(String game) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('uid_$game');
      if (saved != null && saved.isNotEmpty) {
        _uidController.text = saved;
      } else {
        final profileGameId = _authService.currentGamer?.gameId ?? '';
        if (profileGameId.isNotEmpty) {
          _uidController.text = profileGameId;
        } else {
          _uidController.text = '';
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveUidForGame(String game, String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid_$game', uid);
    } catch (_) {}
  }

  final List<String> _cardGameOptions = ['PUBG Mobile', 'BGMI', 'Free Fire', 'COD Mobile', 'Valorant'];
  final List<String> _cardTierOptions = ['Ace', 'Conqueror', 'Crown', 'Diamond'];
  final List<String> _cardLangOptions = ['English', 'Hindi', 'Urdu', 'Punjabi'];

  Future<void> _createSquadFromCard() async {
    if (_isPosting) return;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to create a squad!')),
      );
      return;
    }

    final enteredUid = _uidController.text.trim();
    if (enteredUid.isEmpty) {
      setState(() => _uidErrorText = 'Please enter your ${_cardGame} UID');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your ${_cardGame} UID'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }
    if (enteredUid.length < 4) {
      setState(() => _uidErrorText = 'UID must be at least 4 digits');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UID must be at least 4 digits'),
          backgroundColor: GamerTheme.redAccent,
        ),
      );
      return;
    }
    setState(() => _uidErrorText = null);

    await _saveUidForGame(_cardGame, enteredUid);

    final currentGamer = _authService.currentGamer;
    final String uid = authUser.uid;
    final String email = authUser.email ?? '';
    final String gamerName = (currentGamer?.displayName.isNotEmpty == true)
        ? currentGamer!.displayName
        : (authUser.displayName ?? 'Squad Leader');
    final String gamerTag = (currentGamer?.username.isNotEmpty == true)
        ? currentGamer!.username
        : 'gamer';
    final String avatar = (currentGamer?.photoUrl.isNotEmpty == true)
        ? currentGamer!.photoUrl
        : (authUser.photoURL ?? '');

    setState(() => _isPosting = true);

    const double defaultKd = 3.0;
    final desc = 'Looking for $_cardRole in $_cardMode ($cardTierNeeded: $_cardTier). Mic: ${_cardMicRequired ? "Yes" : "No"}.';

    final postData = {
      'id': uid,
      'postId': uid,
      'squadId': uid,
      'leaderUid': enteredUid,
      'gameUid': enteredUid,
      'inGameUid': enteredUid,
      'bgmiUid': enteredUid,
      'bgmiUidToCopy': enteredUid,
      'hostId': uid,
      'userId': uid,
      'ownerId': uid,
      'ownerEmail': email,
      'hostEmail': email,
      'username': gamerTag,
      'ownerTag': gamerTag,
      'displayName': gamerName,
      'title': '$gamerName ($_cardRole)',
      'userAvatar': avatar,
      'avatar': avatar,
      'userRank': _cardTier,
      'tier': _cardTier,
      'tierNeeded': _cardTier,
      'kd': defaultKd,
      'kdNeeded': defaultKd,
      'micMandatory': _cardMicRequired,
      'micOn': _cardMicRequired,
      'lang': _cardLanguage,
      'language': _cardLanguage,
      'mode': _cardMode,
      'role': _cardRole,
      'description': desc,
      'game': _cardGame,
      'isActive': true,
      'members': [uid],
      'memberCount': 1,
      'membersCount': 1,
      'requestedCount': 0,
      'joinRequests': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance.collection('lfg_posts').doc(uid).set(postData);
      try {
        await FirebaseFirestore.instance.collection('squads').doc(uid).set(postData);
      } catch (_) {}
      try {
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(uid);
        await chatRef.set({
          'squadId': uid,
          'chatId': uid,
          'postId': uid,
          'hostId': uid,
          'leaderUid': enteredUid,
          'gameUid': enteredUid,
          'hostEmail': email,
          'createdAt': FieldValue.serverTimestamp(),
          'members': [uid],
          'isActive': true,
          'title': gamerName,
          'displayName': gamerName,
        }, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      debugPrint('[SquadFinderScreen] Error saving squad: $e');
    }

    final post = SquadPost(
      id: uid,
      userId: uid,
      ownerEmail: email,
      username: gamerTag,
      displayName: gamerName,
      userAvatar: avatar,
      userRank: _cardTier,
      game: _cardGame,
      tierNeeded: _cardTier,
      kdNeeded: defaultKd,
      micOn: _cardMicRequired,
      language: _cardLanguage,
      mode: _cardMode,
      description: desc,
      gameUid: enteredUid,
      isActive: true,
      joinRequests: const [],
      members: [uid],
      membersCount: 1,
      requestedCount: 0,
      createdAt: DateTime.now(),
    );

    setState(() {
      _isPosting = false;
      _localSquads.removeWhere((p) => p.id == uid);
      _localSquads.insert(0, post);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔥 Squad created for $_cardGame! UID: $enteredUid'),
          backgroundColor: const Color(0xFFFF6B00),
        ),
      );
    }
  }

  String get cardTierNeeded => 'Tier';

  @override
  void initState() {
    super.initState();
    // Removed auto-create / auto-repair logic from initState
  }

  List<SquadPost> _combineSquads(List<SquadPost> streamSquads) {
    final Map<String, SquadPost> map = {};
    for (final s in streamSquads) {
      map[s.id] = s;
    }
    for (final s in _localSquads) {
      if (!map.containsKey(s.id)) {
        map[s.id] = s;
      }
    }
    final combined = map.values.toList();
    combined.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.now();
      final bTime = b.createdAt ?? DateTime.now();
      return bTime.compareTo(aTime);
    });
    debugPrint('[SquadFinderScreen] Fetched docs length: ${combined.length} (Stream: ${streamSquads.length}, Local: ${_localSquads.length})');
    return combined;
  }

  Future<void> _openCreateSquadSheet() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to post squad requests!')),
      );
      return;
    }

    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to post squad requests!')),
      );
      return;
    }

    // Check if user already has an active squad in lfg_posts
    try {
      final docRef = FirebaseFirestore.instance.collection('lfg_posts').doc(authUser.uid);
      final existing = await docRef.get();
      if (existing.exists && existing.data()?['isActive'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aapka active squad pehle se hai!'),
              backgroundColor: GamerTheme.accentOrange,
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('[SquadFinderScreen] Pre-check error: $e');
    }

    if (!mounted) return;

    String selectedMode = 'Rank Push';
    String selectedTier = 'Ace+';
    double selectedKd = 3.0;
    bool isMicOn = true;
    String selectedLang = 'Hindi';
    final descController = TextEditingController();
    final uidController = TextEditingController(text: currentGamer.gameId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GamerTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: GamerTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Text('🛡️', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Text(
                      'POST SQUAD REQUIREMENT (LFG)',
                      style: TextStyle(
                        color: GamerTheme.textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mode
                const Text('GAME MODE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ['Rank Push', 'Classic Squad', 'Payload', 'TDM Tourney'].map((m) {
                    final isSel = selectedMode == m;
                    return ChoiceChip(
                      label: Text(m, style: TextStyle(color: isSel ? GamerTheme.bgDark : GamerTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 12)),
                      selected: isSel,
                      selectedColor: GamerTheme.accentBlue,
                      backgroundColor: GamerTheme.bgDark,
                      onSelected: (v) => setSheetState(() => selectedMode = m),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 14),

                // Min Tier Needed & Min KD
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MIN TIER REQUIRED', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: GamerTheme.bgDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: GamerTheme.borderDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedTier,
                                isExpanded: true,
                                dropdownColor: GamerTheme.cardDark,
                                items: ['Diamond+', 'Crown+', 'Ace+', 'Conqueror', 'Any Tier']
                                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setSheetState(() => selectedTier = v ?? selectedTier),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MIN K/D: ${selectedKd.toStringAsFixed(1)}+', style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          Slider(
                            value: selectedKd,
                            min: 1.0,
                            max: 6.0,
                            divisions: 10,
                            activeColor: GamerTheme.accentOrange,
                            inactiveColor: GamerTheme.borderDark,
                            onChanged: (v) => setSheetState(() => selectedKd = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Mic & Language
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mic Mandatory', style: TextStyle(color: GamerTheme.textWhite, fontSize: 13, fontWeight: FontWeight.bold)),
                        value: isMicOn,
                        activeColor: GamerTheme.neonGreen,
                        onChanged: (v) => setSheetState(() => isMicOn = v),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('COMMUNICATION', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: GamerTheme.bgDark,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: GamerTheme.borderDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedLang,
                                isExpanded: true,
                                dropdownColor: GamerTheme.cardDark,
                                items: ['Hindi', 'English', 'Punjabi', 'Tamil', 'Telugu', 'All']
                                    .map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setSheetState(() => selectedLang = v ?? selectedLang),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // In-Game UID
                const Text('IN-GAME CHARACTER UID', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TextField(
                  controller: uidController,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'e.g. 5123456789',
                    hintStyle: const TextStyle(color: GamerTheme.textMuted),
                    filled: true,
                    fillColor: GamerTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),

                const SizedBox(height: 14),

                // Shoutout / Description
                const Text('SQUAD MESSAGE / ROLE NEEDED', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Need 1 IGL and 1 Sniper for 8 PM rank push to Conqueror! Mic on only.',
                    hintStyle: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: GamerTheme.bgDark,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GamerTheme.borderDark)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.accentOrange,
                      foregroundColor: GamerTheme.bgDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (_isPosting) return;
                      _isPosting = true;

                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) {
                        _isPosting = false;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please log in to post squad requests!')),
                        );
                        return;
                      }

                      final bgmiUid = uidController.text.trim();
                      if (bgmiUid.isEmpty) {
                        _isPosting = false;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your BGMI UID!')),
                        );
                        return;
                      }

                      final docRef = FirebaseFirestore.instance.collection('lfg_posts').doc(currentUser.uid);
                      final existing = await docRef.get();
                      if (existing.exists && existing.data()?['isActive'] == true) {
                        // Already has active squad, don't create new
                        _isPosting = false;
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Aapka active squad pehle se hai!'),
                              backgroundColor: GamerTheme.accentOrange,
                            ),
                          );
                        }
                        return;
                      }

                      Navigator.pop(ctx);
                      final String uid = currentUser.uid;
                      final String email = currentUser.email ?? '';

                      final String bgmiName = currentGamer.displayName.isNotEmpty
                          ? currentGamer.displayName
                          : (currentUser.displayName ?? 'Squad Leader');
                      final String tag = currentGamer.username.isNotEmpty
                          ? currentGamer.username
                          : 'gamer';
                      final String avatar = currentGamer.photoUrl.isNotEmpty
                          ? currentGamer.photoUrl
                          : (currentUser.photoURL ?? '');

                      final postData = {
                        'id': uid,
                        'postId': uid,
                        'squadId': uid,
                        'leaderUid': uid,
                        'hostId': uid,
                        'userId': uid,
                        'ownerId': uid,
                        'ownerEmail': email,
                        'hostEmail': email,
                        'username': tag,
                        'ownerTag': tag,
                        'displayName': bgmiName,
                        'title': bgmiName,
                        'userAvatar': avatar,
                        'avatar': avatar,
                        'userRank': selectedTier,
                        'tier': selectedTier,
                        'tierNeeded': selectedTier,
                        'kd': selectedKd,
                        'kdNeeded': selectedKd,
                        'micMandatory': isMicOn,
                        'micOn': isMicOn,
                        'lang': selectedLang,
                        'language': selectedLang,
                        'mode': selectedMode,
                        'description': descController.text.trim(),
                        'bgmiUid': bgmiUid,
                        'inGameUid': bgmiUid,
                        'bgmiUidToCopy': bgmiUid,
                        'game': 'BGMI',
                        'isActive': true,
                        'members': [uid],
                        'memberCount': 1,
                        'membersCount': 1,
                        'requestedCount': 0,
                        'joinRequests': <String>[],
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      try {
                        // 1. In lfg_posts creation, STOP using .add() with random ID. Use user UID as document ID:
                        // collection('lfg_posts').doc(currentUser.uid).set({...})
                        await docRef.set(postData);

                        // Also sync to squads and chats with same uid
                        try {
                          await FirebaseFirestore.instance.collection('squads').doc(uid).set(postData);
                        } catch (_) {}

                        try {
                          final chatRef = FirebaseFirestore.instance.collection('chats').doc(uid);
                          await chatRef.set({
                            'squadId': uid,
                            'chatId': uid,
                            'postId': uid,
                            'hostId': uid,
                            'leaderUid': uid,
                            'hostEmail': email,
                            'createdAt': FieldValue.serverTimestamp(),
                            'members': [uid],
                            'isActive': true,
                            'title': bgmiName,
                            'displayName': bgmiName,
                          }, SetOptions(merge: true));

                          await chatRef.collection('messages').add({
                            'text': 'Squad created!',
                            'senderId': uid,
                            'senderUid': uid,
                            'timestamp': FieldValue.serverTimestamp(),
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } catch (_) {}

                        debugPrint('[SquadFinderScreen] Posted squad using user UID doc: $uid');
                      } catch (e) {
                        debugPrint('[SquadFinderScreen] Error saving squad to Firestore: $e');
                      } finally {
                        _isPosting = false;
                      }

                      final post = SquadPost(
                        id: uid,
                        userId: uid,
                        ownerEmail: email,
                        username: tag,
                        displayName: bgmiName,
                        userAvatar: avatar,
                        userRank: selectedTier,
                        game: 'BGMI',
                        tierNeeded: selectedTier,
                        kdNeeded: selectedKd,
                        micOn: isMicOn,
                        language: selectedLang,
                        mode: selectedMode,
                        description: descController.text.trim(),
                        inGameUid: bgmiUid,
                        isActive: true,
                        joinRequests: const [],
                        members: [uid],
                        membersCount: 1,
                        requestedCount: 0,
                        createdAt: DateTime.now(),
                      );

                      // Update local list
                      setState(() {
                        _localSquads.removeWhere((p) => p.id == uid);
                        _localSquads.insert(0, post);
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🔥 Squad LFG posted! Visible immediately.'),
                            backgroundColor: GamerTheme.accentOrange,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'POST SQUAD REQUIREMENT 🚀',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2E3A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (value != 'All' && value != 'Any') ? const Color(0xFFFF6B00) : const Color(0xFF383E4E),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: const Color(0xFF2A2E3A),
          icon: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          items: items.map((item) {
            final prefix = label.split(':')[0];
            return DropdownMenuItem<String>(
              value: item,
              child: Text('$prefix: $item', style: const TextStyle(color: Colors.white, fontSize: 12)),
            );
          }).toList(),
          onChanged: onChanged,
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      extendBody: false,
      extendBodyBehindAppBar: false,
      body: SafeArea(
        top: true,
        bottom: true,
        child: RefreshIndicator(
        color: const Color(0xFFFF6B00),
        backgroundColor: const Color(0xFF161A24),
        onRefresh: () async {
          debugPrint('[SquadFinderScreen] Pull-to-refresh triggered');
          final fetched = await _squadService.fetchSquadsOnce();
          if (mounted) {
            setState(() {
              for (final p in fetched) {
                if (!_localSquads.any((item) => item.id == p.id)) {
                  _localSquads.add(p);
                }
              }
            });
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // Top FILTERS Bar with 4 dropdown pills
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                color: const Color(0xFF0F1219),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterPill(
                        label: 'Game: $_filterGame',
                        value: _filterGame,
                        items: _gameFilterOptions,
                        onChanged: (v) => setState(() => _filterGame = v ?? 'All'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterPill(
                        label: 'Mode: $_filterMode',
                        value: _filterMode,
                        items: _modeFilterOptions,
                        onChanged: (v) => setState(() => _filterMode = v ?? 'All'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterPill(
                        label: 'Tier: $_filterTier',
                        value: _filterTier,
                        items: _tierFilterOptions,
                        onChanged: (v) => setState(() => _filterTier = v ?? 'All'),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterPill(
                        label: 'K/D: $_filterKd',
                        value: _filterKd,
                        items: _kdFilterOptions,
                        onChanged: (v) => setState(() => _filterKd = v ?? 'Any'),
                      ),
                      if (_filterGame != 'All' || _filterMode != 'All' || _filterTier != 'All' || _filterKd != 'Any') ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterGame = 'All';
                              _filterMode = 'All';
                              _filterTier = 'All';
                              _filterKd = 'Any';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B00).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text('RESET', style: TextStyle(color: Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Card: "Create Squad - PUBG Mobile"
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF262B3A), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B00).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Color(0xFFFF6B00), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Create Squad - $_cardGame',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Game Dropdown & Tier Dropdown
                    Row(
                      children: [
                        // Game dropdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GAME',
                                style: TextStyle(color: Color(0xFF8E95A5), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2E3A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF383E4E)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _cardGame,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF2A2E3A),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                    items: _cardGameOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _cardGame = v);
                                        _loadSavedUidForGame(v);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tier dropdown
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TIER',
                                style: TextStyle(color: Color(0xFF8E95A5), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2E3A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF383E4E)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _cardTier,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF2A2E3A),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                    items: _cardTierOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                    onChanged: (v) => setState(() => _cardTier = v ?? _cardTier),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Mode buttons: TPP / FPP
                    const Text(
                      'MODE',
                      style: TextStyle(color: Color(0xFF8E95A5), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: ['TPP', 'FPP'].map((mode) {
                        final isSel = _cardMode == mode;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: mode == 'TPP' ? 8 : 0),
                            child: InkWell(
                              onTap: () => setState(() => _cardMode = mode),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFFFF6B00) : const Color(0xFF2A2E3A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFFFF6B00) : const Color(0xFF383E4E),
                                  ),
                                ),
                                child: Text(
                                  mode,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // Role buttons: Entry Fragger / IGL / Support
                    const Text(
                      'ROLE',
                      style: TextStyle(color: Color(0xFF8E95A5), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: ['Entry Fragger', 'IGL', 'Support'].map((role) {
                        final isSel = _cardRole == role;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: InkWell(
                              onTap: () => setState(() => _cardRole = role),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSel ? const Color(0xFFFF6B00) : const Color(0xFF2A2E3A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSel ? const Color(0xFFFF6B00) : const Color(0xFF383E4E),
                                  ),
                                ),
                                child: Text(
                                  role,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // Mic Required switch & Language dropdown
                    Row(
                      children: [
                        // Mic Required switch
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2E3A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF383E4E)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.mic_rounded, color: Color(0xFFFF6B00), size: 17),
                                    SizedBox(width: 5),
                                    Text(
                                      'Mic Required',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _cardMicRequired,
                                  activeColor: const Color(0xFFFF6B00),
                                  activeTrackColor: const Color(0xFFFF6B00).withOpacity(0.4),
                                  inactiveThumbColor: Colors.grey,
                                  inactiveTrackColor: const Color(0xFF181C26),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (v) => setState(() => _cardMicRequired = v),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Language dropdown
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2E3A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF383E4E)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _cardLanguage,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF2A2E3A),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                items: _cardLangOptions.map((l) => DropdownMenuItem(value: l, child: Text('Lang: $l'))).toList(),
                                onChanged: (v) => setState(() => _cardLanguage = v ?? _cardLanguage),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Editable Game UID Input Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your $_cardGame UID - e.g. ${_cardGame == 'BGMI' ? 'BGMI UID' : '${_cardGame} UID'}',
                          style: const TextStyle(
                            color: Color(0xFF8E95A5),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _uidController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                          onChanged: (val) {
                            _saveUidForGame(_cardGame, val.trim());
                            if (_uidErrorText != null && val.trim().length >= 4) {
                              setState(() => _uidErrorText = null);
                            }
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF2A2E3A),
                            hintText: 'Enter your UID',
                            hintStyle: const TextStyle(color: Color(0xFF8E95A5), fontSize: 12.5),
                            errorText: _uidErrorText,
                            errorStyle: const TextStyle(color: Color(0xFFFF4D4D), fontSize: 11, fontWeight: FontWeight.w600),
                            prefixIcon: const Icon(Icons.tag_rounded, color: Color(0xFFFF6B00), size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF383E4E)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF383E4E)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFFF6B00), width: 1.5),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFFF4D4D), width: 1.2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFFF4D4D), width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Big orange button: "CREATE SQUAD"
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isPosting ? null : _createSquadFromCard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B00),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(0xFFFF6B00).withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isPosting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.flash_on_rounded, color: Colors.white, size: 19),
                                  SizedBox(width: 8),
                                  Text(
                                    'CREATE SQUAD',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5,
                                      letterSpacing: 1.0,
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

            // Section Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.stream_rounded, color: Color(0xFFFF6B00), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'ACTIVE SQUADS (LFG)',
                      style: TextStyle(
                        color: Color(0xFF8E95A5),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Squad Stream List
            StreamBuilder<List<SquadPost>>(
              stream: _squadService.getActiveSquadsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _localSquads.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
                    ),
                  );
                }

                final streamSquads = snapshot.data ?? [];
                final squads = _combineSquads(streamSquads);

                // Filter in-memory for smooth instant feedback
                final filtered = squads.where((s) {
                  if (_filterGame != 'All' &&
                      !s.game.toLowerCase().contains(_filterGame.toLowerCase())) {
                    return false;
                  }
                  if (_filterMode != 'All' &&
                      !s.mode.toLowerCase().contains(_filterMode.toLowerCase())) {
                    return false;
                  }
                  if (_filterTier != 'All' &&
                      !s.tierNeeded.toLowerCase().contains(_filterTier.toLowerCase()) &&
                      s.tierNeeded != 'Any Tier') {
                    return false;
                  }
                  if (_filterKd != 'Any') {
                    final minVal = double.tryParse(_filterKd.replaceAll('+', '').trim()) ?? 0.0;
                    if (s.kdNeeded < minVal) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                debugPrint('[SquadFinderScreen] Filtered squads count: ${filtered.length}');

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: GamerTheme.cardDark,
                                shape: BoxShape.circle,
                                border: Border.all(color: GamerTheme.borderDark),
                              ),
                              child: const Text('🛡️', style: TextStyle(fontSize: 40)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Squad Posts Found',
                              style: TextStyle(
                                color: GamerTheme.textWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Be the leader! Post your team requirements and find competitive BGMI teammates now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: GamerTheme.textMuted, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: GamerTheme.accentOrange,
                                foregroundColor: GamerTheme.bgDark,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_rounded, color: GamerTheme.bgDark),
                              label: const Text('Post Requirement Now', style: TextStyle(fontWeight: FontWeight.w900)),
                              onPressed: _openCreateSquadSheet,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return SquadCard(squad: filtered[index]);
                    },
                    childCount: filtered.length,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF6B00),
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: const Text(
          'NEED SQUAD',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.white),
        ),
        onPressed: _openCreateSquadSheet,
      ),
    );
  }
}

