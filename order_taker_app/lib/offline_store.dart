import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-first persistence for the Order Taker app.
///
/// When the phone has no internet the app must still save orders, print
/// receipts and show previously-fetched data. Everything is staged here and
/// replayed to the Railway server as soon as connectivity is back.
class OfflineStore {
  static const _pendingOrdersKey = 'ot_pending_orders_v1';
  static const _mutationKey = 'ot_pending_mutations_v1';
  static const _cacheKey = 'ot_server_cache_v1';

  // ---------------------------------------------------------------- orders

  /// Orders created while offline (or whose POST failed). Each entry:
  ///   {
  ///     'clientId': 'ot-&lt;seq&gt;',     // unique local id
  ///     'payload':  {...},             // exact body sent to POST /pos/orders
  ///     'createdAt': iso,              // local creation time
  ///     'display':  {...},             // order map used to render it in lists
  ///   }
  /// After a successful POST the server returns a real order; the entry is
  /// removed and the local list is refreshed with the server copy.
  static Future<List<Map<String, dynamic>>> loadPendingOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOrdersKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      return (list is List ? list : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePendingOrders(
      List<Map<String, dynamic>> orders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingOrdersKey, jsonEncode(orders));
  }

  static Future<void> addPendingOrder(Map<String, dynamic> order) async {
    final list = await loadPendingOrders();
    list.removeWhere((o) => o['clientId'] == order['clientId']);
    list.insert(0, order);
    await savePendingOrders(list);
  }

  static Future<void> removePendingOrder(String clientId) async {
    final list = await loadPendingOrders();
    list.removeWhere((o) => o['clientId'] == clientId);
    await savePendingOrders(list);
  }

  // -------------------------------------------------------------- mutations

  /// Queued PUT/DELETE operations on already-synced orders that failed while
  /// offline, e.g. markPaid / markDue / cancel / delete.
  /// Each entry: { 'op': 'PUT'|'DELETE', 'id': orderId, 'body': {...}? }
  static Future<List<Map<String, dynamic>>> loadMutations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_mutationKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      return (list is List ? list : [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveMutations(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mutationKey, jsonEncode(list));
  }

  static Future<void> addMutation(Map<String, dynamic> mutation) async {
    final list = await loadMutations();
    list.add(mutation);
    await saveMutations(list);
  }

  static Future<void> removeMutation(int index) async {
    final list = await loadMutations();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await saveMutations(list);
    }
  }

  /// Compact queued mutations to the latest state per order id (the server
  /// only needs the final state; replaying stale PUTs just costs time).
  static Future<void> compactMutations() async {
    final list = await loadMutations();
    if (list.length < 2) return;
    final byId = <String, Map<String, dynamic>>{};
    final order = <String>[];
    final deletes = <String>[];
    for (final m in list) {
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (m['op'] == 'DELETE') {
        byId.remove(id);
        order.remove(id);
        deletes.add(id);
        continue;
      }
      if (deletes.contains(id)) continue;
      if (!byId.containsKey(id)) order.add(id);
      byId[id] = m;
    }
    final out = <Map<String, dynamic>>[];
    for (final id in order) {
      if (deletes.contains(id)) continue;
      out.add(byId[id]!);
    }
    for (final id in deletes) {
      out.add({'op': 'DELETE', 'id': id});
    }
    await saveMutations(out);
  }

  // ----------------------------------------------------------------- cache

  /// Last successful server snapshot for [categories, products, tables,
  /// orders, settings, mashallahSlots] so the UI still works offline.
  static Future<Map<String, dynamic>?> loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCache(Map<String, dynamic> cache) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(cache));
  }

  // --------------------------------------------------------------- helpers

  static Future<String> nextClientId() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt('ot_seq') ?? 0) + 1;
    await prefs.setInt('ot_seq', n);
    return 'ot-${DateTime.now().millisecondsSinceEpoch}-$n';
  }
}