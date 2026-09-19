import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/gamer_theme.dart';

/// Host Custom Room Screen & Dialog
class HostCustomRoomScreen extends StatefulWidget {
  const HostCustomRoomScreen({super.key});

  @override
  State<HostCustomRoomScreen> createState() => _HostCustomRoomScreenState();
}

class _HostCustomRoomScreenState extends State<HostCustomRoomScreen> {
  String selectedGame = 'BGMI';
  String selectedMap = 'Erangel';
  int maxSlots = 2;
  int prizeCoins = 100;

  late final TextEditingController titleController;
  late final TextEditingController mapController;
  final TextEditingController roomIdController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  static const List<String> availableMaps = [
    'Erangel',
    'Miramar',
    'Sanhok',
    'Vikendi',
    'Livik',
    'Karakin',
  ];

  static const List<String> gameCategories = [
    'BGMI',
    'Free Fire',
    'PUBG Mobile',
    'COD Mobile',
    'Valorant',
    'Ludo King',
    '8 Ball Pool',
  ];

  String _computeTitle(String map, int slots, int prize) {
    final String slotPart = (slots == 2)
        ? '1v1'
        : (slots == 4 ? '2v2' : '$slots slots');
    return 'BGMI $map $slotPart - $prize Coins';
  }

  int _getDefaultPrize(int slots) {
    if (slots == 2) return 100;
    if (slots == 4) return 250;
    if (slots == 10) return 500;
    return 500;
  }

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: _computeTitle(selectedMap, maxSlots, prizeCoins));
    mapController = TextEditingController(text: selectedMap);
  }

  @override
  void dispose() {
    titleController.dispose();
    mapController.dispose();
    roomIdController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRoomIdEmpty = roomIdController.text.trim().isEmpty;
    final bool isPassEmpty = passController.text.trim().isEmpty;
    final bool isPublishEnabled = !isRoomIdEmpty && !isPassEmpty;

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        backgroundColor: GamerTheme.cardDark,
        title: const Text('Host Custom Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game selection
            const Text('SELECT GAME', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedGame,
              dropdownColor: GamerTheme.cardElevated,
              decoration: InputDecoration(
                filled: true,
                fillColor: GamerTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: gameCategories.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedGame = val);
              },
            ),
            const SizedBox(height: 12),

            // Room Title
            const Text('ROOM TITLE', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: GamerTheme.bgDark,
                hintText: 'Enter room title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),

            // Map & Slots
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MAP', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedMap,
                        dropdownColor: GamerTheme.cardElevated,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: GamerTheme.bgDark,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: availableMaps.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedMap = val;
                              mapController.text = val;
                              titleController.text = _computeTitle(selectedMap, maxSlots, prizeCoins);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SLOTS', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: maxSlots,
                        dropdownColor: GamerTheme.cardElevated,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: GamerTheme.bgDark,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('2 (1v1)')),
                          DropdownMenuItem(value: 4, child: Text('4 (2v2)')),
                          DropdownMenuItem(value: 10, child: Text('10 slots')),
                          DropdownMenuItem(value: 12, child: Text('12 slots')),
                          DropdownMenuItem(value: 24, child: Text('24 slots')),
                          DropdownMenuItem(value: 50, child: Text('50 slots')),
                          DropdownMenuItem(value: 100, child: Text('100 slots')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              maxSlots = val;
                              prizeCoins = _getDefaultPrize(val);
                              titleController.text = _computeTitle(selectedMap, maxSlots, prizeCoins);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Prize
            const Text('PRIZE POOL', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: prizeCoins,
              dropdownColor: GamerTheme.cardElevated,
              decoration: InputDecoration(
                filled: true,
                fillColor: GamerTheme.bgDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: const [
                DropdownMenuItem(value: 100, child: Text('💰 100 Coins')),
                DropdownMenuItem(value: 250, child: Text('💰 250 Coins')),
                DropdownMenuItem(value: 500, child: Text('💰 500 Coins')),
                DropdownMenuItem(value: 1000, child: Text('💰 1000 Coins')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    prizeCoins = val;
                    titleController.text = _computeTitle(selectedMap, maxSlots, prizeCoins);
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Room ID & Password (Required with red * and errorText)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text('IN-GAME ROOM ID', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(' *', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: roomIdController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: GamerTheme.bgDark,
                          hintText: 'e.g. 88453219',
                          errorText: isRoomIdEmpty ? 'Room ID is required' : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                      Row(
                        children: const [
                          Text('PASSWORD', style: TextStyle(color: GamerTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(' *', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: GamerTheme.bgDark,
                          hintText: 'e.g. pubg123',
                          errorText: isPassEmpty ? 'Password is required' : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Publish Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPublishEnabled ? GamerTheme.accentOrange : Colors.grey.shade800,
                  disabledBackgroundColor: Colors.grey.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isPublishEnabled
                    ? () async {
                        final user = FirebaseAuth.instance.currentUser;
                        final uid = user?.uid ?? 'host_user';
                        final name = user?.displayName ?? 'Host';
                        final photo = user?.photoURL ?? '';
                        final docRef = FirebaseFirestore.instance.collection('rooms').doc();

                        final newRoomData = {
                          'id': docRef.id,
                          'title': titleController.text.trim().isNotEmpty ? titleController.text.trim() : 'BGMI Custom Match',
                          'hostId': uid,
                          'hostName': name,
                          'hostAvatar': photo,
                          'game': selectedGame,
                          'gameType': selectedGame,
                          'map': selectedMap,
                          'prize': prizeCoins,
                          'prizePoolCoins': prizeCoins,
                          'entryFee': 'FREE',
                          'entryFeeCoins': 0,
                          'total': maxSlots,
                          'totalSlots': maxSlots,
                          'maxSlots': maxSlots,
                          'filled': 1,
                          'currentSlots': 1,
                          'joinedUserIds': [uid],
                          'joinedPlayers': [uid],
                          'joinedUsers': [
                            {
                              'id': uid,
                              'name': name,
                              'photo': photo,
                              'joinedAt': Timestamp.now(),
                            }
                          ],
                          'joinedPlayerNames': {uid: name},
                          'roomIdCode': roomIdController.text.trim(),
                          'roomId': roomIdController.text.trim(),
                          'password': passController.text.trim(),
                          'status': 'active',
                          'createdAt': FieldValue.serverTimestamp(),
                          'startTime': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 15))),
                          'isLive': true,
                        };

                        await docRef.set(newRoomData);

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Room published successfully!'),
                              backgroundColor: Color(0xFF00FF88),
                            ),
                          );
                        }
                      }
                    : null,
                child: Text(
                  'PUBLISH ROOM',
                  style: TextStyle(
                    color: isPublishEnabled ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
