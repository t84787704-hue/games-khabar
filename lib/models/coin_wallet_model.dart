import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory CoinWallet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CoinWallet.fromMap(data, doc.id);
  }

  factory CoinWallet.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CoinWallet(
      userId: data['userId'] ?? id ?? '',
      coins: (data['coins'] as num?)?.toInt() ?? 1000,
      escrowCoins: (data['escrowCoins'] as num?)?.toInt() ?? 0,
      lifetimeEarned: (data['lifetimeEarned'] as num?)?.toInt() ?? 1000,
      trustScore: (data['trustScore'] as num?)?.toInt() ?? 100,
      lastDailyBonusClaim: parseDate(data['lastDailyBonusClaim']),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'coins': coins,
      'escrowCoins': escrowCoins,
      'lifetimeEarned': lifetimeEarned,
      'trustScore': trustScore,
      'lastDailyBonusClaim': lastDailyBonusClaim != null ? Timestamp.fromDate(lastDailyBonusClaim!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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
