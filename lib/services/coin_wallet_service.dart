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
import 'team_service.dart';
import 'wallet_repository.dart';

class CoinWalletService extends ChangeNotifier {
  static final CoinWalletService _instance = CoinWalletService._internal();
  factory CoinWalletService() => _instance;
  CoinWalletService._internal();

  CoinWallet? _currentWallet;
  CoinWallet? get currentWallet =>
      _currentWallet ?? WalletRepository.instance.walletNotifier.value;

  ValueListenable<int> get gCoinsBalance => WalletRepository.instance.gCoinsBalance;

  StreamSubscription? _walletSub;

  Future<void> _syncToUserDocAndNotifiers(String userId, int coins) async {
    if (userId.isEmpty) return;

    if (_currentWallet != null &&
        (_currentWallet!.userId == userId || userId.isEmpty)) {
      _currentWallet = _currentWallet!.copyWith(
        coins: coins,
        updatedAt: DateTime.now(),
      );
      _saveToLocal(_currentWallet!);
    }

    WalletRepository.instance.publishLiveBalance(
      coins,
      userId: userId,
      wallet: _currentWallet,
    );

    try {
      CoinRewardService().coinsNotifier.value = coins;
    } catch (_) {}

    notifyListeners();

    await WalletRepository.instance.persistWalletToSupabase(
      userId: userId,
      gCoins: coins,
    );
  }

  static Future<void> _checkTeamEligibility(String userId, int newCoins) async {
    if (userId.isEmpty) return;
    try {
      final nowStr = DateTime.now().toIso8601String();

      final leaderTeams = await SupabaseService.client
          .from('teams')
          .select('id, name, status')
          .or('leader_id.eq.$userId,leaderId.eq.$userId');

      if (leaderTeams != null && leaderTeams is List && leaderTeams.isNotEmpty) {
        for (final team in leaderTeams) {
          final teamId = team['id']?.toString() ?? '';
          final teamName = team['name']?.toString() ?? 'wallet_team_default_name'.tr();
          final currentStatus = (team['status'] ?? 'active').toString().toLowerCase();

          if (newCoins < 1000 && currentStatus != 'frozen') {
            await SupabaseService.client.from('teams').update({
              'status': 'frozen',
              'frozen_reason': 'wallet_team_frozen_reason'.tr(args: [newCoins.toString()]),
              'updated_at': nowStr,
            }).or('id.eq.$teamId,team_id.eq.$teamId');

            await _sendDetailedNotification(
              userId: userId,
              type: 'team_frozen',
              title: 'wallet_team_frozen_title'.tr(),
              message: 'wallet_team_frozen_notification'.tr(args: [newCoins.toString(), teamName]),
            );
          }
          else if (newCoins >= 1000 && currentStatus == 'frozen') {
            await SupabaseService.client.from('teams').update({
              'status': 'active',
              'frozen_reason': null,
              'updated_at': nowStr,
            }).or('id.eq.$teamId,team_id.eq.$teamId');

            await _sendDetailedNotification(
              userId: userId,
              type: 'team_reactivated',
              title: 'wallet_team_reactivated_title'.tr(),
              message: 'wallet_team_reactivated_notification'.tr(args: [newCoins.toString(), teamName]),
            );
          }
        }
      }

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
            final teamName = teamMap?['name']?.toString() ?? 'wallet_team_default_name'.tr();

            if (leaderId != userId) {
              await SupabaseService.client
                  .from('team_members')
                  .delete()
                  .eq('id', rowId);

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

              await _sendDetailedNotification(
                userId: userId,
                type: 'team_removed',
                title: 'wallet_team_removed_title'.tr(),
                message: 'wallet_team_removed_low_balance_notification'.tr(args: [newCoins.toString(), teamName]),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[CoinWalletService] _checkTeamEligibility error: $e');
    }
  }

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

  static Future<void> updateCoins({
    required String userId,
    required int amount,
    required String type,
    required String description,
    String? title,
    String? roomId,
    String? teamId,
    String? gameName,
    String? winProofUrl,
    int? inEscrowChange,
  }) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return;
    try {
      final now = DateTime.now();
      final String targetUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(cleanUid)
          ? cleanUid
          : SupabaseService.toUuid(cleanUid);

      // 1. Resolve current authoritative G-Coins balance from `public.coin_wallets` first
      int currentCoins = WalletRepository.instance.currentGCoins > 0
          ? WalletRepository.instance.currentGCoins
          : ((_instance._currentWallet != null &&
                  (_instance._currentWallet!.userId == cleanUid || cleanUid.isEmpty))
              ? _instance._currentWallet!.coins
              : 0);
      int currentEscrow = (_instance._currentWallet != null &&
              (_instance._currentWallet!.userId == cleanUid || cleanUid.isEmpty))
          ? _instance._currentWallet!.escrowCoins
          : 0;
      int lifetimeEarned = (_instance._currentWallet != null &&
              (_instance._currentWallet!.userId == cleanUid || cleanUid.isEmpty))
          ? _instance._currentWallet!.lifetimeEarned
          : currentCoins;
      int lifetimeSpent = (_instance._currentWallet != null &&
              (_instance._currentWallet!.userId == cleanUid || cleanUid.isEmpty))
          ? _instance._currentWallet!.lifetimeSpent
          : 0;
      int trustScore = (_instance._currentWallet != null &&
              (_instance._currentWallet!.userId == cleanUid || cleanUid.isEmpty))
          ? _instance._currentWallet!.trustScore
          : 100;

      try {
        Map<String, dynamic>? walletRow = await SupabaseService.client
            .from('coin_wallets')
            .select()
            .eq('user_id', cleanUid)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));

        if (walletRow == null && targetUuid != cleanUid) {
          walletRow = await SupabaseService.client
              .from('coin_wallets')
              .select()
              .eq('user_id', targetUuid)
              .limit(1)
              .maybeSingle()
              .timeout(const Duration(seconds: 3));
        }

        if (walletRow != null) {
          final parsed = CoinWallet.fromMap(walletRow, cleanUid);
          if (parsed.coins > 0 || currentCoins == 0) {
            // Keep whichever is higher if local repository already reconciled with ledger
            if (WalletRepository.instance.currentGCoins > parsed.coins) {
              currentCoins = WalletRepository.instance.currentGCoins;
            } else {
              currentCoins = parsed.coins;
            }
          }
          currentEscrow = parsed.escrowCoins;
          lifetimeEarned = parsed.lifetimeEarned > currentCoins
              ? parsed.lifetimeEarned
              : currentCoins;
          lifetimeSpent = parsed.lifetimeSpent;
          trustScore = parsed.trustScore;
        }
      } catch (e) {
        debugPrint('updateCoins: fetch coin_wallets notice: $e');
      }

      if (currentCoins <= 0) {
        try {
          final userRow = await SupabaseService.client
              .from('users')
              .select('coins')
              .or('id.eq.$cleanUid,uid.eq.$cleanUid')
              .limit(1)
              .maybeSingle()
              .timeout(const Duration(seconds: 3));
          if (userRow != null) {
            final uCoins = (userRow['coins'] as num?)?.toInt() ?? 0;
            if (uCoins > 0) currentCoins = uCoins;
          }
        } catch (_) {}
      }

      final newCoins = (currentCoins + amount).clamp(0, 999999999);
      final newEscrow = (currentEscrow + (inEscrowChange ?? 0)).clamp(0, 999999999);

      if (amount > 0) {
        lifetimeEarned += amount;
      } else if (amount < 0 && (inEscrowChange == null || inEscrowChange == 0)) {
        lifetimeSpent += amount.abs();
      }

      final updatedWallet = CoinWallet(
        userId: cleanUid,
        coins: newCoins,
        escrowCoins: newEscrow,
        lifetimeEarned: lifetimeEarned,
        lifetimeSpent: lifetimeSpent,
        trustScore: trustScore,
        lastDailyBonusClaim: type == 'daily_bonus'
            ? now
            : (_instance._currentWallet?.lastDailyBonusClaim ??
                WalletRepository.instance.walletNotifier.value?.lastDailyBonusClaim),
        updatedAt: now,
      );

      // Immediately update shared WalletRepository, local wallet state & notifiers so every screen updates right away
      _instance._currentWallet = updatedWallet;
      WalletRepository.instance.publishLiveBalance(
        newCoins,
        userId: cleanUid,
        wallet: updatedWallet,
      );
      _instance.notifyListeners();
      _instance._saveToLocal(updatedWallet);

      try {
        CoinRewardService().coinsNotifier.value = newCoins;
      } catch (_) {}

      final Map<String, dynamic> txData = {
        'user_id': targetUuid,
        'type': type,
        'amount': amount,
        'status': 'completed',
        'title': title ?? description,
        'description': description,
        'balance_after': newCoins,
        'created_at': now.toUtc().toIso8601String(),
      };
      if (roomId != null && roomId.isNotEmpty) {
        txData['room_id'] = roomId;
        txData['reference_id'] = roomId;
      }
      if (teamId != null && teamId.isNotEmpty) {
        txData['team_id'] = teamId;
      }
      if (gameName != null && gameName.isNotEmpty) {
        txData['game_name'] = gameName;
      }
      if (winProofUrl != null && winProofUrl.isNotEmpty) {
        txData['win_proof_url'] = winProofUrl;
      }

      final String combinedDesc =
          (title != null && title.isNotEmpty) ? '$title - $description' : description;

      // Persist to `public.coin_wallets` (`g_coins` & `coins`) and `public.users` (`coins`)
      await WalletRepository.instance.persistWalletToSupabase(
        userId: cleanUid,
        gCoins: newCoins,
        escrowCoins: newEscrow,
        lifetimeEarned: lifetimeEarned,
        lifetimeSpent: lifetimeSpent,
        trustScore: trustScore,
        lastDailyBonusClaim: type == 'daily_bonus' ? now : null,
      );

      // Persist transaction ledger entries non-blockingly so UI buttons never stay in Sending... state
      Future<void>(() async {
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
                  'description': combinedDesc,
                  'balance_after': newCoins,
                  if (roomId != null && roomId.isNotEmpty) 'reference_id': roomId,
                  'created_at': now.toIso8601String(),
                });
          } catch (e2) {
            debugPrint('updateCoins: fallback coin_transactions insert error: $e2, trying minimal schema');
            try {
              await SupabaseService.client
                  .from('coin_transactions')
                  .insert({
                    'user_id': targetUuid,
                    'amount': amount,
                    'type': type,
                    'description': combinedDesc,
                    'created_at': now.toIso8601String(),
                  });
            } catch (e3) {
              debugPrint('updateCoins: minimal coin_transactions insert error: $e3');
            }
          }
        }

        try {
          await SupabaseService.client
              .from('transactions')
              .insert(txData);
        } catch (_) {}

        if (type != 'team_weekly_contribution' &&
            type != 'game_currency_redemption' &&
            type != 'weekly_team_reward') {
          await _checkTeamEligibility(cleanUid, newCoins);
        }
      });
    } catch (e) {
      debugPrint('CoinWalletService updateCoins error: $e');
    }
  }

  static Future<int> recalculateCoins(String userId) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return WalletRepository.instance.currentGCoins;
    try {
      final wallet = await WalletRepository.instance.fetchOrSyncWalletFromSupabase(cleanUid);
      _instance._currentWallet = wallet;
      _instance._saveToLocal(wallet);
      _instance.notifyListeners();
      try {
        CoinRewardService().coinsNotifier.value = wallet.coins;
      } catch (_) {}
      _checkTeamEligibility(cleanUid, wallet.coins);
      return wallet.coins;
    } catch (e) {
      debugPrint('CoinWalletService recalculateCoins error: $e');
      return WalletRepository.instance.currentGCoins;
    }
  }

  Future<CoinWallet> getOrCreateWallet(String userId) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) {
      return const CoinWallet(userId: 'guest', coins: 0);
    }

    final local = await _loadFromLocal(cleanUid);
    if (local != null && _currentWallet == null) {
      _currentWallet = local;
      if (WalletRepository.instance.currentGCoins <= 0 && local.coins > 0) {
        WalletRepository.instance.publishLiveBalance(
          local.coins,
          userId: cleanUid,
          wallet: local,
        );
      }
      notifyListeners();
    }

    try {
      final wallet = await WalletRepository.instance.fetchOrSyncWalletFromSupabase(cleanUid);
      _currentWallet = wallet;
      notifyListeners();
      _saveToLocal(wallet);
      _listenToWalletChanges(cleanUid);
      return wallet;
    } catch (e) {
      debugPrint('CoinWalletService getOrCreateWallet Supabase error: $e');
      final fallback = _currentWallet ??
          WalletRepository.instance.walletNotifier.value ??
          local ??
          CoinWallet(userId: cleanUid, coins: WalletRepository.instance.currentGCoins);
      _currentWallet = fallback;
      return fallback;
    }
  }

  void _listenToWalletChanges(String userId) {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty) return;
    _walletSub?.cancel();
    final userUuid = SupabaseService.toUuid(cleanUid).toLowerCase();
    final rawLower = cleanUid.toLowerCase();
    try {
      _walletSub = SupabaseService.client
          .from('coin_wallets')
          .stream(primaryKey: ['user_id'])
          .listen((rows) {
        final match = rows.where((r) {
          final rowUid = (r['user_id'] ?? r['id'] ?? '').toString().trim().toLowerCase();
          return rowUid == rawLower || rowUid == userUuid;
        });
        if (match.isNotEmpty) {
          final w = CoinWallet.fromMap(match.first, cleanUid);
          // Only accept if non-zero or if we haven't loaded a higher ledger-reconciled balance
          final currentLive = WalletRepository.instance.currentGCoins;
          if (w.coins > 0 && (currentLive <= 0 || w.coins >= currentLive)) {
            _currentWallet = w;
            WalletRepository.instance.publishLiveBalance(
              w.coins,
              userId: cleanUid,
              wallet: w,
            );
            notifyListeners();
            _saveToLocal(w);
          }
        }
      }, onError: (err) {
        debugPrint('CoinWalletService wallet stream notice: $err');
      });
    } catch (_) {}
  }

  Stream<CoinWallet> walletStream(String userId) {
    final cleanUid = userId.trim();
    final int fallbackCoins = WalletRepository.instance.currentGCoins > 0
        ? WalletRepository.instance.currentGCoins
        : (_currentWallet?.coins ??
            GamerAuthService().currentGamer?.coins ??
            CoinRewardService().coinsNotifier.value);
    final CoinWallet initialFallback =
        WalletRepository.instance.walletNotifier.value ??
            _currentWallet ??
            CoinWallet(
              userId: cleanUid.isEmpty ? 'guest' : cleanUid,
              coins: fallbackCoins > 0 ? fallbackCoins : 0,
            );

    if (cleanUid.isEmpty) {
      return Stream.value(initialFallback).asBroadcastStream();
    }

    late StreamController<CoinWallet> controller;
    StreamSubscription? supaSub;
    VoidCallback? repoListener;

    void emitWallet(CoinWallet w) {
      _currentWallet = w;
      if (!controller.isClosed) {
        controller.add(w);
      }
    }

    controller = StreamController<CoinWallet>.broadcast(
      onListen: () {
        final currentRepoWallet = WalletRepository.instance.walletNotifier.value;
        if (currentRepoWallet != null && currentRepoWallet.coins > 0) {
          emitWallet(currentRepoWallet);
        } else {
          emitWallet(initialFallback);
        }

        // Listen to local shared WalletRepository changes immediately
        repoListener = () {
          final latestW = WalletRepository.instance.walletNotifier.value;
          final latestCoins = WalletRepository.instance.currentGCoins;
          if (latestW != null) {
            emitWallet(latestW.copyWith(coins: latestCoins));
          } else if (_currentWallet != null) {
            emitWallet(_currentWallet!.copyWith(coins: latestCoins));
          } else {
            emitWallet(CoinWallet(userId: cleanUid, coins: latestCoins));
          }
        };
        WalletRepository.instance.gCoinsBalance.addListener(repoListener!);

        // Trigger background authoritative fetch & sync from `public.coin_wallets`
        WalletRepository.instance.refreshForCurrentUser(userId: cleanUid);

        // Also subscribe to Supabase realtime changes on `public.coin_wallets`
        try {
          final userUuid = SupabaseService.toUuid(cleanUid).toLowerCase();
          final rawLower = cleanUid.toLowerCase();
          supaSub = SupabaseService.client
              .from('coin_wallets')
              .stream(primaryKey: ['user_id'])
              .listen((rows) {
            final match = rows.where((r) {
              final rowUid = (r['user_id'] ?? r['id'] ?? '').toString().trim().toLowerCase();
              return rowUid == rawLower || rowUid == userUuid;
            });
            if (match.isNotEmpty) {
              final parsed = CoinWallet.fromMap(match.first, cleanUid);
              final liveCoins = WalletRepository.instance.currentGCoins;
              final resolvedCoins =
                  (liveCoins > parsed.coins && liveCoins > 0) ? liveCoins : parsed.coins;
              final synced = parsed.copyWith(coins: resolvedCoins);
              WalletRepository.instance.publishLiveBalance(
                resolvedCoins,
                userId: cleanUid,
                wallet: synced,
              );
              emitWallet(synced);
            }
          }, onError: (_) {});
        } catch (_) {}
      },
      onCancel: () {
        if (repoListener != null) {
          WalletRepository.instance.gCoinsBalance.removeListener(repoListener!);
        }
        supaSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<bool> claimDailyBonus(String userId) async {
    final wallet = await getOrCreateWallet(userId);
    if (!wallet.canClaimDailyBonus) {
      return false;
    }

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

  Future<void> rewardAdCoins(String userId) async {
    await getOrCreateWallet(userId);
    try {
      await updateCoins(
        userId: userId,
        amount: 25,
        type: 'ad_reward',
        title: 'wallet_ad_reward_title'.tr(),
        description: 'wallet_ad_reward_desc'.tr(),
      );
      try {
        NotificationService().sendCoinRewardNotification(
          targetUserId: userId,
          amount: 25,
          reason: 'wallet_ad_reward_reason'.tr(),
          type: 'ad_reward',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('CoinWalletService rewardAdCoins error: $e');
    }
  }

  Future<void> rewardReferralCoins(String userId,
      {String? inviteeName}) async {
    final name = inviteeName ?? 'wallet_friend'.tr();
    await getOrCreateWallet(userId);
    try {
      await updateCoins(
        userId: userId,
        amount: 100,
        type: 'referral',
        title: 'wallet_referral_bonus_title'.tr(),
        description: 'wallet_referral_bonus_desc'.tr(args: [name]),
      );
      try {
        NotificationService().sendCoinRewardNotification(
          targetUserId: userId,
          amount: 100,
          reason: 'wallet_referral_bonus_reason'.tr(args: [name]),
          type: 'referral',
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('CoinWalletService rewardReferralCoins error: $e');
    }
  }

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

      if (roomId.isNotEmpty) {
        final combinedWName = (winnerNames != null && winnerNames.isNotEmpty)
            ? winnerNames.join(', ')
            : 'winner_default_label'.tr();
        await SupabaseService.client.from('tournament_rooms').update({
          'status': 'completed',
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

  Future<void> refundRoom({
    required String hostId,
    required int prizePoolCoins,
    required List<String> joiners,
    required int entryFeeCoins,
    required String roomId,
    required String roomTitle,
  }) async {
    try {
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
      _cachedTransactionsTimeByUser.clear();
    } catch (e) {
      debugPrint('CoinWalletService recordTransaction error: $e');
    }
  }

  static const Duration _txCacheTtl = Duration(seconds: 45);
  final Map<String, List<CoinTransaction>> _cachedTransactionsByUser = {};
  final Map<String, DateTime> _cachedTransactionsTimeByUser = {};

  bool _isTxCacheFresh(String key) {
    final ts = _cachedTransactionsTimeByUser[key];
    if (ts == null) return false;
    return DateTime.now().difference(ts) < _txCacheTtl;
  }

  List<CoinTransaction> getCachedTransactions(String userId) {
    if (userId.trim().isEmpty) return const <CoinTransaction>[];
    final key = userId.trim().toLowerCase();
    final uuidKey = SupabaseService.toUuid(userId.trim()).toLowerCase();
    return _cachedTransactionsByUser[key] ??
        _cachedTransactionsByUser[uuidKey] ??
        const <CoinTransaction>[];
  }

  List<CoinTransaction> _parseAndFilterUserTransactions(
    Iterable<dynamic> rows,
    String userId,
  ) {
    final cleanUid = userId.trim().toLowerCase();
    final userUuid = SupabaseService.toUuid(userId.trim()).toLowerCase();

    final filtered = rows
        .whereType<Map>()
        .where((r) {
          final uid = (r['user_id'] ?? r['userId'] ?? '').toString().trim().toLowerCase();
          final toUid = (r['to'] ?? '').toString().trim().toLowerCase();
          final fromUid = (r['from'] ?? '').toString().trim().toLowerCase();
          return uid == cleanUid ||
              uid == userUuid ||
              toUid == cleanUid ||
              toUid == userUuid ||
              fromUid == cleanUid ||
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
        })
        .toList();

    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  Stream<List<CoinTransaction>> transactionsStream(String userId) {
    final trimmedUid = userId.trim();
    if (trimmedUid.isEmpty) {
      return Stream.value(const <CoinTransaction>[]).asBroadcastStream();
    }

    final cacheKey = trimmedUid.toLowerCase();
    final userUuid = SupabaseService.toUuid(trimmedUid);
    final uuidKey = userUuid.toLowerCase();

    late StreamController<List<CoinTransaction>> controller;
    StreamSubscription? realtimeSub;

    void emitSafely(List<CoinTransaction> txs, {required String source}) {
      if (txs.isNotEmpty) {
        _cachedTransactionsByUser[cacheKey] = txs;
        _cachedTransactionsByUser[uuidKey] = txs;
        _cachedTransactionsTimeByUser[cacheKey] = DateTime.now();
        _cachedTransactionsTimeByUser[uuidKey] = DateTime.now();
        if (!controller.isClosed) {
          controller.add(txs);
        }
      } else {
        final previous = _cachedTransactionsByUser[cacheKey] ??
            _cachedTransactionsByUser[uuidKey];
        if (previous != null && previous.isNotEmpty) {
          debugPrint(
            '[CoinWalletService] Guarded against empty emission from $source; keeping ${previous.length} cached transactions for $trimmedUid',
          );
          if (!controller.isClosed) {
            controller.add(previous);
          }
        } else if (!controller.isClosed) {
          controller.add(const <CoinTransaction>[]);
        }
      }
    }

    Future<void> fetchInitialRestSnapshot({bool force = false}) async {
      if (!force &&
          (_isTxCacheFresh(cacheKey) || _isTxCacheFresh(uuidKey)) &&
          getCachedTransactions(trimmedUid).isNotEmpty) {
        return;
      }
      try {
        final dynamic rows = await SupabaseService.client
            .from('coin_transactions')
            .select()
            .or('user_id.eq.$trimmedUid,user_id.eq.$userUuid')
            .order('created_at', ascending: false)
            .limit(100);
        if (rows is List) {
          final parsed = _parseAndFilterUserTransactions(rows, trimmedUid);
          if (parsed.isNotEmpty) {
            emitSafely(parsed, source: 'REST initial query');
          }
        }
      } catch (e) {
        debugPrint('[CoinWalletService] REST coin_transactions fallback notice: $e');
      }
    }

    controller = StreamController<List<CoinTransaction>>.broadcast(
      onListen: () {
        final cached = getCachedTransactions(trimmedUid);
        if (cached.isNotEmpty && !controller.isClosed) {
          controller.add(cached);
        }

        fetchInitialRestSnapshot();

        try {
          realtimeSub = SupabaseService.client
              .from('coin_transactions')
              .stream(primaryKey: ['id'])
              .eq('user_id', userUuid)
              .limit(50)
              .listen(
            (rows) {
              final filtered = _parseAndFilterUserTransactions(rows, trimmedUid);
              emitSafely(filtered, source: 'Supabase Realtime');
            },
            onError: (err) {
              debugPrint('[CoinWalletService] Realtime coin_transactions error: $err');
              final fallback = getCachedTransactions(trimmedUid);
              if (!controller.isClosed) {
                controller.add(fallback);
              }
            },
          );
        } catch (e) {
          debugPrint('[CoinWalletService] transactionsStream setup error: $e');
          final fallback = getCachedTransactions(trimmedUid);
          if (!controller.isClosed) {
            controller.add(fallback);
          }
        }
      },
      onCancel: () {
        realtimeSub?.cancel();
        realtimeSub = null;
      },
    );

    return controller.stream;
  }

  Future<Map<String, dynamic>> purchaseStoreItem({
    required String userId,
    required String itemId,
    required String itemName,
    required String category,
    required int costCoins,
    Map<String, dynamic>? metadata,
  }) async {
    final userTeams = await TeamService().getUserTeams(userId);
    if (userTeams.isEmpty) {
      return {
        'success': false,
        'error':
            'Team Membership Required: Only players in an active team (up to 4 members) can redeem rewards. Your earned coins remain safely saved in your personal balance and history.',
      };
    }

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
      await updateCoins(
        userId: userId,
        amount: -costCoins,
        type: 'store_purchase',
        title: 'wallet_store_purchase_title'.tr(args: [itemName]),
        description: 'wallet_store_purchase_desc'.tr(args: [category]),
      );

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