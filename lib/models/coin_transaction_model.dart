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

    final userId = data['userId'] ?? data['to'] ?? data['from'] ?? '';
    final type = data['type'] ?? 'admin_bonus';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;

    String title = (data['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) {
      switch (type) {
        case 'win_reward':
        case 'win_prize':
          title = 'Match Victory Reward 🏆';
          break;
        case 'room_host_hold':
          title = 'Room Prize Held 🔒';
          break;
        case 'entry_fee':
          title = 'Room Entry Fee 🎮';
          break;
        case 'refund':
          title = 'Coins Refunded ↩️';
          break;
        case 'ad_reward':
          title = 'Watch Ad Reward 📺';
          break;
        case 'daily_bonus':
        case 'daily_login':
          title = 'Daily Login Bonus 📅';
          break;
        case 'news_read':
          title = 'Gaming News Read 📰';
          break;
        case 'post_created':
          title = 'Community Post ✍️';
          break;
        case 'helpful_received':
          title = 'Helpful Upvote 🌟';
          break;
        case 'referral':
          title = 'Friend Referral 🤝';
          break;
        case 'admin_bonus':
          title = 'Welcome Bonus 🎁';
          break;
        default:
          title = amount >= 0 ? 'Coins Added 🪙' : 'Coins Deducted 🪙';
      }
    }

    String description = (data['description'] as String?)?.trim() ?? '';
    if (description.isEmpty) {
      if (amount > 0) {
        description = '+$amount Coins added to your wallet';
      } else if (amount < 0) {
        description = '${amount.abs()} Coins deducted from your wallet';
      } else {
        description = 'Coin activity recorded';
      }
    }

    return CoinTransaction(
      id: data['id'] ?? id ?? '',
      userId: userId,
      type: type,
      amount: amount,
      status: data['status'] ?? 'completed',
      timestamp: time,
      title: title,
      description: description,
      roomId: data['roomId'] ?? data['squadId'],
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
