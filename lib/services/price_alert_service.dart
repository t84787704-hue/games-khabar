import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

      // Save alert to Firestore so Cloud Functions can track individual alerts
      try {
        final fcmToken = await FirebaseMessaging.instance.getToken().catchError((_) => null);
        await FirebaseFirestore.instance
            .collection('price_alerts')
            .doc('${gameId}_alert')
            .set({
          'gameId': gameId,
          'gameName': gameName,
          'alertPrice': targetPrice,
          'currentPrice': currentPrice,
          'store': store ?? 'Steam',
          'fcmToken': fcmToken,
          'createdAt': FieldValue.serverTimestamp(),
          'active': true,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[PriceAlertService] Firestore save error: $e');
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
        await FirebaseFirestore.instance
            .collection('price_alerts')
            .doc('${gameId}_alert')
            .delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('[PriceAlertService] removeAlert error: $e');
    }
  }
}
