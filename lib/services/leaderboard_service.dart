import 'dart:async';
import '../models/gamer_user_model.dart';
import 'supabase_service.dart';

class LeaderboardService {
  Future<List<GamerUser>> getTopPlayersFromSupabase({int limit = 20}) async {
    try {
      final rows = await SupabaseService.query('users', order: 'coins.desc', limit: limit);
      return rows.map((r) => GamerUser.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<GamerUser>> getTopPlayersByLikes({int limit = 15}) {
    try {
      return SupabaseService.client
          .from('users')
          .stream(primaryKey: ['id'])
          .order('likes_received', ascending: false)
          .limit(limit)
          .map((rows) => rows.map((r) => GamerUser.fromMap(r)).toList());
    } catch (_) {
      return Stream.fromFuture(
        SupabaseService.query('users', order: 'likes_received.desc', limit: limit)
            .then((rows) => rows.map((r) => GamerUser.fromMap(r)).toList()),
      );
    }
  }

  Stream<List<GamerUser>> getTopPlayersByPosts({int limit = 15}) {
    try {
      return SupabaseService.client
          .from('users')
          .stream(primaryKey: ['id'])
          .order('posts_count', ascending: false)
          .limit(limit)
          .map((rows) => rows.map((r) => GamerUser.fromMap(r)).toList());
    } catch (_) {
      return Stream.fromFuture(
        SupabaseService.query('users', order: 'posts_count.desc', limit: limit)
            .then((rows) => rows.map((r) => GamerUser.fromMap(r)).toList()),
      );
    }
  }

  Stream<List<GamerUser>> getTopPlayersByFollowers({int limit = 15}) {
    try {
      return SupabaseService.client
          .from('users')
          .stream(primaryKey: ['id'])
          .order('followers_count', ascending: false)
          .limit(limit)
          .map((rows) => rows.map((r) => GamerUser.fromMap(r)).toList());
    } catch (_) {
      return Stream.fromFuture(
        SupabaseService.query('users', order: 'followers_count.desc', limit: limit)
            .then((rows) => rows.map((r) => GamerUser.fromMap(r)).toList()),
      );
    }
  }

  Stream<List<GamerUser>> getTopKdKings({int limit = 15}) {
    try {
      return SupabaseService.client
          .from('users')
          .stream(primaryKey: ['id'])
          .order('kd_ratio', ascending: false)
          .limit(limit)
          .map((rows) => rows.map((r) => GamerUser.fromMap(r)).toList());
    } catch (_) {
      return Stream.fromFuture(
        SupabaseService.query('users', order: 'kd_ratio.desc', limit: limit)
            .then((rows) => rows.map((r) => GamerUser.fromMap(r)).toList()),
      );
    }
  }
}
