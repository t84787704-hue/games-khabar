import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// =========================================================================
/// SupaStore — A thin, safe wrapper over Supabase that mimics the
/// Firebase-style API used across the app (collection/doc/get/set/update/
/// snapshots/batch/runTransaction + SupaField/SupaTime/SupaSetOptions).
///
/// This keeps `gamer_rooms_screen.dart` and other legacy screens working
/// without rewriting them all at once, while every operation still goes
/// straight to Supabase underneath.
/// =========================================================================
class SupaStore {
  SupaStore._();
  static final SupaStore instance = SupaStore._();

  SupaCollection collection(String name) => SupaCollection(name);

  SupaBatch batch() => SupaBatch();

  Future<T> runTransaction<T>(
    Future<T> Function(SupaTransaction tx) action,
  ) async {
    final tx = SupaTransaction();
    try {
      final result = await action(tx);
      await tx._commit();
      return result;
    } catch (e) {
      tx._rollback();
      rethrow;
    }
  }
}

/// =========================================================================
/// SupaCollection
/// =========================================================================
class SupaCollection {
  final String name;
  SupaCollection(this.name);

  SupaDocRef doc([String? id]) {
    final docId =
        id ?? '${DateTime.now().millisecondsSinceEpoch}_${_randomId()}';
    return SupaDocRef(name, docId);
  }

  SupaQuery where(String field, {dynamic isEqualTo}) {
    return SupaQuery(name).where(field, isEqualTo: isEqualTo);
  }

  Future<SupaQueryResult> get() async {
    return await SupaQuery(name).get();
  }

  Stream<SupaSnap> snapshots() {
    return SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id'])
        .map((rows) {
      final docs = rows
          .map((row) => SupaDoc(
                SupaDocRef(name, row['id']?.toString() ?? ''),
                Map<String, dynamic>.from(row),
              ))
          .toList();
      return SupaSnap(docs);
    });
  }

  Future<SupaDocRef> add(Map<String, dynamic> data) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${_randomId()}';
    await SupabaseService.client.from(name).insert({...data, 'id': id});
    return SupaDocRef(name, id);
  }
}

String _randomId() {
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      (1000 + (DateTime.now().millisecond * 7) % 9000).toString();
}

/// =========================================================================
/// SupaQuery
/// =========================================================================
class SupaQuery {
  final String table;
  final List<MapEntry<String, dynamic>> _filters = [];
  String? _orderField;
  bool _orderDesc = false;
  int? _limitCount;
  bool _limitToLast = false;
  String _selectStr = '*';

  SupaQuery(this.table);

  SupaQuery where(String field, {dynamic isEqualTo}) {
    _filters.add(MapEntry(field, isEqualTo));
    return this;
  }

  SupaQuery orderBy(String field, {bool descending = false}) {
    _orderField = field;
    _orderDesc = descending;
    return this;
  }

  SupaQuery limit(int n) {
    _limitCount = n;
    return this;
  }

  SupaQuery select(String s) {
    _selectStr = s;
    return this;
  }

  Future<SupaQueryResult> get() async {
    try {
      var q = SupabaseService.client.from(table).select(_selectStr);
      for (final f in _filters) {
        q = q.eq(f.key, f.value);
      }
      if (_orderField != null) {
        q = q.order(_orderField!, ascending: !_orderDesc);
      }
      if (_limitCount != null) {
        q = q.limit(_limitCount!);
      }
      final rows = await q;
      final docs = (rows as List)
          .map((row) => SupaDoc(
                SupaDocRef(table, row['id']?.toString() ?? ''),
                Map<String, dynamic>.from(row),
              ))
          .toList();
      return SupaQueryResult(docs);
    } catch (e) {
      debugPrint('SupaQuery error: $e');
      return SupaQueryResult([]);
    }
  }
}

/// =========================================================================
/// SupaDocRef
/// =========================================================================
class SupaDocRef {
  final String collectionName;
  final String id;
  SupaDocRef(this.collectionName, this.id);

  SupaCollection collection(String name) => SupaCollection(name);

  Future<SupaDoc> get() async {
    try {
      final row = await SupabaseService.client
          .from(collectionName)
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) {
        return SupaDoc(this, null);
      }
      return SupaDoc(this, Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('SupaDocRef.get error: $e');
      return SupaDoc(this, null);
    }
  }

  Future<void> set(Map<String, dynamic> data) async {
    await SupabaseService.client
        .from(collectionName)
        .upsert({...data, 'id': id});
  }

  Future<void> update(Map<String, dynamic> data) async {
    final clean = <String, dynamic>{};
    for (final entry in data.entries) {
      final v = entry.value;
      if (v is Map && v['__op'] == 'delete') {
        clean[entry.key] = null;
      } else if (v is Map && v['__op'] == 'increment') {
        // Read current value then increment
        try {
          final row = await SupabaseService.client
              .from(collectionName)
              .select(entry.key)
              .eq('id', id)
              .maybeSingle();
          final current = (row?[entry.key] as num?)?.toDouble() ?? 0;
          final delta = (v['value'] as num?)?.toDouble() ?? 0;
          clean[entry.key] = (current + delta).toInt();
        } catch (_) {
          clean[entry.key] = (v['value'] as num?)?.toInt() ?? 0;
        }
      } else if (v is Map && (v['__op'] == 'arrayUnion' || v['__op'] == 'arrayRemove')) {
        // Read current array then modify
        try {
          final row = await SupabaseService.client
              .from(collectionName)
              .select(entry.key)
              .eq('id', id)
              .maybeSingle();
          final List current = (row?[entry.key] as List?) ?? [];
          final List values = (v['value'] as List?) ?? [];
          final List updated;
          if (v['__op'] == 'arrayUnion') {
            updated = [...current];
            for (final item in values) {
              if (!updated.contains(item)) updated.add(item);
            }
          } else {
            updated = current.where((item) => !values.contains(item)).toList();
          }
          clean[entry.key] = updated;
        } catch (_) {
          clean[entry.key] = v['value'];
        }
      } else {
        clean[entry.key] = v;
      }
    }
    await SupabaseService.client
        .from(collectionName)
        .update(clean)
        .eq('id', id);
  }

  Future<void> delete() async {
    await SupabaseService.client.from(collectionName).delete().eq('id', id);
  }

  Stream<SupaDoc> snapshots() {
    return SupabaseService.client
        .from(collectionName)
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .map((rows) {
      if (rows.isEmpty) return SupaDoc(this, null);
      return SupaDoc(this, Map<String, dynamic>.from(rows.first));
    });
  }
}

/// =========================================================================
/// SupaDoc
/// =========================================================================
class SupaDoc {
  final SupaDocRef reference;
  final Map<String, dynamic>? _data;

  SupaDoc(this.reference, this._data);

  bool get exists => _data != null;

  Map<String, dynamic>? data() => _data;

  String get id => reference.id;
}

/// =========================================================================
/// SupaSnap
/// =========================================================================
class SupaSnap {
  final List<SupaDoc> docs;
  SupaSnap(this.docs);
}

/// =========================================================================
/// SupaQueryResult
/// =========================================================================
class SupaQueryResult {
  final List<SupaDoc> docs;
  SupaQueryResult(this.docs);
}

/// =========================================================================
/// SupaField
/// =========================================================================
class SupaField {
  SupaField._();

  static String serverTimestamp() => DateTime.now().toIso8601String();

  static Map<String, dynamic> increment(num value) =>
      {'__op': 'increment', 'value': value};

  static Map<String, dynamic> arrayUnion(List<dynamic> values) =>
      {'__op': 'arrayUnion', 'value': values};

  static Map<String, dynamic> arrayRemove(List<dynamic> values) =>
      {'__op': 'arrayRemove', 'value': values};

  static Map<String, dynamic> delete() => {'__op': 'delete'};
}

/// =========================================================================
/// SupaTime
/// =========================================================================
class SupaTime {
  final DateTime _dt;
  SupaTime(this._dt);

  static SupaTime now() => SupaTime(DateTime.now());

  static SupaTime fromDate(DateTime dt) => SupaTime(dt);

  DateTime toDate() => _dt;
}

/// =========================================================================
/// SupaSetOptions
/// =========================================================================
class SupaSetOptions {
  final bool merge;
  const SupaSetOptions({this.merge = false});
}

/// =========================================================================
/// SupaBatch
/// =========================================================================
class SupaBatch {
  final List<Future<void> Function()> _ops = [];

  void set(SupaDocRef ref, Map<String, dynamic> data, [SupaSetOptions? opts]) {
    _ops.add(() => ref.set(data));
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
    _ops.clear();
  }
}

/// =========================================================================
/// SupaTransaction
/// =========================================================================
class SupaTransaction {
  final List<Future<void> Function()> _ops = [];

  Future<SupaDoc> get(SupaDocRef ref) => ref.get();

  void set(SupaDocRef ref, Map<String, dynamic> data) {
    _ops.add(() => ref.set(data));
  }

  void update(SupaDocRef ref, Map<String, dynamic> data) {
    _ops.add(() => ref.update(data));
  }

  void delete(SupaDocRef ref) {
    _ops.add(() => ref.delete());
  }

  Future<void> _commit() async {
    for (final op in _ops) {
      await op();
    }
    _ops.clear();
  }

  void _rollback() {
    _ops.clear();
  }
}