import 'dart:collection';

import 'package:dio/dio.dart';

class _CacheEntry {
  final Response<dynamic> response;
  final DateTime expiresAt;

  _CacheEntry({required this.response, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ResponseCache {
  final int maxEntries;
  final LinkedHashMap<String, _CacheEntry> _store = LinkedHashMap();

  ResponseCache({required this.maxEntries});

  void put(String key, Response<dynamic> response, Duration ttl) {
    // Evict oldest if at capacity
    while (_store.length >= maxEntries) {
      _store.remove(_store.keys.first);
    }

    _store[key] = _CacheEntry(response: response, expiresAt: DateTime.now().add(ttl));
  }

  Response<dynamic>? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }

    return entry.response;
  }

  void clear() => _store.clear();

  static String makeKey(String method, Uri uri) {
    final sortedParams = Map.fromEntries(uri.queryParameters.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    final normalizedUri = uri.replace(queryParameters: sortedParams.isEmpty ? null : sortedParams);
    return '${method.toUpperCase()}:$normalizedUri';
  }
}
