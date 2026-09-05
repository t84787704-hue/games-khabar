import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PriceService {
  static final PriceService _instance = PriceService._internal();
  factory PriceService() => _instance;
  PriceService._internal();

  static const double pkrExchangeRate = 280.0;

  static const List<String> paidGames = [
    'GTA VI',
    'Elden Ring',
    'Cyberpunk 2077',
    'God of War',
    'EA Sports FC',
    'Call of Duty',
    'Tekken 8',
    'Counter-Strike 2',
    'Palworld',
    'Helldivers 2',
    'Minecraft',
    'Apex Legends',
    'Genshin Impact',
  ];

  static const List<String> freeGames = [
    'BGMI',
    'PUBG',
    'Free Fire',
    'Valorant',
    'Fortnite',
    'Roblox',
    'Fall Guys',
  ];

  String? _cachedUserId;

  Future<String> getUserId() async {
    if (_cachedUserId != null && _cachedUserId!.isNotEmpty) {
      return _cachedUserId!;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.uid.isNotEmpty) {
      _cachedUserId = authUser.uid;
      return _cachedUserId!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? localId = prefs.getString('local_price_user_id');
    if (localId == null || localId.isEmpty) {
      localId = 'user_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
      await prefs.setString('local_price_user_id', localId);
    }
    _cachedUserId = localId;
    return localId;
  }

  String getGameDocId(String gameName) {
    return gameName.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');
  }

  bool isPaidGame(String gameName) {
    final lower = gameName.toLowerCase().trim();

    // Explicitly exclude free games
    for (final fg in freeGames) {
      if (lower.contains(fg.toLowerCase())) return false;
    }

    // Check paid games list
    for (final pg in paidGames) {
      if (lower.contains(pg.toLowerCase()) || pg.toLowerCase().contains(lower)) {
        return true;
      }
    }
    return false;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamGamePrice(String gameName) {
    final docId = getGameDocId(gameName);
    return FirebaseFirestore.instance
        .collection('game_prices')
        .doc(docId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserAlert(String gameName, String userId) {
    final gameId = getGameDocId(gameName);
    final alertDocId = '${userId}_$gameId';
    return FirebaseFirestore.instance
        .collection('user_price_alerts')
        .doc(alertDocId)
        .snapshots();
  }

  Future<void> setPriceAlert({
    required String gameName,
    required int targetPricePKR,
    double? currentPriceUSD,
  }) async {
    final userId = await getUserId();
    final gameId = getGameDocId(gameName);
    final alertDocId = '${userId}_$gameId';
    final targetPriceUSD = (targetPricePKR / pkrExchangeRate);

    await FirebaseFirestore.instance
        .collection('user_price_alerts')
        .doc(alertDocId)
        .set({
      'userId': userId,
      'gameName': gameName,
      'targetPricePKR': targetPricePKR,
      'targetPriceUSD': double.parse(targetPriceUSD.toStringAsFixed(2)),
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('[PriceService] Alert created for $gameName at Rs. $targetPricePKR ($targetPriceUSD USD)');
  }
}
