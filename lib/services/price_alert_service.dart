import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'supabase_service.dart';

class PriceAlertService {
  static final PriceAlertService _instance = PriceAlertService._internal();
  factory PriceAlertService() => _instance;
  PriceAlertService._internal();

  static final ValueNotifier<Map<String, double>> alertsNotifier =
      ValueNotifier<Map<String, double>>({});

  static const String _prefsPrefix = 'price_alert_';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefsPrefix));
      final Map<String, double> loaded = {};
      for (final key in keys) {
        final gameId = key.replaceFirst(_prefsPrefix, '');
        final val = prefs.getDouble(key);
        if (val != null) {
          loaded[gameId] = val;
        }
      }
      alertsNotifier.value = loaded;
    } catch (e) {
      debugPrint('[PriceAlertService] Init error: $e');
    }
  }

  double? getAlertPrice(String gameId) {
    return alertsNotifier.value[gameId];
  }

  bool hasAlert(String gameId) {
    return alertsNotifier.value.containsKey(gameId);
  }

  Future<void> setAlert({
    required String gameId,
    required String gameName,
    required double targetPrice,
    double? currentPrice,
    String? store,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_prefsPrefix$gameId', targetPrice);

      final updated = Map<String, double>.from(alertsNotifier.value);
      updated[gameId] = targetPrice;
      alertsNotifier.value = updated;

      // Subscribe to FCM topic for this game's price drop
      final topicName = 'price_drop_${gameId.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_')}';
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topicName);
      } catch (e) {
        debugPrint('[PriceAlertService] Subscribe topic error: $e');
      }

      // Save alert to Supabase
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken().catchError((_) => null);
        await SupabaseService.client
            .from('price_alerts')
            .upsert({
          'id': '${gameId}_alert',
          'game_id': gameId,
          'gameId': gameId,
          'game_name': gameName,
          'gameName': gameName,
          'alert_price': targetPrice,
          'alertPrice': targetPrice,
          'current_price': currentPrice,
          'currentPrice': currentPrice,
          'store': store ?? 'Steam',
          'fcm_token': fcmToken,
          'fcmToken': fcmToken,
          'created_at': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'active': true,
        });
      } catch (e) {
        debugPrint('[PriceAlertService] Supabase save error: $e');
      }
    } catch (e) {
      debugPrint('[PriceAlertService] setAlert error: $e');
    }
  }

  Future<void> removeAlert(String gameId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefsPrefix$gameId');

      final updated = Map<String, double>.from(alertsNotifier.value);
      updated.remove(gameId);
      alertsNotifier.value = updated;

      final topicName = 'price_drop_${gameId.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_')}';
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(topicName);
      } catch (_) {}

      try {
        await SupabaseService.client
            .from('price_alerts')
            .delete()
            .or('id.eq.${gameId}_alert,game_id.eq.$gameId');
      } catch (_) {}
    } catch (e) {
      debugPrint('[PriceAlertService] removeAlert error: $e');
    }
  }
}
