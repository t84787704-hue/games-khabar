// ===============================================================================
// SHARED WALLET REPOSITORY — Single Source of Truth for User's Live G-Coins Balance
// - Backed by Supabase `public.coin_wallets` (`g_coins` synced with `coins`)
// - Exposes a shared reactive `gCoinsBalance` (ValueNotifier<int> / Stream<int>)
//   observed across Coin Store, Earn G-Coins, Coin Passbook, Settings, and Profile.
// ===============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coin_wallet_model.dart';
import 'gamer_auth_service.dart';
import 'supabase_service.dart';

class WalletRepository extends ChangeNotifier {
  static final WalletRepository instance = WalletRepository._internal();
  factory WalletRepository() => instance;
  WalletRepository._internal();

  /// Shared reactive G-Coins balance observed by Coin Store, Earn G-Coins,
  /// Coin Passbook, Settings & Preferences, and Profile.
  final ValueNotifier<int> gCoinsBalance = ValueNotifier<int>(0);

  /// Shared reactive CoinWallet state
  final ValueNotifier<CoinWallet?> walletNotifier = ValueNotifier<CoinWallet?>(null);

  final StreamController<int> _gCoinsStreamController =
      StreamController<int>.broadcast();

  Stream<int> get gCoinsStream => _gCoinsStreamController.stream;

  int get currentGCoins => gCoinsBalance.value;

  String _activeUserId = '';
  bool _isSyncing = false;
  DateTime? _lastRemoteFetchAt;

  String resolveActiveUserId([String? explicitUserId]) {
    if (explicitUserId != null && explicitUserId.trim().isNotEmpty) {
      return explicitUserId.trim();
    }
    final authUid = GamerAuthService().currentUid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid.trim();
    final supaUid = SupabaseService.client.auth.currentUser?.id;
    if (supaUid != null && supaUid.trim().isNotEmpty) return supaUid.trim();
    final gamerUid = GamerAuthService().currentGamer?.uid;
    if (gamerUid != null && gamerUid.trim().isNotEmpty) return gamerUid.trim();
    return _activeUserId;
  }

  /// Immediately updates the shared live G-Coins state across all screens.
  void publishLiveBalance(
    int newGCoins, {
    String? userId,
    CoinWallet? wallet,
  }) {
    final sanitized = newGCoins.clamp(0, 999999999);
    final uid = resolveActiveUserId(userId);
    if (uid.isNotEmpty) {
      _activeUserId = uid;
    }

    if (wallet != null) {
      final syncedWallet = wallet.coins == sanitized
          ? wallet
          : wallet.copyWith(coins: sanitized, updatedAt: DateTime.now());
      walletNotifier.value = syncedWallet;
      _cacheWalletLocally(syncedWallet);
    } else if (walletNotifier.value != null) {
      final updated = walletNotifier.value!.copyWith(
        coins: sanitized,
        updatedAt: DateTime.now(),
      );
      walletNotifier.value = updated;
      _cacheWalletLocally(updated);
    }

    if (gCoinsBalance.value != sanitized) {
      gCoinsBalance.value = sanitized;
    }
    if (!_gCoinsStreamController.isClosed) {
      _gCoinsStreamController.add(sanitized);
    }

    try {
      final currentGamer = GamerAuthService().currentGamer;
      if (currentGamer != null &&
          (uid.isEmpty ||
              currentGamer.uid == uid ||
              SupabaseService.toUuid(currentGamer.uid) ==
                  SupabaseService.toUuid(uid)) &&
          currentGamer.coins != sanitized) {
        GamerAuthService().currentGamerNotifier.value =
            currentGamer.copyWith(coins: sanitized);
      }
    } catch (_) {}

    notifyListeners();
  }

  /// Fetches the authoritative `g_coins` balance from `public.coin_wallets`
  /// (and reconciles with `coin_transactions` if `coin_wallets` lagged behind).
  Future<int> refreshForCurrentUser({
    String? userId,
    bool force = false,
  }) async {
    final uid = resolveActiveUserId(userId);
    if (uid.isEmpty) return gCoinsBalance.value;

    if (!force &&
        _activeUserId == uid &&
        _lastRemoteFetchAt != null &&
        DateTime.now().difference(_lastRemoteFetchAt!).inSeconds < 3 &&
        gCoinsBalance.value > 0) {
      return gCoinsBalance.value;
    }

    _activeUserId = uid;

    // 1. Seed from local cache if current balance is still 0
    if (gCoinsBalance.value <= 0) {
      final cached = await _loadCachedWallet(uid);
      if (cached != null && cached.coins > 0) {
        publishLiveBalance(cached.coins, userId: uid, wallet: cached);
      }
    }

    try {
      final wallet = await fetchOrSyncWalletFromSupabase(uid);
      _lastRemoteFetchAt = DateTime.now();
      publishLiveBalance(wallet.coins, userId: uid, wallet: wallet);
      return wallet.coins;
    } catch (e) {
      debugPrint('[WalletRepository] refreshForCurrentUser error: $e');
      return gCoinsBalance.value;
    }
  }

  /// Reads `public.coin_wallets` by `user_id` (`g_coins` as primary source of truth),
  /// verifies against `coin_transactions` ledger so stale rows (e.g. 125 vs 13,965)
  /// are healed automatically, and keeps `coin_wallets.g_coins`, `coin_wallets.coins`,
  /// and `users.coins` in sync.
  Future<CoinWallet> fetchOrSyncWalletFromSupabase(String userId) async {
    final cleanUid = userId.trim();
    final uuidUid = SupabaseService.toUuid(cleanUid);

    Map<String, dynamic>? walletRow;

    // Query `public.coin_wallets` by `user_id` (avoiding non-existent `id` column filter errors)
    try {
      walletRow = await SupabaseService.client
          .from('coin_wallets')
          .select()
          .eq('user_id', cleanUid)
          .limit(1)
          .maybeSingle();
    } catch (_) {}

    if (walletRow == null && uuidUid != cleanUid) {
      try {
        walletRow = await SupabaseService.client
            .from('coin_wallets')
            .select()
            .eq('user_id', uuidUid)
            .limit(1)
            .maybeSingle();
      } catch (_) {}
    }

    DateTime? localDailyClaim = await _loadLocalDailyBonusClaim(cleanUid);

    int walletGCoins = 0;
    int walletCoins = 0;
    int escrowCoins = 0;
    int lifetimeEarned = 0;
    int lifetimeSpent = 0;
    int trustScore = 100;
    DateTime? remoteDailyClaim;

    if (walletRow != null) {
      final parsed = CoinWallet.fromMap(walletRow, cleanUid);
      walletGCoins = (walletRow['g_coins'] as num?)?.toInt() ?? parsed.coins;
      walletCoins = (walletRow['coins'] as num?)?.toInt() ?? parsed.coins;
      escrowCoins = parsed.escrowCoins;
      lifetimeEarned = parsed.lifetimeEarned;
      lifetimeSpent = parsed.lifetimeSpent;
      trustScore = parsed.trustScore;
      remoteDailyClaim = parsed.lastDailyBonusClaim;
    }

    // Check `coin_transactions` ledger net balance so if `coin_wallets` missed an earlier update
    // (such as an admin grant or failed upsert), we reconcile to the accurate ledger balance.
    int? ledgerBalance;
    int ledgerEarned = 0;
    int ledgerSpent = 0;
    try {
      final dynamic txRows = await SupabaseService.client
          .from('coin_transactions')
          .select('amount')
          .or('user_id.eq.$cleanUid,user_id.eq.$uuidUid');
      if (txRows is List && txRows.isNotEmpty) {
        for (final r in txRows) {
          final amt = (r['amount'] as num?)?.toInt() ?? 0;
          if (amt > 0) {
            ledgerEarned += amt;
          } else if (amt < 0) {
            ledgerSpent += amt.abs();
          }
        }
        if (ledgerEarned > 0 || ledgerSpent > 0) {
          ledgerBalance = (ledgerEarned - ledgerSpent).clamp(0, 999999999);
        }
      }
    } catch (_) {}

    // Also check `users.coins` only if both `coin_wallets` and `coin_transactions` are empty
    int userTableCoins = 0;
    if (walletRow == null && ledgerBalance == null) {
      try {
        final userRow = await SupabaseService.client
            .from('users')
            .select('coins')
            .or('id.eq.$cleanUid,uid.eq.$cleanUid')
            .limit(1)
            .maybeSingle();
        if (userRow != null) {
          userTableCoins = (userRow['coins'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}
    }

    int authoritativeGCoins;
    bool needsBackendHeal = false;

    if (walletRow != null) {
      // `coin_wallets.g_coins` is the primary source of truth, synced with `coins`
      authoritativeGCoins = walletGCoins > 0
          ? walletGCoins
          : (walletCoins > 0 ? walletCoins : 0);
      if (walletGCoins != walletCoins) {
        authoritativeGCoins = max(walletGCoins, walletCoins);
        needsBackendHeal = true;
      }
      // If transaction ledger exists and differs from a stale coin_wallets row (e.g., 13,965 vs 125),
      // heal coin_wallets.g_coins and coins to match the transaction ledger.
      if (ledgerBalance != null &&
          ledgerBalance > 0 &&
          authoritativeGCoins != ledgerBalance) {
        authoritativeGCoins = ledgerBalance;
        lifetimeEarned = max(lifetimeEarned, ledgerEarned);
        lifetimeSpent = max(lifetimeSpent, ledgerSpent);
        needsBackendHeal = true;
      }
    } else if (ledgerBalance != null) {
      authoritativeGCoins = ledgerBalance;
      lifetimeEarned = ledgerEarned;
      lifetimeSpent = ledgerSpent;
      needsBackendHeal = true;
    } else {
      authoritativeGCoins = userTableCoins > 0 ? userTableCoins : 1000;
      lifetimeEarned = authoritativeGCoins;
      needsBackendHeal = true;
    }

    final effectiveDailyClaim = remoteDailyClaim ?? localDailyClaim;

    final resolvedWallet = CoinWallet(
      userId: cleanUid,
      coins: authoritativeGCoins,
      escrowCoins: escrowCoins,
      lifetimeEarned: max(lifetimeEarned, authoritativeGCoins),
      lifetimeSpent: lifetimeSpent,
      trustScore: trustScore,
      lastDailyBonusClaim: effectiveDailyClaim,
      updatedAt: DateTime.now(),
    );

    publishLiveBalance(
      authoritativeGCoins,
      userId: cleanUid,
      wallet: resolvedWallet,
    );

    if (needsBackendHeal) {
      unawaited(
        persistWalletToSupabase(
          userId: cleanUid,
          gCoins: authoritativeGCoins,
          escrowCoins: escrowCoins,
          lifetimeEarned: resolvedWallet.lifetimeEarned,
          lifetimeSpent: resolvedWallet.lifetimeSpent,
          trustScore: trustScore,
        ),
      );
    }

    return resolvedWallet;
  }

  /// Writes `g_coins` and `coins` cleanly to `public.coin_wallets` (using `user_id` schema columns)
  /// and syncs `coins` to `public.users`.
  Future<void> persistWalletToSupabase({
    required String userId,
    required int gCoins,
    int? escrowCoins,
    int? lifetimeEarned,
    int? lifetimeSpent,
    int? trustScore,
    DateTime? lastDailyBonusClaim,
  }) async {
    final cleanUid = userId.trim();
    if (cleanUid.isEmpty || _isSyncing) return;
    _isSyncing = true;

    try {
      final currentW = walletNotifier.value;
      final int safeCoins = gCoins.clamp(0, 999999999);
      final int safeEscrow = escrowCoins ?? currentW?.escrowCoins ?? 0;
      final int safeEarned =
          lifetimeEarned ?? currentW?.lifetimeEarned ?? safeCoins;
      final int safeSpent = lifetimeSpent ?? currentW?.lifetimeSpent ?? 0;
      final int safeTrust = trustScore ?? currentW?.trustScore ?? 100;

      if (lastDailyBonusClaim != null) {
        await _saveLocalDailyBonusClaim(cleanUid, lastDailyBonusClaim);
      }

      // Core schema payload for `public.coin_wallets`:
      // user_id, coins, g_coins, escrow_coins, lifetime_earned, lifetime_spent, trust_score
      final Map<String, dynamic> coreWalletPayload = {
        'user_id': cleanUid,
        'g_coins': safeCoins,
        'coins': safeCoins,
        'escrow_coins': safeEscrow,
        'lifetime_earned': safeEarned,
        'lifetime_spent': safeSpent,
        'trust_score': safeTrust,
      };

      bool walletSaved = false;

      // 1. Try updating existing row in `public.coin_wallets` by `user_id`
      try {
        final List<dynamic> updated = await SupabaseService.client
            .from('coin_wallets')
            .update(coreWalletPayload)
            .eq('user_id', cleanUid)
            .select('user_id');
        if (updated.isNotEmpty) {
          walletSaved = true;
        }
      } catch (e) {
        debugPrint('[WalletRepository] coin_wallets update by user_id notice: $e');
      }

      // 2. Also try UUID form of `user_id` if row was stored under UUID
      final String uuidUid = SupabaseService.toUuid(cleanUid);
      if (!walletSaved && uuidUid != cleanUid) {
        try {
          final List<dynamic> updatedUuid = await SupabaseService.client
              .from('coin_wallets')
              .update({
                ...coreWalletPayload,
                'user_id': uuidUid,
              })
              .eq('user_id', uuidUid)
              .select('user_id');
          if (updatedUuid.isNotEmpty) {
            walletSaved = true;
          }
        } catch (_) {}
      }

      // 3. If no existing row matched, upsert on `user_id` (or insert)
      if (!walletSaved) {
        try {
          await SupabaseService.client
              .from('coin_wallets')
              .upsert(coreWalletPayload, onConflict: 'user_id');
          walletSaved = true;
        } catch (_) {
          try {
            await SupabaseService.client
                .from('coin_wallets')
                .insert(coreWalletPayload);
            walletSaved = true;
          } catch (e) {
            debugPrint('[WalletRepository] coin_wallets insert fallback error: $e');
          }
        }
      }

      // 4. Sync `coins` to `public.users` safely (update `coins` alone first so missing `g_coins` on `users` never fails)
      try {
        await SupabaseService.client
            .from('users')
            .update({'coins': safeCoins})
            .or('id.eq.$cleanUid,uid.eq.$cleanUid');
      } catch (e) {
        debugPrint('[WalletRepository] users.coins sync notice: $e');
      }
      // Best-effort optional `g_coins` update on `users` if that column exists
      try {
        await SupabaseService.client
            .from('users')
            .update({'g_coins': safeCoins})
            .or('id.eq.$cleanUid,uid.eq.$cleanUid');
      } catch (_) {}
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _cacheWalletLocally(CoinWallet wallet) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_wallet_${wallet.userId}',
        jsonEncode(wallet.toJson()),
      );
    } catch (_) {}
  }

  Future<CoinWallet?> _loadCachedWallet(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('cached_wallet_$userId');
      if (str != null && str.isNotEmpty) {
        final w = CoinWallet.fromMap(jsonDecode(str), userId);
        final savedClaim = await _loadLocalDailyBonusClaim(userId);
        if (savedClaim != null && w.lastDailyBonusClaim == null) {
          return w.copyWith(lastDailyBonusClaim: savedClaim);
        }
        return w;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveLocalDailyBonusClaim(String userId, DateTime claimedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'last_daily_bonus_claim_$userId',
        claimedAt.toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  Future<DateTime?> _loadLocalDailyBonusClaim(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('last_daily_bonus_claim_$userId');
      if (raw != null && raw.isNotEmpty) {
        return DateTime.tryParse(raw);
      }
    } catch (_) {}
    return null;
  }
}
