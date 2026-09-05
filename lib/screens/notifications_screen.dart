import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../services/gamer_auth_service.dart';
import '../services/gamer_social_service.dart';
import '../widgets/gamer_avatar.dart';
import 'gamer_profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _formatTime(Timestamp? ts) {
    if (ts == null) return 'recently';
    final dt = ts.toDate();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = GamerAuthService().currentUid ?? '';

    return Scaffold(
      backgroundColor: GamerTheme.bgDark,
      appBar: AppBar(
        title: const Text('Gamer Activity'),
        actions: [
          IconButton(
            tooltip: 'Clear activity',
            icon: const Icon(Icons.done_all_rounded, color: GamerTheme.accentBlue, size: 20),
            onPressed: () async {
              try {
                final snap = await FirebaseFirestore.instance
                    .collection('notifications')
                    .where('recipientUid', isEqualTo: currentUid)
                    .get();
                final batch = FirebaseFirestore.instance.batch();
                for (final d in snap.docs) {
                  batch.update(d.reference, {'read': true});
                }
                await batch.commit();
              } catch (_) {}
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientUid', isEqualTo: currentUid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: GamerTheme.accentBlue));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.notifications_none_rounded, color: GamerTheme.textMuted, size: 54),
                    SizedBox(height: 12),
                    Text(
                      'No new notifications',
                      style: TextStyle(color: GamerTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'When gamers follow your ID or like your posts, you\'ll see them here!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: GamerTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(color: GamerTheme.borderDark, height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>? ?? {};
              final senderUid = data['senderUid'] ?? '';
              final type = data['type'] ?? 'activity';
              final message = data['message'] ?? 'interacted with your Gamer ID';
              final timestamp = data['createdAt'] as Timestamp?;
              final isRead = data['read'] == true;

              IconData iconData;
              Color iconColor;
              if (type == 'follow') {
                iconData = Icons.person_add_rounded;
                iconColor = GamerTheme.accentBlue;
              } else if (type == 'like') {
                iconData = Icons.favorite_rounded;
                iconColor = GamerTheme.redAccent;
              } else {
                iconData = Icons.chat_bubble_rounded;
                iconColor = GamerTheme.accentOrange;
              }

              return FutureBuilder(
                future: GamerAuthService().getUserProfile(senderUid),
                builder: (context, userSnap) {
                  final sender = userSnap.data;
                  final senderName = sender?.displayName ?? 'A Gamer';
                  final senderPhoto = sender?.photoUrl ?? '';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    leading: Stack(
                      children: [
                        GamerAvatar(
                          photoUrl: senderPhoto,
                          displayName: senderName,
                          radius: 20,
                          onTap: () {
                            if (senderUid.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: senderUid)),
                              );
                            }
                          },
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: GamerTheme.cardDark,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, color: iconColor, size: 12),
                          ),
                        ),
                      ],
                    ),
                    title: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: GamerTheme.textWhite, fontSize: 13.5),
                        children: [
                          TextSpan(
                            text: senderName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: ' $message',
                            style: TextStyle(color: isRead ? GamerTheme.textGray : GamerTheme.textWhite),
                          ),
                        ],
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatTime(timestamp),
                        style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                      ),
                    ),
                    trailing: !isRead
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: GamerTheme.accentBlue,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    onTap: () {
                      if (senderUid.isNotEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: senderUid)),
                        );
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
