import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coin_wallet_model.dart';
import '../models/coin_transaction_model.dart';
import 'gamer_auth_service.dart';

class CoinWalletService extends ChangeNotifier {
  static final CoinWalletService _instance = CoinWalletService._internal();
  factory CoinWalletService() => _instance;
  CoinWalletService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _walletsRef => _firestore.collection('coin_wallets');
  CollectionReference get _transactionsRef => _firestore.collection('coin_transactions');

  // Cached active user wallet
  CoinWallet? _currentWallet;
  CoinWallet? get currentWallet => _currentWallet;

  StreamSubscription<DocumentSnapshot>? _walletSub;

  /// Initialize or fetch wallet for active user. Grants 1,000 Free G-Coins if new.
  Future<CoinWallet> getOrCreateWallet(String userId) async {
    if (userId.isEmpty) {
      return const CoinWallet(userId: 'guest', coins: 1000);
    }

    try {
      final docRef = _walletsRef.doc(userId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Initial balance for every new user: 1000 G-Coins free
        final newWallet = CoinWallet(
          userId: userId,
          coins: 1000,
          escrowCoins: 0,
          lifetimeEarned: 1000,
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
          amount: 1000,
          status: 'completed',
          timestamp: DateTime.now(),
          title: 'Welcome Bonus 🎁',
          description: 'Free 1,000 G-Coins on joining My Gamer ID!',
        ));

        _currentWallet = newWallet;
        _saveToLocal(newWallet);
        notifyListeners();
        _listenToWallet(userId);
        return newWallet;
      } else {
        final existingWallet = CoinWallet.fromFirestore(doc);
        _currentWallet = existingWallet;
        _saveToLocal(existingWallet);
        notifyListeners();
        _listenToWallet(userId);
        return existingWallet;
      }
    } catch (e) {
      debugPrint('CoinWalletService: getOrCreateWallet error: $e. Falling back to local cache.');
      final local = await _loadFromLocal(userId);
      if (local != null) {
        _currentWallet = local;
        notifyListeners();
        return local;
      }
      final fallback = CoinWallet(userId: userId, coins: 1000);
      _currentWallet = fallback;
      notifyListeners();
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

  /// Claim Daily 100 G-Coins bonus every 24h
  Future<bool> claimDailyBonus(String userId) async {
    final wallet = await getOrCreateWallet(userId);
    if (!wallet.canClaimDailyBonus) {
      return false;
    }

    final newCoins = wallet.coins + 100;
    final newLifetime = wallet.lifetimeEarned + 100;
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
        amount: 100,
        status: 'completed',
        timestamp: now,
        title: 'Daily Bonus Claimed 📅',
        description: 'Claimed +100 G-Coins daily check-in reward.',
      ));
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
  /// Transfer all escrowCoins (prize pool + collected entry fees) to winner's coins.
  /// Clear host's escrow and joiner's escrow.
  Future<void> awardWinnerPrize({
    required String hostId,
    required String winnerId,
    required int prizePoolCoins,
    required int totalEntryFees,
    required List<String> joiners,
    required int entryFeeCoinsPerJoiner,
    required String roomId,
    required String roomTitle,
    String? winnerName,
  }) async {
    final totalPrize = prizePoolCoins + totalEntryFees;
    final now = DateTime.now();

    try {
      // 1. Release host's escrow hold
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
      }

      // 2. Clear escrow for any joiners who paid entry fee
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

      // 3. Credit Winner with totalPrize in Firestore & Local
      int winnerOldCoins = 1000;
      int winnerOldLifetime = 1000;

      if (_currentWallet?.userId == winnerId) {
        winnerOldCoins = _currentWallet!.coins;
        winnerOldLifetime = _currentWallet!.lifetimeEarned;
      } else {
        try {
          final winnerDoc = await _walletsRef.doc(winnerId).get();
          if (winnerDoc.exists) {
            final w = CoinWallet.fromFirestore(winnerDoc);
            winnerOldCoins = w.coins;
            winnerOldLifetime = w.lifetimeEarned;
          } else {
            final local = await _loadFromLocal(winnerId);
            if (local != null) {
              winnerOldCoins = local.coins;
              winnerOldLifetime = local.lifetimeEarned;
            }
          }
        } catch (_) {}
      }

      final newCoins = winnerOldCoins + totalPrize;
      final newLifetime = winnerOldLifetime + totalPrize;

      // Update Firestore 'coin_wallets' collection
      await _walletsRef.doc(winnerId).set({
        'userId': winnerId,
        'coins': newCoins,
        'lifetimeEarned': newLifetime,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update Firestore 'users' collection
      await _firestore.collection('users').doc(winnerId).set({
        'coins': newCoins,
      }, SetOptions(merge: true));

      // Save winner local cache
      final updatedWinnerWallet = CoinWallet(
        userId: winnerId,
        coins: newCoins,
        lifetimeEarned: newLifetime,
        updatedAt: now,
      );
      await _saveToLocal(updatedWinnerWallet);

      // Check if the current user on this device is the winner
      final currentGamer = GamerAuthService().currentGamer;
      final currentUid = currentGamer?.uid ?? GamerAuthService().currentUid ?? '';
      final isCurrentWinner = _currentWallet?.userId == winnerId ||
          (currentUid.isNotEmpty && currentUid == winnerId) ||
          (winnerName != null &&
              winnerName.isNotEmpty &&
              ((currentGamer?.displayName?.toLowerCase() == winnerName.toLowerCase()) ||
                  (currentGamer?.username.toLowerCase() == winnerName.toLowerCase()) ||
                  (winnerName.toLowerCase() == 'ii' &&
                      (currentGamer?.displayName?.toLowerCase() == 'ii' ||
                          currentGamer?.username.toLowerCase() == 'ii'))));

      if (isCurrentWinner) {
        _currentWallet = (_currentWallet ?? updatedWinnerWallet).copyWith(
          coins: newCoins,
          lifetimeEarned: newLifetime,
          updatedAt: now,
        );
        await _saveToLocal(_currentWallet!);
        notifyListeners();

        if (currentGamer != null) {
          GamerAuthService().currentGamerNotifier.value = currentGamer.copyWith(coins: newCoins);
        }
      }

      // 4. Record win_prize transaction
      await _recordTransaction(CoinTransaction(
        id: _transactionsRef.doc().id,
        userId: winnerId,
        type: 'win_prize',
        amount: totalPrize,
        status: 'completed',
        timestamp: now,
        title: 'Tournament Victory Prize! 🏆',
        description: 'Won tournament "$roomTitle" and claimed $totalPrize G-Coins!',
        roomId: roomId,
      ));
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
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CoinTransaction.fromFirestore(d)).toList());
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
