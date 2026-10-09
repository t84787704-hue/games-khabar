// 100% Supabase Coin Wallet Model

class CoinWallet {
  final String userId;
  final int coins;
  final int escrowCoins;
  final int lifetimeEarned;
  final int trustScore; // Default 100
  final DateTime? lastDailyBonusClaim;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoinWallet({
    required this.userId,
    this.coins = 1000,
    this.escrowCoins = 0,
    this.lifetimeEarned = 1000,
    this.trustScore = 100,
    this.lastDailyBonusClaim,
    this.createdAt,
    this.updatedAt,
  });

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
  factory CoinWallet.empty(String userId) {
    return CoinWallet(
      userId: userId,
      coins: 1000,
      escrowCoins: 0,
      lifetimeEarned: 1000,
      trustScore: 100,
    );
  }

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

    return CoinWallet(
      userId: data['userId'] ?? data['user_id'] ?? id ?? '',
      coins: (data['coins'] as num?)?.toInt() ?? 1000,
      escrowCoins: (data['escrowCoins'] ?? data['escrow_coins'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (data['lifetimeEarned'] ?? data['lifetime_earned'] as num?)?.toInt() ?? 1000,
      trustScore: (data['trustScore'] ?? data['trust_score'] as num?)?.toInt() ?? 100,
      lastDailyBonusClaim: parseDate(data['lastDailyBonusClaim'] ?? data['last_daily_bonus_claim']),
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
      'escrowCoins': escrowCoins,
      'escrow_coins': escrowCoins,
      'lifetimeEarned': lifetimeEarned,
      'lifetime_earned': lifetimeEarned,
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
      'coins': coins,
      'escrowCoins': escrowCoins,
      'lifetimeEarned': lifetimeEarned,
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
      trustScore: trustScore ?? this.trustScore,
      lastDailyBonusClaim: lastDailyBonusClaim ?? this.lastDailyBonusClaim,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
