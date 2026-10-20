import 'package:easy_localization/easy_localization.dart';
// ===============================================================================
// COIN WALLET SERVICE — With Automatic 500/1000 Coins Team Moderation & Alerts
// -------------------------------------------------------------------------------
// File: lib/services/coin_wallet_service.dart
// ===============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coin_wallet_model.dart';
import '../models/coin_transaction_model.dart';
import 'gamer_auth_service.dart';
import 'coin_reward_service.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class CoinWalletService extends ChangeNotifier {
  static final CoinWalletService _instance = CoinWalletService._internal();
  factory CoinWalletService() => _instance;
  CoinWalletService._internal();

  // Cached active user wallet
  CoinWallet? _currentWallet;
  CoinWallet? get currentWallet => _currentWallet;

  StreamSubscription? _walletSub;

  /// Helper to synchronize coins to Supabase 'users' table and in-memory notifiers
  Future<void> _syncToUserDocAndNotifiers(String userId, int coins) async {
    if (userId.isEmpty) return;
    try {
      await SupabaseService.client.from('users').update({
        'coins': coins,
        'g_coins': coins,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,uid.eq.$userId');
    } catch (e) {
      debugPrint('CoinWalletService _syncToUserDocAndNotifiers error: $e');
    }

    try {
      final currentGamer = GamerAuthService().currentGamer;
      if (currentGamer != null && (currentGamer.uid == userId || userId.isEmpty)) {
        GamerAuthService().currentGamerNotifier.value = currentGamer.copyWith(coins: coins);
      }
    } catch (_) {}

    try {
      CoinRewardService().coinsNotifier.value = coins;
    } catch (_) {}
  }

  /// =========================================================================
  /// AUTO TEAM MODERATION & DETAILED NOTIFICATIONS LOGIC
  /// 1. Leader < 1,000 Coins: Freeze Team + Detailed Notification
  /// 2. Leader >= 1,000 Coins: Unfreeze Team + Reactivation Notification
  /// 3. Member < 500 Coins: Auto-Remove from Team + Detailed Notification
  /// =========================================================================
  static Future<void> _checkTeamEligibility(String userId, int newCoins) async {
    if (userId.isEmpty) return;
    try {
      final nowStr = DateTime.now().toIso8601String();

      // ───────────────────────────────────────────────────────────────────────
      // 1. CHECK IF USER IS A TEAM LEADER (Rule: 1,000 Coins)
      // ───────────────────────────────────────────────────────────────────────
      final leaderTeams = await SupabaseService.client
          .from('teams')
          .select('id, name, status')
          .or('leader_id.eq.$userId,leaderId.eq.$userId');

      if (leaderTeams != null && leaderTeams is List && leaderTeams.isNotEmpty) {
        for (final team in leaderTeams) {
          final teamId = team['id']?.toString() ?? '';
          final teamName = team['name']?.toString() ?? 'Team';
          final currentStatus = (team['status'] ?? 'active').toString().toLowerCase();

          // A: Leader balance drops below 1000 -> FREEZE
          if (newCoins < 1000 && currentStatus != 'frozen') {
            await SupabaseService.client.from('teams').update({
              'status': 'frozen',
              'frozen_reason': 'Leader balance fell below 1000 coins ($newCoins coins)',
              'updated_at': nowStr,
            }).or('id.eq.$teamId,team_id.eq.$teamId');

            // 📩 Detailed Freeze Notification to Leader
            await _sendDetailedNotification(
              userId: userId,
              type: 'team_frozen',
              title: 'wallet_team_frozen_title'.tr(),
              message:
                  'wallet_team_frozen_notification'.tr(args: [newCoins.toString(), teamName]),
            );
          }
          // B: Leader balance restored to 1000+ -> UNFREEZE / REACTIVATE
          else if (newCoins >= 1000 && currentStatus == 'frozen') {
            await SupabaseService.client.from('teams').update({
              'status': 'active',
              'frozen_reason': null,
              'updated_at': nowStr,
            }).or('id.eq.$teamId,team_id.eq.$teamId');

            // 📩 Reactivation Notification to Leader
            await _sendDetailedNotification(
              userId: userId,
              type: 'team_reactivated',
              title: 'wallet_team_reactivated_title'.tr(),
              message:
                  'wallet_team_reactivated_notification'.tr(args: [newCoins.toString(), teamName]),
            );
          }
        }
      }

      // ───────────────────────────────────────────────────────────────────────
      // 2. CHECK IF USER IS A TEAM MEMBER (Rule: 500 Coins Auto-Remove)
      // ───────────────────────────────────────────────────────────────────────
      if (newCoins < 500) {
        final memberRows = await SupabaseService.client
            .from('team_members')
            .select('id, team_id, teams(name, leader_id, leaderId)')
            .or('user_id.eq.$userId,userId.eq.$userId');

        if (memberRows != null && memberRows is List && memberRows.isNotEmpty) {
          for (final row in memberRows) {
            final rowId = row['id'];
            final teamId = row['team_id']?.toString() ?? '';
            final teamMap = row['teams'] as Map<String, dynamic>?;
            final leaderId = teamMap?['leader_id'] ?? teamMap?['leaderId'];
            final teamName = teamMap?['name']?.toString() ?? 'Team';

            // Agar user leader nahi hai (sirf member hai), to remove karein
            if (leaderId != userId) {
              await SupabaseService.client
                  .from('team_members')
                  .delete()
                  .eq('id', rowId);

              // Update team members count
              try {
                final tDoc = await SupabaseService.client
                    .from('teams')
                    .select('members_count')
                    .or('id.eq.$teamId,team_id.eq.$teamId')
                    .maybeSingle();
                if (tDoc != null) {
                  int count = (tDoc['members_count'] as num?)?.toInt() ?? 1;
                  await SupabaseService.client.from('teams').update({
                    'members_count': count > 1 ? count - 1 : 1,
                  }).or('id.eq.$teamId,team_id.eq.$teamId');
                }
              } catch (_) {}

              // 📩 Detailed Removal Notification to Member
              await _sendDetailedNotification(
                userId: userId,
                type: 'team_removed',
                title: 'wallet_team_removed_title'.tr(),
                message:
                    'wallet_team_removed_low_balance_notification'.tr(args: [newCoins.toString(), teamName]),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[CoinWalletService] _checkTeamEligibility error: $e');
    }
  }

  /// Helper to send persistent notification & push alert
  static Future<void> _sendDetailedNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await SupabaseService.client.from('notifications').insert({
        'user_id': userId,
        'recipientUid': userId,
        'type': type,
        'title': title,
        'message': message,
        'body': message,
        'read': false,
        'created_at': nowStr,
        'createdAt': nowStr,
      });

      try {
        await NotificationService().sendNotification(
          userId: userId,
          type: type,
          title: title,
          body: message,
          priority: 'high',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('[CoinWalletService] _sendDetailedNotification error: $e');
    }
  }

  /// =========================================================================
  /// UNIFIED COIN UPDATE FUNCTION (100% Supabase & 100% snake_case)
  /// =========================================================================
  static Future<void> updateCoins({
    required String userId,
    required int amount,
    required String type,
    required String description,
    String? title,
    String? roomId,
    String? winProofUrl,
    int? inEscrowChange,
  }) async {
    if (userId.isEmpty) return;
    try {
      final now = DateTime.now();

      // 1. Fetch current balances from users table (PRIMARY SOURCE)
      int currentCoins = 1000;
      int currentEscrow = 0;
      int currentWinnings = 0;
      int currentWins = 0;

      try {
        final userRow = await SupabaseService.client
            .from('users')
            .select('coins, g_coins, in_escrow, total_winnings, wins')
            .or('id.eq.$userId,uid.eq.$userId')
            .maybeSingle();

        if (userRow != null) {
          currentCoins = (userRow['coins'] as num?)?.toInt() ??
              (userRow['g_coins'] as num?)?.toInt() ??
              1000;
          currentEscrow = (userRow['in_escrow'] as num?)?.toInt() ?? 0;
          currentWinnings = (userRow['total_winnings'] as num?)?.toInt() ?? 0;
          currentWins = (userRow['wins'] as num?)?.toInt() ?? 0;
        }
      } catch (e) {
        debugPrint('updateCoins: fetch user error: $e');
      }

      final newCoins = (currentCoins + amount).clamp(0, 9999999);
      final newEscrow = (currentEscrow + (inEscrowChange ?? 0)).clamp(0, 9999999);

      // 2. Update users table (SINGLE SOURCE OF TRUTH - strict snake_case)
      final Map<String, dynamic> userUpdate = {
        'coins': newCoins,
        'g_coins': newCoins,
        'updated_at': now.toIso8601String(),
      };
      if (inEscrowChange != null && inEscrowChange != 0) {
        userUpdate['in_escrow'] = newEscrow;
      }
      if (type == 'win_reward' || type == 'win_prize' || type == 'team_prize') {
        if (amount > 0) {
          userUpdate['total_winnings'] = currentWinnings + amount;
          userUpdate['wins'] = currentWins + 1;
          userUpdate['last_reward_at'] = now.toIso8601String();
        }
      }

      try {
        await SupabaseService.client
            .from('users')
            .update(userUpdate)
            .or('id.eq.$userId,uid.eq.$userId');
      } catch (e) {
        debugPrint('updateCoins: users update error: $e');
      }

      // 3. Update coin_wallets table (strict snake_case)
      int lifetimeEarned = currentCoins;
      int lifetimeSpent = 0;
      int trustScore = 100;
      try {
        final walletRow = await SupabaseService.client
            .from('coin_wallets')
            .select('lifetime_earned, lifetime_spent, trust_score')
            .or('user_id.eq.$userId,id.eq.$userId')
            .maybeSingle();
        if (walletRow != null) {
          lifetimeEarned = (walletRow['lifetime_earned'] as num?)?.toInt() ?? lifetimeEarned;
          lifetimeSpent = (walletRow['lifetime_spent'] as num?)?.toInt() ?? lifetimeSpent;
          trustScore = (walletRow['trust_score'] as num?)?.toInt() ?? trustScore;
        }
      } catch (_) {}

      if (amount > 0) {
        lifetimeEarned += amount;
      } else if (amount < 0 && (inEscrowChange == null || inEscrowChange == 0)) {
        lifetimeSpent += amount.abs();
      }

      final Map<String, dynamic> walletUpdate = {
        'id': userId,
        'user_id': userId,
        'coins': newCoins,
        'g_coins': newCoins,
        'escrow_coins': newEscrow,
        'lifetime_earned': lifetimeEarned,
        'lifetime_spent': lifetimeSpent,
        'trust_score': trustScore,
        'updated_at': now.toIso8601String(),
      };
      if (type == 'daily_bonus') {
        walletUpdate['last_daily_bonus_claim'] = now.toIso8601String();
      }

      try {
        await SupabaseService.client.from('coin_wallets').upsert(walletUpdate);
      } catch (e) {
        debugPrint('updateCoins: coin_wallets upsert error: $e');
      }

      // 4. Transaction log (both coin_transactions & transactions tables)
      final String targetUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(userId)
          ? userId
          : SupabaseService.toUuid(userId);

      final Map<String, dynamic> txData = {
        'user_id': targetUuid,
        'type': type,
        'amount': amount,
        'status': 'completed',
        'title': title ?? description,
        'description': description,
        'balance_after': newCoins,
        'created_at': now.toIso8601String(),
      };
      if (roomId != null && roomId.isNotEmpty) {
        txData['room_id'] = roomId;
        txData['reference_id'] = roomId;
      }
      if (winProofUrl != null && winProofUrl.isNotEmpty) {
        txData['win_proof_url'] = winProofUrl;
      }

      try {
        await SupabaseService.client
            .from('coin_transactions')
            .insert(txData);
      } catch (e) {
        debugPrint('updateCoins: coin_transactions insert error: $e, trying schema-fallback');
        try {
          await SupabaseService.client
              .from('coin_transactions')
              .insert({
                'user_id': targetUuid,
                'amount': amount,
                'type': type,
                'description': (title != null && title.isNotEmpty) ? '$title - $description' : description,
                'balance_after': newCoins,
                if (roomId != null && roomId.isNotEmpty) 'reference_id': roomId,
                'created_at': now.toIso8601String(),
              });
        } catch (e2) {
          debugPrint('updateCoins: fallback coin_transactions insert error: $e2');
        }
      }

      try {
        await SupabaseService.client
            .from('transactions')
            .insert(txData);
      } catch (_) {}

      // 5. Update in-memory state & notifiers
      _instance._syncToUserDocAndNotifiers(userId, newCoins);

      if (_instance._currentWallet != null &&
          (_instance._currentWallet!.userId == userId || userId.isEmpty)) {
        _instance._currentWallet = _instance._currentWallet!.copyWith(
          coins: newCoins,
          escrowCoins: newEscrow,
          lifetimeEarned: lifetimeEarned,
          updatedAt: now,
          lastDailyBonusClaim: type == 'daily_bonus'
              ? now
              : _instance._currentWallet!.lastDailyBonusClaim,
        );
        _instance.notifyListeners();
        _instance._saveToLocal(_instance._currentWallet!);
      }

      // ✅ 6. AUTOMATIC TEAM MODERATION CHECK (Runs in background)
      _checkTeamEligibility(userId, newCoins);

    } catch (e) {
      debugPrint('CoinWalletService updateCoins error: $e');
    }
  }

  /// Recalculate true coin balance from transactions
  static Future<int> recalculateCoins(String userId) async {
    if (userId.isEmpty) return 1000;
    try {
      final rows = await SupabaseService.client
          .from('coin_transactions')
          .select('amount')
          .or('user_id.eq.$userId');

      int computed = 1000;
      for (final r in rows) {
        computed += (r['amount'] as num?)?.toInt() ?? 0;
      }
      if (computed < 0) computed = 0;

      await SupabaseService.client.from('users').update({
        'coins': computed,
        'g_coins': computed,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,uid.eq.$userId');

      await SupabaseService.client.from('coin_wallets').upsert({
        'id': userId,
        'user_id': userId,
        'coins': computed,
        'g_coins': computed,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _instance._syncToUserDocAndNotifiers(userId, computed);

      // Check eligibility after recalculation
      _checkTeamEligibility(userId, computed);

      return computed;
    } catch (e) {
      debugPrint('CoinWalletService recalculateCoins error: $e');
      return 1000;
    }
  }

  /// Load or initialize wallet for user
  Future<CoinWallet> getOrCreateWallet(String userId) async {
    if (userId.isEmpty) {
      return const CoinWallet(userId: 'guest', coins: 1000);
    }

    if (_currentWallet != null && _currentWallet!.userId == userId) {
      return _currentWallet!;
    }

    // 1. Try local cache
    final local = await _loadFromLocal(userId);
    if (local != null) {
      _currentWallet = local;
      notifyListeners();
    }

    // 2. Fetch from Supabase
    try {
      final row = await SupabaseService.client
          .from('coin_wallets')
          .select()
          .or('user_id.eq.$userId,id.eq.$userId')
          .maybeSingle();

      if (row != null) {
        final w = CoinWallet.fromMap(row, userId);
        _currentWallet = w;
        notifyListeners();
        _saveToLocal(w);
        _listenToWalletChanges(userId);
        return w;
      }

      // Check users table for existing coins (PRIMARY SOURCE OF TRUTH)
      final userRow = await SupabaseService.client
          .from('users')
          .select('coins, g_coins')
          .or('id.eq.$userId,uid.eq.$userId')
          .maybeSingle();

      int initialCoins = 1000;
      if (userRow != null) {
        initialCoins = (userRow['coins'] as num?)?.toInt() ??
            (userRow['g_coins'] as num?)?.toInt() ??
            1000;
      }

      final initial = CoinWallet(
        userId: userId,
        coins: initialCoins,
        escrowCoins: 0,
        lifetimeEarned: initialCoins,
        trustScore: 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await SupabaseService.client.from('coin_wallets').upsert({
        'id': userId,
        'user_id': userId,
        'coins': initialCoins,
        'g_coins': initialCoins,
        'escrow_coins': 0,
        'lifetime_earned': initialCoins,
        'lifetime_spent': 0,
        'trust_score': 100,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      _currentWallet = initial;
      notifyListeners();
      _saveToLocal(initial);
      _listenToWalletChanges(userId);
      return initial;
    } catch (e) {
      debugPrint('CoinWalletService getOrCreateWallet Supabase error: $e');
      final fallback = local ?? CoinWallet(userId: userId, coins: 1000);
      _currentWallet = fallback;
      return fallback;
    }
  }

  void _listenToWalletChanges(String userId) {
    if (userId.isEmpty) return;
    _walletSub?.cancel();
    try {
      _walletSub = SupabaseService.client
          .from('coin_wallets')
          .stream(primaryKey: ['id'])
          .listen((rows) {
        final match = rows.where((r) =>
            (r['user_id'] ?? r['id'])?.toString() == userId);
        if (match.isNotEmpty) {
          final w = CoinWallet.fromMap(match.first, userId);
          _currentWallet = w;
          notifyListeners();
          _saveToLocal(w);
        }
      }, onError: (err) {
        debugPrint('CoinWalletService wallet stream notice: $err');
      });
    } catch (_) {}
  }

  Stream<CoinWallet> walletStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value(_currentWallet ??
          const CoinWallet(userId: 'guest', coins: 1000));
    }
    try {
      return SupabaseService.client
          .from('coin_wallets')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final match = rows.where((r) =>
            (r['user_id'] ?? r['id'])?.toString() == userId);
        if (match.isNotEmpty) {
          final w = CoinWallet.fromMap(match.first, userId);
          _currentWallet = w;
          return w;
        }
        return _currentWallet ?? CoinWallet(userId: userId, coins: 1000);
      });
    } catch (_) {
      return Stream.value(_currentWallet ?? CoinWallet(userId: userId, coins: 1000));
    }
  }

  /// Claim Daily 50 G-Coins bonus every 24h
  Future<bool> claimDailyBonus(String userId) async {
    final wallet = await getOrCreateWallet(userId);
    if (!wallet.canClaimDailyBonus) {
      return false;
    }

    final now = DateTime.now();
    final newCoins = wallet.coins + 50;
    final newLifetime = wallet.lifetimeEarned + 50;

    final updated = wallet.copyWith(
      coins: newCoins,
      lifetimeEarned: newLifetime,
      lastDailyBonusClaim: now,
      updatedAt: now,
    );

    _currentWallet = updated;
    notifyListeners();
    _saveToLocal(updated);

    try {
      await updateCoins(
        userId: userId,
        amount: 50,
        type: 'daily_bonus',
        title: 'wallet_daily_bonus_claimed_title'.tr(),
        description: 'wallet_daily_bonus_claimed_desc'.tr(),
      );
      try {
        NotificationService().sendCoinRewardNotification(
          targetUserId: userId,
          amount: 50,
          reason: 'wallet_daily_bonus_reason'.tr(),
          type: 'daily_bonus',
        );
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('CoinWalletService claimDailyBonus error: $e');
      return true;
    }
  }

  /// Reward 100 G-Coins for watching an Ad (Unlimited)
  Future<void> rewardAdCoins(String userId) async {
    final wallet = await getOrCreateWallet(userId);
    final newCoins = wallet.coins + 100;
    final newLifetime = wallet.lifetimeEarned + 100;
    final now = DateTime.now();

    final updated = wallet.copyWith(
      coins: newCoins,
      lifetimeEarned: newLifetime,
      updatedAt: now,
    );

    _currentWallet = updated;
    notifyListeners();
    _saveToLocal(updated);

    try {
      await updateCoins(
        userId: userId,
        amount: 100,
        type: 'ad_reward',
        title: 'wallet_ad_reward_title'.tr(),
        description: 'wallet_ad_reward_desc'.tr(),
      );
      try {
        NotificationService().sendCoinRewardNotification(
          targetUserId: userId,
          amount: 100,
          reason: 'wallet_ad_reward_reason'.tr(),
          type: 'ad_reward',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('CoinWalletService rewardAdCoins error: $e');
    }
  }

  /// Reward Referral Coins (100 G-Coins)
  Future<void> rewardReferralCoins(String userId,
      {String inviteeName = 'Friend'}) async {
    final wallet = await getOrCreateWallet(userId);
    final newCoins = wallet.coins + 100;
    final newLifetime = wallet.lifetimeEarned + 100;
    final now = DateTime.now();

    final updated = wallet.copyWith(
      coins: newCoins,
      lifetimeEarned: newLifetime,
      updatedAt: now,
    );

    _currentWallet = updated;
    notifyListeners();
    _saveToLocal(updated);

    try {
      await updateCoins(
        userId: userId,
        amount: 100,
        type: 'referral',
        title: 'wallet_referral_bonus_title'.tr(),
        description: 'wallet_referral_bonus_desc'.tr(args: [inviteeName]),
      );
      try {
        NotificationService().sendCoinRewardNotification(
          targetUserId: userId,
          amount: 100,
          reason: 'wallet_referral_bonus_reason'.tr(args: [inviteeName]),
          type: 'referral',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('CoinWalletService rewardReferralCoins error: $e');
    }
  }

  /// Host Room Escrow Hold
  Future<bool> holdRoomHostCoins({
    required String userId,
    required int prizePoolCoins,
    required String roomId,
    required String roomTitle,
  }) async {
    if (prizePoolCoins <= 0) return true;

    CoinWallet wallet;
    if (_currentWallet != null &&
        (_currentWallet!.userId == userId || userId.isEmpty)) {
      wallet = _currentWallet!;
    } else {
      wallet = await getOrCreateWallet(userId);
    }

    if (wallet.coins < prizePoolCoins) {
      return false;
    }

    final newCoins = (wallet.coins - prizePoolCoins).clamp(0, 9999999);
    final newEscrow = wallet.escrowCoins + prizePoolCoins;
    final now = DateTime.now();

    final updated = wallet.copyWith(
      coins: newCoins,
      escrowCoins: newEscrow,
      updatedAt: now,
    );

    _currentWallet = updated;
    notifyListeners();
    _saveToLocal(updated);

    try {
      await updateCoins(
        userId: userId,
        amount: -prizePoolCoins,
        type: 'room_host_hold',
        inEscrowChange: prizePoolCoins,
        title: 'wallet_host_escrow_title'.tr(),
        description: 'wallet_host_escrow_desc'.tr(args: [roomTitle]),
        roomId: roomId,
      );
      return true;
    } catch (e) {
      debugPrint('CoinWalletService holdRoomHostCoins error: $e');
      return true;
    }
  }

  /// Join Room Entry Fee Escrow Hold
  Future<bool> holdEntryFeeCoins({
    required String userId,
    required int entryFeeCoins,
    required String roomId,
    required String roomTitle,
  }) async {
    if (entryFeeCoins <= 0) return true;

    CoinWallet wallet;
    if (_currentWallet != null &&
        (_currentWallet!.userId == userId || userId.isEmpty)) {
      wallet = _currentWallet!;
    } else {
      wallet = await getOrCreateWallet(userId);
    }

    if (wallet.coins < entryFeeCoins) {
      return false;
    }

    final newCoins = (wallet.coins - entryFeeCoins).clamp(0, 9999999);
    final newEscrow = wallet.escrowCoins + entryFeeCoins;
    final now = DateTime.now();

    final updated = wallet.copyWith(
      coins: newCoins,
      escrowCoins: newEscrow,
      updatedAt: now,
    );

    _currentWallet = updated;
    notifyListeners();
    _saveToLocal(updated);

    try {
      await updateCoins(
        userId: userId,
        amount: -entryFeeCoins,
        type: 'tournament_entry',
        inEscrowChange: entryFeeCoins,
        title: 'wallet_entry_fee_escrow_title'.tr(),
        description: 'wallet_entry_fee_escrow_desc'.tr(args: [roomTitle]),
        roomId: roomId,
      );
      return true;
    } catch (e) {
      debugPrint('CoinWalletService holdEntryFeeCoins error: $e');
      return true;
    }
  }

  /// Leave Room: Refund Entry Fee if user leaves before match start
  Future<void> refundEntryFeeOnLeave({
    required String userId,
    required int entryFeeCoins,
    required String roomId,
    required String roomTitle,
  }) async {
    if (entryFeeCoins <= 0) return;

    final wallet = await getOrCreateWallet(userId);
    final newCoins = wallet.coins + entryFeeCoins;
    final newEscrow = (wallet.escrowCoins - entryFeeCoins).clamp(0, 9999999);
    final now = DateTime.now();

    final updated = wallet.copyWith(
      coins: newCoins,
      escrowCoins: newEscrow,
      updatedAt: now,
    );

    _currentWallet = updated;
    notifyListeners();
    _saveToLocal(updated);

    try {
      await updateCoins(
        userId: userId,
        amount: entryFeeCoins,
        type: 'escrow_refund',
        inEscrowChange: -entryFeeCoins,
        title: 'wallet_entry_fee_refund_title'.tr(),
        description: 'wallet_entry_fee_refund_desc'.tr(args: [roomTitle]),
        roomId: roomId,
      );
    } catch (e) {
      debugPrint('CoinWalletService refundEntryFeeOnLeave error: $e');
    }
  }

  /// Finalize Match Winner:
  /// Transfer all escrowCoins to winner(s) coins
  Future<void> awardWinnerPrize({
    required String hostId,
    String? winnerId,
    List<String>? winnerIds,
    required int prizePoolCoins,
    required int totalEntryFees,
    required List<String> joiners,
    required int entryFeeCoinsPerJoiner,
    required String roomId,
    required String roomTitle,
    String? winnerName,
    List<String>? winnerNames,
  }) async {
    final List<String> allWinnerIds = [];
    if (winnerIds != null && winnerIds.isNotEmpty) {
      allWinnerIds.addAll(winnerIds);
    } else if (winnerId != null && winnerId.isNotEmpty) {
      allWinnerIds.add(winnerId);
    }
    if (allWinnerIds.isEmpty) return;

    final totalPrize = prizePoolCoins > 0 ? prizePoolCoins : 500;
    final int winnerCount = allWinnerIds.length;
    final int prizePerWinner = (totalPrize / winnerCount).floor();
    final now = DateTime.now();

    try {
      // 1. Release host's escrow hold if applicable
      if (prizePoolCoins > 0 && hostId.isNotEmpty) {
        try {
          await updateCoins(
            userId: hostId,
            amount: 0,
            type: 'escrow_release',
            inEscrowChange: -prizePoolCoins,
            title: 'wallet_escrow_released_title'.tr(),
            description:
                'wallet_escrow_released_desc'.tr(args: [prizePoolCoins.toString(), roomTitle]),
            roomId: roomId,
          );
        } catch (_) {}
      }

      // 2. Clear escrow for joiners
      if (entryFeeCoinsPerJoiner > 0) {
        for (final joinerId in joiners) {
          if (joinerId != hostId) {
            try {
              await updateCoins(
                userId: joinerId,
                amount: 0,
                type: 'escrow_cleared',
                inEscrowChange: -entryFeeCoinsPerJoiner,
                description: 'wallet_escrow_cleared_desc'.tr(args: [roomTitle]),
                roomId: roomId,
              );
            } catch (_) {}
          }
        }
      }

      // 3. Distribute prize to all winners
      for (int i = 0; i < allWinnerIds.length; i++) {
        final wId = allWinnerIds[i].trim();
        if (wId.isEmpty) continue;

        await updateCoins(
          userId: wId,
          amount: prizePerWinner,
          type: winnerCount > 1 ? 'team_prize' : 'win_prize',
          title: winnerCount > 1
              ? 'wallet_team_victory_prize_title'.tr()
              : 'wallet_tournament_victory_prize_title'.tr(),
          description: winnerCount > 1
              ? 'wallet_team_victory_prize_desc'.tr(args: [roomTitle, prizePerWinner.toString()])
              : 'wallet_tournament_victory_prize_desc'.tr(args: [roomTitle, prizePerWinner.toString()]),
          roomId: roomId,
        );
      }

      // Update room status in Supabase
      if (roomId.isNotEmpty) {
        final combinedWName = (winnerNames != null && winnerNames.isNotEmpty)
            ? winnerNames.join(', ')
            : 'Winner';
        await SupabaseService.client.from('tournament_rooms').update({
          'status': 'COMPLETED',
          'winnerUid': allWinnerIds.join(','),
          'winnerName': combinedWName,
          'isLive': false,
          'updated_at': now.toIso8601String(),
        }).or('id.eq.$roomId,room_id.eq.$roomId');
      }
    } catch (e) {
      debugPrint('CoinWalletService awardWinnerPrize error: $e');
    }
  }

  /// Refund room if expired or cancelled
  Future<void> refundRoom({
    required String hostId,
    required int prizePoolCoins,
    required List<String> joiners,
    required int entryFeeCoins,
    required String roomId,
    required String roomTitle,
  }) async {
    try {
      // 1. Refund host
      if (prizePoolCoins > 0 && hostId.isNotEmpty) {
        await updateCoins(
          userId: hostId,
          amount: prizePoolCoins,
          type: 'refund',
          inEscrowChange: -prizePoolCoins,
          title: 'wallet_host_refund_title'.tr(),
          description:
              'wallet_host_refund_desc'.tr(args: [roomTitle]),
          roomId: roomId,
        );
      }

      // 2. Refund joiners
      if (entryFeeCoins > 0) {
        for (final jId in joiners) {
          if (jId != hostId) {
            try {
              await updateCoins(
                userId: jId,
                amount: entryFeeCoins,
                type: 'refund',
                inEscrowChange: -entryFeeCoins,
                title: 'wallet_entry_fee_refund_title'.tr(),
                description:
                    'wallet_entry_fee_refund_returned_desc'.tr(args: [roomTitle, entryFeeCoins.toString()]),
                roomId: roomId,
              );
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('CoinWalletService refundRoom error: $e');
    }
  }

  /// Deducts trustScore by penalty points
  Future<void> penalizeTrustScore(
      String userId, int penaltyPoints, String reason) async {
    try {
      final wallet = await getOrCreateWallet(userId);
      final newTrust = (wallet.trustScore - penaltyPoints).clamp(0, 100);
      await SupabaseService.client.from('coin_wallets').update({
        'trust_score': newTrust,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('user_id.eq.$userId,id.eq.$userId');

      final updated = wallet.copyWith(trustScore: newTrust);
      _currentWallet = updated;
      notifyListeners();
      _saveToLocal(updated);
    } catch (e) {
      debugPrint('CoinWalletService penalizeTrustScore error: $e');
    }
  }

  Future<void> recordTransaction(CoinTransaction tx) async {
    await _recordTransaction(tx);
  }

  Future<void> _recordTransaction(CoinTransaction tx) async {
    try {
      final map = tx.toMap();
      map['created_at'] = DateTime.now().toIso8601String();
      if (map['userId'] != null && map['user_id'] == null) {
        map['user_id'] = map['userId'];
      }
      await SupabaseService.client.from('coin_transactions').insert(map);
      await SupabaseService.client.from('transactions').insert(map);
    } catch (e) {
      debugPrint('CoinWalletService recordTransaction error: $e');
    }
  }

  Stream<List<CoinTransaction>> transactionsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    try {
      final userUuid = SupabaseService.toUuid(userId);
      return SupabaseService.client
          .from('coin_transactions')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final filtered = rows
            .where((r) {
              final uid = r['user_id']?.toString() ?? r['userId']?.toString() ?? '';
              final toUid = r['to']?.toString() ?? '';
              final fromUid = r['from']?.toString() ?? '';
              return uid == userId ||
                  uid == userUuid ||
                  toUid == userId ||
                  toUid == userUuid ||
                  fromUid == userId ||
                  fromUid == userUuid;
            })
            .map((r) {
          final map = Map<String, dynamic>.from(r);
          if (map['userId'] == null && map['user_id'] != null) {
            map['userId'] = map['user_id'];
          }
          if (map['roomId'] == null && map['room_id'] != null) {
            map['roomId'] = map['room_id'];
          }
          if (map['roomId'] == null && map['reference_id'] != null) {
            map['roomId'] = map['reference_id'];
          }
          return CoinTransaction.fromMap(map);
        }).toList();
        filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return filtered;
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Purchase In-App Store Items
  Future<Map<String, dynamic>> purchaseStoreItem({
    required String userId,
    required String itemId,
    required String itemName,
    required String category,
    required int costCoins,
    Map<String, dynamic>? metadata,
  }) async {
    final wallet = await getOrCreateWallet(userId);
    if (wallet.coins < costCoins) {
      return {
        'success': false,
        'error':
            'wallet_insufficient_coins_error'.tr(args: [wallet.coins.toString(), costCoins.toString()]),
      };
    }

    final newCoins = (wallet.coins - costCoins).clamp(0, 9999999);
    final now = DateTime.now();
    final updated = wallet.copyWith(
      coins: newCoins,
      updatedAt: now,
    );

    _currentWallet = updated;
    notifyListeners();
    _saveToLocal(updated);

    try {
      // 1. Deduct coins from wallet & user profile
      await updateCoins(
        userId: userId,
        amount: -costCoins,
        type: 'store_purchase',
        title: 'wallet_store_purchase_title'.tr(args: [itemName]),
        description: 'wallet_store_purchase_desc'.tr(args: [category]),
      );

      // 2. Update user profile perks based on category in Supabase (100% snake_case)
      final Map<String, dynamic> userPerks = {
        'updated_at': now.toIso8601String(),
      };

      if (category == 'frame') {
        userPerks['active_frame'] = itemId;
        try {
          final uDoc = await SupabaseService.client
              .from('users')
              .select('unlocked_frames')
              .or('id.eq.$userId,uid.eq.$userId')
              .maybeSingle();
          final List<dynamic> current =
              List.from(uDoc?['unlocked_frames'] ?? []);
          if (!current.contains(itemId)) current.add(itemId);
          userPerks['unlocked_frames'] = current;
        } catch (_) {}
      } else if (category == 'badge') {
        userPerks['active_badge'] = itemId;
        try {
          final uDoc = await SupabaseService.client
              .from('users')
              .select('unlocked_badges')
              .or('id.eq.$userId,uid.eq.$userId')
              .maybeSingle();
          final List<dynamic> current =
              List.from(uDoc?['unlocked_badges'] ?? []);
          if (!current.contains(itemId)) current.add(itemId);
          userPerks['unlocked_badges'] = current;
        } catch (_) {}
      } else if (category == 'chat_color') {
        final colorHex = metadata?['colorHex'] ?? '#00FF66';
        userPerks['chat_color'] = colorHex;
        try {
          final uDoc = await SupabaseService.client
              .from('users')
              .select('unlocked_chat_colors')
              .or('id.eq.$userId,uid.eq.$userId')
              .maybeSingle();
          final List<dynamic> current =
              List.from(uDoc?['unlocked_chat_colors'] ?? []);
          if (!current.contains(colorHex)) current.add(colorHex);
          userPerks['unlocked_chat_colors'] = current;
        } catch (_) {}
      } else if (category == 'vip_pass') {
        final days = (metadata?['durationDays'] as num?)?.toInt() ?? 7;
        final expiresAt = now.add(Duration(days: days));
        userPerks['vip_tournament_pass_until'] = expiresAt.toIso8601String();
        userPerks['is_vip_member'] = true;
      } else if (category == 'spotlight') {
        final hours = (metadata?['durationHours'] as num?)?.toInt() ?? 24;
        final expiresAt = now.add(Duration(hours: hours));
        userPerks['leaderboard_spotlight_until'] = expiresAt.toIso8601String();
      } else if (category == 'room_boost') {
        final roomId = metadata?['roomId'] as String? ?? '';
        final hours = (metadata?['durationHours'] as num?)?.toInt() ?? 24;
        if (roomId.isNotEmpty) {
          final until = now.add(Duration(hours: hours)).toIso8601String();
          try {
            await SupabaseService.client.from('rooms').update({
              'boosted_until': until,
            }).eq('id', roomId);
          } catch (_) {}
        }
      }

      await SupabaseService.client
          .from('users')
          .update(userPerks)
          .or('id.eq.$userId,uid.eq.$userId');

      try {
        NotificationService().sendStorePurchaseNotification(
          targetUserId: userId,
          itemName: itemName,
          costCoins: costCoins,
          category: category,
        );
      } catch (_) {}

      return {'success': true};
    } catch (e) {
      debugPrint('CoinWalletService purchaseStoreItem error: $e');
      return {'success': true};
    }
  }

  /// Track tournament participation
  Future<void> recordTournamentJoinedAndCheckReferral(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentPlayed =
          (prefs.getInt('user_tournaments_played_$userId') ?? 0) + 1;
      await prefs.setInt('user_tournaments_played_$userId', currentPlayed);

      await SupabaseService.client.from('users').update({
        'tournaments_played': currentPlayed,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,uid.eq.$userId');

      final referrerUid = prefs.getString('user_referrer_uid_$userId');
      final alreadyRewarded =
          prefs.getBool('user_referral_rewarded_$userId') ?? false;

      if (currentPlayed >= 5 &&
          referrerUid != null &&
          referrerUid.isNotEmpty &&
          !alreadyRewarded) {
        await prefs.setBool('user_referral_rewarded_$userId', true);
        await rewardReferralCoins(referrerUid,
            inviteeName: 'wallet_friend_milestone'.tr());
        await rewardReferralCoins(userId,
            inviteeName: 'wallet_referral_welcome_milestone'.tr());
      }
    } catch (e) {
      debugPrint('recordTournamentJoinedAndCheckReferral error: $e');
    }
  }

  /// Link friend referral code
  Future<bool> registerReferralCode(String userId, String referrerCode) async {
    try {
      final trimmed = referrerCode.trim();
      if (trimmed.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getString('user_referrer_uid_$userId');
      if (current != null && current.isNotEmpty) {
        return false;
      }

      await prefs.setString('user_referrer_uid_$userId', trimmed);
      await SupabaseService.client.from('users').update({
        'referred_by': trimmed,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,uid.eq.$userId');
      return true;
    } catch (_) {
      return false;
    }
  }

  String getReferralCode(String userId) {
    if (userId.isEmpty) return 'GK1000';
    final clean = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (clean.length <= 6) return 'GK${clean.padRight(6, 'X')}';
    return 'GK${clean.substring(0, 6)}';
  }

  Future<void> _saveToLocal(CoinWallet wallet) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'cached_wallet_${wallet.userId}', jsonEncode(wallet.toJson()));
    } catch (_) {}
  }

  Future<CoinWallet?> _loadFromLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('cached_wallet_$userId');
      if (str != null && str.isNotEmpty) {
        return CoinWallet.fromMap(jsonDecode(str), userId);
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    super.dispose();
  }
}
