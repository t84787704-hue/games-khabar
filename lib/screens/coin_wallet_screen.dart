// ===============================================================================
// COIN WALLET & REWARDS SCREEN — Google Play Policy Compliant Setup
// - Weekly (7-Day) Cycle Focused on Free Fire & PUBG Mobile
// - 1,500 PKR Equivalent #1 Team Prize Divided Equally Among Up to 4 Members
// - Personal Wallet First + Manual Team Contribution (All/Max, Custom, or 0)
// - Winner-Only (#1 Team) Redemption, Personal Coin Safety & Weekly Reset to 0
// - Strict Privacy & Data Minimization (Public Gaming Handles Only)
// File: lib/screens/coin_wallet_screen.dart
// ===============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/gamer_theme.dart';
import '../models/coin_transaction_model.dart';
import '../models/coin_wallet_model.dart';
import '../models/team_model.dart';
import '../services/ad_free_service.dart';
import '../services/coin_wallet_service.dart';
import '../services/gamer_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/team_service.dart';
import '../services/theme_service.dart';
import '../widgets/coin_history_sheet.dart';
import 'coin_store_screen.dart';
import 'earn_coins_screen.dart';
import 'leaderboard_screen.dart';
import 'team_profile_screen.dart';
import 'teams_screen.dart';

class CoinWalletScreen extends StatefulWidget {
  const CoinWalletScreen({super.key});

  static String normalizeGameKeyForClaim(String gameName) {
    if (TeamService.matchesGameName(gameName, 'PUBG Mobile')) {
      return 'pubg_mobile';
    }
    return 'free_fire';
  }

  static String getConsistentRewardLabelForShare(String gameName, int shareAmountPkr) {
    final isPubg = TeamService.matchesGameName(gameName, 'PUBG Mobile');
    if (isPubg) {
      if (shareAmountPkr >= 1500) return '660 UC (1,500 PKR Share)';
      if (shareAmountPkr >= 750) return '325 UC (750 PKR Share)';
      if (shareAmountPkr >= 500) return '180 UC (500 PKR Share)';
      return '60 UC (375 PKR Share)';
    } else {
      if (shareAmountPkr >= 1500) return '520 Diamonds (1,500 PKR Share)';
      if (shareAmountPkr >= 750) return '310 Diamonds (750 PKR Share)';
      if (shareAmountPkr >= 500) return '170 Diamonds (500 PKR Share)';
      return '100 Diamonds (375 PKR Share)';
    }
  }

  /// Resolves the logged-in user's locked Game UID & default IGN directly from their Gamer Profile
  static Future<Map<String, String>> resolveLockedProfileGameIdentity({
    required String userId,
    required String gameName,
  }) async {
    final cleanUid = userId.trim();
    String lockedUid = '';
    String defaultIgn = '';

    final currentGamer = GamerAuthService().currentGamer;
    if (currentGamer != null) {
      if (currentGamer.gameId.trim().isNotEmpty &&
          currentGamer.gameId.trim().toLowerCase() != 'null' &&
          currentGamer.gameId.trim().toLowerCase() != 'id not set') {
        lockedUid = currentGamer.gameId.trim();
      }
      if (currentGamer.username.trim().isNotEmpty) {
        defaultIgn = currentGamer.username.trim();
      } else if (currentGamer.displayName.trim().isNotEmpty) {
        defaultIgn = currentGamer.displayName.trim();
      }
    }

    if ((lockedUid.isEmpty || defaultIgn.isEmpty) && cleanUid.isNotEmpty) {
      try {
        final userRow = await SupabaseService.client
            .from('users')
            .select()
            .or('id.eq.$cleanUid,uid.eq.$cleanUid')
            .maybeSingle();
        if (userRow != null) {
          for (final key in ['game_id', 'gamer_id', 'bgmiUid', 'gameId', 'inGameId']) {
            final v = (userRow[key] ?? '').toString().trim();
            if (lockedUid.isEmpty &&
                v.isNotEmpty &&
                v.toLowerCase() != 'null' &&
                v.toLowerCase() != 'id not set') {
              lockedUid = v;
              break;
            }
          }
          if (defaultIgn.isEmpty) {
            final un = (userRow['username'] ?? userRow['display_name'] ?? '').toString().trim();
            if (un.isNotEmpty && un.toLowerCase() != 'null') {
              defaultIgn = un;
            }
          }
        }
      } catch (_) {}
    }

    if ((lockedUid.isEmpty || defaultIgn.isEmpty) && cleanUid.isNotEmpty) {
      try {
        final profRow = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', cleanUid)
            .maybeSingle();
        if (profRow != null) {
          for (final key in ['game_id', 'gamer_id', 'gameId']) {
            final v = (profRow[key] ?? '').toString().trim();
            if (lockedUid.isEmpty &&
                v.isNotEmpty &&
                v.toLowerCase() != 'null' &&
                v.toLowerCase() != 'id not set') {
              lockedUid = v;
              break;
            }
          }
          if (defaultIgn.isEmpty) {
            final un = (profRow['username'] ?? profRow['display_name'] ?? '').toString().trim();
            if (un.isNotEmpty && un.toLowerCase() != 'null') {
              defaultIgn = un;
            }
          }
        }
      } catch (_) {}
    }

    if ((lockedUid.isEmpty || defaultIgn.isEmpty) && cleanUid.isNotEmpty) {
      try {
        final gUser = await GamerAuthService().getUserProfile(cleanUid);
        if (gUser != null) {
          if (lockedUid.isEmpty &&
              gUser.gameId.trim().isNotEmpty &&
              gUser.gameId.trim().toLowerCase() != 'id not set') {
            lockedUid = gUser.gameId.trim();
          }
          if (defaultIgn.isEmpty) {
            if (gUser.username.trim().isNotEmpty) {
              defaultIgn = gUser.username.trim();
            } else if (gUser.displayName.trim().isNotEmpty) {
              defaultIgn = gUser.displayName.trim();
            }
          }
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUid =
        prefs.getString('saved_game_uid_${gameName.toLowerCase()}_$cleanUid')?.trim() ?? '';
    final savedIgn =
        prefs.getString('saved_game_ign_${gameName.toLowerCase()}_$cleanUid')?.trim() ?? '';

    if (lockedUid.isEmpty && savedUid.isNotEmpty) {
      lockedUid = savedUid;
    }
    if (defaultIgn.isEmpty && savedIgn.isNotEmpty) {
      defaultIgn = savedIgn;
    }

    // Final profile fallback if user's account never set a separate numeric game_id
    if (lockedUid.isEmpty) {
      if (defaultIgn.isNotEmpty) {
        lockedUid = defaultIgn;
      } else if (cleanUid.isNotEmpty) {
        lockedUid = cleanUid.length > 10 ? cleanUid.substring(0, 10).toUpperCase() : cleanUid;
      } else {
        lockedUid = 'PROFILE-UID';
      }
    }

    return {
      'gameUid': lockedUid,
      'gameIgn': defaultIgn,
    };
  }

  /// Static helper so TeamProfileScreen can open the exact same Locked-UID Winner Team Claim dialog
  static Future<void> openWinnerTeamMemberClaimDialog({
    required BuildContext context,
    required TeamModel activeTeam,
    required String userId,
    VoidCallback? onClaimSubmitted,
  }) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return;

    final String gameName = TeamService.matchesGameName(activeTeam.game, 'PUBG Mobile')
        ? 'PUBG Mobile'
        : 'Free Fire';
    final int memberCount = activeTeam.memberCount.clamp(1, TeamModel.maxMembers);
    final int equalPkrShare = TeamService.getEqualPkrShare(memberCount);
    final String currencyLabel = TeamService.getGameCurrencyLabel(gameName);
    final String weekLabel = TeamService.getWeekRangeLabel();
    final String weekKey = TeamService.getWeekCycleKey();
    final String normalizedGameKey = normalizeGameKeyForClaim(gameName);
    final String consistentRewardLabel = getConsistentRewardLabelForShare(gameName, equalPkrShare);

    // Check public.reward_claims in Supabase for existing active claim in current round
    Map<String, dynamic>? existingClaim;
    try {
      final allTeamClaimsRows = await SupabaseService.client
          .from('reward_claims')
          .select()
          .eq('game_name', normalizedGameKey);
      final List<Map<String, dynamic>> mergedClaims = [
        ...SupabaseService.cachedRewardClaims,
        ...allTeamClaimsRows.map((e) => Map<String, dynamic>.from(e)),
      ];
      final resetInfo = TeamService.evaluateTeamRewardCycleReset(
        team: activeTeam,
        allClaims: mergedClaims,
        weekKey: weekKey,
      );
      final bool hasResetRound = (resetInfo['hasReset'] as bool?) ?? false;
      final int cutoffUtcMs = (resetInfo['cutoffUtcMs'] as num?)?.toInt() ?? 0;

      final String cleanUuid = SupabaseService.toUuid(cleanUid);
      final List<Map<String, dynamic>> candidateRows = [];
      try {
        final rows = await SupabaseService.client
            .from('reward_claims')
            .select()
            .eq('game_name', normalizedGameKey)
            .order('created_at', ascending: false);
        for (final r in rows) {
          candidateRows.add(Map<String, dynamic>.from(r));
        }
      } catch (_) {}
      for (final cached in SupabaseService.cachedRewardClaims) {
        candidateRows.add(Map<String, dynamic>.from(cached));
      }

      for (final row in candidateRows) {
        final String rowUid = (row['user_id'] ?? '').toString().trim();
        final String rowUuid = rowUid.isNotEmpty ? SupabaseService.toUuid(rowUid) : '';
        final bool uidMatch = rowUid == cleanUid ||
            rowUid.toLowerCase() == cleanUid.toLowerCase() ||
            (cleanUuid.isNotEmpty && rowUuid.toLowerCase() == cleanUuid.toLowerCase());
        if (!uidMatch) continue;
        final String rGame = (row['game_name'] ?? '').toString().trim().toLowerCase();
        if (rGame.isNotEmpty && rGame != normalizedGameKey) continue;
        final String rWeek = (row['week_key'] ?? '').toString().trim();
        if (rWeek != weekKey && !rWeek.startsWith('${weekKey}_r')) continue;
        final String rStatus = (row['status'] ?? 'pending').toString().trim().toLowerCase();
        if (rStatus == 'rejected') continue;
        if (hasResetRound && cutoffUtcMs > 0 && rStatus == 'delivered') {
          final int claimTs = TeamService.parseUtcMs(
            row['delivered_at'] ?? row['updated_at'] ?? row['created_at'],
          );
          if (claimTs <= 0 || claimTs <= cutoffUtcMs) {
            // Delivered claim belongs to a completed/reset round; do not block new round
            continue;
          }
        }
        existingClaim = row;
        break;
      }
    } catch (_) {}

    final bool isDark = ThemeService.isDarkMode;
    final Color goldTextColor = isDark ? const Color(0xFFFFD700) : const Color(0xFF92400E);
    final Color greenTextColor = isDark ? GamerTheme.neonGreen : const Color(0xFF065F46);
    final Color amberTextColor = isDark ? const Color(0xFFFFB800) : const Color(0xFFB45309);
    final Color strongBodyTextColor = isDark ? Colors.white : const Color(0xFF000000);

    if (existingClaim != null) {
      SupabaseService.upsertCachedRewardClaim(existingClaim);
      if (!context.mounted) return;
      final String existingCode = (existingClaim['claim_code'] ?? '#RW').toString();
      final String existingUid = (existingClaim['player_uid'] ?? 'N/A').toString();
      final String existingIgn = (existingClaim['player_ign'] ?? '').toString();
      final String existingTeam =
          (existingClaim['team_name'] ?? '${activeTeam.name} [${activeTeam.tag}]').toString();
      final String existingStatus =
          (existingClaim['status'] ?? 'pending').toString().toLowerCase();
      final bool isDelivered = existingStatus == 'delivered';

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isDelivered
                  ? (isDark ? GamerTheme.neonGreen : const Color(0xFF059669))
                  : (isDark ? const Color(0xFFFFB800) : const Color(0xFFD97706)),
              width: 1.4,
            ),
          ),
          title: Row(
            children: [
              Icon(
                isDelivered ? Icons.verified_rounded : Icons.check_circle_rounded,
                color: isDelivered ? greenTextColor : amberTextColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDelivered ? 'Reward Delivered! 🎉' : 'Claim Done ✅',
                  style: TextStyle(
                    color: strongBodyTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Claim ID: $existingCode',
                style: TextStyle(
                  color: goldTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Game UID: $existingUid${existingIgn.isNotEmpty ? ' ($existingIgn)' : ''}',
                style: TextStyle(
                  color: greenTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Team: $existingTeam',
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Your Share: $consistentRewardLabel',
                style: TextStyle(
                  color: goldTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDelivered
                      ? (isDark ? GamerTheme.neonGreen.withOpacity(0.15) : const Color(0xFFD1FAE5))
                      : (isDark ? const Color(0xFFFFB800).withOpacity(0.15) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDelivered
                        ? (isDark ? GamerTheme.neonGreen.withOpacity(0.5) : const Color(0xFF059669))
                        : (isDark ? const Color(0xFFFFB800).withOpacity(0.5) : const Color(0xFFD97706)),
                  ),
                ),
                child: Text(
                  isDelivered
                      ? '✅ Status: Claim Done (Delivered — آپ کا ریوارڈ بھیج دیا گیا ہے)'
                      : '✅ Status: Claim Done — Delivery in Progress (Top-up within 24–48 hrs)',
                  style: TextStyle(
                    color: isDelivered ? greenTextColor : amberTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.8,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.neonGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final identity = await resolveLockedProfileGameIdentity(
      userId: cleanUid,
      gameName: gameName,
    );
    final String lockedGameUid = identity['gameUid'] ?? '';
    final String defaultGameIgn = identity['gameIgn'] ?? '';
    final uidController = TextEditingController(text: lockedGameUid);
    final ignController = TextEditingController(text: defaultGameIgn);

    if (!context.mounted) return;
    final Map<String, String>? claimData = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? GamerTheme.neonGreen.withOpacity(0.6) : const Color(0xFF059669),
            width: 1.3,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: goldTextColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Claim #1 Team Weekly Reward',
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFFFFD700).withOpacity(0.4) : const Color(0xFFD97706),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎁 Reward: $consistentRewardLabel ($gameName)',
                      style: TextStyle(
                        color: strongBodyTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🥇 Rank #1 Team: ${activeTeam.name} [${activeTeam.tag}] ($memberCount/${TeamModel.maxMembers} active members)',
                      style: TextStyle(
                        color: goldTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '💰 Your Current Share: ${NumberFormat('#,###').format(equalPkrShare)} PKR Equivalent in $currencyLabel',
                      style: TextStyle(
                        color: greenTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '🏆 Total Team Prize: ${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR ($weekLabel)',
                      style: TextStyle(
                        color: strongBodyTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Note: Your $gameName Player UID is automatically loaded from your Gamer Profile and locked for security:',
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: uidController,
                readOnly: true,
                enableInteractiveSelection: false,
                style: TextStyle(
                  color: greenTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  labelText: '$gameName Player UID (Locked from Profile)',
                  prefixIcon: Icon(Icons.lock_rounded, color: greenTextColor, size: 18),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: isDark
                          ? GamerTheme.neonGreen.withOpacity(0.16)
                          : const Color(0xFFD1FAE5),
                      side: BorderSide(
                        color: isDark ? GamerTheme.neonGreen.withOpacity(0.45) : const Color(0xFF059669),
                      ),
                      label: Text(
                        '🔒 Locked',
                        style: TextStyle(
                          color: greenTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  helperText: '🔒 Auto-filled from your Profile — cannot be changed',
                  helperStyle: TextStyle(
                    color: strongBodyTextColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ignController,
                keyboardType: TextInputType.text,
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: 'In-Game Name (IGN) (Optional)',
                  hintText: 'Your nickname in $gameName',
                  prefixIcon: Icon(Icons.person_rounded, color: ThemeService.textSecondary, size: 18),
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: TextStyle(color: strongBodyTextColor, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.neonGreen,
              foregroundColor: Colors.black,
              iconColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.black),
            label: const Text(
              'Submit Claim',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
            ),
            onPressed: () {
              final enteredIgn = ignController.text.trim();
              Navigator.pop(ctx, {
                'gameUid': lockedGameUid,
                'gameIgn': enteredIgn,
              });
            },
          ),
        ],
      ),
    );

    if (claimData == null) return;
    final String playerGameUid = claimData['gameUid'] ?? '';
    final String playerGameIgn = claimData['gameIgn'] ?? '';
    if (playerGameUid.isEmpty) return;

    await prefs.setString('saved_game_uid_${gameName.toLowerCase()}_$cleanUid', playerGameUid);
    if (playerGameIgn.isNotEmpty) {
      await prefs.setString('saved_game_ign_${gameName.toLowerCase()}_$cleanUid', playerGameIgn);
    }

    final String claimCode =
        '#RW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final String ignSuffix = playerGameIgn.isNotEmpty ? ' ($playerGameIgn)' : '';
    final String fullTeamName = '${activeTeam.name} [${activeTeam.tag}]';

    try {
      final dupRows = await SupabaseService.client
          .from('reward_claims')
          .select('id, claim_code, status, week_key')
          .eq('user_id', cleanUid)
          .eq('game_name', normalizedGameKey)
          .order('created_at', ascending: false);
      Map<String, dynamic>? activePendingDup;
      bool hasSameWeekRow = false;
      for (final rawDup in dupRows) {
        final d = Map<String, dynamic>.from(rawDup);
        final String dWeek = (d['week_key'] ?? '').toString().trim();
        if (dWeek == weekKey) hasSameWeekRow = true;
        if (dWeek != weekKey && !dWeek.startsWith('${weekKey}_r')) continue;
        final String dStatus = (d['status'] ?? 'pending').toString().trim().toLowerCase();
        if (dStatus == 'pending' || dStatus == 'processing') {
          activePendingDup = d;
          break;
        }
      }
      if (activePendingDup != null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You already have an active submitted claim (${activePendingDup['claim_code']}) for $gameName in week $weekKey.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            backgroundColor: const Color(0xFFB45309),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final String effectiveWeekKey = hasSameWeekRow
          ? '${weekKey}_r${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}'
          : weekKey;

      final Map<String, dynamic> newClaimPayload = {
        'claim_code': claimCode,
        'user_id': cleanUid,
        'team_id': activeTeam.id,
        'team_name': fullTeamName,
        'week_key': effectiveWeekKey,
        'game_name': normalizedGameKey,
        'player_uid': playerGameUid,
        'player_ign': playerGameIgn,
        'reward_label': consistentRewardLabel,
        'share_amount_pkr': equalPkrShare,
        'status': 'pending',
      };
      List<dynamic> insertedRows = const [];
      try {
        insertedRows = await SupabaseService.client
            .from('reward_claims')
            .insert(newClaimPayload)
            .select();
      } catch (insertErr) {
        final errStr = insertErr.toString().toLowerCase();
        if (errStr.contains('23505') || errStr.contains('duplicate') || errStr.contains('unique')) {
          final fallbackPayload = {
            ...newClaimPayload,
            'week_key': '${weekKey}_r${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
          };
          insertedRows = await SupabaseService.client
              .from('reward_claims')
              .insert(fallbackPayload)
              .select();
        } else {
          rethrow;
        }
      }
      if (insertedRows.isNotEmpty) {
        SupabaseService.upsertCachedRewardClaim(
          Map<String, dynamic>.from(insertedRows.first),
        );
      } else {
        SupabaseService.upsertCachedRewardClaim({
          ...newClaimPayload,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      try {
        await CoinWalletService.updateCoins(
          userId: cleanUid,
          amount: 0,
          type: 'game_currency_redemption',
          title: '🎁 #1 Team Claimed $gameName - $consistentRewardLabel',
          description:
              'Claim $claimCode • Game UID: $playerGameUid$ignSuffix • Your Share: $equalPkrShare PKR / 1,500 PKR Total Team Prize • Team: $fullTeamName ($weekLabel) • Status: Claim Done (Delivery in 24–48 hrs)',
        );
      } catch (_) {}

      onClaimSubmitted?.call();

      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isDark ? GamerTheme.neonGreen : const Color(0xFF059669),
              width: 1.4,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.verified_rounded, color: greenTextColor, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Claim Done ✅',
                  style: TextStyle(
                    color: strongBodyTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Claim ID: $claimCode',
                style: TextStyle(
                  color: goldTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Game UID: $playerGameUid$ignSuffix',
                style: TextStyle(
                  color: greenTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Team: $fullTeamName ($memberCount/${TeamModel.maxMembers} members)',
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Your Share: $consistentRewardLabel',
                style: TextStyle(
                  color: goldTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? GamerTheme.neonGreen.withOpacity(0.15) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? GamerTheme.neonGreen.withOpacity(0.5) : const Color(0xFF059669),
                  ),
                ),
                child: Text(
                  '✅ Status: Claim Done — Delivery in Progress (Top-up within 24–48 hrs)',
                  style: TextStyle(
                    color: greenTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.8,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.neonGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting claim: $e'),
            backgroundColor: const Color(0xFFFF4655),
          ),
        );
      }
    }
  }

  @override
  State<CoinWalletScreen> createState() => _CoinWalletScreenState();
}

class _CoinWalletScreenState extends State<CoinWalletScreen> {
  final CoinWalletService _walletService = CoinWalletService();
  final TeamService _teamService = TeamService();
  final TextEditingController _customContributionCtrl = TextEditingController();
  final PageController _walletPageController = PageController();
  int _currentWalletPage = 0;

  bool _isClaimingDaily = false;
  bool _isWatchingAd = false;
  bool _isContributingCoins = false;
  String _selectedGameTab = 'Free Fire';
  String _selectedContributionMode = 'custom'; // 'all', 'custom', 'zero'
  String? _selectedContributeTeamId;
  List<TeamModel> _userTeams = [];
  bool _isLoadingTeams = true;

  Stream<CoinWallet>? _walletStream;
  Stream<List<TeamModel>>? _userTeamsStream;
  Stream<List<CoinTransaction>>? _transactionsStream;
  Stream<List<Map<String, dynamic>>>? _rewardClaimsStream;
  Stream<List<Map<String, dynamic>>>? _allRewardClaimsStream;
  String? _cachedStatsTeamId;
  Future<Map<String, dynamic>>? _teamWeeklyStatsFuture;
  final Map<String, Future<List<Map<String, dynamic>>>> _gameLeaderboardFutures = {};
  final Map<String, String> _memberHandleCache = {};

  String _resolvedUserId = '';

  String get _userId {
    final authUid = GamerAuthService().currentUid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid.trim();
    final supaUid = SupabaseService.client.auth.currentUser?.id;
    if (supaUid != null && supaUid.trim().isNotEmpty) return supaUid.trim();
    return _resolvedUserId;
  }

  @override
  void initState() {
    super.initState();
    final uid = _userId;
    final cachedTeams = uid.isNotEmpty ? _teamService.getCachedUserTeams(uid) : null;
    if (cachedTeams != null) {
      _userTeams = cachedTeams;
      _isLoadingTeams = false;
    } else {
      _isLoadingTeams = true;
    }
    _initStreams();
    _initWalletAndTeamData();
  }

  void _initStreams() {
    final uid = _userId;
    _walletStream = _walletService.walletStream(uid);
    _userTeamsStream = uid.isNotEmpty
        ? _teamService.getUserTeamsStream(uid)
        : const Stream<List<TeamModel>>.empty();
    _transactionsStream = _walletService.transactionsStream(uid);
    _rewardClaimsStream = uid.isNotEmpty
        ? SupabaseService.getRealtimeRewardClaims(userId: uid)
        : Stream.value(const <Map<String, dynamic>>[]).asBroadcastStream();
    _allRewardClaimsStream = SupabaseService.getRealtimeRewardClaims();
  }

  Future<String> _fetchMemberHandle(
    String uid, {
    required bool isLeader,
    String? leaderName,
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) {
      return isLeader ? 'Leader' : 'Gamer';
    }
    if (_memberHandleCache.containsKey(cleanUid)) {
      return _memberHandleCache[cleanUid]!;
    }

    bool isGeneric(String s) {
      final l = s.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
      return l.isEmpty ||
          l == 'player' ||
          l == 'gamer' ||
          l == 'leader' ||
          l == 'member' ||
          l == 'null';
    }

    String resolved = '';
    if (cleanUid == _userId) {
      final cg = GamerAuthService().currentGamer;
      if (cg != null) {
        if (!isGeneric(cg.username)) {
          resolved = cg.username.trim();
        } else if (!isGeneric(cg.displayName)) {
          resolved = cg.displayName.trim();
        }
      }
    }

    if (isGeneric(resolved)) {
      try {
        final userRow = await SupabaseService.client
            .from('users')
            .select()
            .or('id.eq.$cleanUid,uid.eq.$cleanUid')
            .maybeSingle();
        if (userRow != null) {
          for (final candidate in [
            (userRow['username'] ?? '').toString().trim(),
            (userRow['display_name'] ?? '').toString().trim(),
            (userRow['game_id'] ?? userRow['gamer_id'] ?? '').toString().trim(),
          ]) {
            if (!isGeneric(candidate) && !candidate.toLowerCase().startsWith('user_')) {
              resolved = candidate;
              break;
            }
          }
          if (isGeneric(resolved)) {
            for (final candidate in [
              (userRow['username'] ?? '').toString().trim(),
              (userRow['display_name'] ?? '').toString().trim(),
            ]) {
              if (!isGeneric(candidate)) {
                resolved = candidate;
                break;
              }
            }
          }
        }
      } catch (_) {}
    }

    if (isGeneric(resolved)) {
      try {
        final sbProfile = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('id', cleanUid)
            .maybeSingle();
        if (sbProfile != null) {
          for (final candidate in [
            (sbProfile['username'] ?? '').toString().trim(),
            (sbProfile['display_name'] ?? '').toString().trim(),
          ]) {
            if (!isGeneric(candidate)) {
              resolved = candidate;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (isGeneric(resolved)) {
      try {
        final gUser = await GamerAuthService().getUserProfile(cleanUid);
        if (gUser != null) {
          if (!isGeneric(gUser.username)) {
            resolved = gUser.username.trim();
          } else if (!isGeneric(gUser.displayName)) {
            resolved = gUser.displayName.trim();
          }
        }
      } catch (_) {}
    }

    if (isGeneric(resolved) && isLeader && leaderName != null && !isGeneric(leaderName)) {
      resolved = leaderName.trim();
    }

    final sanitized = TeamModel.sanitizePublicHandle(
      resolved,
      fallback: isLeader ? 'Leader' : 'Gamer',
    ).replaceFirst(RegExp(r'^@+'), '');
    _memberHandleCache[cleanUid] = sanitized;
    return sanitized;
  }

  String _normalizeGameNameForClaim(String gameName) {
    return CoinWalletScreen.normalizeGameKeyForClaim(gameName);
  }

  String _displayGameNameFromKey(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'pubg_mobile' || lower.contains('pubg') || lower.contains('bgmi')) {
      return 'PUBG Mobile';
    }
    return 'Free Fire';
  }

  String _getConsistentRewardLabel(String gameName, int shareAmountPkr) {
    return CoinWalletScreen.getConsistentRewardLabelForShare(gameName, shareAmountPkr);
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied: $text'),
        backgroundColor: GamerTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<Map<String, dynamic>> _getOrCreateTeamStatsFuture(TeamModel team) {
    final cached = _teamService.getCachedTeamWeeklyStats(team.id);
    if (_teamWeeklyStatsFuture == null || _cachedStatsTeamId != team.id) {
      _cachedStatsTeamId = team.id;
      _teamWeeklyStatsFuture = _teamService.getTeamWeeklyCoinStats(team);
    } else if (cached != null) {
      return Future.value(cached);
    }
    return _teamWeeklyStatsFuture!;
  }

  Future<List<Map<String, dynamic>>> _getOrCreateGameLeaderboardFuture(String game) {
    return _gameLeaderboardFutures.putIfAbsent(
      game,
      () => _teamService.getGameWeeklyLeaderboard(game),
    );
  }

  Future<void> _initWalletAndTeamData() async {
    if (_userId.isEmpty) {
      try {
        final fetchedUid = await SupabaseService.getCurrentUserId();
        if (fetchedUid != null && fetchedUid.trim().isNotEmpty) {
          _resolvedUserId = fetchedUid.trim();
          _initStreams();
        }
      } catch (_) {}
    }

    if (_userId.isNotEmpty) {
      _walletService.getOrCreateWallet(_userId);
      await _loadUserTeams();
    } else {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
    // Check and distribute concluded weekly cycle #1 team rewards per game
    await _teamService.checkAndDistributeWeeklyGameRewards();
  }

  Future<void> _loadUserTeams() async {
    final uid = _userId;
    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _userTeams = [];
          _isLoadingTeams = false;
        });
      }
      return;
    }
    try {
      final teams = await _teamService.getUserTeams(uid);
      if (teams.isNotEmpty) {
        final bool hasValidSelected = _selectedContributeTeamId != null &&
            teams.any((t) => t.id == _selectedContributeTeamId);
        final primary = hasValidSelected
            ? teams.firstWhere((t) => t.id == _selectedContributeTeamId)
            : teams.first;
        _selectedContributeTeamId = primary.id;
        final stats = _teamService.getCachedTeamWeeklyStats(primary.id) ??
            await _teamService.getTeamWeeklyCoinStats(primary);
        _cachedStatsTeamId = primary.id;
        _teamWeeklyStatsFuture = Future.value(stats);
      }
      if (mounted) {
        setState(() {
          _userTeams = teams;
          _isLoadingTeams = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  void _switchToWalletPage(int index) {
    if (_currentWalletPage != index) {
      setState(() => _currentWalletPage = index);
    }
    if (_walletPageController.hasClients) {
      _walletPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _customContributionCtrl.dispose();
    _walletPageController.dispose();
    super.dispose();
  }

  Future<void> _watchAdFor25Coins() async {
    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);
    try {
      await AdFreeService().showRewardedAdForAction(
        context: context,
        actionTitle: 'Watch Ad (+25 Coins)',
        onRewardEarned: () async {
          await _walletService.rewardAdCoins(_userId);
          await _loadUserTeams();
          if (mounted) {
            setState(() {});
            final bool hasTeam = _userTeams.isNotEmpty;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  hasTeam
                      ? '🎉 +25 G-Coins added to your Personal Wallet! Choose how many to contribute to your Team Profile below.'
                      : '🎉 +25 G-Coins safely saved in your Personal Wallet!',
                ),
                backgroundColor: GamerTheme.neonGreen,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ad failed to load: $e'),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
  }

  Future<void> _claimDailyBonus() async {
    if (_isClaimingDaily) return;
    setState(() => _isClaimingDaily = true);
    try {
      final ok = await _walletService.claimDailyBonus(_userId);
      if (ok) {
        await _loadUserTeams();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? (_userTeams.isNotEmpty
                    ? '🎁 +50 G-Coins daily bonus added to your Personal Wallet! Choose how many to contribute to your Team Profile below.'
                    : '🎁 +50 G-Coins safely saved in your Personal Wallet!')
                : ('daily_bonus_already_claimed'.tr() != 'daily_bonus_already_claimed'
                    ? 'daily_bonus_already_claimed'.tr()
                    : 'Already claimed today! Come back tomorrow.')),
            backgroundColor: ok ? GamerTheme.neonGreen : GamerTheme.accentOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: GamerTheme.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaimingDaily = false);
    }
  }

  Future<void> _handleContributeToTeam({
    required TeamModel team,
    required CoinWallet wallet,
    required int amount,
  }) async {
    if (_isContributingCoins) return;
    FocusScope.of(context).unfocus();

    if (amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid contribution amount (0 or higher).'),
          backgroundColor: Color(0xFFFF4655),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (amount > wallet.coins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient Personal Wallet balance! Available: ${NumberFormat('#,###').format(wallet.coins)} G-Coins.',
          ),
          backgroundColor: const Color(0xFFFF4655),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isContributingCoins = true);
    try {
      final res = await _teamService
          .contributePersonalCoinsToTeam(
            userId: _userId,
            team: team,
            amount: amount,
          )
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => <String, dynamic>{
              'success': true,
              'contributed': amount,
              'message':
                  'Contributed $amount G-Coins to ${team.name} [${team.tag}]!',
            },
          );
      _selectedContributeTeamId = team.id;
      _gameLeaderboardFutures.clear();
      _cachedStatsTeamId = team.id;
      final optimisticCached = _teamService.getCachedTeamWeeklyStats(team.id);
      _teamWeeklyStatsFuture = optimisticCached != null
          ? Future.value(optimisticCached)
          : _teamService.getTeamWeeklyCoinStats(team);

      if (mounted) {
        final bool ok = res['success'] == true;
        if (ok && amount > 0) {
          _customContributionCtrl.clear();
          _selectedContributionMode = 'custom';
        }
        setState(() {
          _isContributingCoins = false;
        });
        final String msg = (res['message'] ?? 'Contribution processed.').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
            backgroundColor: ok ? GamerTheme.neonGreen : const Color(0xFFFF4655),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Refresh full team list in the background without blocking the button spinner
      Future<void>(() async {
        try {
          await _loadUserTeams();
          if (mounted) {
            setState(() {
              _cachedStatsTeamId = null;
              _teamWeeklyStatsFuture = null;
            });
          }
        } catch (_) {}
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isContributingCoins = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contribution failed: $e'),
            backgroundColor: const Color(0xFFFF4655),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted && _isContributingCoins) {
        setState(() => _isContributingCoins = false);
      }
    }
  }

  Future<void> _refreshWallet() async {
    if (_userId.isNotEmpty) {
      _gameLeaderboardFutures.clear();
      _cachedStatsTeamId = null;
      _teamWeeklyStatsFuture = null;
      await _walletService.getOrCreateWallet(_userId);
      await _loadUserTeams();
      await _teamService.checkAndDistributeWeeklyGameRewards();
      await CoinWalletService.recalculateCoins(_userId);
    }
  }

  void _showWinnerOnlyRedemptionDialog({
    required String gameName,
    required bool hasTeam,
    int? currentRank,
    String? activeTeamName,
  }) {
    final currencyLabel = TeamService.getGameCurrencyLabel(gameName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFFB800), width: 1.4),
        ),
        title: Row(
          children: [
            Icon(
              hasTeam ? Icons.emoji_events_rounded : Icons.groups_rounded,
              color: const Color(0xFFFFB800),
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasTeam
                    ? 'Rank #1 Team Required to Redeem'
                    : 'Active Team & Rank #1 Required',
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          hasTeam
              ? 'Weekly game-currency reward redemption (${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR equivalent in $currencyLabel, divided equally among up to 4 members) is strictly unlocked for members of the Rank #1 team in $gameName.\n\n'
                  'Your team (${activeTeamName ?? 'Active Team'}) is currently Rank #${currentRank ?? '-'} in $gameName. Contribute G-Coins from your Personal Wallet to help your team reach Rank #1! All personal G-Coins in your Personal Wallet remain 100% safe across weekly resets.'
              : 'Weekly game-currency reward redemption (${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR equivalent in $currencyLabel, divided equally among up to 4 active members) is strictly unlocked for members of the Rank #1 team in $gameName.\n\n'
                  'All G-Coins in your Personal Wallet remain 100% safe in your balance and history. Join or create a 4-member Free Fire or PUBG team and contribute coins to compete for Rank #1!',
          style: TextStyle(
            color: ThemeService.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got It', style: TextStyle(color: ThemeService.textSecondary)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.neonGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(
              hasTeam ? Icons.leaderboard_rounded : Icons.shield_rounded,
              size: 16,
            ),
            label: Text(
              hasTeam ? 'View Weekly Leaderboard' : 'Join / Create Team',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (hasTeam) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                ).then((_) => _loadUserTeams());
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TeamsScreen()),
                ).then((_) => _loadUserTeams());
              }
            },
          ),
        ],
      ),
    );
  }

  /// Delegates winner team reward redemption to _redeemPack with locked profile UID
  Future<void> _handleRedeemItem(
    String gameName,
    String packTitle,
    int cost,
    CoinWallet wallet,
    List<TeamModel> activeTeams,
  ) =>
      _redeemPack(gameName, packTitle, cost, wallet, activeTeams);

  Future<void> _redeemPack(
    String gameName,
    String packTitle,
    int cost,
    CoinWallet wallet,
    List<TeamModel> activeTeams,
  ) async {
    // 1. Must belong to an active team
    if (activeTeams.isEmpty) {
      _showWinnerOnlyRedemptionDialog(
        gameName: gameName,
        hasTeam: false,
      );
      return;
    }

    // 2. Find user's team for this game (or primary team) and verify Rank #1 status
    TeamModel? matchingTeam;
    for (final t in activeTeams) {
      if (TeamService.matchesGameName(t.game, gameName)) {
        matchingTeam = t;
        break;
      }
    }
    final activeTeam = matchingTeam ?? activeTeams.first;
    final bool matchesSelectedGame = TeamService.matchesGameName(activeTeam.game, gameName);

    final stats = _teamService.getCachedTeamWeeklyStats(activeTeam.id) ??
        await _teamService.getTeamWeeklyCoinStats(activeTeam);
    final int weeklyRank = (stats['weeklyRank'] as num?)?.toInt() ??
        (activeTeam.weeklyRank > 0 ? activeTeam.weeklyRank : 2);
    final int teamWeeklyCoins = (stats['weeklyCoins'] as num?)?.toInt() ?? activeTeam.weeklyCoins;
    final bool isRankOneWinner = matchesSelectedGame && weeklyRank == 1 && teamWeeklyCoins > 0;

    // Rule 3: Winner-Only Redemption — strictly members of the #1 team in that game
    if (!isRankOneWinner) {
      _showWinnerOnlyRedemptionDialog(
        gameName: gameName,
        hasTeam: true,
        currentRank: matchesSelectedGame ? weeklyRank : null,
        activeTeamName: '${activeTeam.name} [${activeTeam.tag}] (${activeTeam.game})',
      );
      return;
    }

    final int memberCount = activeTeam.memberCount.clamp(1, TeamModel.maxMembers);
    final int equalPkrShare = TeamService.getEqualPkrShare(memberCount);
    final String currencyLabel = TeamService.getGameCurrencyLabel(gameName);
    final String weekLabel = TeamService.getWeekRangeLabel();
    final String weekKey = TeamService.getWeekCycleKey();
    final String normalizedGameKey = _normalizeGameNameForClaim(gameName);
    final String consistentRewardLabel = _getConsistentRewardLabel(gameName, equalPkrShare);

    // Check public.reward_claims in Supabase for existing active claim in current round
    Map<String, dynamic>? existingClaim;
    try {
      final allTeamClaimsRows = await SupabaseService.client
          .from('reward_claims')
          .select()
          .eq('game_name', normalizedGameKey);
      final List<Map<String, dynamic>> mergedClaims = [
        ...SupabaseService.cachedRewardClaims,
        ...allTeamClaimsRows.map((e) => Map<String, dynamic>.from(e)),
      ];
      final resetInfo = TeamService.evaluateTeamRewardCycleReset(
        team: activeTeam,
        allClaims: mergedClaims,
        weekKey: weekKey,
      );
      final bool hasResetRound = (resetInfo['hasReset'] as bool?) ?? false;
      final int cutoffUtcMs = (resetInfo['cutoffUtcMs'] as num?)?.toInt() ?? 0;

      final String cleanUid = _userId.trim();
      final String cleanUuid = cleanUid.isNotEmpty ? SupabaseService.toUuid(cleanUid) : '';
      final List<Map<String, dynamic>> candidateRows = [];
      try {
        final rows = await SupabaseService.client
            .from('reward_claims')
            .select()
            .eq('game_name', normalizedGameKey)
            .order('created_at', ascending: false);
        for (final r in rows) {
          candidateRows.add(Map<String, dynamic>.from(r));
        }
      } catch (_) {}
      for (final cached in SupabaseService.cachedRewardClaims) {
        candidateRows.add(Map<String, dynamic>.from(cached));
      }

      for (final row in candidateRows) {
        final String rowUid = (row['user_id'] ?? '').toString().trim();
        final String rowUuid = rowUid.isNotEmpty ? SupabaseService.toUuid(rowUid) : '';
        final bool uidMatch = rowUid == cleanUid ||
            rowUid.toLowerCase() == cleanUid.toLowerCase() ||
            (cleanUuid.isNotEmpty && rowUuid.toLowerCase() == cleanUuid.toLowerCase());
        if (!uidMatch) continue;
        final String rGame = (row['game_name'] ?? '').toString().trim().toLowerCase();
        if (rGame.isNotEmpty && rGame != normalizedGameKey) continue;
        final String rWeek = (row['week_key'] ?? '').toString().trim();
        if (rWeek != weekKey && !rWeek.startsWith('${weekKey}_r')) continue;
        final String rStatus = (row['status'] ?? 'pending').toString().trim().toLowerCase();
        if (rStatus == 'rejected') continue;
        if (hasResetRound && cutoffUtcMs > 0 && rStatus == 'delivered') {
          final int claimTs = TeamService.parseUtcMs(
            row['delivered_at'] ?? row['updated_at'] ?? row['created_at'],
          );
          if (claimTs <= 0 || claimTs <= cutoffUtcMs) {
            continue;
          }
        }
        existingClaim = row;
        break;
      }
    } catch (_) {}

    final bool isDark = ThemeService.isDarkMode;
    final Color goldTextColor = isDark ? const Color(0xFFFFD700) : const Color(0xFF92400E);
    final Color greenTextColor = isDark ? GamerTheme.neonGreen : const Color(0xFF065F46);
    final Color amberTextColor = isDark ? const Color(0xFFFFB800) : const Color(0xFFB45309);
    final Color strongBodyTextColor = isDark ? Colors.white : const Color(0xFF000000);

    if (existingClaim != null) {
      SupabaseService.upsertCachedRewardClaim(existingClaim);
      if (!mounted) return;
      final String existingCode = (existingClaim['claim_code'] ?? '#RW').toString();
      final String existingUid = (existingClaim['player_uid'] ?? 'N/A').toString();
      final String existingIgn = (existingClaim['player_ign'] ?? '').toString();
      final String existingTeam =
          (existingClaim['team_name'] ?? '${activeTeam.name} [${activeTeam.tag}]').toString();
      final int existingShare =
          (existingClaim['share_amount_pkr'] as num?)?.toInt() ?? equalPkrShare;
      final String existingStatus =
          (existingClaim['status'] ?? 'pending').toString().toLowerCase();
      final bool isDelivered = existingStatus == 'delivered';
      final String existingProofUrl =
          (existingClaim['proof_image_url'] ?? '').toString().trim();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isDelivered
                  ? (isDark ? GamerTheme.neonGreen : const Color(0xFF059669))
                  : (isDark ? const Color(0xFFFFB800) : const Color(0xFFD97706)),
              width: 1.4,
            ),
          ),
          title: Row(
            children: [
              Icon(
                isDelivered ? Icons.verified_rounded : Icons.check_circle_rounded,
                color: isDelivered ? greenTextColor : amberTextColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDelivered
                      ? 'Reward Already Delivered! 🎉'
                      : 'Claim Done ✅ (Weekly #1 Claim Submitted)',
                  style: TextStyle(
                    color: strongBodyTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note: A weekly #1 reward claim has already been submitted for your account in $gameName for week $weekKey ($weekLabel). Duplicate claims are not allowed.',
                  style: TextStyle(
                    color: strongBodyTextColor,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeService.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Claim ID: $existingCode',
                              style: TextStyle(
                                color: goldTextColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _copyToClipboard(existingCode, 'Claim ID'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 13, color: greenTextColor),
                                const SizedBox(width: 3),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    color: greenTextColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Game UID: $existingUid${existingIgn.isNotEmpty ? ' ($existingIgn)' : ''}',
                        style: TextStyle(
                          color: greenTextColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Team Name: $existingTeam',
                        style: TextStyle(
                          color: strongBodyTextColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Share: $consistentRewardLabel',
                        style: TextStyle(
                          color: goldTextColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Total Team Prize: ${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR (Equal Share: ${NumberFormat('#,###').format(existingShare)} PKR)',
                        style: TextStyle(
                          color: strongBodyTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDelivered
                              ? (isDark ? GamerTheme.neonGreen.withOpacity(0.14) : const Color(0xFFD1FAE5))
                              : (isDark ? const Color(0xFFFFB800).withOpacity(0.14) : const Color(0xFFFEF3C7)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDelivered
                                ? (isDark ? GamerTheme.neonGreen.withOpacity(0.5) : const Color(0xFF059669))
                                : (isDark ? const Color(0xFFFFB800).withOpacity(0.5) : const Color(0xFFD97706)),
                          ),
                        ),
                        child: Text(
                          isDelivered
                              ? '✅ Status: Claim Done (Delivered — آپ کا ریوارڈ بھیج دیا گیا ہے)'
                              : '✅ Status: Claim Done — Delivery in Progress (Top-up within 24–48 hrs)',
                          style: TextStyle(
                            color: isDelivered ? greenTextColor : amberTextColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (existingProofUrl.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildDeliveryProofThumbnail(
                          imageUrl: existingProofUrl,
                          claimCode: existingCode,
                          playerUid: existingUid,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.neonGreen,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final identity = await CoinWalletScreen.resolveLockedProfileGameIdentity(
      userId: _userId,
      gameName: gameName,
    );
    final String lockedGameUid = identity['gameUid'] ?? '';
    final String defaultGameIgn = identity['gameIgn'] ?? '';
    final uidController = TextEditingController(text: lockedGameUid);
    final ignController = TextEditingController(text: defaultGameIgn);

    if (!mounted) return;
    final Map<String, String>? claimData = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeService.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? GamerTheme.neonGreen.withOpacity(0.6) : const Color(0xFF059669),
            width: 1.3,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: goldTextColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Claim #1 Team Weekly Reward',
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFFFFD700).withOpacity(0.4) : const Color(0xFFD97706),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎁 Reward: $consistentRewardLabel ($gameName)',
                      style: TextStyle(
                        color: strongBodyTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '🥇 Rank #1 Team: ${activeTeam.name} [${activeTeam.tag}] ($memberCount/${TeamModel.maxMembers} active members)',
                      style: TextStyle(
                        color: goldTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '💰 Your Current Share: ${NumberFormat('#,###').format(equalPkrShare)} PKR Equivalent in $currencyLabel',
                      style: TextStyle(
                        color: greenTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '🏆 Total Team Prize: ${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR ($weekLabel)',
                      style: TextStyle(
                        color: strongBodyTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Note: Your $gameName Player UID is automatically loaded from your Gamer Profile and locked for security:',
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: uidController,
                readOnly: true,
                enableInteractiveSelection: false,
                style: TextStyle(
                  color: greenTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  labelText: '$gameName Player UID (Locked from Profile)',
                  prefixIcon: Icon(Icons.lock_rounded, color: greenTextColor, size: 18),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: isDark
                          ? GamerTheme.neonGreen.withOpacity(0.16)
                          : const Color(0xFFD1FAE5),
                      side: BorderSide(
                        color: isDark ? GamerTheme.neonGreen.withOpacity(0.45) : const Color(0xFF059669),
                      ),
                      label: Text(
                        '🔒 Locked',
                        style: TextStyle(
                          color: greenTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  helperText: '🔒 Auto-filled from your Profile — cannot be changed',
                  helperStyle: TextStyle(
                    color: strongBodyTextColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ignController,
                keyboardType: TextInputType.text,
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  labelText: 'In-Game Name (IGN) (Optional)',
                  hintText: 'Your nickname in $gameName',
                  prefixIcon: Icon(Icons.person_rounded, color: ThemeService.textSecondary, size: 18),
                  filled: true,
                  fillColor: ThemeService.cardSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Cancel', style: TextStyle(color: strongBodyTextColor, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: GamerTheme.neonGreen,
              foregroundColor: Colors.black,
              iconColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.black),
            label: const Text(
              'Submit Claim',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
            ),
            onPressed: () {
              final enteredIgn = ignController.text.trim();
              Navigator.pop(ctx, {
                'gameUid': lockedGameUid,
                'gameIgn': enteredIgn,
              });
            },
          ),
        ],
      ),
    );

    if (claimData == null) return;
    final String playerGameUid = claimData['gameUid'] ?? '';
    final String playerGameIgn = claimData['gameIgn'] ?? '';
    if (playerGameUid.isEmpty) return;

    await prefs.setString('saved_game_uid_${gameName.toLowerCase()}_$_userId', playerGameUid);
    if (playerGameIgn.isNotEmpty) {
      await prefs.setString('saved_game_ign_${gameName.toLowerCase()}_$_userId', playerGameIgn);
    }

    final String claimCode =
        '#RW-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final String ignSuffix = playerGameIgn.isNotEmpty ? ' ($playerGameIgn)' : '';
    final String fullTeamName = '${activeTeam.name} [${activeTeam.tag}]';

    try {
      // Double-check duplicate pending claim right before inserting into public.reward_claims
      final dupRows = await SupabaseService.client
          .from('reward_claims')
          .select('id, claim_code, status, week_key')
          .eq('user_id', _userId)
          .eq('game_name', normalizedGameKey)
          .order('created_at', ascending: false);
      Map<String, dynamic>? activePendingDup;
      bool hasSameWeekRow = false;
      for (final rawDup in dupRows) {
        final d = Map<String, dynamic>.from(rawDup);
        final String dWeek = (d['week_key'] ?? '').toString().trim();
        if (dWeek == weekKey) hasSameWeekRow = true;
        if (dWeek != weekKey && !dWeek.startsWith('${weekKey}_r')) continue;
        final String dStatus = (d['status'] ?? 'pending').toString().trim().toLowerCase();
        if (dStatus == 'pending' || dStatus == 'processing') {
          activePendingDup = d;
          break;
        }
      }
      if (activePendingDup != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You already have an active submitted claim (${activePendingDup['claim_code']}) for $gameName in week $weekKey.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            backgroundColor: const Color(0xFFB45309),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final String effectiveWeekKey = hasSameWeekRow
          ? '${weekKey}_r${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}'
          : weekKey;

      // 1. Insert into public.reward_claims
      final Map<String, dynamic> newClaimPayload = {
        'claim_code': claimCode,
        'user_id': _userId,
        'team_id': activeTeam.id,
        'team_name': fullTeamName,
        'week_key': effectiveWeekKey,
        'game_name': normalizedGameKey,
        'player_uid': playerGameUid,
        'player_ign': playerGameIgn,
        'reward_label': consistentRewardLabel,
        'share_amount_pkr': equalPkrShare,
        'status': 'pending',
      };
      List<dynamic> insertedRows = const [];
      try {
        insertedRows = await SupabaseService.client
            .from('reward_claims')
            .insert(newClaimPayload)
            .select();
      } catch (insertErr) {
        final errStr = insertErr.toString().toLowerCase();
        if (errStr.contains('23505') || errStr.contains('duplicate') || errStr.contains('unique')) {
          final fallbackPayload = {
            ...newClaimPayload,
            'week_key': '${weekKey}_r${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
          };
          insertedRows = await SupabaseService.client
              .from('reward_claims')
              .insert(fallbackPayload)
              .select();
        } else {
          rethrow;
        }
      }
      if (insertedRows.isNotEmpty) {
        SupabaseService.upsertCachedRewardClaim(
          Map<String, dynamic>.from(insertedRows.first),
        );
      } else {
        SupabaseService.upsertCachedRewardClaim({
          ...newClaimPayload,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // 2. Also record in coin_transactions for wallet ledger consistency
      try {
        await CoinWalletService.updateCoins(
          userId: _userId,
          amount: 0,
          type: 'game_currency_redemption',
          title: '🎁 #1 Team Claimed $gameName - $consistentRewardLabel',
          description:
              'Claim $claimCode • Game UID: $playerGameUid$ignSuffix • Your Share: $equalPkrShare PKR / 1,500 PKR Total Team Prize • Team: $fullTeamName ($weekLabel) • Status: Claim Done (Delivery in 24–48 hrs)',
        );
      } catch (_) {}

      if (mounted) {
        setState(() {});
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ThemeService.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isDark ? GamerTheme.neonGreen : const Color(0xFF059669),
              width: 1.4,
            ),
          ),
          title: Row(
            children: [
              Icon(Icons.verified_rounded, color: greenTextColor, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Claim Done ✅',
                  style: TextStyle(
                    color: strongBodyTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Note: Your Rank #1 Team weekly reward claim has been recorded:',
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Claim ID: $claimCode',
                            style: TextStyle(
                              color: goldTextColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _copyToClipboard(claimCode, 'Claim ID'),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? GamerTheme.neonGreen.withOpacity(0.15)
                                  : const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? GamerTheme.neonGreen.withOpacity(0.5)
                                    : const Color(0xFF059669),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 12, color: greenTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    color: greenTextColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Game UID: $playerGameUid$ignSuffix',
                      style: TextStyle(
                        color: greenTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Team Name: $fullTeamName ($memberCount/${TeamModel.maxMembers} members)',
                      style: TextStyle(
                        color: strongBodyTextColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your Share: $consistentRewardLabel',
                      style: TextStyle(
                        color: goldTextColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Team Prize: ${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR ($gameName)',
                      style: TextStyle(
                        color: strongBodyTextColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? GamerTheme.neonGreen.withOpacity(0.15) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? GamerTheme.neonGreen.withOpacity(0.5) : const Color(0xFF059669),
                        ),
                      ),
                      child: Text(
                        '✅ Status: Claim Done — Delivery in Progress (Top-up within 24–48 hrs)',
                        style: TextStyle(
                          color: greenTextColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You can track your live delivery status anytime in the "Coins & Redemption History" section below.',
                style: TextStyle(
                  color: strongBodyTextColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GamerTheme.neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (mounted) {
        if (errStr.contains('duplicate') || errStr.contains('23505') || errStr.contains('unique')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You have already submitted a weekly #1 reward claim for $gameName in week $weekKey.',
              ),
              backgroundColor: const Color(0xFFFFB800),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting claim: $e'), backgroundColor: const Color(0xFFFF4655)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, _, __) {
        final isDark = ThemeService.isDarkMode;

        return Scaffold(
          backgroundColor: ThemeService.bg,
          appBar: AppBar(
            backgroundColor: ThemeService.appBarBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: ThemeService.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'G-Coins Wallet & Rewards 🪙',
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700)),
                tooltip: 'Weekly Leaderboards',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.storefront_rounded, color: GamerTheme.neonGreen),
                tooltip: 'Store',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CoinStoreScreen()),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            color: GamerTheme.neonGreen,
            backgroundColor: ThemeService.card,
            onRefresh: _refreshWallet,
            child: StreamBuilder<CoinWallet>(
              stream: _walletStream ?? _walletService.walletStream(_userId),
              builder: (context, walletSnap) {
                final wallet = walletSnap.data ??
                    _walletService.currentWallet ??
                    CoinWallet.empty(_userId);

                return StreamBuilder<List<TeamModel>>(
                  stream: _userTeamsStream ??
                      (_userId.isNotEmpty
                          ? _teamService.getUserTeamsStream(_userId)
                          : const Stream<List<TeamModel>>.empty()),
                  builder: (context, teamsSnap) {
                    if (teamsSnap.hasData && _userId.isNotEmpty) {
                      _userTeams = teamsSnap.data!;
                      _isLoadingTeams = false;
                    }
                    final activeTeams =
                        (teamsSnap.hasData && _userId.isNotEmpty) ? teamsSnap.data! : _userTeams;
                    final bool isTeamsLoading = _isLoadingTeams;

                    return Column(
                      children: [
                        _buildWalletPageSwitcher(
                          isDark: isDark,
                          activeTeams: activeTeams,
                        ),
                        Expanded(
                          child: PageView(
                            controller: _walletPageController,
                            onPageChanged: (index) {
                              if (_currentWalletPage != index) {
                                setState(() => _currentWalletPage = index);
                              }
                            },
                            children: [
                              // Page 1: Personal Wallet
                              RefreshIndicator(
                                color: GamerTheme.neonGreen,
                                backgroundColor: ThemeService.card,
                                onRefresh: _refreshWallet,
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 1. Prominent Personal Coin Wallet Card
                                      _buildBalanceCard(
                                        wallet,
                                        isDark,
                                        activeTeams,
                                        isLoadingTeams: isTeamsLoading,
                                      ),
                                      const SizedBox(height: 14),

                                      // 2. Team Membership Status + Manual Personal-to-Team Contribution Card
                                      _buildTeamMembershipStatusBanner(
                                        wallet,
                                        activeTeams,
                                        isLoadingTeams: isTeamsLoading,
                                      ),
                                      const SizedBox(height: 16),

                                      _buildActionButtons(),
                                      const SizedBox(height: 20),

                                      // 3. Clear "Earn Coins" Cards (+25 Ad Watch, +50 Daily Bonus -> Personal Wallet First)
                                      _buildEarnCoinsSection(),
                                      const SizedBox(height: 20),

                                      // 4. Coins & Redemption History List
                                      _buildRecentTransactions(),
                                      const SizedBox(height: 20),

                                      // 6. Transparent Play Policy & Privacy Disclosure Card
                                      _buildPlayPolicyDisclosureCard(),
                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                ),
                              ),

                              // Page 2: Your Team Profile Wallet
                              RefreshIndicator(
                                color: GamerTheme.neonGreen,
                                backgroundColor: ThemeService.card,
                                onRefresh: _refreshWallet,
                                child: _buildTeamProfileWalletPage(
                                  wallet,
                                  isDark,
                                  activeTeams,
                                  isLoadingTeams: isTeamsLoading,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletPageSwitcher({
    required bool isDark,
    required List<TeamModel> activeTeams,
  }) {
    final TeamModel? primaryTeam = activeTeams.isNotEmpty
        ? activeTeams.firstWhere(
            (t) => t.id == _selectedContributeTeamId,
            orElse: () => activeTeams.first,
          )
        : null;
    final String teamSubtitle = primaryTeam != null
        ? '${primaryTeam.name} [${primaryTeam.tag}]'
        : 'Join / View Team';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: ThemeService.appBarBg,
        border: Border(
          bottom: BorderSide(
            color: ThemeService.border.withOpacity(0.6),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: ThemeService.cardSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ThemeService.border,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchToWalletPage(0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _currentWalletPage == 0
                            ? GamerTheme.neonGreen.withOpacity(isDark ? 0.2 : 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _currentWalletPage == 0
                              ? GamerTheme.neonGreen.withOpacity(0.65)
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Personal Wallet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _currentWalletPage == 0
                                    ? (isDark ? GamerTheme.neonGreen : const Color(0xFF047857))
                                    : ThemeService.textSecondary,
                                fontWeight: _currentWalletPage == 0
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _switchToWalletPage(1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                      decoration: BoxDecoration(
                        color: _currentWalletPage == 1
                            ? const Color(0xFFFFD700).withOpacity(isDark ? 0.2 : 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _currentWalletPage == 1
                              ? const Color(0xFFFFD700).withOpacity(0.75)
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🛡️', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Team Profile Wallet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _currentWalletPage == 1
                                    ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309))
                                    : ThemeService.textSecondary,
                                fontWeight: _currentWalletPage == 1
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: _currentWalletPage == 0 ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentWalletPage == 0
                      ? GamerTheme.neonGreen
                      : ThemeService.textSecondary.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: _currentWalletPage == 1 ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentWalletPage == 1
                      ? const Color(0xFFFFD700)
                      : ThemeService.textSecondary.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _switchToWalletPage(_currentWalletPage == 0 ? 1 : 0),
                child: Text(
                  _currentWalletPage == 0
                      ? 'Swipe left for Team Wallet ($teamSubtitle) →'
                      : '← Swipe right for Personal Wallet',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamProfileWalletPage(
    CoinWallet wallet,
    bool isDark,
    List<TeamModel> activeTeams, {
    required bool isLoadingTeams,
  }) {
    if (isLoadingTeams && activeTeams.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: _buildTeamLoadingSkeletonCard(),
      );
    }

    if (activeTeams.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFB800).withOpacity(0.45),
              width: 1.3,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFFFB800),
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No Active Team Joined Yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Personal G-Coins (${NumberFormat('#,###').format(wallet.coins)}) are safely stored in your Personal Wallet.\n\nJoin or create a 4-member team for Free Fire or PUBG Mobile to activate your Team Profile Wallet, contribute coins to your team\'s weekly score, and compete for the #1 Weekly 1,500 PKR Prize!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeamsScreen()),
                    );
                    _loadUserTeams();
                  },
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: const Text(
                    'Join or Create a 4-Member Team 🛡️',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB800),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _switchToWalletPage(0),
                icon: const Icon(Icons.arrow_back_rounded, size: 16, color: GamerTheme.neonGreen),
                label: const Text(
                  'Back to Personal Wallet',
                  style: TextStyle(
                    color: GamerTheme.neonGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bool hasSelectedTeam = _selectedContributeTeamId != null &&
        activeTeams.any((t) => t.id == _selectedContributeTeamId);
    final TeamModel primaryTeam = hasSelectedTeam
        ? activeTeams.firstWhere((t) => t.id == _selectedContributeTeamId)
        : activeTeams.first;
    _selectedContributeTeamId = primaryTeam.id;

    final int memberCount = primaryTeam.memberCount.clamp(1, TeamModel.maxMembers);
    final int perMemberSharePkr = (1500 / memberCount).round();
    final bool isFreeFire = TeamService.matchesGameName(primaryTeam.game, 'Free Fire');
    final String displayGameName =
        TeamService.displayGameLabel(primaryTeam.game);
    final String prizeCurrency = isFreeFire ? 'Free Fire Diamonds' : 'PUBG Mobile UC';
    final String shareRewardLabel =
        _getConsistentRewardLabel(displayGameName, perMemberSharePkr);
    final Map<String, dynamic>? cachedStats =
        _teamService.getCachedTeamWeeklyStats(primaryTeam.id);

    return FutureBuilder<Map<String, dynamic>>(
      initialData: cachedStats,
      future: _getOrCreateTeamStatsFuture(primaryTeam),
      builder: (context, snap) {
        final stats = snap.data ?? cachedStats ?? {};
        final Map<String, int> memberCoins = {};
        if (stats['memberCoins'] is Map) {
          (stats['memberCoins'] as Map).forEach((k, v) {
            memberCoins[k.toString()] = (v as num?)?.toInt() ?? 0;
          });
        }
        final Map<String, String> statsMemberNames = {};
        if (stats['memberNames'] is Map) {
          (stats['memberNames'] as Map).forEach((k, v) {
            final val = (v ?? '').toString().trim();
            if (val.isNotEmpty) {
              statsMemberNames[k.toString()] = val;
            }
          });
        }

        final String uidClean = _userId.trim();
        final String uidLower = uidClean.toLowerCase();
        final String uidUuidLower = uidClean.isNotEmpty
            ? SupabaseService.toUuid(uidClean).toLowerCase()
            : '';

        final List<Map<String, dynamic>> rawBreakdown =
            ((stats['memberBreakdown'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

        // Fallback to primaryTeam.cappedMembers (List<String>) if memberBreakdown is not populated yet
        final List<Map<String, dynamic>> memberBreakdown = rawBreakdown.isNotEmpty
            ? rawBreakdown
            : primaryTeam.cappedMembers.map((String memberUid) {
                final bool isLeader = primaryTeam.isLeader(memberUid);
                final String mClean = memberUid.trim();
                final String mLower = mClean.toLowerCase();
                final String mUuidLower = mClean.isNotEmpty
                    ? SupabaseService.toUuid(mClean).toLowerCase()
                    : '';
                String resolvedName = statsMemberNames[mClean] ??
                    statsMemberNames[mLower] ??
                    statsMemberNames[mUuidLower] ??
                    primaryTeam.memberNames[mClean] ??
                    primaryTeam.memberNames[mLower] ??
                    '';
                if (resolvedName.isEmpty &&
                    isLeader &&
                    primaryTeam.leaderName.isNotEmpty) {
                  resolvedName = primaryTeam.leaderName;
                }
                if (resolvedName.isEmpty) {
                  for (final detail in primaryTeam.memberDetails) {
                    final dUid = (detail['id'] ??
                            detail['uid'] ??
                            detail['userId'] ??
                            '')
                        .toString()
                        .trim();
                    if (dUid == mClean || dUid.toLowerCase() == mLower) {
                      resolvedName =
                          (detail['name'] ?? detail['username'] ?? '')
                              .toString()
                              .trim();
                      break;
                    }
                  }
                }
                final int mEarned = memberCoins[mClean] ??
                    memberCoins[mLower] ??
                    memberCoins[mUuidLower] ??
                    (stats.isNotEmpty
                        ? 0
                        : (primaryTeam.memberWeeklyCoins[mClean] ??
                            primaryTeam.memberWeeklyCoins[mLower] ??
                            0));
                final String cleanHandle = TeamModel.sanitizePublicHandle(
                  resolvedName,
                  fallback: isLeader ? 'Leader' : 'Gamer',
                );
                return <String, dynamic>{
                  'userId': memberUid,
                  'handle': cleanHandle,
                  'username': cleanHandle,
                  'role': isLeader ? 'Leader' : 'Member',
                  'weeklyCoins': mEarned,
                  'coins': mEarned,
                };
              }).toList();

        int breakdownCoinsSum = 0;
        int breakdownMyContrib = 0;
        for (final m in memberBreakdown) {
          final String mUid = (m['userId'] ?? '').toString().trim();
          final String mLower = mUid.toLowerCase();
          final String mUuid =
              mUid.isNotEmpty ? SupabaseService.toUuid(mUid).toLowerCase() : '';
          final int c = ((m['weeklyCoins'] ?? m['coins']) as num?)?.toInt() ??
              memberCoins[mUid] ??
              memberCoins[mLower] ??
              memberCoins[mUuid] ??
              0;
          breakdownCoinsSum += c;
          if (uidClean.isNotEmpty &&
              (mUid == uidClean || mLower == uidLower || mUuid == uidUuidLower)) {
            breakdownMyContrib = c;
          }
        }

        final int myContributedFromMap = memberCoins[uidClean] ??
            memberCoins[uidLower] ??
            memberCoins[uidUuidLower] ??
            0;
        final int myContributed = myContributedFromMap > 0
            ? myContributedFromMap
            : breakdownMyContrib;

        final int statsWeeklyCoins = stats.containsKey('weeklyCoins') ||
                stats.containsKey('totalTeamCoins')
            ? (((stats['weeklyCoins'] ?? stats['totalTeamCoins']) as num?)?.toInt() ?? 0)
            : primaryTeam.weeklyCoins;
        int teamCoins = memberBreakdown.isNotEmpty
            ? (breakdownCoinsSum >= statsWeeklyCoins ? breakdownCoinsSum : statsWeeklyCoins)
            : statsWeeklyCoins;
        if (myContributed > teamCoins) {
          teamCoins = myContributed;
        }

        final int rank = ((stats['weeklyRank'] ?? stats['rank']) as num?)?.toInt() ??
            (primaryTeam.weeklyRank > 0 ? primaryTeam.weeklyRank : 1);
        final bool isRankOne =
            (stats['isRankOne'] as bool?) ?? (rank == 1 && teamCoins > 0);

        final currentGamer = GamerAuthService().currentGamer;
        final String currentGamerHandle = currentGamer != null
            ? (currentGamer.username.trim().isNotEmpty
                ? currentGamer.username.trim()
                : currentGamer.displayName.trim())
            : '';

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Multi-team selector if user is in more than 1 team
              if (activeTeams.length > 1) ...[
                Text(
                  'SWITCH YOUR JOINED TEAM (${activeTeams.length}):',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activeTeams.map((teamItem) {
                    final bool isSelected = teamItem.id == primaryTeam.id;
                    final String teamGameLabel =
                        TeamService.displayGameLabel(teamItem.game);
                    return InkWell(
                      onTap: () {
                        if (teamItem.id == primaryTeam.id) return;
                        setState(() {
                          _selectedContributeTeamId = teamItem.id;
                          _cachedStatsTeamId = teamItem.id;
                          final cached =
                              _teamService.getCachedTeamWeeklyStats(teamItem.id);
                          _teamWeeklyStatsFuture = cached != null
                              ? Future.value(cached)
                              : _teamService.getTeamWeeklyCoinStats(teamItem);
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFD700).withOpacity(0.18)
                              : ThemeService.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFFD700)
                                : ThemeService.border,
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        child: Text(
                          '🛡️ ${teamItem.name} [${teamItem.tag}] • $teamGameLabel',
                          style: TextStyle(
                            color: isSelected
                                ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309))
                                : ThemeService.textPrimary,
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // 1. Main Team Profile Wallet Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? null : ThemeService.card,
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF1F1C2C), Color(0xFF121726)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isRankOne
                        ? const Color(0xFFFFD700).withOpacity(0.75)
                        : GamerTheme.neonGreen.withOpacity(0.45),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isRankOne ? const Color(0xFFFFD700) : GamerTheme.neonGreen)
                          .withOpacity(0.12),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Text('🛡️', style: TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'YOUR TEAM PROFILE WALLET',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ThemeService.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRankOne
                                ? (isDark
                                    ? const Color(0xFFFFD700).withOpacity(0.2)
                                    : const Color(0xFFFEF3C7))
                                : (isDark
                                    ? GamerTheme.neonGreen.withOpacity(0.14)
                                    : const Color(0xFFD1FAE5)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isRankOne
                                  ? (isDark
                                      ? const Color(0xFFFFD700).withOpacity(0.65)
                                      : const Color(0xFFD97706))
                                  : (isDark
                                      ? GamerTheme.neonGreen.withOpacity(0.45)
                                      : const Color(0xFF059669)),
                            ),
                          ),
                          child: Text(
                            rank > 0 ? '${rank == 1 ? '🥇 ' : ''}Rank #$rank' : 'Unranked',
                            style: TextStyle(
                              color: isRankOne
                                  ? (isDark ? const Color(0xFFFFD700) : const Color(0xFF92400E))
                                  : (isDark ? GamerTheme.neonGreen : const Color(0xFF065F46)),
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Team Name & Tag
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isRankOne
                                ? (isDark
                                    ? const Color(0xFFFFD700).withOpacity(0.16)
                                    : const Color(0xFFFEF3C7))
                                : (isDark
                                    ? GamerTheme.neonGreen.withOpacity(0.14)
                                    : const Color(0xFFD1FAE5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isRankOne ? Icons.emoji_events_rounded : Icons.shield_rounded,
                            color: isRankOne
                                ? (isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706))
                                : (isDark ? GamerTheme.neonGreen : const Color(0xFF059669)),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${primaryTeam.name} [${primaryTeam.tag}]',
                                style: TextStyle(
                                  color: ThemeService.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Game: $displayGameName • Members: ${primaryTeam.memberCount}/${TeamModel.maxMembers}',
                                style: TextStyle(
                                  color: isDark ? GamerTheme.neonGreen : const Color(0xFF047857),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Weekly Team Coins Big Display (Responsive Wrap header so badge never clips)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFFFFD700).withOpacity(0.35)
                              : const Color(0xFFD97706).withOpacity(0.45),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'WEEKLY TEAM COINS ($displayGameName)',
                                style: TextStyle(
                                  color: ThemeService.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? GamerTheme.neonGreen.withOpacity(0.14)
                                      : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? GamerTheme.neonGreen.withOpacity(0.35)
                                        : const Color(0xFF059669),
                                  ),
                                ),
                                child: Text(
                                  'Your Weekly Contrib: +${NumberFormat('#,###').format(myContributed)}',
                                  style: TextStyle(
                                    color: isDark ? GamerTheme.neonGreen : const Color(0xFF065F46),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 28)),
                              const SizedBox(width: 8),
                              Text(
                                NumberFormat('#,###').format(teamCoins),
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Team Coins',
                                style: TextStyle(
                                  color: ThemeService.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRankOne
                                ? '🔓 #1 Winner Redemption Unlocked in Team Profile for ${primaryTeam.name} [${primaryTeam.tag}]!'
                                : '🔒 Redeem Locked in Team Profile — Finish Rank #1 at the end of the week to unlock & divide 1,500 PKR equally among active team members.',
                            style: TextStyle(
                              color: isRankOne
                                  ? (isDark ? GamerTheme.neonGreen : const Color(0xFF047857))
                                  : ThemeService.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Weekly Prize Pool & Equal Share Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: isDark ? const Color(0xFFFFD700) : const Color(0xFFD97706),
                          size: 19,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Weekly #1 Team Prize & Equal Member Share',
                            style: TextStyle(
                              color: ThemeService.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? GamerTheme.neonGreen.withOpacity(0.12)
                                : const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? GamerTheme.neonGreen.withOpacity(0.35)
                                  : const Color(0xFF059669),
                            ),
                          ),
                          child: Text(
                            '🏆 #1 Weekly Prize: 1,500 PKR ($prizeCurrency)',
                            style: TextStyle(
                              color: isDark ? GamerTheme.neonGreen : const Color(0xFF065F46),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFFFFD700).withOpacity(0.14)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFFFFD700).withOpacity(0.45)
                                  : const Color(0xFFD97706),
                            ),
                          ),
                          child: Text(
                            '👥 Equal Share: $perMemberSharePkr PKR / member ($memberCount/${TeamModel.maxMembers})',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFFFD700) : const Color(0xFF92400E),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Your Reward Package if Rank #1: $shareRewardLabel (Divided equally among active members at week\'s end)',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weekly Cycle: ${TeamService.getWeekRangeLabel()} • Key: ${TeamService.getWeekCycleKey()}',
                      style: TextStyle(
                        color: ThemeService.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. 4-Member Weekly Contribution Breakdown Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeService.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.groups_rounded,
                                color: GamerTheme.neonGreen,
                                size: 19,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '4-Member Weekly Contribution Breakdown',
                                  style: TextStyle(
                                    color: ThemeService.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ThemeService.cardSecondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ThemeService.border),
                          ),
                          child: Text(
                            '${memberBreakdown.length}/${TeamModel.maxMembers}',
                            style: TextStyle(
                              color: ThemeService.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _allRewardClaimsStream ?? SupabaseService.getRealtimeRewardClaims(),
                      builder: (context, claimsSnap) {
                        final List<Map<String, dynamic>> allClaims = [
                          ...SupabaseService.cachedRewardClaims,
                          ...(claimsSnap.data ?? const <Map<String, dynamic>>[]),
                        ];
                        final String currentWeekKey = TeamService.getWeekCycleKey();
                        final String normalizedTeamGameKey =
                            CoinWalletScreen.normalizeGameKeyForClaim(primaryTeam.game);
                        final resetInfo = TeamService.evaluateTeamRewardCycleReset(
                          team: primaryTeam,
                          allClaims: allClaims,
                          weekKey: currentWeekKey,
                        );
                        final bool hasResetRound = (resetInfo['hasReset'] as bool?) ?? false;
                        final int cutoffUtcMs = (resetInfo['cutoffUtcMs'] as num?)?.toInt() ?? 0;

                        Map<String, dynamic>? findMemberClaim(String memberId) {
                          final cleanM = memberId.trim();
                          if (cleanM.isEmpty) return null;
                          final cleanMLower = cleanM.toLowerCase();
                          final cleanMUuidLower =
                              SupabaseService.toUuid(cleanM).toLowerCase();
                          for (final c in allClaims) {
                            final cUid = (c['user_id'] ?? '').toString().trim();
                            final cLower = cUid.toLowerCase();
                            final cUuidLower = cUid.isNotEmpty
                                ? SupabaseService.toUuid(cUid).toLowerCase()
                                : '';
                            final bool userMatches = cUid == cleanM ||
                                cLower == cleanMLower ||
                                (cleanMUuidLower.isNotEmpty && cUuidLower == cleanMUuidLower);
                            if (!userMatches) continue;
                            final cWeek = (c['week_key'] ?? '').toString().trim();
                            final cGame = (c['game_name'] ?? '').toString().trim().toLowerCase();
                            final String status =
                                (c['status'] ?? 'pending').toString().toLowerCase();
                            if (status == 'rejected') continue;
                            final bool weekMatches = cWeek.isEmpty ||
                                cWeek == currentWeekKey ||
                                cWeek.startsWith('${currentWeekKey}_r');
                            if (weekMatches &&
                                (cGame.isEmpty || cGame == normalizedTeamGameKey)) {
                              if (hasResetRound && cutoffUtcMs > 0 && status == 'delivered') {
                                final int claimTs = TeamService.parseUtcMs(
                                  c['delivered_at'] ?? c['updated_at'] ?? c['created_at'],
                                );
                                if (claimTs <= 0 || claimTs <= cutoffUtcMs) {
                                  // Completed & delivered round has been reset to 0
                                  continue;
                                }
                              }
                              return c;
                            }
                          }
                          return null;
                        }

                        return Column(
                          children: memberBreakdown.map((m) {
                            final String mUid = (m['userId'] ?? '').toString().trim();
                            final String mLower = mUid.toLowerCase();
                            final String mUuidLower = mUid.isNotEmpty
                                ? SupabaseService.toUuid(mUid).toLowerCase()
                                : '';
                            final bool isCurrentUser = uidClean.isNotEmpty &&
                                (mUid == uidClean ||
                                    mLower == uidLower ||
                                    mUuidLower == uidUuidLower);
                            final bool isMemberLeader = primaryTeam.isLeader(mUid) ||
                                (m['role'] ?? '').toString().toLowerCase() == 'leader';

                            String candidateName = (m['handle'] ??
                                    m['username'] ??
                                    m['gamerId'] ??
                                    statsMemberNames[mUid] ??
                                    statsMemberNames[mLower] ??
                                    statsMemberNames[mUuidLower] ??
                                    primaryTeam.memberNames[mUid] ??
                                    primaryTeam.memberNames[mLower] ??
                                    '')
                                .toString()
                                .trim();

                            bool isGenericName(String s) {
                              final l =
                                  s.trim().toLowerCase().replaceFirst(RegExp(r'^@+'), '');
                              return l.isEmpty ||
                                  l == 'player' ||
                                  l == 'gamer' ||
                                  l == 'leader' ||
                                  l == 'member' ||
                                  l == 'null';
                            }

                            if (isGenericName(candidateName) &&
                                isCurrentUser &&
                                currentGamerHandle.isNotEmpty) {
                              candidateName = currentGamerHandle;
                            }
                            if (isGenericName(candidateName) &&
                                isMemberLeader &&
                                primaryTeam.leaderName.trim().isNotEmpty &&
                                !isGenericName(primaryTeam.leaderName)) {
                              candidateName = primaryTeam.leaderName.trim();
                            }
                            if (isGenericName(candidateName)) {
                              for (final detail in primaryTeam.memberDetails) {
                                final dUid = (detail['id'] ??
                                        detail['uid'] ??
                                        detail['userId'] ??
                                        '')
                                    .toString()
                                    .trim();
                                if (dUid == mUid || dUid.toLowerCase() == mLower) {
                                  final dName =
                                      (detail['name'] ?? detail['username'] ?? '')
                                          .toString()
                                          .trim();
                                  if (!isGenericName(dName)) {
                                    candidateName = dName;
                                    break;
                                  }
                                }
                              }
                            }

                            final String cleanUsername = TeamModel.sanitizePublicHandle(
                              candidateName,
                              fallback: isMemberLeader ? 'Leader' : 'Gamer',
                            ).replaceFirst(RegExp(r'^@+'), '');
                            final String initialHandle = '@$cleanUsername';

                            final int coins =
                                ((m['weeklyCoins'] ?? m['coins']) as num?)?.toInt() ??
                                    memberCoins[mUid] ??
                                    memberCoins[mLower] ??
                                    memberCoins[mUuidLower] ??
                                    0;
                            final double shareRatio =
                                teamCoins > 0 ? (coins / teamCoins).clamp(0.0, 1.0) : 0.0;

                            final Map<String, dynamic>? memberClaim = findMemberClaim(mUid);
                            final bool hasMemberClaimed = memberClaim != null;
                            final bool isMemberClaimDelivered =
                                (memberClaim?['status'] ?? '').toString().toLowerCase() ==
                                    'delivered';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrentUser
                                    ? GamerTheme.neonGreen.withOpacity(0.08)
                                    : ThemeService.cardSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrentUser
                                      ? GamerTheme.neonGreen.withOpacity(0.45)
                                      : ThemeService.border,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              isMemberLeader ? '👑' : '🎮',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: isGenericName(cleanUsername) &&
                                                      mUid.isNotEmpty
                                                  ? FutureBuilder<String>(
                                                      future: _fetchMemberHandle(
                                                        mUid,
                                                        isLeader: isMemberLeader,
                                                        leaderName: primaryTeam.leaderName,
                                                      ),
                                                      builder: (context, handleSnap) {
                                                        final resolved =
                                                            (handleSnap.data ?? cleanUsername)
                                                                .replaceFirst(
                                                                    RegExp(r'^@+'), '');
                                                        return Text(
                                                          '@$resolved',
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: TextStyle(
                                                            color: ThemeService.textPrimary,
                                                            fontSize: 12.5,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        );
                                                      },
                                                    )
                                                  : Text(
                                                      initialHandle,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: ThemeService.textPrimary,
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                            ),
                                            if (isCurrentUser) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? GamerTheme.neonGreen.withOpacity(0.2)
                                                      : const Color(0xFFD1FAE5),
                                                  borderRadius: BorderRadius.circular(5),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? GamerTheme.neonGreen.withOpacity(0.5)
                                                        : const Color(0xFF059669),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  'YOU',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? GamerTheme.neonGreen
                                                        : const Color(0xFF065F46),
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '+${NumberFormat('#,###').format(coins)} Coins',
                                        style: TextStyle(
                                          color: coins > 0
                                              ? (isDark
                                                  ? const Color(0xFFFFD700)
                                                  : const Color(0xFFB45309))
                                              : ThemeService.textSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: shareRatio,
                                      minHeight: 5,
                                      backgroundColor: ThemeService.border.withOpacity(0.45),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        coins > 0
                                            ? (isDark
                                                ? GamerTheme.neonGreen
                                                : const Color(0xFF059669))
                                            : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  // Per-Member Reward Share & Individual Claim Action / Status
                                  if (isRankOne) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ThemeService.card,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: hasMemberClaimed
                                              ? (isDark
                                                  ? GamerTheme.neonGreen.withOpacity(0.55)
                                                  : const Color(0xFF059669))
                                              : (isDark
                                                  ? const Color(0xFFFFD700).withOpacity(0.45)
                                                  : const Color(0xFFD97706)),
                                        ),
                                      ),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.card_giftcard_rounded,
                                                color: isDark
                                                    ? const Color(0xFFFFD700)
                                                    : const Color(0xFFD97706),
                                                size: 15,
                                              ),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  'Reward Share: $shareRewardLabel',
                                                  style: TextStyle(
                                                    color: ThemeService.textPrimary,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (hasMemberClaimed)
                                            InkWell(
                                              onTap: isCurrentUser
                                                  ? () => _handleRedeemItem(
                                                        displayGameName,
                                                        shareRewardLabel,
                                                        0,
                                                        wallet,
                                                        activeTeams,
                                                      )
                                                  : null,
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? GamerTheme.neonGreen.withOpacity(0.16)
                                                      : const Color(0xFFD1FAE5),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? GamerTheme.neonGreen.withOpacity(0.6)
                                                        : const Color(0xFF059669),
                                                  ),
                                                ),
                                                child: Text(
                                                  isMemberClaimDelivered
                                                      ? '✅ Claim Done (Delivered)'
                                                      : '✅ Claim Done',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? GamerTheme.neonGreen
                                                        : const Color(0xFF065F46),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else if (isCurrentUser)
                                            SizedBox(
                                              height: 32,
                                              child: ElevatedButton.icon(
                                                onPressed: () => _handleRedeemItem(
                                                  displayGameName,
                                                  shareRewardLabel,
                                                  0,
                                                  wallet,
                                                  activeTeams,
                                                ),
                                                icon: const Icon(
                                                  Icons.redeem_rounded,
                                                  size: 14,
                                                  color: Colors.black,
                                                ),
                                                label: Text(
                                                  'Claim $shareRewardLabel',
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: GamerTheme.neonGreen,
                                                  foregroundColor: Colors.black,
                                                  iconColor: Colors.black,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 9,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFFFFB800).withOpacity(0.14)
                                                    : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isDark
                                                      ? const Color(0xFFFFB800).withOpacity(0.45)
                                                      : const Color(0xFFD97706),
                                                ),
                                              ),
                                              child: Text(
                                                '⏳ Not Claimed Yet',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? const Color(0xFFFFB800)
                                                      : const Color(0xFF92400E),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Direct Personal-to-Team Contribution Box on Team Profile Wallet Page
              _buildManualTeamContributionBox(primaryTeam, wallet),
              const SizedBox(height: 14),

              // 5. Quick Actions: Open Full Team Profile & Weekly Leaderboard
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeamProfileScreen(
                              teamId: primaryTeam.id,
                              team: primaryTeam,
                            ),
                          ),
                        );
                        _loadUserTeams();
                      },
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: isDark ? GamerTheme.neonGreen : const Color(0xFF047857),
                      ),
                      label: Text(
                        'Full Team Profile',
                        style: TextStyle(
                          color: isDark ? GamerTheme.neonGreen : const Color(0xFF047857),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? Colors.transparent : const Color(0xFFECFDF5),
                        side: BorderSide(
                          color: isDark
                              ? GamerTheme.neonGreen.withOpacity(0.55)
                              : const Color(0xFF059669),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                        );
                      },
                      icon: Icon(
                        Icons.emoji_events_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309),
                      ),
                      label: Text(
                        'Top Teams Rank',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? Colors.transparent : const Color(0xFFFFFBEB),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFFFFD700).withOpacity(0.55)
                              : const Color(0xFFD97706),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceCard(
    CoinWallet wallet,
    bool isDark,
    List<TeamModel> activeTeams, {
    required bool isLoadingTeams,
  }) {
    final bool hasTeam = activeTeams.isNotEmpty;
    final TeamModel? primaryTeam = hasTeam
        ? activeTeams.firstWhere(
            (t) => t.id == _selectedContributeTeamId,
            orElse: () => activeTeams.first,
          )
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? null : ThemeService.card,
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF141D2E), Color(0xFF0F1523)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GamerTheme.neonGreen.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: GamerTheme.neonGreen.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PERSONAL G-COINS BALANCE',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              if (isLoadingTeams)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: ThemeService.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Checking Team...',
                        style: TextStyle(
                          color: ThemeService.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _switchToWalletPage(1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: hasTeam
                          ? GamerTheme.neonGreen.withOpacity(0.15)
                          : const Color(0xFFFFB800).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasTeam ? '🛡️ Team Eligible →' : '👤 Solo Wallet (Saved)',
                      style: TextStyle(
                        color: hasTeam ? GamerTheme.neonGreen : const Color(0xFFFFB800),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Text(
                NumberFormat('#,###').format(wallet.coins),
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _switchToWalletPage(1),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: ThemeService.cardSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.35),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      primaryTeam != null
                          ? 'Swipe left or tap for Team Wallet: ${primaryTeam.name} [${primaryTeam.tag}] →'
                          : 'Swipe left or tap to open Your Team Profile Wallet →',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamLoadingSkeletonCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeService.border, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GamerTheme.neonGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checking Active Team Membership...',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 10,
                      width: 180,
                      decoration: BoxDecoration(
                        color: ThemeService.cardSecondary,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 34,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ThemeService.cardSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
    );
  }

  /// Displays either:
  /// - Loading skeleton placeholder while active team membership is resolving.
  /// - Solo User Notice: confirming personal earned coins are safely kept in Personal Wallet while explaining how to join a Free Fire or PUBG team for the 1,500 PKR weekly competition.
  /// - Active Team Summary + Manual Coin Contribution Card: allowing the user to contribute All/Max, a custom amount, or 0 (Keep in Personal Wallet) to their Team Profile.
  Widget _buildTeamMembershipStatusBanner(
    CoinWallet wallet,
    List<TeamModel> activeTeams, {
    required bool isLoadingTeams,
  }) {
    if (isLoadingTeams) {
      return _buildTeamLoadingSkeletonCard();
    }

    if (activeTeams.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB800).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFFFFB800), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Solo Player Notice • Personal Coins 100% Safe',
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'All G-Coins you earn from watching ads (+25) or daily bonuses (+50) go directly into your Personal Wallet and remain safely stored across weekly resets. '
              'To compete for the weekly 1,500 PKR equivalent #1 Team Prize in Free Fire or PUBG Mobile (and unlock #1 team reward redemption), join or create a 4-member team.',
              style: TextStyle(
                color: ThemeService.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.groups_rounded, size: 16),
                label: const Text(
                  'Join or Create a 4-Member Team 🛡️',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeamsScreen()),
                  ).then((_) => _loadUserTeams());
                },
              ),
            ),
          ],
        ),
      );
    }

    final bool hasValidSelected = _selectedContributeTeamId != null &&
        activeTeams.any((t) => t.id == _selectedContributeTeamId);
    final TeamModel primaryTeam = hasValidSelected
        ? activeTeams.firstWhere((t) => t.id == _selectedContributeTeamId)
        : activeTeams.first;
    _selectedContributeTeamId = primaryTeam.id;

    final cachedStats = _teamService.getCachedTeamWeeklyStats(primaryTeam.id);
    return FutureBuilder<Map<String, dynamic>>(
      initialData: cachedStats,
      future: _getOrCreateTeamStatsFuture(primaryTeam),
      builder: (context, snap) {
        final stats = snap.data ?? cachedStats;
        final int statsWeeklyCoins = (stats?['weeklyCoins'] as num?)?.toInt() ?? 0;
        final int breakdownCoins = (stats?['memberBreakdown'] is List)
            ? (stats!['memberBreakdown'] as List).fold<int>(
                0,
                (sum, m) => sum + ((m is Map ? (m['weeklyCoins'] as num?)?.toInt() : 0) ?? 0),
              )
            : 0;
        final int teamWeeklyCoins =
            (stats != null && stats['memberBreakdown'] is List) ? breakdownCoins : statsWeeklyCoins;

        final int weeklyRank = (stats?['weeklyRank'] as num?)?.toInt() ??
            (primaryTeam.weeklyRank > 0 ? primaryTeam.weeklyRank : 1);
        final int memberCount = primaryTeam.memberCount.clamp(1, TeamModel.maxMembers);
        final int equalPkrShare = TeamService.getEqualPkrShare(memberCount);
        final String displayGameLabel = TeamService.displayGameLabel(primaryTeam.game);
        final String currencyLabel = TeamService.getGameCurrencyLabel(displayGameLabel);
        final String weekLabel = TeamService.getWeekRangeLabel();
        final bool isRankOneWinner = weeklyRank == 1 && teamWeeklyCoins > 0;

        // Calculate current user's weekly contribution strictly to this team & game
        int myWeeklyContrib = 0;
        if (stats?['memberCoins'] is Map) {
          final map = stats!['memberCoins'] as Map;
          final uidClean = _userId.trim();
          final uidLower = uidClean.toLowerCase();
          final uidUuid = SupabaseService.toUuid(uidClean).toLowerCase();
          myWeeklyContrib = (map[uidClean] as num?)?.toInt() ??
              (map[uidLower] as num?)?.toInt() ??
              (map[uidUuid] as num?)?.toInt() ??
              0;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRankOneWinner
                  ? const Color(0xFFFFD700).withOpacity(0.65)
                  : GamerTheme.neonGreen.withOpacity(0.45),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeTeams.length > 1) ...[
                Text(
                  'Select Target Team for Coin Transfer (${activeTeams.length} Joined Teams):',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.2,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: activeTeams.map((t) {
                      final isSel = t.id == primaryTeam.id;
                      final tGame = TeamService.displayGameLabel(t.game);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            '${t.name} [${t.tag}] • $tGame',
                            style: TextStyle(
                              color: isSel ? Colors.black : ThemeService.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          selected: isSel,
                          selectedColor: GamerTheme.neonGreen,
                          backgroundColor: ThemeService.cardSecondary,
                          side: BorderSide(
                            color: isSel ? GamerTheme.neonGreen : ThemeService.border,
                          ),
                          onSelected: (_) {
                            setState(() {
                              _selectedContributeTeamId = t.id;
                              _cachedStatsTeamId = null;
                              _teamWeeklyStatsFuture = null;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isRankOneWinner
                          ? const Color(0xFFFFD700).withOpacity(0.18)
                          : GamerTheme.neonGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRankOneWinner ? Icons.emoji_events_rounded : Icons.verified_rounded,
                      color: isRankOneWinner ? const Color(0xFFFFD700) : GamerTheme.neonGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Team: ${primaryTeam.name} [${primaryTeam.tag}]',
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Game: $displayGameLabel • Members: $memberCount/${TeamModel.maxMembers} • ${isRankOneWinner ? '#1 Winner Redemption Unlocked 🔓' : 'Reach #1 to Redeem ($weekLabel)'}',
                          style: TextStyle(
                            color: isRankOneWinner
                                ? (ThemeService.isDarkMode
                                    ? GamerTheme.neonGreen
                                    : const Color(0xFF047857))
                                : ThemeService.textSecondary,
                            fontSize: 11,
                            fontWeight: isRankOneWinner ? FontWeight.w800 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ThemeService.isDarkMode
                          ? const Color(0xFFFFD700).withOpacity(0.15)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ThemeService.isDarkMode
                            ? const Color(0xFFFFD700).withOpacity(0.5)
                            : const Color(0xFFD97706),
                      ),
                    ),
                    child: Text(
                      '${weeklyRank == 1 ? '🥇 ' : ''}Rank #$weeklyRank',
                      style: TextStyle(
                        color: ThemeService.isDarkMode
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF92400E),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Weekly Team Coins: ${NumberFormat('#,###').format(teamWeeklyCoins)}',
                          style: TextStyle(
                            color: ThemeService.isDarkMode
                                ? const Color(0xFFFFD700)
                                : const Color(0xFFB45309),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Your Weekly Contrib: +${NumberFormat('#,###').format(myWeeklyContrib)}',
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 0.8,
                      color: ThemeService.border,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '#1 Weekly Prize: ${NumberFormat('#,###').format(TeamService.weeklyGameRewardPkr)} PKR ($currencyLabel)',
                          style: TextStyle(
                            color: ThemeService.isDarkMode
                                ? GamerTheme.neonGreen
                                : const Color(0xFF047857),
                            fontWeight: FontWeight.w900,
                            fontSize: 11.2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: ThemeService.card,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: ThemeService.border),
                          ),
                          child: Text(
                            'Equal Share: ${NumberFormat('#,###').format(equalPkrShare)} PKR / member',
                            style: TextStyle(
                              color: ThemeService.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Manual Personal-to-Team Contribution Controls
              _buildManualTeamContributionBox(primaryTeam, wallet),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 14,
                    color: ThemeService.isDarkMode
                        ? GamerTheme.neonGreen
                        : const Color(0xFF047857),
                  ),
                  label: Text(
                    'View 4-Member Breakdown in Team Profile',
                    style: TextStyle(
                      color: ThemeService.isDarkMode
                          ? GamerTheme.neonGreen
                          : const Color(0xFF047857),
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamProfileScreen(
                          teamId: primaryTeam.id,
                          team: primaryTeam,
                        ),
                      ),
                    ).then((_) => _loadUserTeams());
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Interactive box inside the Wallet screen allowing the user to manually transfer/contribute
  /// personal G-Coins to their active Team Profile (`All / Max`, custom amount, or `0` to keep in Personal Wallet).
  Widget _buildManualTeamContributionBox(TeamModel team, CoinWallet wallet) {
    final int availableCoins = wallet.coins.clamp(0, 999999999);
    final String displayGameLabel = TeamService.displayGameLabel(team.game);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeService.cardSecondary.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GamerTheme.neonGreen.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: GamerTheme.neonGreen, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Contribute Personal Coins to Team ($displayGameLabel)',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how many coins from your Personal Wallet (${NumberFormat('#,###').format(availableCoins)} available) to add to ${team.name}\'s weekly score. Weekly team scores reset to 0 every Monday; uncontributed coins stay safely in your Personal Wallet.',
            style: TextStyle(
              color: ThemeService.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _contributionPresetChip(
                label: 'All / Max (${NumberFormat('#,###').format(availableCoins)})',
                isSelected: _selectedContributionMode == 'all',
                onTap: () {
                  setState(() {
                    _selectedContributionMode = 'all';
                    _customContributionCtrl.text = availableCoins.toString();
                  });
                },
              ),
              if (availableCoins >= 100)
                _contributionPresetChip(
                  label: '+100 Coins',
                  isSelected: _selectedContributionMode == '100',
                  onTap: () {
                    setState(() {
                      _selectedContributionMode = '100';
                      _customContributionCtrl.text = '100';
                    });
                  },
                ),
              if (availableCoins >= 500)
                _contributionPresetChip(
                  label: '+500 Coins',
                  isSelected: _selectedContributionMode == '500',
                  onTap: () {
                    setState(() {
                      _selectedContributionMode = '500';
                      _customContributionCtrl.text = '500';
                    });
                  },
                ),
              _contributionPresetChip(
                label: 'Keep in Personal Wallet (0)',
                isSelected: _selectedContributionMode == 'zero',
                onTap: () {
                  setState(() {
                    _selectedContributionMode = 'zero';
                    _customContributionCtrl.text = '0';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _customContributionCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) {
                      if (_selectedContributionMode != 'custom') {
                        setState(() => _selectedContributionMode = 'custom');
                      }
                    },
                    style: TextStyle(
                      color: ThemeService.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter amount (0 – $availableCoins)',
                      hintStyle: TextStyle(
                        color: ThemeService.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: const Icon(
                        Icons.monetization_on_outlined,
                        color: Color(0xFFFFD700),
                        size: 17,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: ThemeService.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ThemeService.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ThemeService.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: GamerTheme.neonGreen, width: 1.3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GamerTheme.neonGreen,
                    foregroundColor: Colors.black,
                    iconColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: _isContributingCoins
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.shield_rounded, size: 16, color: Colors.black),
                  label: Text(
                    _isContributingCoins ? 'Sending...' : 'Contribute',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                  onPressed: _isContributingCoins
                      ? null
                      : () {
                          final rawText = _customContributionCtrl.text.trim();
                          final int parsed = rawText.isEmpty
                              ? (_selectedContributionMode == 'all' ? availableCoins : 0)
                              : (int.tryParse(rawText) ?? -1);
                          _handleContributeToTeam(
                            team: team,
                            wallet: wallet,
                            amount: parsed,
                          );
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contributionPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bool isDark = ThemeService.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? GamerTheme.neonGreen.withOpacity(0.2)
                  : const Color(0xFFD1FAE5))
              : ThemeService.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isDark ? GamerTheme.neonGreen : const Color(0xFF059669))
                : ThemeService.border,
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? GamerTheme.neonGreen : const Color(0xFF065F46))
                : ThemeService.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final bool isDark = ThemeService.isDarkMode;
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.play_circle_fill_rounded,
            label: 'Earn Coins ⚡',
            color: isDark ? GamerTheme.neonGreen : const Color(0xFF047857),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EarnCoinsScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            icon: Icons.shield_rounded,
            label: 'Team Profile Wallet 🛡️',
            color: isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309),
            onTap: () => _switchToWalletPage(1),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarnCoinsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚡ Earn Free Coins (Added to Personal Wallet First)',
          style: TextStyle(
            color: ThemeService.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _earnCard(
                title: _isWatchingAd ? 'Loading...' : 'Watch Ad',
                reward: '+25 Coins',
                icon: Icons.video_library_rounded,
                color: GamerTheme.accentBlue,
                onTap: _watchAdFor25Coins,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _earnCard(
                title: 'Daily Bonus',
                reward: '+50 Coins',
                icon: Icons.card_giftcard_rounded,
                color: GamerTheme.neonGreen,
                onTap: _claimDailyBonus,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _earnCard(
                title: 'Invite Friend',
                reward: '+100 Coins',
                icon: Icons.group_add_rounded,
                color: const Color(0xFFFFB800),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EarnCoinsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _earnCard({
    required String title,
    required String reward,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeService.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                reward,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemGameCurrencySection(
    CoinWallet wallet,
    List<TeamModel> activeTeams, {
    required bool isLoadingTeams,
  }) {
    final games = TeamService.supportedGames; // ['Free Fire', 'PUBG Mobile']
    if (!games.contains(_selectedGameTab)) {
      _selectedGameTab = games.first;
    }
    final bool hasTeam = activeTeams.isNotEmpty;

    // Check if the user belongs to the Rank #1 team in _selectedGameTab
    TeamModel? matchingGameTeam;
    for (final t in activeTeams) {
      if (TeamService.matchesGameName(t.game, _selectedGameTab)) {
        matchingGameTeam = t;
        break;
      }
    }
    final TeamModel? evaluatedTeam = matchingGameTeam ?? (activeTeams.isNotEmpty ? activeTeams.first : null);
    final cachedTeamStats = evaluatedTeam != null
        ? _teamService.getCachedTeamWeeklyStats(evaluatedTeam.id)
        : null;
    final int teamRankInGame = (cachedTeamStats?['weeklyRank'] as num?)?.toInt() ??
        (evaluatedTeam?.weeklyRank ?? 0);
    final int teamWeeklyCoinsInGame = (cachedTeamStats?['weeklyCoins'] as num?)?.toInt() ??
        (evaluatedTeam?.weeklyCoins ?? 0);
    final bool isRankOneInSelectedGame = hasTeam &&
        evaluatedTeam != null &&
        TeamService.matchesGameName(evaluatedTeam.game, _selectedGameTab) &&
        teamRankInGame == 1 &&
        teamWeeklyCoinsInGame > 0;

    final packsMap = {
      'Free Fire': [
        {'title': '100 Diamonds (375 PKR Share)', 'cost': 500, 'icon': '💎'},
        {'title': '310 Diamonds (750 PKR Share)', 'cost': 1400, 'icon': '💎'},
        {'title': '520 Diamonds (1,500 PKR #1 Pool)', 'cost': 2200, 'icon': '💎'},
      ],
      'PUBG Mobile': [
        {'title': '60 UC (375 PKR Share)', 'cost': 600, 'icon': '🪙'},
        {'title': '325 UC (750 PKR Share)', 'cost': 2800, 'icon': '🪙'},
        {'title': '660 UC (1,500 PKR #1 Pool)', 'cost': 5400, 'icon': '🪙'},
      ],
    };

    final currentPacks = packsMap[_selectedGameTab] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '🎮 Redeem Game Currency (#1 Team)',
                style: TextStyle(
                  color: ThemeService.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (isLoadingTeams)
              Text(
                'Checking Team...',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                isRankOneInSelectedGame
                    ? '🥇 #1 Team Unlocked'
                    : (hasTeam ? 'Requires Rank #1 🏆' : 'Requires #1 Team 🔒'),
                style: TextStyle(
                  color: isRankOneInSelectedGame
                      ? GamerTheme.neonGreen
                      : const Color(0xFFFFB800),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Two Weekly Competition Games Tabs: Free Fire & PUBG Mobile
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: games.map((game) {
              final isSelected = game == _selectedGameTab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(game),
                  selected: isSelected,
                  selectedColor: GamerTheme.neonGreen,
                  backgroundColor: ThemeService.card,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _selectedGameTab = game),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Per-Game Weekly #1 Team Reward Banner (1,500 PKR Equivalent) for selected game
        _buildPerGameWeeklyTopTeamCard(_selectedGameTab),
        const SizedBox(height: 12),

        // Reward Packs List (Winner-Only Redemption)
        Column(
          children: currentPacks.map((pack) {
            final title = pack['title'] as String;
            final cost = pack['cost'] as int;
            final icon = pack['icon'] as String;
            final canRedeem = !isLoadingTeams && isRankOneInSelectedGame;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: canRedeem
                      ? GamerTheme.neonGreen.withOpacity(0.45)
                      : ThemeService.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ThemeService.cardSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: ThemeService.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isLoadingTeams
                              ? '⏳ Checking active team rank...'
                              : (!hasTeam
                                  ? '🛡️ Join a 4-Member Team • Weekly #1 Team Only (1,500 PKR Pool)'
                                  : (!isRankOneInSelectedGame
                                      ? '🏆 Weekly Rank #1 Team Only • Your Current Share: ${NumberFormat('#,###').format(TeamService.getEqualPkrShare(evaluatedTeam!.memberCount.clamp(1, TeamModel.maxMembers)))} PKR (${evaluatedTeam.memberCount.clamp(1, TeamModel.maxMembers)}/4 members • 1,500 PKR Pool)'
                                      : '🥇 Rank #1 Unlocked • Your Current Share: ${NumberFormat('#,###').format(TeamService.getEqualPkrShare(evaluatedTeam.memberCount.clamp(1, TeamModel.maxMembers)))} PKR (${evaluatedTeam.memberCount.clamp(1, TeamModel.maxMembers)}/4 members • 1,500 PKR Pool)')),
                          style: TextStyle(
                            color: isLoadingTeams
                                ? ThemeService.textSecondary
                                : (isRankOneInSelectedGame
                                    ? GamerTheme.neonGreen
                                    : const Color(0xFFFFB800)),
                            fontSize: 11.3,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLoadingTeams
                          ? ThemeService.cardSecondary
                          : (canRedeem
                              ? GamerTheme.neonGreen
                              : const Color(0xFFFFB800).withOpacity(0.18)),
                      foregroundColor: isLoadingTeams
                          ? ThemeService.textSecondary
                          : (canRedeem
                              ? Colors.black
                              : const Color(0xFFFFB800)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: isLoadingTeams
                        ? null
                        : () => _redeemPack(
                              _selectedGameTab,
                              title,
                              cost,
                              wallet,
                              activeTeams,
                            ),
                    child: Text(
                      isLoadingTeams
                          ? '...'
                          : (!hasTeam
                              ? 'Join Team'
                              : (!isRankOneInSelectedGame ? '#1 Only' : 'Redeem')),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isLoadingTeams
                            ? ThemeService.textSecondary
                            : (canRedeem
                                ? Colors.black
                                : const Color(0xFFFFB800)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Displays the current 7-day week's #1 Team & 1,500 PKR Equivalent Weekly Prize Pool for [game]
  Widget _buildPerGameWeeklyTopTeamCard(String game) {
    final weekLabel = TeamService.getWeekRangeLabel();
    final cachedLeaderboard = _teamService.getCachedGameWeeklyLeaderboard(game);
    final currencyLabel = TeamService.getGameCurrencyLabel(game);

    return FutureBuilder<List<Map<String, dynamic>>>(
      initialData: cachedLeaderboard,
      future: _getOrCreateGameLeaderboardFuture(game),
      builder: (context, snap) {
        final entries = snap.data ?? cachedLeaderboard ?? const [];
        final topEntry = entries.isNotEmpty ? entries.first : null;
        final String topTeamName = topEntry != null
            ? '${topEntry['teamName']} [${topEntry['teamTag']}]'
            : 'No ranked team yet';
        final int topWeeklyCoins = (topEntry?['weeklyCoins'] as int?) ?? 0;
        final int topMemberCount = ((topEntry?['memberCount'] as int?) ?? 4).clamp(1, 4);
        final int equalPkrShare = TeamService.getEqualPkrShare(topMemberCount);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThemeService.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$game Weekly #1 Prize (1,500 PKR Equivalent • $currencyLabel)',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.2,
                      ),
                    ),
                  ),
                  Text(
                    weekLabel,
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                topEntry != null && topWeeklyCoins > 0
                    ? 'Current #1 in $game: $topTeamName • ${NumberFormat('#,###').format(topWeeklyCoins)} Weekly Team Coins ($topMemberCount/4 active members • $equalPkrShare PKR equivalent in $currencyLabel each at week\'s end)'
                    : 'At the end of the 7-day weekly cycle ($weekLabel), the #1 team in $game receives 1,500 PKR equivalent in $currencyLabel divided equally among its active members (up to 4). Weekly team scores reset to 0 each new week.',
                style: TextStyle(
                  color: ThemeService.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '📜 Coins & Redemption History',
              style: TextStyle(
                color: ThemeService.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                CoinHistorySheet.show(context, userId: _userId);
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: GamerTheme.neonGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _rewardClaimsStream ??
              (_userId.isNotEmpty
                  ? SupabaseService.getRealtimeRewardClaims(userId: _userId)
                  : Stream.value(const <Map<String, dynamic>>[]).asBroadcastStream()),
          builder: (context, claimsSnap) {
            final claims = claimsSnap.data ?? const <Map<String, dynamic>>[];

            return StreamBuilder<List<CoinTransaction>>(
              stream: _transactionsStream ?? _walletService.transactionsStream(_userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData &&
                    claimsSnap.connectionState == ConnectionState.waiting &&
                    !claimsSnap.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: GamerTheme.neonGreen),
                    ),
                  );
                }

                // Filter out legacy game_currency_redemption tx rows if reward_claims already exist
                // so that public.reward_claims is the single source of truth for claim status
                final allTxs = snapshot.data ?? const <CoinTransaction>[];
                final filteredTxs = claims.isNotEmpty
                    ? allTxs.where((tx) => tx.type != 'game_currency_redemption').take(6).toList()
                    : allTxs.take(6).toList();

                if (claims.isEmpty && filteredTxs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ThemeService.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ThemeService.border),
                    ),
                    child: Center(
                      child: Text(
                        'No transaction history yet. Earn or contribute coins to start!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ThemeService.textSecondary, fontSize: 12),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    ...claims.take(5).map((claim) => _buildRewardClaimHistoryCard(claim)),
                    ...filteredTxs.map((tx) => _buildTxTile(tx)),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRewardClaimHistoryCard(Map<String, dynamic> claim) {
    final String claimCode = (claim['claim_code'] ?? '#RW').toString();
    final String gameLabel = _displayGameNameFromKey((claim['game_name'] ?? 'free_fire').toString());
    final String playerUid = (claim['player_uid'] ?? 'N/A').toString();
    final String playerIgn = (claim['player_ign'] ?? '').toString();
    final String teamName = (claim['team_name'] ?? 'Rank #1 Team').toString();
    final String weekKey = (claim['week_key'] ?? '').toString();
    final int shareAmountPkr = (claim['share_amount_pkr'] as num?)?.toInt() ?? 375;
    final String rewardLabel = (claim['reward_label'] ?? '').toString().isNotEmpty
        ? (claim['reward_label']).toString()
        : _getConsistentRewardLabel(gameLabel, shareAmountPkr);
    final String status = (claim['status'] ?? 'pending').toString().toLowerCase();
    final String adminNote = (claim['admin_note'] ?? '').toString();
    final String proofImageUrl = (claim['proof_image_url'] ?? '').toString().trim();

    final bool isDelivered = status == 'delivered';
    final bool isRejected = status == 'rejected';

    final Color accentColor = isDelivered
        ? GamerTheme.neonGreen
        : (isRejected ? GamerTheme.redAccent : const Color(0xFFFFB800));

    final DateTime? timestamp =
        DateTime.tryParse((claim['delivered_at'] ?? claim['created_at'] ?? '').toString());
    final String dateText = timestamp != null
        ? DateFormat('dd MMM yyyy • hh:mm a').format(timestamp.toLocal())
        : (weekKey.isNotEmpty ? 'Week $weekKey' : 'Recent');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withOpacity(0.55),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDelivered
                      ? Icons.verified_rounded
                      : (isRejected ? Icons.cancel_rounded : Icons.card_giftcard_rounded),
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎁 #1 Team Reward • $gameLabel',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      rewardLabel,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withOpacity(0.45)),
                ),
                child: Text(
                  isDelivered
                      ? '✅ Reward Sent'
                      : (isRejected ? '❌ Rejected' : '⏳ Pending Delivery (24–48 hrs)'),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              InkWell(
                onTap: () => _copyToClipboard(claimCode, 'Claim ID'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeService.cardSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Claim ID: $claimCode',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, size: 12, color: Color(0xFFFFD700)),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Text(
                  'Game UID: $playerUid${playerIgn.isNotEmpty ? ' ($playerIgn)' : ''}',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Text(
                  'Team: $teamName',
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeService.cardSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThemeService.border),
                ),
                child: Text(
                  'Your Share: ${NumberFormat('#,###').format(shareAmountPkr)} PKR / 1,500 PKR Pool',
                  style: const TextStyle(
                    color: GamerTheme.neonGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDelivered
                      ? 'Reward Sent! آپ کا ریوارڈ بھیج دیا گیا ہے — براہِ کرم اپنا گیم اکاؤنٹ چیک کر لیں۔\n(Claim ID: $claimCode • Game UID: $playerUid)'
                      : (isRejected
                          ? 'Claim Status: Rejected${adminNote.isNotEmpty ? ' • Note: $adminNote' : ''}'
                          : '⏳ Status: Pending Delivery (24–48 hrs) • Claim ID: $claimCode • Game UID: $playerUid'),
                  style: TextStyle(
                    color: isDelivered ? GamerTheme.neonGreen : accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.8,
                    height: 1.4,
                  ),
                ),
                if (isDelivered && adminNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Admin Note: $adminNote',
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (proofImageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildDeliveryProofThumbnail(
              imageUrl: proofImageUrl,
              claimCode: claimCode,
              playerUid: playerUid,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            dateText,
            style: TextStyle(
              color: ThemeService.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryProofThumbnail({
    required String imageUrl,
    required String claimCode,
    required String playerUid,
  }) {
    return InkWell(
      onTap: () => _showDeliveryProofDialog(
        imageUrl: imageUrl,
        claimCode: claimCode,
        playerUid: playerUid,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: GamerTheme.neonGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: GamerTheme.neonGreen.withOpacity(0.45),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: GamerTheme.neonGreen,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '📸 Delivery Proof Screenshot (Tap to View Full Screen)',
                    style: TextStyle(
                      color: GamerTheme.neonGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: GamerTheme.neonGreen.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_out_map_rounded, size: 12, color: GamerTheme.neonGreen),
                      SizedBox(width: 3),
                      Text(
                        'View',
                        style: TextStyle(
                          color: GamerTheme.neonGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                height: 135,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: ThemeService.cardSecondary,
                    alignment: Alignment.center,
                    child: const Text(
                      'Unable to load delivery proof screenshot',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryProofDialog({
    required String imageUrl,
    required String claimCode,
    required String playerUid,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GamerTheme.neonGreen, width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: ThemeService.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: GamerTheme.neonGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delivery Proof • $claimCode (UID: $playerUid)',
                      style: TextStyle(
                        color: ThemeService.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: ThemeService.textPrimary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Failed to load delivery proof screenshot',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxTile(CoinTransaction tx) {
    final isCredit = tx.amount > 0;
    final isWeeklyReward = tx.type == 'weekly_team_reward';
    final isTeamContribution = tx.type == 'team_weekly_contribution';
    final isRedemption = tx.type == 'game_currency_redemption' || tx.type == 'store_purchase';

    final Color color = isWeeklyReward
        ? const Color(0xFFFFD700)
        : (isTeamContribution
            ? GamerTheme.accentBlue
            : (isCredit ? GamerTheme.neonGreen : GamerTheme.redAccent));

    String statusLabel = isCredit ? 'Added to Personal Wallet' : 'Spent';
    if (isWeeklyReward) {
      statusLabel = 'Weekly #1 Prize Share';
    } else if (isTeamContribution) {
      statusLabel = 'Contributed to Team';
    } else if (isRedemption) {
      statusLabel = 'Pending Delivery (24–48 hrs)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWeeklyReward
              ? const Color(0xFFFFD700).withOpacity(0.45)
              : (isTeamContribution
                  ? GamerTheme.accentBlue.withOpacity(0.45)
                  : ThemeService.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isWeeklyReward
                  ? Icons.emoji_events_rounded
                  : (isTeamContribution
                      ? Icons.shield_rounded
                      : (isCredit ? Icons.add_rounded : Icons.redeem_rounded)),
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tx.description.isNotEmpty && tx.description != tx.title) ...[
                  const SizedBox(height: 4),
                  Text(
                    tx.description,
                    style: TextStyle(
                      color: ThemeService.textSecondary,
                      fontSize: 11.2,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  DateFormat('dd MMM • hh:mm a').format(tx.timestamp),
                  style: TextStyle(
                    color: ThemeService.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}${tx.amount} G-Coins',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: color.withOpacity(0.95),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Google Play Policy-Compliant In-App Explanatory Notice & Privacy Disclosure
  Widget _buildPlayPolicyDisclosureCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeService.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeService.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.policy_rounded, color: Color(0xFF1877F2), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'How G-Coins, 1,500 PKR Weekly Team Prize & Privacy Work',
                  style: TextStyle(
                    color: ThemeService.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _disclosureBullet(
            '1. Weekly (7-Day) Cycle, Two Games & 1,500 PKR Equivalent Prize:',
            'The weekly team competition runs on a 7-day cycle (Monday 00:00 UTC – Sunday 23:59 UTC) focused on Free Fire and PUBG Mobile. At the end of each week, the #1 team in Free Fire and the #1 team in PUBG Mobile each receive 1,500 PKR equivalent in that game\'s in-game currency (Free Fire Diamonds or PUBG UC), divided equally among that winning #1 team\'s active members (up to 4 members per team).',
          ),
          const SizedBox(height: 6),
          _disclosureBullet(
            '2. Personal Wallet First + Manual Team Contribution:',
            'All G-Coins earned from watching ads (+25), daily bonuses (+50), or activities go directly into your Personal Wallet first. Inside this Wallet screen, you choose how many personal coins to contribute to your active Team Profile for the weekly competition (All / Max, a custom amount, or keep them in your Personal Wallet / contribute 0).',
          ),
          const SizedBox(height: 6),
          _disclosureBullet(
            '3. Winner-Only Redemption, Personal Coin Safety & Weekly Reset:',
            'Weekly game-currency reward redemption is unlocked strictly for members of the #1 team in that game for that weekly cycle. Non-#1 teams\' and solo players\' personal G-Coins remain 100% safe in their Personal Wallet balance and history. Weekly team coin scores and weekly member contributions reset to 0 at the start of each new weekly cycle while preserving past results.',
          ),
          const SizedBox(height: 6),
          _disclosureBullet(
            '4. Privacy & Data Minimization (Play Policy):',
            'In team views and weekly leaderboards, only public gaming display names/handles, team rank, and coin contribution figures are shown. Private or sensitive personal data (such as email addresses, phone numbers, real names/addresses, or account credentials) is never exposed to other users.',
          ),
        ],
      ),
    );
  }

  Widget _disclosureBullet(String heading, String body) {
    final bool isDark = ThemeService.isDarkMode;
    final Color noteColor = isDark ? Colors.white : const Color(0xFF000000);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: noteColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        children: [
          TextSpan(
            text: '$heading ',
            style: TextStyle(
              color: noteColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: body),
        ],
      ),
    );
  }
}
