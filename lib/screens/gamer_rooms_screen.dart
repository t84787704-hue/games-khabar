// ===============================================================================
// File: lib/screens/gamer_rooms_screen.dart
// Clean Gamer Rooms Screen with Realtime Updates, Anti-Dispute Verification & Full Localization
// ===============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../widgets/gamer_avatar.dart';

class GamerRoomsScreen extends StatefulWidget {
  const GamerRoomsScreen({super.key});

  @override
  State<GamerRoomsScreen> createState() => _GamerRoomsScreenState();
}

class _GamerRoomsScreenState extends State<GamerRoomsScreen> {
  String _selectedGame = 'All';
  String? _currentUserId;
  String _currentUsername = 'Gamer';
  bool _isLoadingUser = true;

  final List<String> _games = [
    'All',
    'PUBG Mobile',
    'BGMI',
    'Free Fire',
    'Call of Duty Mobile',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      _currentUserId = user.id;
      try {
        final profile = await SupabaseService.client
            .from('users')
            .select('username')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null && profile['username'] != null) {
          _currentUsername = profile['username'].toString();
        }
      } catch (e) {
        debugPrint('Error loading user profile: $e');
      }
    }
    if (mounted) setState(() => _isLoadingUser = false);
  }

  void _openCreateRoomDialog() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_login_create_room'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final activeRooms = await SupabaseService.client
          .from('custom_rooms')
          .select('id')
          .eq('host_id', _currentUserId!)
          .inFilter('status', ['open', 'active', 'under_review']);

      if ((activeRooms as List).length >= 2) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: ThemeService.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'room_limit_reached_title'.tr(),
                    style: TextStyle(color: ThemeService.textPrimary, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Text(
              'room_limit_explanation'.tr(),
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('btn_ok'.tr()),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error checking active rooms: $e');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreateRoomDialog(
        currentUserId: _currentUserId!,
        currentUsername: _currentUsername,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            title: Text(
              'nav_rooms'.tr(),
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Color(0xFF1877F2)),
                tooltip: 'rules'.tr(),
                onPressed: () => _showRulesDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Games Filter
              Container(
                color: ThemeService.appBarBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _games.length,
                    itemBuilder: (context, i) {
                      final game = _games[i];
                      final isSelected = _selectedGame == game;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(game),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedGame = game);
                          },
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : ThemeService.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: ThemeService.cardSecondary,
                          selectedColor: const Color(0xFF1877F2),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          showCheckmark: false,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Rooms Stream
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: SupabaseService.client
                      .from('custom_rooms')
                      .stream(primaryKey: ['id'])
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'err_failed_to_load'.tr(),
                          style: TextStyle(color: ThemeService.textSecondary),
                        ),
                      );
                    }

                    var rooms = snapshot.data ?? [];

                    if (_selectedGame != 'All') {
                      rooms = rooms
                          .where((r) => (r['game'] ?? '').toString() == _selectedGame)
                          .toList();
                    }

                    if (rooms.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.meeting_room_outlined,
                              size: 64,
                              color: ThemeService.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'no_active_rooms_found'.tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ThemeService.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: rooms.length,
                      itemBuilder: (context, i) {
                        final room = rooms[i];
                        return _RoomCard(
                          room: room,
                          currentUserId: _currentUserId,
                          currentUsername: _currentUsername,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.add),
            label: Text('create_game_room'.tr()),
            onPressed: _openCreateRoomDialog,
          ),
        );
      },
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.rule_folder_outlined, color: Color(0xFF1877F2)),
            const SizedBox(width: 8),
            Text('match_rules'.tr(), style: TextStyle(color: ThemeService.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRuleItem('1', 'Enter Room ID & Password carefully.'),
            _buildRuleItem('2', 'Take screenshot of the Victory / Defeat screen.'),
            _buildRuleItem('3', 'Winner must submit clear screenshot proof.'),
            _buildRuleItem('4', 'Fake proof or cheating will result in account ban.'),
            _buildRuleItem('5', 'Coins will be awarded after verification.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('btn_ok'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFF1877F2),
              shape: BoxShape.circle,
            ),
            child: Text(
              num,
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: ThemeService.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Room Card Widget ───────────────────────────

class _RoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final String? currentUserId;
  final String currentUsername;

  const _RoomCard({
    required this.room,
    required this.currentUserId,
    required this.currentUsername,
  });

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = (room['status'] ?? 'open').toString().toLowerCase();
    final game = (room['game'] ?? 'Gaming').toString();
    final mode = (room['mode'] ?? 'Squad').toString();
    final hostName = (room['host_name'] ?? 'Host').toString();
    final prizePool = room['prize_pool'] ?? 0;
    final totalSlots = room['total_slots'] ?? 100;
    final joinedUsers = List<String>.from(room['joined_users'] ?? []);
    final filledSlots = joinedUsers.length;

    final isHost = currentUserId != null && room['host_id'] == currentUserId;
    final isJoined = currentUserId != null && joinedUsers.contains(currentUserId);

    Color statusColor;
    String statusText;

    switch (status) {
      case 'open':
        statusColor = Colors.green;
        statusText = 'status_active'.tr();
        break;
      case 'active':
        statusColor = Colors.orange;
        statusText = 'status_live_caps'.tr();
        break;
      case 'under_review':
        statusColor = Colors.amber;
        statusText = 'proof_under_admin_review'.tr();
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'status_completed'.tr();
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: ThemeService.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isHost ? const Color(0xFF1877F2).withOpacity(0.5) : ThemeService.border,
          width: isHost ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Host Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    if (isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1877F2).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'host'.tr(),
                          style: const TextStyle(
                            color: Color(0xFF1877F2),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Text(
                      '$game • $mode',
                      style: TextStyle(
                        color: ThemeService.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Host & Prize Info
            Row(
              children: [
                GamerAvatar(
                  photoUrl: '',
                  displayName: hostName,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hostName,
                        style: TextStyle(
                          color: ThemeService.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'leader_named'.tr(args: [hostName]),
                        style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$prizePool',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Slots Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalSlots > 0 ? (filledSlots / totalSlots).clamp(0.0, 1.0) : 0,
                backgroundColor: ThemeService.cardSecondary,
                color: const Color(0xFF1877F2),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'room_players_ratio'.tr(args: ['$filledSlots', '$totalSlots']),
                  style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                ),
                if (isJoined || isHost)
                  Text(
                    'joined'.tr(),
                    style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Room Credentials Box (if joined or host)
            if (isJoined || isHost) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('room_id_label'.tr(),
                              style: TextStyle(color: ThemeService.textSecondary, fontSize: 10)),
                          Text(
                            room['room_id']?.toString() ?? '---',
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'tooltip_copy'.tr(),
                      onPressed: () => _copyToClipboard(
                        context,
                        room['room_id']?.toString() ?? '',
                        'room_id_copied'.tr(),
                      ),
                    ),
                    const VerticalDivider(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('password_label'.tr(),
                              style: TextStyle(color: ThemeService.textSecondary, fontSize: 10)),
                          Text(
                            room['room_password']?.toString() ?? '---',
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'tooltip_copy'.tr(),
                      onPressed: () => _copyToClipboard(
                        context,
                        room['room_password']?.toString() ?? '',
                        'password_copied'.tr(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Actions Bottom
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isJoined && !isHost && status == 'open')
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () => _joinRoom(context),
                    child: Text('join_room'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  )
                else if (isJoined && !isHost && status == 'open')
                  TextButton.icon(
                    icon: const Icon(Icons.exit_to_app, size: 16, color: Colors.red),
                    label: Text('leave_squad'.tr(), style: const TextStyle(color: Colors.red, fontSize: 12)),
                    onPressed: () => _leaveRoom(context),
                  )
                else
                  const SizedBox.shrink(),

                TextButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text('match_room'.tr(), style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _showChatSheet(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _joinRoom(BuildContext context) async {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_login_first'.tr())),
      );
      return;
    }

    try {
      final joinedUsers = List<String>.from(room['joined_users'] ?? []);
      final totalSlots = room['total_slots'] ?? 100;

      if (joinedUsers.length >= totalSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('room_already_full'.tr())),
        );
        return;
      }

      joinedUsers.add(currentUserId!);

      await SupabaseService.client
          .from('custom_rooms')
          .update({'joined_users': joinedUsers})
          .eq('id', room['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('msg_joined_room_success'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('err_joining_room'.tr(args: ['$e']))),
      );
    }
  }

  void _leaveRoom(BuildContext context) async {
    if (currentUserId == null) return;
    try {
      final joinedUsers = List<String>.from(room['joined_users'] ?? []);
      joinedUsers.remove(currentUserId);

      await SupabaseService.client
          .from('custom_rooms')
          .update({'joined_users': joinedUsers})
          .eq('id', room['id']);
    } catch (e) {
      debugPrint('Error leaving room: $e');
    }
  }

  void _showChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThemeService.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _RoomChatSheet(
        roomId: room['id'].toString(),
        currentUserId: currentUserId ?? '',
        currentUsername: currentUsername,
      ),
    );
  }
}

// ─────────────────────────── Create Room Dialog ───────────────────────────

class _CreateRoomDialog extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;

  const _CreateRoomDialog({
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _roomIdCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _prizePoolCtrl = TextEditingController(text: '100');
  final _totalSlotsCtrl = TextEditingController(text: '100');

  String _selectedGame = 'PUBG Mobile';
  String _selectedMode = 'Squad';
  bool _isCreating = false;

  final List<String> _games = [
    'PUBG Mobile',
    'BGMI',
    'Free Fire',
    'Call of Duty Mobile',
  ];

  final List<String> _modes = ['Solo', 'Duo', 'Squad', 'TDM'];

  @override
  void dispose() {
    _roomIdCtrl.dispose();
    _passwordCtrl.dispose();
    _prizePoolCtrl.dispose();
    _totalSlotsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRoom() async {
    final roomId = _roomIdCtrl.text.trim();
    final pwd = _passwordCtrl.text.trim();

    if (roomId.isEmpty || pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('err_enter_room_id_pwd'.tr()), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final prize = int.tryParse(_prizePoolCtrl.text.trim()) ?? 100;
      final slots = int.tryParse(_totalSlotsCtrl.text.trim()) ?? 100;

      await SupabaseService.client.from('custom_rooms').insert({
        'host_id': widget.currentUserId,
        'host_name': widget.currentUsername,
        'game': _selectedGame,
        'mode': _selectedMode,
        'room_id': roomId,
        'room_password': pwd,
        'prize_pool': prize,
        'total_slots': slots,
        'joined_users': [widget.currentUserId],
        'status': 'open',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('msg_room_created_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('err_creating_room'.tr(args: ['$e'])),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ThemeService.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'create_game_room'.tr(),
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: ThemeService.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Game Selector
              Text('game'.tr(), style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedGame,
                dropdownColor: ThemeService.cardSecondary,
                style: TextStyle(color: ThemeService.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                items: _games
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGame = val!),
              ),
              const SizedBox(height: 12),

              // Mode Selector
              Text('match_mode'.tr(), style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedMode,
                dropdownColor: ThemeService.cardSecondary,
                style: TextStyle(color: ThemeService.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                ),
                items: _modes
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedMode = val!),
              ),
              const SizedBox(height: 12),

              // Room ID & Password
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('room_id'.tr(), style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _roomIdCtrl,
                          style: TextStyle(color: ThemeService.textPrimary),
                          decoration: InputDecoration(
                            hintText: '123456',
                            hintStyle: TextStyle(color: ThemeService.textSecondary),
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('password'.tr(), style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordCtrl,
                          style: TextStyle(color: ThemeService.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'pass123',
                            hintStyle: TextStyle(color: ThemeService.textSecondary),
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Prize Pool & Slots
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('prize_pool'.tr(), style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _prizePoolCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: ThemeService.textPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('slots'.tr(), style: TextStyle(color: ThemeService.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _totalSlotsCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: ThemeService.textPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: ThemeService.cardSecondary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isCreating ? null : _submitRoom,
                  child: _isCreating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('btn_create'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Room Chat Sheet ───────────────────────────

class _RoomChatSheet extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currentUsername;

  const _RoomChatSheet({
    required this.roomId,
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<_RoomChatSheet> createState() => _RoomChatSheetState();
}

class _RoomChatSheetState extends State<_RoomChatSheet> {
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || widget.currentUserId.isEmpty) return;

    _msgCtrl.clear();

    try {
      await SupabaseService.client.from('room_chats').insert({
        'room_id': widget.roomId,
        'user_id': widget.currentUserId,
        'username': widget.currentUsername,
        'message': text,
      });
    } catch (e) {
      debugPrint('Error sending room chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: 450,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThemeService.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Text('match_room'.tr(),
                style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Divider(color: ThemeService.border),

            // Messages Stream
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: SupabaseService.client
                    .from('room_chats')
                    .stream(primaryKey: ['id'])
                    .eq('room_id', widget.roomId)
                    .order('created_at', ascending: true),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Text('no_messages_yet'.tr(),
                          style: TextStyle(color: ThemeService.textSecondary)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final isMe = m['user_id'] == widget.currentUserId;
                      final sender = (m['username'] ?? 'Gamer').toString();
                      final text = (m['message'] ?? '').toString();

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF1877F2) : ThemeService.cardSecondary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  sender,
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              Text(
                                text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : ThemeService.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Input Bar
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: TextStyle(color: ThemeService.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'type_a_message'.tr(),
                        hintStyle: TextStyle(color: ThemeService.textSecondary),
                        filled: true,
                        fillColor: ThemeService.cardSecondary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF1877F2)),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}