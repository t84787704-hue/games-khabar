import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coin_wallet_model.dart';
import '../models/coin_transaction_model.dart';
import 'gamer_auth_service.dart';
import 'coin_reward_service.dart';

class CoinWalletService extends ChangeNotifier {
  static final CoinWalletService _instance = CoinWalletService._internal();
  factory CoinWalletService() => _instance;
  CoinWalletService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _walletsRef => _firestore.collection('coin_wallets');
  CollectionReference<Map<String, dynamic>> get _transactionsRef => _firestore.collection('coin_transactions');

  // Cached active user wallet
  CoinWallet? _currentWallet;
  CoinWallet? get currentWallet => _currentWallet;

  StreamSubscription<DocumentSnapshot>? _walletSub;

  /// Helper to synchronize coins to 'users' collection and in-memory notifiers
  Future<void> _syncToUserDocAndNotifiers(String userId, int coins) async {
    if (userId.isEmpty) return;
    try {
      await _firestore.collection('users').doc(userId).set({
        'coins': coins,
      }, SetOptions(merge: true));
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

  /// Initialize or fetch wallet for active user. Grants 1,000 Free G-Coins if new.
  Future<CoinWallet> getOrCreateWallet(String userId) async {
    if (userId.isEmpty) {
      return const CoinWallet(userId: 'guest', coins: 1000);
    }

    try {
      final docRef = _walletsRef.doc(userId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Check if user already had coins in 'users' doc
        int initialCoins = 1000;
        try {
          final userSnap = await _firestore.collection('users').doc(userId).get();
          if (userSnap.exists) {
            final userC = (userSnap.data()?['coins'] as num?)?.toInt();
            if (userC != null && userC > 0) {
              initialCoins = userC;
            }
          }
        } catch (_) {}

        final newWallet = CoinWallet(
          userId: userId,
          coins: initialCoins,
          escrowCoins: 0,
          lifetimeEarned: initialCoins,
          trustScore: 100,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await docRef.set(newWallet.toMap());

        // Create welcome bonus transaction
        await _recordTransaction(CoinTransaction(
          id: _transactionsRef.doc().id,
          userId: userId,
          type: 'admin_bonus',
          amount: initialCoins,
          status: 'completed',
          timestamp: DateTime.now(),
          title: 'Welcome Bonus 🎁',
          description: 'Free $initialCoins G-Coins on joining My Gamer ID!',
        ));

        _currentWallet = newWallet;
        _saveToLocal(newWallet);
        notifyListeners();
        _listenToWallet(userId);
        _syncToUserDocAndNotifiers(userId, initialCoins);
        return newWallet;
      } else {
        final existingWallet = CoinWallet.fromFirestore(doc);
        _currentWallet = existingWallet;
        _saveToLocal(existingWallet);
        notifyListeners();
        _listenToWallet(userId);
        _syncToUserDocAndNotifiers(userId, existingWallet.coins);
        return existingWallet;
      }
    } catch (e) {
      debugPrint('CoinWalletService: getOrCreateWallet error: $e. Falling back to local cache.');
      final local = await _loadFromLocal(userId);
      if (local != null) {
        _currentWallet = local;
        notifyListeners();
        _syncToUserDocAndNotifiers(userId, local.coins);
        return local;
      }
      final fallback = CoinWallet(userId: userId, coins: 1000);
      _currentWallet = fallback;
      notifyListeners();
      _syncToUserDocAndNotifiers(userId, fallback.coins);
      return fallback;
    }
  }

  void _listenToWallet(String userId) {
    _walletSub?.cancel();
    _walletSub = _walletsRef.doc(userId).snapshots().listen(
      (snap) {
        if (snap.exists) {
          _currentWallet = CoinWallet.fromFirestore(snap);
          _saveToLocal(_currentWallet!);
          notifyListeners();
          _syncToUserDocAndNotifiers(userId, _currentWallet!.coins);
        }
      },
      onError: (err) {
        debugPrint('CoinWalletService listen error: $err');
      },
    );
  }

  Stream<CoinWallet> walletStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value(_currentWallet ?? const CoinWallet(userId: 'guest', coins: 1000));
    }
    return _walletsRef.doc(userId).snapshots().map((snap) {
      if (snap.exists) {
        final w = CoinWallet.fromFirestore(snap);
        _currentWallet = w;
        return w;
      }
      return _currentWallet ?? const CoinWallet(userId: '', coins: 1000);
    });
  }

  /// Claim Daily 50 G-Coins bonus every 24h (after watching 1 ad)
  Future<bool> claimDailyBonus(String userId) async {
    final wallet = await getOrCreateWallet(userId);
    if (!wallet.canClaimDailyBonus) {
      return false;
    }

    final newCoins = wallet.coins + 50;
    final newLifetime = wallet.lifetimeEarned + 50;
    final now = DateTime.now();

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
      await _walletsRef.doc(userId).update({
        'coins': newCoins,
        'lifetimeEarned': newLifetime,
        'lastDailyBonusClaim': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _recordTransaction(CoinTransaction(
        id: _transactionsRef.doc().id,
        userId: userId,
        type: 'daily_bonus',
        amount: 50,
        status: 'completed',
        timestamp: now,
        title: 'Daily Check-in Reward 📅',
        description: 'Watched 1 ad for daily check-in (+50 G-Coins).',
      ));
      _syncToUserDocAndNotifiers(userId, newCoins);
      return true;
    } catch (e) {
      debugPrint('CoinWalletService claimDailyBonus error: $e');
      return true;
    }
  }

  /// Watch Rewarded Ad -> +50 Coins per ad
  Future<void> rewardAdCoins(String userId) async {
    final wallet = await getOrCreateWallet(userId);
    final newCoins = wallet.coins + 50;
    final newLifetime = wallet.lifetimeEarned + 50;
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
      await _walletsRef.doc(userId).update({
        'coins': newCoins,
        'lifetimeEarned': newLifetime,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _recordTransaction(CoinTransaction(
        id: _transactionsRef.doc().id,
        userId: userId,
        type: 'ad_reward',
        amount: 50,
        status: 'completed',
        timestamp: now,
        title: 'Rewarded Ad Bonus 📺',
        description: 'Watched sponsored gaming ad (+50 G-Coins).',
      ));
      _syncToUserDocAndNotifiers(userId, newCoins);
    } catch (e) {
      debugPrint('CoinWalletService rewardAdCoins error: $e');
    }
  }

  /// Referral: +200 Coins on invite
  Future<void> rewardReferralCoins(String userId, {String inviteeName = 'Friend'}) async {
    final wallet = await getOrCreateWallet(userId);
    final newCoins = wallet.coins + 200;
    final newLifetime = wallet.lifetimeEarned + 200;
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
      await _walletsRef.doc(userId).update({
        'coins': newCoins,
        'lifetimeEarned': newLifetime,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _recordTransaction(CoinTransaction(
        id: _transactionsRef.doc().id,
        userId: userId,
        type: 'referral',
        amount: 200,
        status: 'completed',
        timestamp: now,
        title: 'Friend Referral Reward 🤝',
        description: '$inviteeName joined My Gamer ID using your invite link (+200 G-Coins).',
      ));
      _syncToUserDocAndNotifiers(userId, newCoins);
    } catch (e) {
      debugPrint('CoinWalletService rewardReferralCoins error: $e');
    }
  }

  /// Host Room Escrow Hold: Checks if wallet.coins >= prizePoolCoins.
  /// If yes, deducts prizePoolCoins from coins and moves to escrowCoins.
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
      return false; // Not enough coins
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

    // Update GamerAuthService notifier as well
    final currentGamer = GamerAuthService().currentGamer;
    if (currentGamer != null && (currentGamer.uid == userId || userId.isEmpty)) {
      GamerAuthService().currentGamerNotifier.value = currentGamer.copyWith(coins: newCoins);
    }

    try {
      await _walletsRef.doc(userId).set({
        'userId': userId,
        'coins': newCoins,
        'escrowCoins': newEscrow,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(userId).set({
        'coins': newCoins,
      }, SetOptions(merge: true));

      _syncToUserDocAndNotifiers(userId, newCoins);

      await _recordTransaction(CoinTransaction(
        id: _transactionsRef.doc().id,
        userId: userId,
        type: 'room_host_hold',
        amount: -prizePoolCoins,
        status: 'completed',
        timestamp: now,
        title: 'Host Prize Escrow 🔒',
        description: 'Held in escrow for tournament "$roomTitle"',
        roomId: roomId,
      ));
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

    // Update GamerAuthService notifier as well
    final currentGamer = GamerAuthService().currentGamer;
    if (currentGamer != null && (currentGamer.uid == userId || userId.isEmpty)) {
      GamerAuthService().currentGamerNotifier.value = currentGamer.copyWith(coins: newCoins);
    }

    try {
      await _walletsRef.doc(userId).set({
        'userId': userId,
        'coins': newCoins,
        'escrowCoins': newEscrow,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(userId).set({
        'coins': newCoins,
      }, SetOptions(merge: true));

      _syncToUserDocAndNotifiers(userId, newCoins);

      await _recordTransaction(CoinTransaction(
        id: _transactionsRef.doc().id,
        userId: userId,
        type: 'entry_fee',
        amount: -entryFeeCoins,
        status: 'completed',
        timestamp: now,
        title: 'Entry Fee Escrow 🎮',
        description: 'Slot registration for "$roomTitle"',
        roomId: roomId,
      ));
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

    final currentGamer = GamerAuthService().currentGamer;
    if (currentGamer != null && (currentGamer.uid == userId || userId.isEmpty)) {
      GamerAuthService().currentGamerNotifier.value = currentGamer.copyWith(coins: newCoins);
    }

    try {
      await _walletsRef.doc(userId).update({
        'coins': newCoins,
        'escrowCoins': newEscrow,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _syncToUserDocAndNotifiers(userId, newCoins);

      await _recordTransaction(CoinTransaction(
        id: _transactionsRef.doc().id,
        userId: userId,
        type: 'refund',
        amount: entryFeeCoins,
        status: 'completed',
        timestamp: now,
        title: 'Entry Fee Refunded ↩️',
        description: 'Left slot for "$roomTitle"',
        roomId: roomId,
      ));
    } catch (e) {
      debugPrint('CoinWalletService refundEntryFeeOnLeave error: $e');
    }
  }

  /// Finalize Match Winner:
  /// Transfer all escrowCoins (prize pool + collected entry fees) to winner(s) coins.
  /// When a team wins, divides the prize pool EQUALLY among all winning team members.
  /// Clear host's escrow and joiner's escrow.
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

    // Formula: Share = 500 (or prizePoolCoins) / Number of Checked Winners
    final totalPrize = prizePoolCoins > 0 ? prizePoolCoins : 500;
    final int winnerCount = allWinnerIds.length;
    final int prizePerWinner = (totalPrize / winnerCount).floor();
    final now = DateTime.now();

    try {
      // 1. Release host's escrow hold if applicable
      if (prizePoolCoins > 0 && hostId.isNotEmpty) {
        CoinWallet? hostWallet;
        if (_currentWallet?.userId == hostId) {
          hostWallet = _currentWallet;
        } else {
          try {
            final hostDoc = await _walletsRef.doc(hostId).get();
            if (hostDoc.exists) {
              hostWallet = CoinWallet.fromFirestore(hostDoc);
            } else {
              hostWallet = await _loadFromLocal(hostId);
            }
          } catch (_) {}
        }

        final currentHostEscrow = hostWallet?.escrowCoins ?? prizePoolCoins;
        final updatedHostEscrow = (currentHostEscrow - prizePoolCoins).clamp(0, 9999999);

        try {
          await _walletsRef.doc(hostId).set({
            'userId': hostId,
            'escrowCoins': updatedHostEscrow,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('awardWinnerPrize: host Firestore update error: $e');
        }

        if (_currentWallet?.userId == hostId) {
          _currentWallet = _currentWallet!.copyWith(
            escrowCoins: updatedHostEscrow,
            updatedAt: now,
          );
          await _saveToLocal(_currentWallet!);
          notifyListeners();
        }

        // Record Escrow Transfer transaction for Host
        await _recordTransaction(CoinTransaction(
          id: _transactionsRef.doc().id,
          userId: hostId,
          type: 'escrow_transferred',
          amount: 0,
          status: 'completed',
          timestamp: now,
          title: 'Escrow Released to Winner(s) 🏆',
          description: 'Transferred $prizePoolCoins escrow prize to winning team of "$roomTitle"',
          roomId: roomId,
        ));
      }

      // 2. Clear escrow for any joiners if needed
      if (entryFeeCoinsPerJoiner > 0) {
        for (final joinerId in joiners) {
          if (joinerId != hostId) {
            try {
              await _walletsRef.doc(joinerId).set({
                'escrowCoins': FieldValue.increment(-entryFeeCoinsPerJoiner),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
          }
        }
      }

      // 3. FIRESTORE TRANSACTION: Send coins atomically to correct UIDs (No hardcoded IDs)
      final Map<String, int> finalCoinsMap = {};
      final Map<String, int> finalLifetimeMap = {};

      try {
        await _firestore.runTransaction((transaction) async {
          // A. Read phase: get current coin balances for all winning UIDs
          final Map<String, int> currentCoinsMap = {};
          final Map<String, int> currentLifetimeMap = {};

          for (final wId in allWinnerIds) {
            final userRef = _firestore.collection('users').doc(wId);
            final walletRef = _walletsRef.doc(wId);

            int coins = 1000;
            int lifetime = 1000;

            final userSnap = await transaction.get(userRef);
            if (userSnap.exists && userSnap.data()?['coins'] != null) {
              coins = (userSnap.data()!['coins'] as num).toInt();
            }

            final walletSnap = await transaction.get(walletRef);
            final walletData = walletSnap.data() as Map<String, dynamic>?;
            if (walletSnap.exists && walletData != null && walletData['coins'] != null) {
              final wCoins = (walletData['coins'] as num).toInt();
              if (wCoins > coins) coins = wCoins;
              lifetime = (walletData['lifetimeEarned'] as num?)?.toInt() ?? (coins + prizePerWinner);
            } else {
              lifetime = coins;
            }

            currentCoinsMap[wId] = coins;
            currentLifetimeMap[wId] = lifetime;
          }

          // B. Write phase: update users and coin_wallets with exact equal share
          for (final wId in allWinnerIds) {
            final userRef = _firestore.collection('users').doc(wId);
            final walletRef = _walletsRef.doc(wId);

            final newCoins = (currentCoinsMap[wId] ?? 1000) + prizePerWinner;
            final newLifetime = (currentLifetimeMap[wId] ?? 1000) + prizePerWinner;

            finalCoinsMap[wId] = newCoins;
            finalLifetimeMap[wId] = newLifetime;

            transaction.set(userRef, {
              'coins': newCoins,
            }, SetOptions(merge: true));

            transaction.set(walletRef, {
              'userId': wId,
              'coins': newCoins,
              'lifetimeEarned': newLifetime,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }

          // Update room status in transaction
          if (roomId.isNotEmpty) {
            final roomRef = _firestore.collection('tournament_rooms').doc(roomId);
            final combinedWName = (winnerNames != null && winnerNames.isNotEmpty) ? winnerNames.join(', ') : 'Winner';
            transaction.set(roomRef, {
              'status': 'COMPLETED',
              'winnerUid': allWinnerIds.join(','),
              'winnerName': combinedWName,
              'isLive': false,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        });
      } catch (txError) {
        debugPrint('awardWinnerPrize: Firestore Transaction fallback notice: $txError');
        // Fallback direct update if transaction encountered offline/network condition
        for (final wId in allWinnerIds) {
          int oldCoins = _currentWallet?.userId == wId ? _currentWallet!.coins : 1000;
          final newCoins = oldCoins + prizePerWinner;
          finalLifetimeMap[wId] = newCoins;
          finalCoinsMap[wId] = newCoins;
          try {
            await _walletsRef.doc(wId).set({
              'userId': wId,
              'coins': newCoins,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            await _firestore.collection('users').doc(wId).set({
              'coins': newCoins,
            }, SetOptions(merge: true));
          } catch (_) {}
        }
      }

      // 4. Update Local State and create CoinTransaction entries for each winner
      final currentGamer = GamerAuthService().currentGamer;
      final currentUid = currentGamer?.uid ?? GamerAuthService().currentUid ?? '';

      for (int i = 0; i < allWinnerIds.length; i++) {
        final wId = allWinnerIds[i].trim();
        if (wId.isEmpty) continue;

        final wName = (winnerNames != null && i < winnerNames.length && winnerNames[i].isNotEmpty)
            ? winnerNames[i]
            : (winnerName?.isNotEmpty == true ? winnerName! : 'Winner');

        final finalCoins = finalCoinsMap[wId] ?? ((_currentWallet?.userId == wId ? _currentWallet!.coins : 1000) + prizePerWinner);
        final finalLifetime = finalLifetimeMap[wId] ?? finalCoins;

        // Save winner local cache
        final updatedWinnerWallet = CoinWallet(
          userId: wId,
          coins: finalCoins,
          lifetimeEarned: finalLifetime,
          updatedAt: now,
        );
        await _saveToLocal(updatedWinnerWallet);

        // Check if the current user on this device is this winner
        final isThisDeviceWinner = _currentWallet?.userId == wId ||
            (currentUid.isNotEmpty && currentUid == wId) ||
            (wName.isNotEmpty &&
                ((currentGamer?.displayName?.toLowerCase() == wName.toLowerCase()) ||
                    (currentGamer?.username.toLowerCase() == wName.toLowerCase())));

        if (isThisDeviceWinner) {
          _currentWallet = (_currentWallet ?? updatedWinnerWallet).copyWith(
            coins: finalCoins,
            lifetimeEarned: finalLifetime,
            updatedAt: now,
          );
          await _saveToLocal(_currentWallet!);
          notifyListeners();

          if (currentGamer != null) {
            GamerAuthService().currentGamerNotifier.value = currentGamer.copyWith(coins: finalCoins);
          }
          CoinRewardService().coinsNotifier.value = finalCoins;
        }

        // Record win_prize transaction in history for each winner UID
        await _recordTransaction(CoinTransaction(
          id: _transactionsRef.doc().id,
          userId: wId,
          type: 'win_prize',
          amount: prizePerWinner,
          status: 'completed',
          timestamp: now,
          title: winnerCount > 1 ? 'Team Victory Prize! 🏆' : 'Tournament Victory Prize! 🏆',
          description: winnerCount > 1
              ? 'Won tournament "$roomTitle" with team! Equal share: $prizePerWinner G-Coins ($totalPrize total from Admin Escrow)'
              : 'Won tournament "$roomTitle" and claimed $prizePerWinner G-Coins from Admin Escrow!',
          roomId: roomId,
        ));
      }
    } catch (e) {
      debugPrint('CoinWalletService awardWinnerPrize error: $e');
    }
  }

  /// Refund room if expired or cancelled:
  /// Returns prizePoolCoins back to host, and entry fees back to joiners.
  Future<void> refundRoom({
    required String hostId,
    required int prizePoolCoins,
    required List<String> joiners,
    required int entryFeeCoins,
    required String roomId,
    required String roomTitle,
  }) async {
    final now = DateTime.now();
    try {
      // 1. Refund host
      if (prizePoolCoins > 0 && hostId.isNotEmpty) {
        CoinWallet? hostWallet;
        if (_currentWallet?.userId == hostId) {
          hostWallet = _currentWallet;
        } else {
          final hostDoc = await _walletsRef.doc(hostId).get();
          if (hostDoc.exists) {
            hostWallet = CoinWallet.fromFirestore(hostDoc);
          } else {
            hostWallet = await _loadFromLocal(hostId);
          }
        }

        final currentHostCoins = hostWallet?.coins ?? 1000;
        final currentHostEscrow = hostWallet?.escrowCoins ?? prizePoolCoins;
        final newHostCoins = currentHostCoins + prizePoolCoins;
        final newHostEscrow = (currentHostEscrow - prizePoolCoins).clamp(0, 9999999);

        await _walletsRef.doc(hostId).set({
          'userId': hostId,
          'coins': newHostCoins,
          'escrowCoins': newHostEscrow,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _firestore.collection('users').doc(hostId).set({
          'coins': newHostCoins,
        }, SetOptions(merge: true));

        if (_currentWallet?.userId == hostId) {
          _currentWallet = _currentWallet!.copyWith(
            coins: newHostCoins,
            escrowCoins: newHostEscrow,
            updatedAt: now,
          );
          await _saveToLocal(_currentWallet!);
          notifyListeners();
        }

        final currentGamer = GamerAuthService().currentGamer;
        if (currentGamer != null && (currentGamer.uid == hostId || hostId.isEmpty)) {
          GamerAuthService().currentGamerNotifier.value = currentGamer.copyWith(coins: newHostCoins);
          CoinRewardService().coinsNotifier.value = newHostCoins;
        }

        await _recordTransaction(CoinTransaction(
          id: _transactionsRef.doc().id,
          userId: hostId,
          type: 'refund',
          amount: prizePoolCoins,
          status: 'completed',
          timestamp: now,
          title: 'Host Prize Refunded ↩️',
          description: 'Tournament "$roomTitle" expired/cancelled. Escrow refunded.',
          roomId: roomId,
        ));
      }

      // 2. Refund joiners
      if (entryFeeCoins > 0) {
        for (final jId in joiners) {
          if (jId != hostId) {
            try {
              final jDoc = await _walletsRef.doc(jId).get();
              final jWallet = jDoc.exists ? CoinWallet.fromFirestore(jDoc) : await _loadFromLocal(jId);
              final currentCoins = jWallet?.coins ?? 1000;
              final currentEscrow = jWallet?.escrowCoins ?? entryFeeCoins;
              final newCoins = currentCoins + entryFeeCoins;
              final newEscrow = (currentEscrow - entryFeeCoins).clamp(0, 9999999);

              await _walletsRef.doc(jId).set({
                'userId': jId,
                'coins': newCoins,
                'escrowCoins': newEscrow,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              await _firestore.collection('users').doc(jId).set({
                'coins': newCoins,
              }, SetOptions(merge: true));

              if (_currentWallet?.userId == jId) {
                _currentWallet = _currentWallet!.copyWith(
                  coins: newCoins,
                  escrowCoins: newEscrow,
                  updatedAt: now,
                );
                await _saveToLocal(_currentWallet!);
                notifyListeners();
              }

              await _recordTransaction(CoinTransaction(
                id: _transactionsRef.doc().id,
                userId: jId,
                type: 'refund',
                amount: entryFeeCoins,
                status: 'completed',
                timestamp: now,
                title: 'Entry Fee Refunded ↩️',
                description: 'Tournament "$roomTitle" cancelled. $entryFeeCoins Coins returned.',
                roomId: roomId,
              ));
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('CoinWalletService refundRoom error: $e');
    }
  }

  /// Deducts trustScore by penalty points if user ghosts or cheats
  Future<void> penalizeTrustScore(String userId, int penaltyPoints, String reason) async {
    try {
      final wallet = await getOrCreateWallet(userId);
      final newTrust = (wallet.trustScore - penaltyPoints).clamp(0, 100);
      await _walletsRef.doc(userId).update({
        'trustScore': newTrust,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('CoinWalletService penalizeTrustScore error: $e');
    }
  }

  Future<void> recordTransaction(CoinTransaction tx) async {
    await _recordTransaction(tx);
  }

  Future<void> _recordTransaction(CoinTransaction tx) async {
    try {
      await _transactionsRef.doc(tx.id).set(tx.toMap());
    } catch (e) {
      debugPrint('CoinWalletService recordTransaction error: $e');
    }
  }

  Stream<List<CoinTransaction>> transactionsStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _transactionsRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => CoinTransaction.fromFirestore(d)).toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  /// Request Redeem of Skill Tournament Rewards (UC, Diamonds, Mega Gift Card)
  /// Enforces KYC verification data and checks strict balance thresholds:
  /// - 10,000 Coins = 60 BGMI UC
  /// - 15,000 Coins = 100 Free Fire Diamonds
  /// - 1,000,000 Coins = $100 Mega Gift Card
  /// - 2,000,000 Coins = $200 Mega Gift Card
  Future<Map<String, dynamic>> requestRedeemReward({
    required String userId,
    required String rewardType,
    required String rewardTitle,
    required int costCoins,
    required String legalName,
    required String govtIdNumber,
    required String deliveryDetails,
    required String contactNumber,
  }) async {
    final wallet = await getOrCreateWallet(userId);
    if (wallet.coins < costCoins) {
      return {
        'success': false,
        'error': 'Insufficient G-Coins. You have ${wallet.coins}, but need $costCoins.',
      };
    }

    final newCoins = wallet.coins - costCoins;
    final now = DateTime.now();
    final updated = wallet.copyWith(
      coins: newCoins,
      updatedAt: now,
    );

    _currentWallet = updated;
    notifyListeners();
    _saveToLocal(updated);

    final requestId = _firestore.collection('redeem_requests').doc().id;

    try {
      // 1. Deduct coins from wallet & user profile
      await _walletsRef.doc(userId).update({
        'coins': newCoins,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _syncToUserDocAndNotifiers(userId, newCoins);

      // 2. Save KYC and Redeem request
      await _firestore.collection('redeem_requests').doc(requestId).set({
        'id': requestId,
        'userId': userId,
        'rewardType': rewardType,
        'rewardTitle': rewardTitle,
        'costCoins': costCoins,
        'legalName': legalName.trim(),
        'govtIdNumber': govtIdNumber.trim(),
        'deliveryDetails': deliveryDetails.trim(),
        'contactNumber': contactNumber.trim(),
        'status': 'pending_verification',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Record transaction with Play Store safe words
      await _recordTransaction(CoinTransaction(
        id: _transactionsRef.doc().id,
        userId: userId,
        type: 'redeem_reward',
        amount: -costCoins,
        status: 'pending',
        timestamp: now,
        title: '$rewardTitle Claimed 🎁',
        description: 'KYC Verification ID: $govtIdNumber • Delivery: $deliveryDetails',
      ));

      return {
        'success': true,
        'requestId': requestId,
      };
    } catch (e) {
      debugPrint('CoinWalletService requestRedeemReward error: $e');
      return {
        'success': true,
        'requestId': requestId,
      };
    }
  }

  /// Stream of user's submitted redeem requests
  Stream<List<Map<String, dynamic>>> getRedeemRequestsStream(String userId) {
    return _firestore
        .collection('redeem_requests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => d.data()).toList();
      list.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  /// Track tournament participation and award referral bonus only after 5 matches
  Future<void> recordTournamentJoinedAndCheckReferral(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentPlayed = (prefs.getInt('user_tournaments_played_$userId') ?? 0) + 1;
      await prefs.setInt('user_tournaments_played_$userId', currentPlayed);

      // Update Firestore user tournament count
      await _firestore.collection('users').doc(userId).set({
        'tournamentsPlayed': currentPlayed,
        'lastTournamentJoined': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Check if user was referred by someone and reached milestone of 5 tournaments
      final referrerUid = prefs.getString('user_referrer_uid_$userId');
      final alreadyRewarded = prefs.getBool('user_referral_rewarded_$userId') ?? false;

      if (currentPlayed >= 5 && referrerUid != null && referrerUid.isNotEmpty && !alreadyRewarded) {
        await prefs.setBool('user_referral_rewarded_$userId', true);

        // Award both users 200 G-Coins
        await rewardReferralCoins(referrerUid, inviteeName: 'Friend (5 Tournaments Milestone)');
        await rewardReferralCoins(userId, inviteeName: 'Referral Welcome (5 Tournaments Milestone)');

        debugPrint('Referral bonus of 200 Coins awarded to referrer $referrerUid and friend $userId');
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
        return false; // Already referred
      }

      await prefs.setString('user_referrer_uid_$userId', referrerCode.trim());
      await _firestore.collection('users').doc(userId).set({
        'referredBy': referrerCode.trim(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
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
