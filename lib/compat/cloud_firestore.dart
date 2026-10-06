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

class GetOptions {
  const GetOptions();
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

/// QuerySnapshot compatibility class
class QuerySnapshot<T extends Object?> {
  final List<DocumentSnapshot<T>> docs;
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

/// Query compatibility class
class Query<T extends Object?> {
  final String collectionPath;
  final List<Map<String, dynamic>> _filters = [];
  String? _orderByField;
  bool _descending = false;
  int? _limitCount;

  Query(this.collectionPath);

  Query<T> where(
    Object field, {
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
    q._orderByField = field.toString();
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

  Future<QuerySnapshot<T>> get([GetOptions? options]) async {
    final table = _resolveTableName(collectionPath);
    try {
      final filtersMap = <String, String>{};
      for (final f in _filters) {
        final field = f['field'].toString();
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
        return DocumentSnapshot<T>(
          id: docId,
          data: r,
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
          data: rows.first,
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
    final clean = _cleanDataForSupabase(mapData);
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
    final clean = _cleanDataForSupabase(data);
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
