import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

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
    final authUser = SupabaseService.client.auth.currentUser;
    if (authUser != null && authUser.id.isNotEmpty) {
      _cachedUserId = authUser.id;
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

  Stream<Map<String, dynamic>?> streamGamePrice(String gameName) async* {
    final docId = getGameDocId(gameName);
    try {
      final initial = await SupabaseService.client
          .from('game_prices')
          .select()
          .eq('id', docId)
          .maybeSingle();
      yield initial;
    } catch (_) {}

    try {
      yield* SupabaseService.client
          .from('game_prices')
          .stream(primaryKey: ['id'])
          .eq('id', docId)
          .map((list) => list.isNotEmpty ? list.first : null);
    } catch (_) {}
  }

  Stream<Map<String, dynamic>?> streamUserAlert(String gameName, String userId) async* {
    final gameId = getGameDocId(gameName);
    final alertDocId = '${userId}_$gameId';
    try {
      final initial = await SupabaseService.client
          .from('user_price_alerts')
          .select()
          .eq('id', alertDocId)
          .maybeSingle();
      yield initial;
    } catch (_) {}

    try {
      yield* SupabaseService.client
          .from('user_price_alerts')
          .stream(primaryKey: ['id'])
          .eq('id', alertDocId)
          .map((list) => list.isNotEmpty ? list.first : null);
    } catch (_) {}
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
    final nowIso = DateTime.now().toIso8601String();

    try {
      await SupabaseService.client.from('user_price_alerts').upsert({
        'id': alertDocId,
        'userId': userId,
        'user_id': userId,
        'gameName': gameName,
        'game_name': gameName,
        'targetPricePKR': targetPricePKR,
        'target_price_pkr': targetPricePKR,
        'targetPriceUSD': double.parse(targetPriceUSD.toStringAsFixed(2)),
        'target_price_usd': double.parse(targetPriceUSD.toStringAsFixed(2)),
        'isActive': true,
        'is_active': true,
        'createdAt': nowIso,
        'created_at': nowIso,
      });
      debugPrint('[PriceService] Alert created for $gameName at Rs. $targetPricePKR ($targetPriceUSD USD)');
    } catch (e) {
      debugPrint('[PriceService] Error setting price alert: $e');
    }
  }
}
