import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

/// Timestamp compatibility class
class Timestamp implements Comparable<Timestamp> {
  final int seconds;
  final int nanoseconds;

  const Timestamp(this.seconds, this.nanoseconds);

  factory Timestamp.now() {
    final now = DateTime.now();
    return Timestamp.fromDate(now);
  }

  factory Timestamp.fromDate(DateTime date) {
    final seconds = date.millisecondsSinceEpoch ~/ 1000;
    final nanoseconds = (date.millisecondsSinceEpoch % 1000) * 1000000;
    return Timestamp(seconds, nanoseconds);
  }

  factory Timestamp.fromMillisecondsSinceEpoch(int ms) {
    return Timestamp(ms ~/ 1000, (ms % 1000) * 1000000);
  }

  DateTime toDate() {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + nanoseconds ~/ 1000000);
  }

  int get millisecondsSinceEpoch => seconds * 1000 + nanoseconds ~/ 1000000;

  @override
  int compareTo(Timestamp other) {
    if (seconds == other.seconds) {
      return nanoseconds.compareTo(other.nanoseconds);
    }
    return seconds.compareTo(other.seconds);
  }

  @override
  bool operator ==(Object other) {
    return other is Timestamp && other.seconds == seconds && other.nanoseconds == nanoseconds;
  }

  @override
  int get hashCode => Object.hash(seconds, nanoseconds);

  @override
  String toString() => toDate().toIso8601String();
}

/// FieldValue compatibility class
class FieldValue {
  final dynamic _value;
  final String _type;

  const FieldValue._(this._type, [this._value]);

  static FieldValue serverTimestamp() => const FieldValue._('serverTimestamp');
  static FieldValue delete() => const FieldValue._('delete');
  static FieldValue increment(num value) => FieldValue._('increment', value);
  static FieldValue arrayUnion(List elements) => FieldValue._('arrayUnion', elements);
  static FieldValue arrayRemove(List elements) => FieldValue._('arrayRemove', elements);

  String get type => _type;
  dynamic get value => _value;
}

/// SetOptions compatibility class
class SetOptions {
  final bool? merge;
  const SetOptions({this.merge});
}

enum Source { serverAndCache, server, cache }

class GetOptions {
  final Source? source;
  const GetOptions({this.source});
}

/// Filter compatibility class for Firestore queries
class Filter {
  final String? field;
  final dynamic isEqualTo;
  final dynamic isNotEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic arrayContains;
  final List? arrayContainsAny;
  final List? whereIn;
  final List? whereNotIn;
  final bool? isNull;
  final List<Filter>? orFilters;
  final List<Filter>? andFilters;

  Filter(
    this.field, {
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayContainsAny,
    this.whereIn,
    this.whereNotIn,
    this.isNull,
    this.orFilters,
    this.andFilters,
  });

  static Filter or(Filter a, Filter b, [Filter? c, Filter? d]) {
    final list = [a, b];
    if (c != null) list.add(c);
    if (d != null) list.add(d);
    return Filter(null, orFilters: list);
  }

  static Filter and(Filter a, Filter b, [Filter? c, Filter? d]) {
    final list = [a, b];
    if (c != null) list.add(c);
    if (d != null) list.add(d);
    return Filter(null, andFilters: list);
  }
}

enum DocumentChangeType { added, modified, removed }

class DocumentChange<T extends Object?> {
  final DocumentChangeType type;
  final DocumentSnapshot<T> doc;
  final int oldIndex;
  final int newIndex;

  DocumentChange({
    required this.type,
    required this.doc,
    this.oldIndex = -1,
    this.newIndex = -1,
  });
}

/// DocumentSnapshot compatibility class
class DocumentSnapshot<T extends Object?> {
  final String id;
  final Map<String, dynamic>? _data;
  final bool exists;
  final DocumentReference<T> reference;

  DocumentSnapshot({
    required this.id,
    Map<String, dynamic>? data,
    required this.exists,
    required this.reference,
  }) : _data = data;

  dynamic data() => _data;

  dynamic get(Object field) => _data?[field.toString()];

  dynamic operator [](Object field) => _data?[field.toString()];
}

/// QueryDocumentSnapshot compatibility class
class QueryDocumentSnapshot<T extends Object?> extends DocumentSnapshot<T> {
  QueryDocumentSnapshot({
    required super.id,
    super.data,
    required super.exists,
    required super.reference,
  });

  @override
  dynamic data() => _data ?? <String, dynamic>{};
}

/// QuerySnapshot compatibility class
class QuerySnapshot<T extends Object?> {
  final List<QueryDocumentSnapshot<T>> docs;
  final List<DocumentChange<T>> docChanges;

  QuerySnapshot({required this.docs, List<DocumentChange<T>>? changes})
      : docChanges = changes ??
            docs
                .map((d) => DocumentChange<T>(type: DocumentChangeType.added, doc: d))
                .toList();

  int get size => docs.length;
}

/// FirebaseFirestore compatibility class backed by Supabase
class FirebaseFirestore {
  static final FirebaseFirestore instance = FirebaseFirestore._();
  FirebaseFirestore._();

  CollectionReference<Map<String, dynamic>> collection(String path) {
    return CollectionReference<Map<String, dynamic>>(path);
  }

  DocumentReference<Map<String, dynamic>> doc(String path) {
    final segments = path.split('/');
    if (segments.length == 2) {
      return CollectionReference<Map<String, dynamic>>(segments[0]).doc(segments[1]);
    }
    return DocumentReference<Map<String, dynamic>>(path, path.split('/').last);
  }

  WriteBatch batch() => WriteBatch();

  Future<T> runTransaction<T>(Future<T> Function(Transaction) action) async {
    final transaction = Transaction();
    return await action(transaction);
  }
}

class WriteBatch {
  final List<Future<void> Function()> _ops = [];

  void set(DocumentReference ref, Map<String, dynamic> data, [SetOptions? options]) {
    _ops.add(() => ref.set(data, options));
  }

  void update(DocumentReference ref, Map<String, dynamic> data) {
    _ops.add(() => ref.update(data));
  }

  void delete(DocumentReference ref) {
    _ops.add(() => ref.delete());
  }

  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
  }
}

class Transaction {
  Future<DocumentSnapshot> get(DocumentReference ref) => ref.get();
  void set(DocumentReference ref, Map<String, dynamic> data, [SetOptions? options]) => ref.set(data, options);
  void update(DocumentReference ref, Map<String, dynamic> data) => ref.update(data);
  void delete(DocumentReference ref) => ref.delete();
}

/// Helper to map Firestore collection paths to Supabase tables
String _resolveTableName(String collectionPath) {
  final c = collectionPath.toLowerCase().trim();
  if (c == 'users') return 'users';
  if (c == 'posts' || c == 'community_posts' || c == 'lfg_posts' || c == 'squad_posts' || c == 'gaming_news') {
    return 'posts';
  }
  if (c == 'comments') return 'comments';
  if (c == 'likes') return 'likes';
  if (c == 'teams' || c == 'squads') return 'teams';
  if (c == 'team_members') return 'team_members';
  if (c == 'team_join_requests') return 'team_join_requests';
  if (c == 'team_matches' || c == 'active_matches') return 'team_matches';
  if (c == 'rooms' || c == 'tournament_rooms') return 'rooms';
  if (c == 'room_members') return 'room_members';
  if (c == 'coin_transactions' || c == 'transactions') return 'coin_transactions';
  if (c == 'notifications') return 'notifications';
  return c;
}

/// Converts FieldValue, Timestamp, DateTime into Supabase-friendly values.
Map<String, dynamic> _cleanDataForSupabase(Map<String, dynamic> input) {
  final Map<String, dynamic> result = {};
  input.forEach((key, value) {
    if (value is FieldValue) {
      if (value.type == 'serverTimestamp') {
        result[key] = DateTime.now().toIso8601String();
      } else if (value.type == 'increment') {
        result[key] = value.value;
      } else if (value.type == 'arrayUnion') {
        result[key] = value.value;
      }
    } else if (value is Timestamp) {
      result[key] = value.toDate().toIso8601String();
    } else if (value is DateTime) {
      result[key] = value.toIso8601String();
    } else {
      result[key] = value;
    }
  });
  return result;
}

/// Maps Firebase-style field names -> Supabase column names (write path).
Map<String, dynamic> _firebaseToSupabaseFields(Map<String, dynamic> input) {
  final Map<String, dynamic> result = {};
  input.forEach((key, value) {
    String newKey = key;
    switch (key) {
      case 'displayName':
        newKey = 'display_name';
        break;
      case 'photoUrl':
        newKey = 'avatar_url';
        break;
      case 'coverUrl':
        newKey = 'cover_url';
        break;
      case 'isBanned':
        newKey = 'is_banned';
        break;
      case 'isDemoAccount':
        newKey = 'is_demo_account';
        break;
      case 'blueTickStatus':
        newKey = 'blue_tick_status';
        break;
      case 'isBlueTickVerified':
        newKey = 'is_blue_tick_verified';
        break;
      case 'blueTickVerified':
        newKey = 'blue_tick_verified';
        break;
      case 'verificationStatus':
        newKey = 'verification_status';
        break;
      case 'isVerifiedBlue':
        newKey = 'is_verified_blue';
        break;
      case 'createdAt':
        newKey = 'created_at';
        break;
      case 'updatedAt':
        newKey = 'updated_at';
        break;
      case 'followersCount':
        newKey = 'followers_count';
        break;
      case 'followingCount':
        newKey = 'following_count';
        break;
      case 'postsCount':
        newKey = 'posts_count';
        break;
      case 'likesReceived':
        newKey = 'likes_received';
        break;
      case 'reportsCount':
        newKey = 'reports_count';
        break;
      case 'rankStatus':
        newKey = 'rank_status';
        break;
      case 'rankScreenshot':
        newKey = 'rank_screenshot';
        break;
      case 'rankVerifiedBy':
        newKey = 'rank_verified_by';
        break;
      case 'rankRejectReason':
        newKey = 'rank_reject_reason';
        break;
      case 'isRankVerified':
        newKey = 'is_rank_verified';
        break;
      case 'gameId':
        newKey = 'game_id';
        break;
      case 'activeFrame':
        newKey = 'active_frame';
        break;
      case 'unlockedFrames':
        newKey = 'unlocked_frames';
        break;
      case 'activeBadge':
        newKey = 'active_badge';
        break;
      case 'unlockedBadges':
        newKey = 'unlocked_badges';
        break;
      case 'chatColor':
        newKey = 'chat_color';
        break;
      case 'unlockedChatColors':
        newKey = 'unlocked_chat_colors';
        break;
      case 'isVipMember':
        newKey = 'is_vip_member';
        break;
      case 'vipTournamentPassUntil':
        newKey = 'vip_tournament_pass_until';
        break;
      case 'leaderboardSpotlightUntil':
        newKey = 'leaderboard_spotlight_until';
        break;
      case 'bannedAt':
        newKey = 'banned_at';
        break;
      case 'bannedBy':
        newKey = 'banned_by';
        break;
      case 'bannedReason':
        newKey = 'banned_reason';
        break;
      case 'favoriteGame':
        newKey = 'favorite_game';
        break;
      case 'selectedGame':
        newKey = 'selected_game';
        break;
      case 'selectedRank':
        newKey = 'selected_rank';
        break;
      case 'kdRatio':
        newKey = 'kd_ratio';
        break;
      case 'isOwner':
        newKey = 'is_owner';
        break;
      case 'isAdmin':
        newKey = 'is_admin';
        break;
      case 'isSuperAdmin':
        newKey = 'is_super_admin';
        break;
      case 'isVerified':
        newKey = 'is_verified';
        break;
    }
    result[newKey] = value;
  });
  return result;
}

/// Maps Supabase column names -> Firebase-style field names (read path),
/// so GamerUser.fromFirestore() works with Supabase data.
Map<String, dynamic> _supabaseToFirebaseFields(Map<String, dynamic> input) {
  final Map<String, dynamic> result = {};
  input.forEach((key, value) {
    String newKey = key;
    switch (key) {
      case 'display_name':
        newKey = 'displayName';
        break;
      case 'avatar_url':
        newKey = 'photoUrl';
        break;
      case 'cover_url':
        newKey = 'coverUrl';
        break;
      case 'is_banned':
        newKey = 'isBanned';
        break;
      case 'is_demo_account':
        newKey = 'isDemoAccount';
        break;
      case 'blue_tick_status':
        newKey = 'blueTickStatus';
        break;
      case 'is_blue_tick_verified':
        newKey = 'isBlueTickVerified';
        break;
      case 'blue_tick_verified':
        newKey = 'blueTickVerified';
        break;
      case 'verification_status':
        newKey = 'verificationStatus';
        break;
      case 'is_verified_blue':
        newKey = 'isVerifiedBlue';
        break;
      case 'created_at':
        newKey = 'createdAt';
        break;
      case 'updated_at':
        newKey = 'updatedAt';
        break;
      case 'followers_count':
        newKey = 'followersCount';
        break;
      case 'following_count':
        newKey = 'followingCount';
        break;
      case 'posts_count':
        newKey = 'postsCount';
        break;
      case 'likes_received':
        newKey = 'likesReceived';
        break;
      case 'reports_count':
        newKey = 'reportsCount';
        break;
      case 'rank_status':
        newKey = 'rankStatus';
        break;
      case 'rank_screenshot':
        newKey = 'rankScreenshot';
        break;
      case 'rank_verified_by':
        newKey = 'rankVerifiedBy';
        break;
      case 'rank_reject_reason':
        newKey = 'rankRejectReason';
        break;
      case 'is_rank_verified':
        newKey = 'isRankVerified';
        break;
      case 'game_id':
        newKey = 'gameId';
        break;
      case 'active_frame':
        newKey = 'activeFrame';
        break;
      case 'unlocked_frames':
        newKey = 'unlockedFrames';
        break;
      case 'active_badge':
        newKey = 'activeBadge';
        break;
      case 'unlocked_badges':
        newKey = 'unlockedBadges';
        break;
      case 'chat_color':
        newKey = 'chatColor';
        break;
      case 'unlocked_chat_colors':
        newKey = 'unlockedChatColors';
        break;
      case 'is_vip_member':
        newKey = 'isVipMember';
        break;
      case 'vip_tournament_pass_until':
        newKey = 'vipTournamentPassUntil';
        break;
      case 'leaderboard_spotlight_until':
        newKey = 'leaderboardSpotlightUntil';
        break;
      case 'banned_at':
        newKey = 'bannedAt';
        break;
      case 'banned_by':
        newKey = 'bannedBy';
        break;
      case 'banned_reason':
        newKey = 'bannedReason';
        break;
      case 'favorite_game':
        newKey = 'favoriteGame';
        break;
      case 'selected_game':
        newKey = 'selectedGame';
        break;
      case 'selected_rank':
        newKey = 'selectedRank';
        break;
      case 'kd_ratio':
        newKey = 'kdRatio';
        break;
      case 'is_owner':
        newKey = 'isOwner';
        break;
      case 'is_admin':
        newKey = 'isAdmin';
        break;
      case 'is_super_admin':
        newKey = 'isSuperAdmin';
        break;
      case 'is_verified':
        newKey = 'isVerified';
        break;
    }
    result[newKey] = value;
  });
  return result;
}

/// Query compatibility class
class Query<T extends Object?> {
  final String collectionPath;
  final List<Map<String, dynamic>> _filters = [];
  String? _orderByField;
  bool _descending = false;
  int? _limitCount;

  Query(this.collectionPath);

  Query<T> where(
    dynamic field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List? arrayContainsAny,
    List? whereIn,
    List? whereNotIn,
    bool? isNull,
  }) {
    final q = Query<T>(collectionPath);
    q._filters.addAll(_filters);
    q._orderByField = _orderByField;
    q._descending = _descending;
    q._limitCount = _limitCount;

    if (field is Filter) {
      if (field.field != null && field.isEqualTo != null) {
        q._filters.add({'field': field.field!, 'op': 'eq', 'val': field.isEqualTo});
      }
      return q;
    }

    final fName = field.toString();
    if (isEqualTo != null) {
      q._filters.add({'field': fName, 'op': 'eq', 'val': isEqualTo});
    } else if (arrayContains != null) {
      q._filters.add({'field': fName, 'op': 'cs', 'val': arrayContains});
    } else if (isGreaterThan != null) {
      q._filters.add({'field': fName, 'op': 'gt', 'val': isGreaterThan});
    } else if (isLessThan != null) {
      q._filters.add({'field': fName, 'op': 'lt', 'val': isLessThan});
    }
    return q;
  }

  Query<T> orderBy(Object field, {bool descending = false}) {
    final q = Query<T>(collectionPath);
    q._filters.addAll(_filters);
    q._orderByField = _firebaseFieldToSupabase(field.toString());
    q._descending = descending;
    q._limitCount = _limitCount;
    return q;
  }

  Query<T> limit(int limit) {
    final q = Query<T>(collectionPath);
    q._filters.addAll(_filters);
    q._orderByField = _orderByField;
    q._descending = _descending;
    q._limitCount = limit;
    return q;
  }

  /// Converts Firebase field name to Supabase column name for query filters.
  String _firebaseFieldToSupabase(String field) {
    switch (field) {
      case 'displayName':
        return 'display_name';
      case 'photoUrl':
        return 'avatar_url';
      case 'isBanned':
        return 'is_banned';
      case 'isDemoAccount':
        return 'is_demo_account';
      case 'blueTickStatus':
        return 'blue_tick_status';
      case 'createdAt':
        return 'created_at';
      case 'updatedAt':
        return 'updated_at';
      case 'favoriteGame':
        return 'favorite_game';
      case 'verificationStatus':
        return 'verification_status';
      default:
        return field;
    }
  }

  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    final table = _resolveTableName(collectionPath);
    try {
      final filtersMap = <String, String>{};
      for (final f in _filters) {
        final field = _firebaseFieldToSupabase(f['field'].toString());
        final val = f['val'];
        if (f['op'] == 'eq') {
          filtersMap[field] = 'eq.$val';
        }
      }

      String? order;
      if (_orderByField != null) {
        order = '$_orderByField.${_descending ? 'desc' : 'asc'}';
      }

      final rows = await SupabaseService.query(
        table,
        filters: filtersMap.isNotEmpty ? filtersMap : null,
        order: order,
        limit: _limitCount ?? 50,
      );

      final docList = rows.map((r) {
        final docId = (r['id'] ?? r['uid'] ?? r['post_id'] ?? r['team_id'] ?? '').toString();
        final mapped = _supabaseToFirebaseFields(r);
        return QueryDocumentSnapshot<T>(
          id: docId,
          data: mapped,
          exists: true,
          reference: DocumentReference<T>(collectionPath, docId),
        );
      }).toList();

      return QuerySnapshot<T>(docs: docList);
    } catch (e) {
      debugPrint('[Compat Firestore] Query get error on $table: $e');
      return QuerySnapshot<T>(docs: []);
    }
  }

  Stream<QuerySnapshot<T>> snapshots() async* {
    while (true) {
      yield await get();
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Query<R> withConverter<R extends Object?>({required dynamic fromFirestore, required dynamic toFirestore}) {
    return Query<R>(collectionPath);
  }
}

/// CollectionReference compatibility class
class CollectionReference<T extends Object?> extends Query<T> {
  CollectionReference(super.collectionPath);

  String get id => collectionPath.split('/').last;
  String get path => collectionPath;

  DocumentReference<T> doc([String? id]) {
    final docId = id ?? 'doc_${DateTime.now().millisecondsSinceEpoch}';
    return DocumentReference<T>(collectionPath, docId);
  }

  Future<DocumentReference<T>> add(dynamic data) async {
    final ref = doc();
    await ref.set(data);
    return ref;
  }

  @override
  CollectionReference<R> withConverter<R extends Object?>({required dynamic fromFirestore, required dynamic toFirestore}) {
    return CollectionReference<R>(collectionPath);
  }
}

/// DocumentReference compatibility class
class DocumentReference<T extends Object?> {
  final String collectionPath;
  final String id;

  DocumentReference(this.collectionPath, this.id);

  String get path => '$collectionPath/$id';

  CollectionReference<Map<String, dynamic>> collection(String subcollectionPath) {
    return CollectionReference<Map<String, dynamic>>('$collectionPath/$id/$subcollectionPath');
  }

  Future<DocumentSnapshot<T>> get([GetOptions? options]) async {
    final table = _resolveTableName(collectionPath);
    try {
      // 1. Check by id
      var rows = await SupabaseService.query(table, filters: {'id': 'eq.$id'}, limit: 1);
      if (rows.isEmpty) {
        // Try query by uid or team_id
        rows = await SupabaseService.query(table, filters: {'uid': 'eq.$id'}, limit: 1);
      }
      if (rows.isEmpty) {
        rows = await SupabaseService.query(table, filters: {'team_id': 'eq.$id'}, limit: 1);
      }

      if (rows.isNotEmpty) {
        return DocumentSnapshot<T>(
          id: id,
          data: _supabaseToFirebaseFields(rows.first),
          exists: true,
          reference: this,
        );
      }
      return DocumentSnapshot<T>(
        id: id,
        data: null,
        exists: false,
        reference: this,
      );
    } catch (e) {
      debugPrint('[Compat Firestore] doc get error on $table/$id: $e');
      return DocumentSnapshot<T>(id: id, data: null, exists: false, reference: this);
    }
  }

  Stream<DocumentSnapshot<T>> snapshots() async* {
    while (true) {
      yield await get();
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  DocumentReference<R> withConverter<R extends Object?>({required dynamic fromFirestore, required dynamic toFirestore}) {
    return DocumentReference<R>(collectionPath, id);
  }

  Future<void> set(dynamic data, [SetOptions? options]) async {
    final table = _resolveTableName(collectionPath);
    final mapData = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final cleaned = _cleanDataForSupabase(mapData);
    final clean = _firebaseToSupabaseFields(cleaned);
    if (!clean.containsKey('id') && !clean.containsKey('uid')) {
      clean['id'] = id;
    }
    if (table == 'users' && !clean.containsKey('uid')) {
      clean['uid'] = id;
    }
    try {
      if (table == 'users') {
        await SupabaseService.upsertUser(clean);
      } else {
        await SupabaseService.insert(table, clean);
      }
    } catch (e) {
      debugPrint('[Compat Firestore] doc set error on $table: $e');
    }
  }

  Future<void> update(Map<String, dynamic> data) async {
    final table = _resolveTableName(collectionPath);
    final cleaned = _cleanDataForSupabase(data);
    final clean = _firebaseToSupabaseFields(cleaned);
    try {
      await SupabaseService.update(table, clean, 'id', id);
    } catch (e) {
      debugPrint('[Compat Firestore] doc update error on $table: $e');
    }
  }

  Future<void> delete() async {
    final table = _resolveTableName(collectionPath);
    try {
      await SupabaseService.delete(table, 'id', id);
    } catch (e) {
      debugPrint('[Compat Firestore] doc delete error on $table: $e');
    }
  }
}