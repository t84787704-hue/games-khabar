import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament_room_model.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_rooms_screen.dart';

/// TournamentBoardScreen
/// Displays tournament rooms and manages host display resolution.
class TournamentBoardScreen extends StatefulWidget {
  const TournamentBoardScreen({super.key});

  @override
  State<TournamentBoardScreen> createState() => _TournamentBoardScreenState();
}

class _TournamentBoardScreenState extends State<TournamentBoardScreen> {
  // Cache for host usernames fetched from Firestore 'users' collection to avoid repeated reads
  final Map<String, String> _hostNameCache = {};

  /// Ensure host display name is loaded into cache (reads users collection once per hostId)
  Future<void> _ensureHostNameLoaded(String hostId) async {
    if (hostId.isEmpty || _hostNameCache.containsKey(hostId)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(hostId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final username = (data['username'] ?? data['displayName'] ?? data['name'])?.toString().trim() ?? '';
        if (username.isNotEmpty) {
          _hostNameCache[hostId] = username;
          if (mounted) setState(() {});
          return;
        }
      }
    } catch (_) {}
    _hostNameCache[hostId] = 'Host';
  }

  /// Builds a tournament room card with proper hostDisplay resolution
  Widget _buildRoomCard(TournamentRoom room) {
    // hostDisplay logic: if room.hostName is not null, not empty, and not equal to map values like
    // "Erangel", "Miramar", "Sanhok", "Vikendi" then use room.hostName.
    // Else, fetch username from Firestore collection 'users' docId = room.hostId.
    // Use field 'username' -> 'displayName' -> 'name' in that order.
    // Cache result in a Map<String, String> _hostNameCache to avoid repeated reads.
    final String rawHostName = room.hostName.trim();
    const mapNames = ['Erangel', 'Miramar', 'Sanhok', 'Vikendi', 'Livik', 'Karakin', 'Nusa', 'Warehouse'];
    final bool isMapValue = mapNames.any((m) => m.toLowerCase() == rawHostName.toLowerCase()) ||
        (room.map.trim().isNotEmpty && rawHostName.toLowerCase() == room.map.trim().toLowerCase());

    final String hostDisplay;
    if (rawHostName.isNotEmpty && !isMapValue) {
      hostDisplay = rawHostName;
    } else {
      if (_hostNameCache.containsKey(room.hostId) && _hostNameCache[room.hostId]!.isNotEmpty) {
        hostDisplay = _hostNameCache[room.hostId]!;
      } else {
        if (room.hostId.isNotEmpty) {
          _ensureHostNameLoaded(room.hostId);
        }
        hostDisplay = rawHostName.isNotEmpty && !isMapValue ? rawHostName : 'Host';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF00FF88),
            child: GamerAvatar(
              photoUrl: room.hostAvatar,
              displayName: hostDisplay,
              radius: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Host: $hostDisplay',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const GamerRoomsScreen();
  }
}
