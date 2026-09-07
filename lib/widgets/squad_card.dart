import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../constants/gamer_theme.dart';
import '../models/squad_post_model.dart';
import '../models/squad_request_model.dart';
import '../models/gamer_user_model.dart';
import '../services/gamer_auth_service.dart';
import '../services/squad_service.dart';
import '../widgets/gamer_avatar.dart';
import '../widgets/rank_badge_widget.dart';
import '../widgets/requests_bottom_sheet.dart';
import '../screens/gamer_profile_screen.dart';

typedef SquadCard = LFGCard;

class LFGCard extends StatefulWidget {
  final SquadPost squad;

  const LFGCard({super.key, required this.squad});

  @override
  State<LFGCard> createState() => _LFGCardState();
}

class _LFGCardState extends State<LFGCard> {
  bool _isRequesting = false;

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('dd MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final squad = widget.squad;
    final authService = GamerAuthService();
    final currentGamer = authService.currentGamer;
    final currentUid = authService.currentUid ?? currentGamer?.uid ?? '';
    final currentUsername = currentGamer?.username.trim().toLowerCase() ?? '';
    final postUsername = squad.username.trim().toLowerCase();
    final currentGameId = currentGamer?.gameId.trim() ?? '';
    final postInGameUid = squad.inGameUid.trim();

    // Comprehensive owner check: UID, username, or gameId / inGameUid
    final isOwnPost = (currentUid.isNotEmpty && currentUid == squad.userId) ||
        (currentUsername.isNotEmpty && currentUsername == postUsername) ||
        (currentGameId.isNotEmpty && postInGameUid.isNotEmpty && currentGameId == postInGameUid);

    // Requester check: currentUid or username present in joinRequests
    final hasRequested = squad.joinRequests.contains(currentUid) ||
        (currentUsername.isNotEmpty && squad.joinRequests.contains(currentUsername));

    // Rank badge for squad leader
    final leaderBadge = GamerRankBadge(
      type: squad.userRank.toLowerCase().contains('conqueror')
          ? RankBadgeType.conqueror
          : squad.userRank.toLowerCase().contains('ace')
              ? RankBadgeType.ace
              : RankBadgeType.none,
      label: squad.userRank,
      emoji: squad.userRank.toLowerCase().contains('conqueror') ? '👑' : '⭐',
      icon: Icons.star_rounded,
      primaryColor: squad.userRank.toLowerCase().contains('conqueror')
          ? const Color(0xFFFF334B)
          : const Color(0xFFFF9500),
      backgroundColor: const Color(0x33FF9500),
      borderColor: const Color(0x88FF9500),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: GamerTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOwnPost ? GamerTheme.accentOrange.withOpacity(0.7) : GamerTheme.borderDark,
          width: isOwnPost ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Leader info + Mode badge
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (squad.userId.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => GamerProfileScreen(userId: squad.userId)),
                      );
                    }
                  },
                  child: GamerAvatar(
                    photoUrl: squad.userAvatar,
                    displayName: squad.displayName,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              squad.displayName,
                              style: const TextStyle(
                                color: GamerTheme.textWhite,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          RankBadgeWidget(badge: leaderBadge, size: 12),
                          if (isOwnPost) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: GamerTheme.accentOrange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: GamerTheme.accentOrange, width: 1.2),
                              ),
                              child: const Text(
                                'Your Post',
                                style: TextStyle(
                                  color: GamerTheme.accentOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '@${squad.username}',
                            style: const TextStyle(
                              color: GamerTheme.accentOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: GamerTheme.textMuted, fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(
                            _formatTime(squad.createdAt),
                            style: const TextStyle(color: GamerTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Mode chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: GamerTheme.accentBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GamerTheme.accentBlue.withOpacity(0.3)),
                  ),
                  child: Text(
                    squad.mode,
                    style: const TextStyle(
                      color: GamerTheme.accentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Description if present
          if (squad.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                squad.description,
                style: const TextStyle(
                  color: GamerTheme.textWhite,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Requirement Badges Row: Tier Needed, KD Needed, Mic, Language
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRequirementChip(
                  icon: Icons.military_tech_rounded,
                  label: 'Min: ${squad.tierNeeded}',
                  color: const Color(0xFFFF9500),
                ),
                _buildRequirementChip(
                  icon: Icons.speed_rounded,
                  label: '${squad.kdNeeded.toStringAsFixed(1)}+ K/D',
                  color: const Color(0xFFFF2D55),
                ),
                _buildRequirementChip(
                  icon: squad.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  label: squad.micOn ? 'Mic Mandatory' : 'Mic Optional',
                  color: squad.micOn ? GamerTheme.neonGreen : GamerTheme.textMuted,
                ),
                _buildRequirementChip(
                  icon: Icons.language_rounded,
                  label: squad.language,
                  color: GamerTheme.accentBlue,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // In-Game UID Bar
          if (squad.inGameUid.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: GamerTheme.bgDark.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GamerTheme.borderLight.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag_rounded, color: GamerTheme.accentOrange, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'UID: ',
                    style: TextStyle(color: GamerTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    squad.inGameUid,
                    style: const TextStyle(
                      color: GamerTheme.textWhite,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: squad.inGameUid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied UID ${squad.inGameUid} to clipboard!'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GamerTheme.cardElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GamerTheme.borderLight),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.copy_rounded, color: GamerTheme.accentOrange, size: 12),
                          SizedBox(width: 4),
                          Text('COPY', style: TextStyle(color: GamerTheme.accentOrange, fontSize: 10.5, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Squad Members Slots (4 Slots: Leader + Accepted Members)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: GamerTheme.bgDark.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GamerTheme.borderLight.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: GamerTheme.accentCyan, size: 15),
                const SizedBox(width: 6),
                Text(
                  'Squad Members (${squad.members.isNotEmpty ? squad.members.length : squad.membersCount}/4):',
                  style: const TextStyle(
                    color: GamerTheme.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // 4 squad slot dots / avatars
                Row(
                  children: List.generate(4, (index) {
                    final isFilled = index < (squad.members.isNotEmpty ? squad.members.length : squad.membersCount);
                    return Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isFilled ? GamerTheme.accentCyan.withOpacity(0.25) : GamerTheme.cardElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFilled ? GamerTheme.accentCyan : GamerTheme.borderLight.withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          isFilled ? (index == 0 ? Icons.star_rounded : Icons.person_rounded) : Icons.add_rounded,
                          size: 12,
                          color: isFilled ? GamerTheme.accentCyan : GamerTheme.textMuted.withOpacity(0.5),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Divider and Footer Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: GamerTheme.borderDark)),
            ),
            child: Row(
              children: [
                if (isOwnPost) ...[
                  // Owner View: Real-Time Clickable "X requested VIEW" Button
                  StreamBuilder<List<SquadJoinRequest>>(
                    stream: SquadService().getSquadRequestsStream(squad.id, squad.joinRequests),
                    initialData: squad.joinRequests
                        .map((uid) => SquadJoinRequest(id: uid, userId: uid, name: 'Gamer'))
                        .toList(),
                    builder: (context, reqSnap) {
                      final requests = reqSnap.data ?? [];
                      final count = requests.isNotEmpty ? requests.length : squad.joinRequests.length;
                      final hasRequests = count > 0;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => RequestsBottomSheet(squad: squad),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  size: 16,
                                  color: hasRequests ? GamerTheme.accentOrange : GamerTheme.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$count requested',
                                  style: TextStyle(
                                    color: hasRequests ? GamerTheme.accentOrange : GamerTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: hasRequests ? FontWeight.bold : FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: hasRequests
                                        ? GamerTheme.accentOrange.withOpacity(0.5)
                                        : GamerTheme.textMuted.withOpacity(0.4),
                                  ),
                                ),
                                if (hasRequests) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: GamerTheme.accentOrange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: GamerTheme.accentOrange.withOpacity(0.5)),
                                    ),
                                    child: const Text(
                                      'VIEW',
                                      style: TextStyle(
                                        color: GamerTheme.accentOrange,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(),

                  // Owner Action: Close LFG
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: GamerTheme.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Close LFG', style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await SquadService().closeSquadPost(squad.id);
                    },
                  ),
                ] else if (hasRequested) ...[
                  // Requester View: Non-owner who has already requested
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 16, color: GamerTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        '${squad.joinRequests.length} requested',
                        style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Green "Requested" badge (disabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: GamerTheme.cardElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 16, color: GamerTheme.neonGreen),
                        SizedBox(width: 6),
                        Text(
                          'Requested',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: GamerTheme.neonGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Other Users: Non-owner who has not requested yet
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 16, color: GamerTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        '${squad.joinRequests.length} requested',
                        style: const TextStyle(color: GamerTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // "Request to Join" button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GamerTheme.accentOrange,
                      foregroundColor: GamerTheme.bgDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.group_add_rounded, size: 16, color: GamerTheme.bgDark),
                    label: const Text(
                      'Request to Join',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: GamerTheme.bgDark,
                      ),
                    ),
                    onPressed: _isRequesting
                        ? null
                        : () async {
                            if (currentGamer == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please create your Gamer ID to join squads!')),
                              );
                              return;
                            }
                            setState(() => _isRequesting = true);
                            await SquadService().requestJoinSquad(
                              postId: squad.id,
                              leaderUid: squad.userId,
                              applicantUid: currentGamer.uid,
                              applicantName: currentGamer.displayName,
                              applicantUsername: currentGamer.username,
                              applicantAvatar: currentGamer.photoUrl,
                              applicantTier: currentGamer.rank,
                              applicantKd: currentGamer.kdRatio,
                              applicantGameId: currentGamer.gameId,
                            );
                            setState(() => _isRequesting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Squad request sent to ${squad.displayName}!'),
                                  backgroundColor: GamerTheme.accentOrange,
                                ),
                              );
                            }
                          },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
