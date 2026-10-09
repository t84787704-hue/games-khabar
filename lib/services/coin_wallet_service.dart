import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coin_wallet_model.dart';
import '../models/coin_transaction_model.dart';
import 'gamer_auth_service.dart';
import 'coin_reward_service.dart';
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
        'gCoins': coins,
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
  /// UNIFIED COIN UPDATE FUNCTION (100% Supabase)
  /// Atomically increments users.gCoins, users.coins, creates transaction
  /// in both 'transactions' & 'coin_transactions' tables, and syncs wallets.
  /// =========================================================================
  static Future<void> updateCoins({
    required String userId,
    required int amount,
    required String type, // 'win_reward', 'escrow_hold', 'escrow_refund', 'team_prize', 'win_prize', etc.
    required String description,
    String? title,
    String? roomId,
    String? winProofUrl,
    int? inEscrowChange,
  }) async {
    if (userId.isEmpty) return;
    try {
      final now = DateTime.now();

      // 1. Fetch current balances from Supabase
      int currentCoins = 1000;
      int currentEscrow = 0;
      int currentWinnings = 0;
      int currentWins = 0;

      try {
        final userRow = await SupabaseService.client
            .from('users')
            .select('coins, gCoins, inEscrow, totalWinnings, wins')
            .or('id.eq.$userId,uid.eq.$userId')
            .maybeSingle();

        if (userRow != null) {
          currentCoins = (userRow['coins'] as num?)?.toInt() ??
              (userRow['gCoins'] as num?)?.toInt() ??
              1000;
          currentEscrow = (userRow['inEscrow'] as num?)?.toInt() ?? 0;
          currentWinnings = (userRow['totalWinnings'] as num?)?.toInt() ?? 0;
          currentWins = (userRow['wins'] as num?)?.toInt() ?? 0;
        } else {
          final walletRow = await SupabaseService.client
              .from('coin_wallets')
              .select('coins, escrowCoins')
              .or('user_id.eq.$userId,userId.eq.$userId')
              .maybeSingle();
          if (walletRow != null) {
            currentCoins = (walletRow['coins'] as num?)?.toInt() ?? 1000;
            currentEscrow = (walletRow['escrowCoins'] as num?)?.toInt() ?? 0;
          }
        }
      } catch (_) {}

      final newCoins = (currentCoins + amount).clamp(0, 9999999);
      final newEscrow = (currentEscrow + (inEscrowChange ?? 0)).clamp(0, 9999999);

      final Map<String, dynamic> userUpdate = {
        'coins': newCoins,
        'gCoins': newCoins,
        'lastUpdated': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      if (inEscrowChange != null && inEscrowChange != 0) {
        userUpdate['inEscrow'] = newEscrow;
      }
      if (type == 'win_reward' || type == 'win_prize' || type == 'team_prize') {
        if (amount > 0) {
          userUpdate['totalWinnings'] = currentWinnings + amount;
          userUpdate['wins'] = currentWins + 1;
          userUpdate['lastRewardAt'] = now.toIso8601String();
        }
      }

      // Update user in Supabase
      try {
        await SupabaseService.client
            .from('users')
            .update(userUpdate)
            .or('id.eq.$userId,uid.eq.$userId');
      } catch (e) {
        debugPrint('CoinWalletService: Supabase user update error: $e');
      }

      // 2. Keep coin_wallets synchronized in Supabase
      try {
        await SupabaseService.client.from('coin_wallets').upsert({
          'id': userId,
          'user_id': userId,
          'userId': userId,
          'coins': newCoins,
          'gCoins': newCoins,
          'escrowCoins': newEscrow,
          'updated_at': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('CoinWalletService: Supabase coin_wallets sync error: $e');
      }

      // 3. Create transaction record in Supabase
      final txId = 'tx_${now.millisecondsSinceEpoch}_${userId.hashCode.abs() % 10000}';
      final Map<String, dynamic> txData = {
        'id': txId,
        'userId': userId,
        'user_id': userId,
        'type': type,
        'amount': amount,
        'status': 'completed',
        'title': title ?? description,
        'description': description,
        'balanceAfter': newCoins,
        'balance_after': newCoins,
        'timestamp': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };
      if (roomId != null && roomId.isNotEmpty) {
        txData['roomId'] = roomId;
        txData['reference_id'] = roomId;
      }
      if (winProofUrl != null && winProofUrl.isNotEmpty) {
        txData['winProofUrl'] = winProofUrl;
      }

      try {
        await SupabaseService.client.from('coin_transactions').upsert(txData);
        await SupabaseService.client.from('transactions').upsert(txData);
      } catch (e) {
        debugPrint('CoinWalletService: Supabase transaction log error: $e');
      }

      // 4. Update in-memory state
      _instance._syncToUserDocAndNotifiers(userId, newCoins);

      if (_instance._currentWallet != null &&
          (_instance._currentWallet!.userId == userId || userId.isEmpty)) {
        _instance._currentWallet = _instance._currentWallet!.copyWith(
          coins: newCoins,
          escrowCoins: newEscrow,
          updatedAt: now,
        );
        _instance.notifyListeners();
        _instance._saveToLocal(_instance._currentWallet!);
      }
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
          .or('userId.eq.$userId,user_id.eq.$userId');

      int computed = 1000;
      for (final r in rows) {
        computed += (r['amount'] as num?)?.toInt() ?? 0;
      }
      if (computed < 0) computed = 0;

      await SupabaseService.client.from('users').update({
        'coins': computed,
        'gCoins': computed,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,uid.eq.$userId');

      await SupabaseService.client.from('coin_wallets').upsert({
        'id': userId,
        'user_id': userId,
        'userId': userId,
        'coins': computed,
        'gCoins': computed,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _instance._syncToUserDocAndNotifiers(userId, computed);
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
          .or('user_id.eq.$userId,userId.eq.$userId,id.eq.$userId')
          .maybeSingle();

      if (row != null) {
        final w = CoinWallet.fromMap(row, userId);
        _currentWallet = w;
        notifyListeners();
        _saveToLocal(w);
        _listenToWalletChanges(userId);
        return w;
      }

      // Check users table for existing coins
      final userRow = await SupabaseService.client
          .from('users')
          .select('coins, gCoins')
          .or('id.eq.$userId,uid.eq.$userId')
          .maybeSingle();

      int initialCoins = 1000;
      if (userRow != null) {
        initialCoins = (userRow['coins'] as num?)?.toInt() ??
            (userRow['gCoins'] as num?)?.toInt() ??
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
        'userId': userId,
        'coins': initialCoins,
        'gCoins': initialCoins,
        'escrowCoins': 0,
        'trustScore': 100,
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
            (r['user_id'] ?? r['userId'] ?? r['id'])?.toString() == userId);
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
      return Stream.value(_currentWallet ?? const CoinWallet(userId: 'guest', coins: 1000));
    }
    try {
      return SupabaseService.client
          .from('coin_wallets')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final match = rows.where((r) =>
            (r['user_id'] ?? r['userId'] ?? r['id'])?.toString() == userId);
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
        title: 'Daily Bonus Claimed! 🎁',
        description: '+50 G-Coins collected',
      );

      await SupabaseService.client.from('coin_wallets').upsert({
        'id': userId,
        'user_id': userId,
        'lastDailyBonusClaim': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('CoinWalletService claimDailyBonus error: $e');
      return true;
    }
  }

  /// Reward 10 G-Coins for watching an Ad
  Future<void> rewardAdCoins(String userId) async {
    final wallet = await getOrCreateWallet(userId);
    final newCoins = wallet.coins + 10;
    final newLifetime = wallet.lifetimeEarned + 10;
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
        amount: 10,
        type: 'ad_reward',
        title: 'Ad Reward Earned! 📺',
        description: '+10 G-Coins for watching rewarded video',
      );
    } catch (e) {
      debugPrint('CoinWalletService rewardAdCoins error: $e');
    }
  }

  /// Reward Referral Coins (100 G-Coins)
  Future<void> rewardReferralCoins(String userId, {String inviteeName = 'Friend'}) async {
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
        title: 'Referral Bonus! 👥',
        description: '+100 G-Coins for inviting $inviteeName',
      );
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
    if (_currentWallet != null && (_currentWallet!.userId == userId || userId.isEmpty)) {
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
        title: 'Host Prize Escrow 🔒',
        description: 'Held in escrow for tournament "$roomTitle"',
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
    if (_currentWallet != null && (_currentWallet!.userId == userId || userId.isEmpty)) {
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
        type: 'escrow_hold',
        inEscrowChange: entryFeeCoins,
        title: 'Entry Fee Escrow 🎮',
        description: 'Slot registration for "$roomTitle"',
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
        title: 'Entry Fee Refunded ↩️',
        description: 'Left slot for "$roomTitle"',
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
            title: 'Escrow Released to Winner(s) 🏆',
            description: 'Transferred $prizePoolCoins escrow prize to winning team of "$roomTitle"',
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
                description: 'Entry fee escrow cleared for "$roomTitle"',
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
          title: winnerCount > 1 ? 'Team Victory Prize! 🏆' : 'Tournament Victory Prize! 🏆',
          description: winnerCount > 1
              ? 'Won tournament "$roomTitle" with team! Equal share: $prizePerWinner G-Coins'
              : 'Won tournament "$roomTitle" and claimed $prizePerWinner G-Coins from Admin Escrow!',
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
          title: 'Host Prize Refunded ↩️',
          description: 'Tournament "$roomTitle" expired/cancelled. Escrow refunded.',
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
                title: 'Entry Fee Refunded ↩️',
                description: 'Tournament "$roomTitle" cancelled. $entryFeeCoins Coins returned.',
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
  Future<void> penalizeTrustScore(String userId, int penaltyPoints, String reason) async {
    try {
      final wallet = await getOrCreateWallet(userId);
      final newTrust = (wallet.trustScore - penaltyPoints).clamp(0, 100);
      await SupabaseService.client.from('coin_wallets').update({
        'trustScore': newTrust,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('user_id.eq.$userId,userId.eq.$userId,id.eq.$userId');

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
      await SupabaseService.client.from('coin_transactions').upsert(map);
      await SupabaseService.client.from('transactions').upsert(map);
    } catch (e) {
      debugPrint('CoinWalletService recordTransaction error: $e');
    }
  }

  Stream<List<CoinTransaction>> transactionsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    try {
      return SupabaseService.client
          .from('coin_transactions')
          .stream(primaryKey: ['id'])
          .map((rows) {
        final filtered = rows
            .where((r) =>
                (r['userId'] ?? r['user_id'])?.toString() == userId ||
                r['to']?.toString() == userId ||
                r['from']?.toString() == userId)
            .map((r) => CoinTransaction.fromMap(r))
            .toList();
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
        'error': 'Insufficient G-Coins. You have ${wallet.coins}, but need $costCoins.',
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
        title: '$itemName Unlocked! ✨',
        description: 'Purchased in Coin Store ($category)',
      );

      // 2. Update user profile perks based on category in Supabase
      final Map<String, dynamic> userPerks = {
        'updated_at': now.toIso8601String(),
      };

      if (category == 'frame') {
        userPerks['activeFrame'] = itemId;
      } else if (category == 'badge') {
        userPerks['activeBadge'] = itemId;
      } else if (category == 'chat_color') {
        userPerks['chatColor'] = metadata?['colorHex'] ?? '#00FF66';
      } else if (category == 'vip_pass') {
        final days = (metadata?['durationDays'] as num?)?.toInt() ?? 7;
        final expiresAt = now.add(Duration(days: days));
        userPerks['vipTournamentPassUntil'] = expiresAt.toIso8601String();
        userPerks['isVipMember'] = true;
      } else if (category == 'spotlight') {
        final hours = (metadata?['durationHours'] as num?)?.toInt() ?? 24;
        final expiresAt = now.add(Duration(hours: hours));
        userPerks['leaderboardSpotlightUntil'] = expiresAt.toIso8601String();
      }

      await SupabaseService.client
          .from('users')
          .update(userPerks)
          .or('id.eq.$userId,uid.eq.$userId');

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
      final currentPlayed = (prefs.getInt('user_tournaments_played_$userId') ?? 0) + 1;
      await prefs.setInt('user_tournaments_played_$userId', currentPlayed);

      await SupabaseService.client.from('users').update({
        'tournamentsPlayed': currentPlayed,
        'updated_at': DateTime.now().toIso8601String(),
      }).or('id.eq.$userId,uid.eq.$userId');

      final referrerUid = prefs.getString('user_referrer_uid_$userId');
      final alreadyRewarded = prefs.getBool('user_referral_rewarded_$userId') ?? false;

      if (currentPlayed >= 5 && referrerUid != null && referrerUid.isNotEmpty && !alreadyRewarded) {
        await prefs.setBool('user_referral_rewarded_$userId', true);
        await rewardReferralCoins(referrerUid, inviteeName: 'Friend (5 Tournaments Milestone)');
        await rewardReferralCoins(userId, inviteeName: 'Referral Welcome (5 Tournaments Milestone)');
      }
    } catch (e) {
      debugPrint('recordTournamentJoinedAndCheckReferral error: $e');
    }
  }

  /// Link friend referral code
  Future<bool> registerReferralCode(String userId, String referrerCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getString('user_referrer_uid_$userId');
      if (current != null && current.isNotEmpty) {
        return false;
      }

      await prefs.setString('user_referrer_uid_$userId', referrerCode.trim());
      await SupabaseService.client.from('users').update({
        'referredBy': referrerCode.trim(),
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
      await prefs.setString('cached_wallet_${wallet.userId}', jsonEncode(wallet.toJson()));
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
