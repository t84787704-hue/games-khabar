// 100% Supabase Coin Wallet Model — Single Source of Truth via `g_coins` (synced with `coins`)

import 'dart:math';

class CoinWallet {
  final String userId;
  final int coins;
  final int escrowCoins;
  final int lifetimeEarned;
  final int lifetimeSpent;
  final int trustScore; // Default 100
  final DateTime? lastDailyBonusClaim;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoinWallet({
    required this.userId,
    this.coins = 0,
    this.escrowCoins = 0,
    this.lifetimeEarned = 0,
    this.lifetimeSpent = 0,
    this.trustScore = 100,
    this.lastDailyBonusClaim,
    this.createdAt,
    this.updatedAt,
  });

  int get gCoins => coins;
  int get balance => coins;
  int get currentBalance => coins;
  int get totalNetWorth => coins + escrowCoins;

  bool get canClaimDailyBonus {
    if (lastDailyBonusClaim == null) return true;
    final now = DateTime.now();
    return now.difference(lastDailyBonusClaim!).inHours >= 24;
  }

  Duration get nextDailyBonusDuration {
    if (lastDailyBonusClaim == null) return Duration.zero;
    final nextAvailable = lastDailyBonusClaim!.add(const Duration(hours: 24));
    final diff = nextAvailable.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  // Empty fallback wallet instance for initial UI rendering
  factory CoinWallet.empty(String userId, {int initialCoins = 0}) {
    return CoinWallet(
      userId: userId,
      coins: initialCoins,
      escrowCoins: 0,
      lifetimeEarned: initialCoins,
      lifetimeSpent: 0,
      trustScore: 100,
    );
  }

  factory CoinWallet.fromFirestore(dynamic doc) => CoinWallet.fromSupabase(doc);
  factory CoinWallet.fromSupabase(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return CoinWallet.fromMap(doc);
    }
    try {
      final data = (doc.data != null ? doc.data() : null) as Map<String, dynamic>? ?? {};
      return CoinWallet.fromMap(data, doc.id?.toString());
    } catch (_) {
      return CoinWallet.empty('');
    }
  }

  factory CoinWallet.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      try {
        if (val.toDate != null) return val.toDate();
      } catch (_) {}
      return null;
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val.trim());
      return null;
    }

    // Single source of truth: coin_wallets.g_coins (synced with coins)
    final int? rawGCoins = parseInt(data['g_coins']) ?? parseInt(data['gCoins']);
    final int? rawCoins = parseInt(data['coins']);
    final int resolvedBalance;
    if (rawGCoins != null && rawCoins != null) {
      // If one column was updated while the other lagged, prefer the non-zero / larger synced balance
      resolvedBalance = rawGCoins == rawCoins ? rawGCoins : max(rawGCoins, rawCoins);
    } else {
      resolvedBalance = rawGCoins ?? rawCoins ?? 0;
    }

    final int parsedEarned =
        parseInt(data['lifetime_earned']) ?? parseInt(data['lifetimeEarned']) ?? resolvedBalance;
    final int parsedSpent =
        parseInt(data['lifetime_spent']) ?? parseInt(data['lifetimeSpent']) ?? 0;

    return CoinWallet(
      userId: (data['user_id'] ?? data['userId'] ?? id ?? '').toString(),
      coins: resolvedBalance,
      escrowCoins: parseInt(data['escrow_coins']) ?? parseInt(data['escrowCoins']) ?? 0,
      lifetimeEarned: parsedEarned,
      lifetimeSpent: parsedSpent,
      trustScore: parseInt(data['trust_score']) ?? parseInt(data['trustScore']) ?? 100,
      lastDailyBonusClaim:
          parseDate(data['lastDailyBonusClaim'] ?? data['last_daily_bonus_claim']),
      createdAt: parseDate(data['createdAt'] ?? data['created_at']),
      updatedAt: parseDate(data['updatedAt'] ?? data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    final nowIso = DateTime.now().toIso8601String();
    return {
      'userId': userId,
      'user_id': userId,
      'coins': coins,
      'g_coins': coins,
      'escrowCoins': escrowCoins,
      'escrow_coins': escrowCoins,
      'lifetimeEarned': lifetimeEarned,
      'lifetime_earned': lifetimeEarned,
      'lifetimeSpent': lifetimeSpent,
      'lifetime_spent': lifetimeSpent,
      'trustScore': trustScore,
      'trust_score': trustScore,
      'lastDailyBonusClaim': lastDailyBonusClaim?.toIso8601String(),
      'last_daily_bonus_claim': lastDailyBonusClaim?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String() ?? nowIso,
      'created_at': createdAt?.toIso8601String() ?? nowIso,
      'updatedAt': nowIso,
      'updated_at': nowIso,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'user_id': userId,
      'coins': coins,
      'g_coins': coins,
      'escrowCoins': escrowCoins,
      'lifetimeEarned': lifetimeEarned,
      'lifetimeSpent': lifetimeSpent,
      'trustScore': trustScore,
      'lastDailyBonusClaim': lastDailyBonusClaim?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  CoinWallet copyWith({
    String? userId,
    int? coins,
    int? escrowCoins,
    int? lifetimeEarned,
    int? lifetimeSpent,
    int? trustScore,
    DateTime? lastDailyBonusClaim,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoinWallet(
      userId: userId ?? this.userId,
      coins: coins ?? this.coins,
      escrowCoins: escrowCoins ?? this.escrowCoins,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lifetimeSpent: lifetimeSpent ?? this.lifetimeSpent,
      trustScore: trustScore ?? this.trustScore,
      lastDailyBonusClaim: lastDailyBonusClaim ?? this.lastDailyBonusClaim,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
