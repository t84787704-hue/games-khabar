import 'package:flutter/foundation.dart';
import '../models/challenge_model.dart';
import 'supabase_service.dart';

class ChallengeService {
  static final ChallengeService _instance = ChallengeService._internal();
  factory ChallengeService() => _instance;
  ChallengeService._internal();

  Future<void> sendChallenge(GamerChallenge challenge) async {
    try {
      final challengerUuid = SupabaseService.toUuid(challenge.challengerId);
      final challengedUuid = SupabaseService.toUuid(challenge.challengedId);

      final inserted = await SupabaseService.client
          .from('challenges')
          .insert({
        'challenger_id': challengerUuid,
        'challenger_name': challenge.challengerName,
        'challenger_avatar': challenge.challengerAvatar,
        'challenged_id': challengedUuid,
        'challenged_name': challenge.challengedName,
        'challenged_avatar': challenge.challengedAvatar,
        'game': challenge.game,
        'mode': challenge.mode,
        'weapon_rule': challenge.weaponRule,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      try {
        await SupabaseService.sendNotification({
          'userId': challengedUuid,
          'title': '⚔️ 1v1 Battle Challenge',
          'message':
              '${challenge.challengerName} challenged you to a 1v1 (${challenge.mode}, ${challenge.weaponRule})!',
          'type': 'challenge',
        });
      } catch (e) {
        debugPrint('[ChallengeService] Notification error: $e');
      }

      debugPrint('[ChallengeService] Challenge sent: ${inserted['id']}');
    } catch (e) {
      debugPrint('[ChallengeService] sendChallenge error: $e');
      rethrow;
    }
  }

  Future<void> acceptChallenge(
    String challengeId, {
    String? challengerUid,
    String? responderName,
  }) async {
    try {
      await SupabaseService.client
          .from('challenges')
          .update({'status': 'accepted'})
          .eq('id', challengeId);

      if (challengerUid != null && challengerUid.isNotEmpty) {
        try {
          await SupabaseService.sendNotification({
            'userId': SupabaseService.toUuid(challengerUid),
            'title': '✅ 1v1 Challenge Accepted',
            'message':
                '${responderName ?? "Opponent"} accepted your 1v1 challenge! Room is ON.',
            'type': 'challenge_accepted',
          });
        } catch (e) {
          debugPrint('[ChallengeService] Notification error: $e');
        }
      }
    } catch (e) {
      debugPrint('[ChallengeService] acceptChallenge error: $e');
    }
  }

  Future<void> declineChallenge(String challengeId) async {
    try {
      await SupabaseService.client
          .from('challenges')
          .update({'status': 'declined'})
          .eq('id', challengeId);
    } catch (e) {
      debugPrint('[ChallengeService] declineChallenge error: $e');
    }
  }

  Future<void> setWinner(String challengeId, String winnerId) async {
    try {
      await SupabaseService.client.from('challenges').update({
        'status': 'completed',
        'winner_id': SupabaseService.toUuid(winnerId),
      }).eq('id', challengeId);
    } catch (e) {
      debugPrint('[ChallengeService] setWinner error: $e');
    }
  }

  Stream<List<GamerChallenge>> getUserChallengesStream(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    final uuid = SupabaseService.toUuid(userId);
    return SupabaseService.client
        .from('challenges')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) {
      return rows
          .where((r) =>
              r['challenger_id']?.toString() == uuid ||
              r['challenged_id']?.toString() == uuid)
          .map((r) => GamerChallenge.fromSupabase(r))
          .toList();
    });
  }

  Stream<List<GamerChallenge>> getPendingIncomingChallenges(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    final uuid = SupabaseService.toUuid(userId);
    return SupabaseService.client
        .from('challenges')
        .stream(primaryKey: ['id'])
        .map((rows) {
      return rows
          .where((r) =>
              r['challenged_id']?.toString() == uuid &&
              r['status']?.toString() == 'pending')
          .map((r) => GamerChallenge.fromSupabase(r))
          .toList();
    });
  }
}