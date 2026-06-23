import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/cache_service.dart';

abstract class SupabaseCrudService<T> {
  final SupabaseClient client;
  final CacheService cacheService;
  final String table;

  SupabaseCrudService(this.table, {SupabaseClient? client, CacheService? cacheService})
      : client = client ?? Supabase.instance.client,
        cacheService = cacheService ?? CacheService();

  T fromJson(String id, Map<String, dynamic> json);

  Map<String, dynamic> toJson(T value);

  String get selectStatement => '*';

  Future<List<Map<String, dynamic>>> transformRows(
    List<Map<String, dynamic>> rows,
  ) async {
    return rows;
  }

  Map<String, dynamic> preparePayload(
    Map<String, dynamic> payload, {
    required bool isUpdate,
  }) {
    final normalized = Map<String, dynamic>.from(payload);
    normalized.remove('deleted_at');
    return normalized;
  }

  Map<String, dynamic> payloadFromValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value.cast<String, dynamic>());
    }
    return toJson(value as T);
  }

  Future<List<T>> getAllIncremental({
    bool forceFullFetch = false,
    bool includeDeleted = false,
  }) async {
    return getAll(includeDeleted: includeDeleted);
  }

  Future<List<T>> getAll({bool includeDeleted = false}) async {
    try {
      dynamic query = client.from(table).select(selectStatement);
      if (!includeDeleted) {
        query = query.eq('is_deleted', false);
      }
      final rows = await query;
      return mapResponseList(rows);
    } catch (error) {
      throw Exception('Failed to fetch from $table: $error');
    }
  }

  Future<T?> getById(String id) async {
    try {
      final row = await client
          .from(table)
          .select(selectStatement)
          .eq('id', normalizeIdValue(id))
          .eq('is_deleted', false)
          .maybeSingle();
      if (row == null) return null;
      return mapResponseSingle(row);
    } catch (error) {
      throw Exception('Failed to fetch $id from $table: $error');
    }
  }

  Future<T> create(dynamic value, {String? id}) async {
    try {
      final payload = preparePayload(payloadFromValue(value), isUpdate: false);
      if (id != null && id.trim().isNotEmpty) {
        payload['id'] = normalizeIdValue(id);
      }
      final row = await client
          .from(table)
          .insert(payload)
          .select(selectStatement)
          .single();
      return mapResponseSingle(row);
    } catch (error) {
      throw Exception('Failed to insert into $table: $error');
    }
  }

  Future<T> update(String id, dynamic value) async {
    try {
      final payload = preparePayload(payloadFromValue(value), isUpdate: true);
      if (payload.isEmpty) {
        final existing = await getById(id);
        if (existing == null) {
          throw Exception('Record $id tidak ditemukan di $table.');
        }
        return existing;
      }
      final row = await client
          .from(table)
          .update(payload)
          .eq('id', normalizeIdValue(id))
          .select(selectStatement)
          .single();
      return mapResponseSingle(row);
    } catch (error) {
      throw Exception('Failed to update $id in $table: $error');
    }
  }

  Future<void> delete(String id) async {
    try {
      await client.from(table).update(<String, dynamic>{
        'is_deleted': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', normalizeIdValue(id));
    } catch (error) {
      throw Exception('Failed to delete $id from $table: $error');
    }
  }

  Future<List<T>> mapResponseList(dynamic rows) async {
    final records = (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final transformed = await transformRows(records);
    return transformed
        .map((record) => fromJson(record['id']?.toString() ?? '', record))
        .toList(growable: false);
  }

  Future<T> mapResponseSingle(dynamic row) async {
    final record = Map<String, dynamic>.from(row as Map);
    final transformed = await transformRows(<Map<String, dynamic>>[record]);
    final normalized = transformed.first;
    return fromJson(normalized['id']?.toString() ?? '', normalized);
  }

  Object normalizeIdValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      final integerValue = int.tryParse(trimmed);
      if (integerValue != null) {
        return integerValue;
      }
      return trimmed;
    }
    return value;
  }
}
