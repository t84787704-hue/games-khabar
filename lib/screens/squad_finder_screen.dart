import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  // Local list to immediately display created posts without waiting for Firestore stream
  final List<SquadPost> _localSquads = [];

  String _filterMode = 'All';
  String _filterTier = 'All';
  double _filterMinKd = 0.0;
  bool? _filterMicOn;
  String _filterLanguage = 'All';

  final List<String> _modeOptions = ['All', 'Rank Push', 'Classic Squad', 'TDM Tourney', 'Payload'];
  final List<String> _tierOptions = ['All', 'Diamond+', 'Crown+', 'Ace+', 'Conqueror'];
  final List<String> _langOptions = ['All', 'Hindi', 'English', 'Punjabi', 'Tamil', 'Telugu'];

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

  void _openCreateSquadSheet() {
    final currentGamer = _authService.currentGamer;
    if (currentGamer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create your Gamer ID to post squad requests!')),
      );
      return;
    }

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
                      Navigator.pop(ctx);
                      final docId = FirebaseFirestore.instance.collection('squads').doc().id;
                      final userAuthUid = FirebaseAuth.instance.currentUser?.uid ?? currentGamer.uid;
                      final post = SquadPost(
                        id: docId,
                        userId: userAuthUid,
                        username: currentGamer.username,
                        displayName: currentGamer.displayName,
                        userAvatar: currentGamer.photoUrl,
                        userRank: currentGamer.rank,
                        game: 'BGMI',
                        tierNeeded: selectedTier,
                        kdNeeded: selectedKd,
                        micOn: isMicOn,
                        language: selectedLang,
                        mode: selectedMode,
                        description: descController.text.trim(),
                        inGameUid: uidController.text.trim(),
                        isActive: true,
                        joinRequests: const [],
                        members: [userAuthUid],
                        membersCount: 1,
                        requestedCount: 0,
                        createdAt: DateTime.now(),
                      );

                      // 1. Immediately add it to local list and call setState, don't wait for stream
                      setState(() {
                        _localSquads.removeWhere((p) => p.id == docId);
                        _localSquads.insert(0, post);
                      });

                      // Write to Firestore
                      try {
                        await _squadService.createSquadPost(post);
                        debugPrint('[SquadFinderScreen] Created LFG post doc in Firestore: $docId');
                      } catch (e) {
                        debugPrint('[SquadFinderScreen] Error saving squad post to Firestore: $e');
                      }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      extendBody: false,
      extendBodyBehindAppBar: false,
      body: SafeArea(
        top: true,
        bottom: true,
        child: RefreshIndicator(
        color: GamerTheme.accentOrange,
        backgroundColor: GamerTheme.cardDark,
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
            // Filter Header Bar
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: const BoxDecoration(
                  color: GamerTheme.bgDark,
                  border: Border(bottom: BorderSide(color: GamerTheme.borderDark, width: 0.8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.filter_list_rounded, color: GamerTheme.accentOrange, size: 16),
                        const SizedBox(width: 6),
                        const Text(
                          'FILTERS:',
                          style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        if (_filterMode != 'All' || _filterTier != 'All' || _filterMinKd > 0 || _filterMicOn != null || _filterLanguage != 'All')
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _filterMode = 'All';
                                _filterTier = 'All';
                                _filterMinKd = 0.0;
                                _filterMicOn = null;
                                _filterLanguage = 'All';
                              });
                            },
                            child: const Text('RESET', style: TextStyle(color: GamerTheme.accentOrange, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Mode dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: GamerTheme.cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _filterMode != 'All' ? GamerTheme.accentCyan : GamerTheme.borderDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _filterMode,
                                dropdownColor: GamerTheme.cardDark,
                                style: TextStyle(
                                  color: _filterMode != 'All' ? GamerTheme.accentCyan : GamerTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: _modeOptions.map((m) => DropdownMenuItem(value: m, child: Text('Mode: $m'))).toList(),
                                onChanged: (v) => setState(() => _filterMode = v ?? 'All'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Tier dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: GamerTheme.cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _filterTier != 'All' ? GamerTheme.accentOrange : GamerTheme.borderDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _filterTier,
                                dropdownColor: GamerTheme.cardDark,
                                style: TextStyle(
                                  color: _filterTier != 'All' ? GamerTheme.accentOrange : GamerTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: _tierOptions.map((t) => DropdownMenuItem(value: t, child: Text('Tier: $t'))).toList(),
                                onChanged: (v) => setState(() => _filterTier = v ?? 'All'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // KD Filter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: GamerTheme.cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _filterMinKd > 0 ? const Color(0xFFFF2D55) : GamerTheme.borderDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<double>(
                                value: _filterMinKd,
                                dropdownColor: GamerTheme.cardDark,
                                style: TextStyle(
                                  color: _filterMinKd > 0 ? const Color(0xFFFF2D55) : GamerTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: const [
                                  DropdownMenuItem(value: 0.0, child: Text('K/D: Any')),
                                  DropdownMenuItem(value: 2.0, child: Text('K/D: 2.0+')),
                                  DropdownMenuItem(value: 3.0, child: Text('K/D: 3.0+')),
                                  DropdownMenuItem(value: 4.0, child: Text('K/D: 4.0+')),
                                  DropdownMenuItem(value: 5.0, child: Text('K/D: 5.0+')),
                                ],
                                onChanged: (v) => setState(() => _filterMinKd = v ?? 0.0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Mic Filter Chip
                          FilterChip(
                            label: Text(
                              _filterMicOn == true ? 'Mic Required' : 'Mic: Any',
                              style: TextStyle(
                                color: _filterMicOn == true ? GamerTheme.bgDark : GamerTheme.textWhite,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: _filterMicOn == true,
                            selectedColor: GamerTheme.neonGreen,
                            backgroundColor: GamerTheme.cardDark,
                            onSelected: (val) => setState(() => _filterMicOn = val ? true : null),
                          ),
                          const SizedBox(width: 8),

                          // Language dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: GamerTheme.cardDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _filterLanguage != 'All' ? GamerTheme.accentBlue : GamerTheme.borderDark),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _filterLanguage,
                                dropdownColor: GamerTheme.cardDark,
                                style: TextStyle(
                                  color: _filterLanguage != 'All' ? GamerTheme.accentBlue : GamerTheme.textWhite,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                items: _langOptions.map((l) => DropdownMenuItem(value: l, child: Text('Lang: $l'))).toList(),
                                onChanged: (v) => setState(() => _filterLanguage = v ?? 'All'),
                              ),
                            ),
                          ),
                        ],
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
                      child: CircularProgressIndicator(color: GamerTheme.accentOrange),
                    ),
                  );
                }

                final streamSquads = snapshot.data ?? [];
                final squads = _combineSquads(streamSquads);

                // Filter in-memory for smooth instant feedback
                // No where filter for Tier/K/D on initial load; show ALL posts including userId == currentUserId
                final filtered = squads.where((s) {
                  if (_filterMode != 'All' &&
                      !s.mode.toLowerCase().contains(_filterMode.toLowerCase())) {
                    return false;
                  }
                  if (_filterTier != 'All' &&
                      !s.tierNeeded.toLowerCase().contains(_filterTier.replaceAll('+', '').toLowerCase()) &&
                      s.tierNeeded != 'Any Tier') {
                    return false;
                  }
                  if (_filterMinKd > 0 && s.kdNeeded < _filterMinKd) {
                    return false;
                  }
                  if (_filterMicOn != null && s.micOn != _filterMicOn) {
                    return false;
                  }
                  if (_filterLanguage != 'All' && s.language != _filterLanguage && s.language != 'All') {
                    return false;
                  }
                  // Show all posts including current user's posts
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
        backgroundColor: GamerTheme.accentOrange,
        foregroundColor: GamerTheme.bgDark,
        elevation: 6,
        icon: const Icon(Icons.group_add_rounded, color: GamerTheme.bgDark),
        label: const Text(
          'NEED SQUAD',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
        ),
        onPressed: _openCreateSquadSheet,
      ),
    );
  }
}

