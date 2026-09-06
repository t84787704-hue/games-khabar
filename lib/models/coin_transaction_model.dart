import 'package:cloud_firestore/cloud_firestore.dart';

class CoinTransaction {
  final String id;
  final String userId;
  final String type; // 'daily_bonus', 'ad_reward', 'room_host_hold', 'entry_fee', 'win_prize', 'refund', 'admin_bonus', 'referral'
  final int amount; // positive for income, negative for expense/escrow hold
  final String status; // 'completed', 'pending', 'refunded'
  final DateTime timestamp;
  final String title;
  final String description;
  final String? roomId;

  const CoinTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.status = 'completed',
    required this.timestamp,
    required this.title,
    this.description = '',
    this.roomId,
  });

  bool get isCredit => amount > 0;

  factory CoinTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CoinTransaction.fromMap(data, doc.id);
  }

  factory CoinTransaction.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime time = DateTime.now();
    final rawTime = data['timestamp'];
    if (rawTime is Timestamp) {
      time = rawTime.toDate();
    } else if (rawTime is String) {
      time = DateTime.tryParse(rawTime) ?? time;
    }

    return CoinTransaction(
      id: data['id'] ?? id ?? '',
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'admin_bonus',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'completed',
      timestamp: time,
      title: data['title'] ?? 'Transaction',
      description: data['description'] ?? '',
      roomId: data['roomId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'amount': amount,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'title': title,
      'description': description,
      'roomId': roomId,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'amount': amount,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'title': title,
      'description': description,
      'roomId': roomId,
    };
  }
}
