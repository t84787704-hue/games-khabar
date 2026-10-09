import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Supabase timestamp representation
class SupaTime implements Comparable<SupaTime> {
  final int seconds;
  final int nanoseconds;

  const SupaTime(this.seconds, this.nanoseconds);

  factory SupaTime.now() {
    final now = DateTime.now();
    return SupaTime.fromDate(now);
  }

  factory SupaTime.fromDate(DateTime date) {
    final seconds = date.millisecondsSinceEpoch ~/ 1000;
    final nanoseconds = (date.millisecondsSinceEpoch % 1000) * 1000000;
    return SupaTime(seconds, nanoseconds);
  }

  factory SupaTime.fromMillisecondsSinceEpoch(int ms) {
    return SupaTime(ms ~/ 1000, (ms % 1000) * 1000000);
  }

  DateTime toDate() {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + nanoseconds ~/ 1000000);
  }

  int get millisecondsSinceEpoch => seconds * 1000 + nanoseconds ~/ 1000000;

  @override
  int compareTo(SupaTime other) {
    if (seconds == other.seconds) {
      return nanoseconds.compareTo(other.nanoseconds);
    }
    return seconds.compareTo(other.seconds);
  }

  @override
  bool operator ==(Object other) {
    return other is SupaTime && other.seconds == seconds && other.nanoseconds == nanoseconds;
  }

  @override
  int get hashCode => Object.hash(seconds, nanoseconds);

  @override
  String toString() => toDate().toIso8601String();
}

/// Supabase field manipulation helper
class SupaField {
  final dynamic _value;
  final String _type;

  const SupaField._(this._type, [this._value]);

  static SupaField serverTimestamp() => const SupaField._('serverTimestamp');
  static SupaField delete() => const SupaField._('delete');
  static SupaField increment(num value) => SupaField._('increment', value);
  static SupaField arrayUnion(List elements) => SupaField._('arrayUnion', elements);
  static SupaField arrayRemove(List elements) => SupaField._('arrayRemove', elements);

  String get type => _type;
  dynamic get value => _value;
}

class SupaSetOptions {
  final bool? merge;
  const SupaSetOptions({this.merge});
}

class SupaFilter {
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
  final List<SupaFilter>? orFilters;
  final List<SupaFilter>? andFilters;

  SupaFilter(
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

  static SupaFilter or(SupaFilter a, SupaFilter b, [SupaFilter? c, SupaFilter? d]) {
    final list = [a, b];
    if (c != null) list.add(c);
    if (d != null) list.add(d);
    return SupaFilter(null, orFilters: list);
  }

  static SupaFilter and(SupaFilter a, SupaFilter b, [SupaFilter? c, SupaFilter? d]) {
    final list = [a, b];
    if (c != null) list.add(c);
    if (d != null) list.add(d);
    return SupaFilter(null, andFilters: list);
  }
}

/// Supabase Document Snapshot
class SupaDoc<T extends Object?> {
  final String id;
  final Map<String, dynamic>? _data;
  final bool exists;
  final SupaDocRef<T> reference;

  SupaDoc({
    required this.id,
    Map<String, dynamic>? data,
    required this.exists,
    required this.reference,
  }) : _data = data;

  Map<String, dynamic>? data() => _data;

  dynamic get(Object field) {
    if (_data == null) return null;
    return _data[field.toString()];
  }

  dynamic operator [](Object field) => get(field);
}

/// Supabase Query Snapshot
class SupaSnap<T extends Object?> {
  final List<SupaDoc<T>> docs;

  SupaSnap(this.docs);

  int get size => docs.length;
  bool get isEmpty => docs.isEmpty;
  bool get isNotEmpty => docs.isNotEmpty;
}

/// Main Supabase Store
class SupaStore {
  static final SupaStore instance = SupaStore._();
  SupaStore._();

  SupaColRef<Map<String, dynamic>> collection(String path) {
    return SupaColRef<Map<String, dynamic>>(path);
  }

  SupaDocRef<Map<String, dynamic>> doc(String path) {
    final segments = path.split('/');
    if (segments.length == 2) {
      return SupaColRef<Map<String, dynamic>>(segments[0]).doc(segments[1]);
    }
    return SupaDocRef<Map<String, dynamic>>(path, path.split('/').last);
  }

  SupaBatch batch() => SupaBatch();

  Future<T> runTransaction<T>(Future<T> Function(SupaTx) action) async {
    final transaction = SupaTx();
    return await action(transaction);
  }
}

class SupaBatch {
  final List<Future<void> Function()> _ops = [];

  void set(SupaDocRef ref, Map<String, dynamic> data, [SupaSetOptions? options]) {
    _ops.add(() => ref.set(data, options));
  }

  void update(SupaDocRef ref, Map<String, dynamic> data) {
    _ops.add(() => ref.update(data));
  }

  void delete(SupaDocRef ref) {
    _ops.add(() => ref.delete());
  }

  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
  }
}

class SupaTx {
  Future<SupaDoc> get(SupaDocRef ref) => ref.get();
  void set(SupaDocRef ref, Map<String, dynamic> data, [SupaSetOptions? options]) => ref.set(data, options);
  void update(SupaDocRef ref, Map<String, dynamic> data) => ref.update(data);
  void delete(SupaDocRef ref) => ref.delete();
}

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
  if (c.contains('messages')) return 'messages';
  return c;
}

Map<String, dynamic> _cleanDataForSupabase(Map<String, dynamic> input) {
  final Map<String, dynamic> result = {};
  input.forEach((key, value) {
    if (value is SupaField) {
      if (value.type == 'serverTimestamp') {
        result[key] = DateTime.now().toIso8601String();
      } else if (value.type == 'increment') {
        result[key] = value.value;
      } else if (value.type == 'arrayUnion') {
        result[key] = value.value;
      }
    } else if (value is SupaTime) {
      result[key] = value.toDate().toIso8601String();
    } else if (value is DateTime) {
      result[key] = value.toIso8601String();
    } else {
      result[key] = value;
    }
  });
  return result;
}

Map<String, dynamic> _fieldsToSupabase(Map<String, dynamic> input) {
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
      case 'createdAt':
        newKey = 'created_at';
        break;
      case 'updatedAt':
        newKey = 'updated_at';
        break;
      case 'gameId':
        newKey = 'game_id';
        break;
    }
    result[newKey] = value;
  });
  return result;
}

Map<String, dynamic> _fieldsFromSupabase(Map<String, dynamic> input) {
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
      case 'created_at':
        newKey = 'createdAt';
        break;
      case 'updated_at':
        newKey = 'updatedAt';
        break;
      case 'game_id':
        newKey = 'gameId';
        break;
    }
    result[newKey] = value;
  });
  return result;
}

class SupaQuery<T extends Object?> {
  final String collectionPath;
  final List<Map<String, dynamic>> _filters = [];
  final List<String> _orders = [];
  int? _limitCount;

  SupaQuery(this.collectionPath);

  SupaQuery<T> where(
    dynamic field, {
    dynamic isEqualTo,
    dynamic isNotEqualTo,
    dynamic isLessThan,
    dynamic isLessThanOrEqualTo,
    dynamic isGreaterThan,
    dynamic isGreaterThanOrEqualTo,
    dynamic arrayContains,
    List? arrayContainsAny,
    List? whereIn,
    List? whereNotIn,
    bool? isNull,
  }) {
    final q = SupaQuery<T>(collectionPath);
    q._filters.addAll(_filters);
    q._orders.addAll(_orders);
    q._limitCount = _limitCount;

    if (field is String) {
      if (isEqualTo != null) q._filters.add({'field': field, 'op': 'eq', 'value': isEqualTo});
      if (isNotEqualTo != null) q._filters.add({'field': field, 'op': 'neq', 'value': isNotEqualTo});
      if (isLessThan != null) q._filters.add({'field': field, 'op': 'lt', 'value': isLessThan});
      if (isLessThanOrEqualTo != null) q._filters.add({'field': field, 'op': 'lte', 'value': isLessThanOrEqualTo});
      if (isGreaterThan != null) q._filters.add({'field': field, 'op': 'gt', 'value': isGreaterThan});
      if (isGreaterThanOrEqualTo != null) q._filters.add({'field': field, 'op': 'gte', 'value': isGreaterThanOrEqualTo});
    }
    return q;
  }

  SupaQuery<T> orderBy(String field, {bool descending = false}) {
    final q = SupaQuery<T>(collectionPath);
    q._filters.addAll(_filters);
    q._orders.addAll(_orders);
    q._orders.add('$field.${descending ? 'desc' : 'asc'}');
    q._limitCount = _limitCount;
    return q;
  }

  SupaQuery<T> limit(int count) {
    final q = SupaQuery<T>(collectionPath);
    q._filters.addAll(_filters);
    q._orders.addAll(_orders);
    q._limitCount = count;
    return q;
  }

  Future<SupaSnap<T>> get() async {
    final table = _resolveTableName(collectionPath);
    try {
      final Map<String, String> filterMap = {};
      for (final f in _filters) {
        final field = f['field'] as String;
        final op = f['op'] as String;
        final val = f['value'];
        filterMap[field] = '$op.$val';
      }

      final rows = await SupabaseService.query(
        table,
        filters: filterMap.isNotEmpty ? filterMap : null,
        order: _orders.isNotEmpty ? _orders.first : null,
        limit: _limitCount,
      );

      final docs = rows.map((r) {
        final id = (r['id'] ?? r['uid'] ?? '').toString();
        return SupaDoc<T>(
          id: id,
          data: _fieldsFromSupabase(r),
          exists: true,
          reference: SupaDocRef<T>(collectionPath, id),
        );
      }).toList();

      return SupaSnap<T>(docs);
    } catch (e) {
      debugPrint('[SupaStore] query get error on $table: $e');
      return SupaSnap<T>([]);
    }
  }

  Stream<SupaSnap<T>> snapshots() async* {
    while (true) {
      yield await get();
      await Future.delayed(const Duration(seconds: 4));
    }
  }
}

class SupaColRef<T extends Object?> extends SupaQuery<T> {
  SupaColRef(super.collectionPath);

  String get id => collectionPath.split('/').last;
  String get path => collectionPath;

  SupaDocRef<T> doc([String? id]) {
    final docId = id ?? 'doc_${DateTime.now().millisecondsSinceEpoch}';
    return SupaDocRef<T>(collectionPath, docId);
  }

  Future<SupaDocRef<T>> add(dynamic data) async {
    final ref = doc();
    await ref.set(data);
    return ref;
  }
}

class SupaDocRef<T extends Object?> {
  final String collectionPath;
  final String id;

  SupaDocRef(this.collectionPath, this.id);

  String get path => '$collectionPath/$id';

  SupaColRef<Map<String, dynamic>> collection(String subcollectionPath) {
    return SupaColRef<Map<String, dynamic>>('$collectionPath/$id/$subcollectionPath');
  }

  Future<SupaDoc<T>> get() async {
    final table = _resolveTableName(collectionPath);
    try {
      var rows = await SupabaseService.query(table, filters: {'id': 'eq.$id'}, limit: 1);
      if (rows.isEmpty) {
        rows = await SupabaseService.query(table, filters: {'uid': 'eq.$id'}, limit: 1);
      }
      if (rows.isEmpty) {
        rows = await SupabaseService.query(table, filters: {'room_id': 'eq.$id'}, limit: 1);
      }

      if (rows.isNotEmpty) {
        return SupaDoc<T>(
          id: id,
          data: _fieldsFromSupabase(rows.first),
          exists: true,
          reference: this,
        );
      }
      return SupaDoc<T>(id: id, data: null, exists: false, reference: this);
    } catch (e) {
      debugPrint('[SupaStore] doc get error on $table/$id: $e');
      return SupaDoc<T>(id: id, data: null, exists: false, reference: this);
    }
  }

  Stream<SupaDoc<T>> snapshots() async* {
    while (true) {
      yield await get();
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  Future<void> set(dynamic data, [SupaSetOptions? options]) async {
    final table = _resolveTableName(collectionPath);
    final mapData = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final cleaned = _cleanDataForSupabase(mapData);
    final clean = _fieldsToSupabase(cleaned);
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
      debugPrint('[SupaStore] doc set error on $table: $e');
    }
  }

  Future<void> update(Map<String, dynamic> data) async {
    final table = _resolveTableName(collectionPath);
    final cleaned = _cleanDataForSupabase(data);
    final clean = _fieldsToSupabase(cleaned);
    try {
      await SupabaseService.update(table, clean, 'id', id);
    } catch (e) {
      debugPrint('[SupaStore] doc update error on $table: $e');
    }
  }

  Future<void> delete() async {
    final table = _resolveTableName(collectionPath);
    try {
      await SupabaseService.delete(table, 'id', id);
    } catch (e) {
      debugPrint('[SupaStore] doc delete error on $table: $e');
    }
  }
}
