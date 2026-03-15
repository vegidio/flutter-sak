import 'package:dio/dio.dart';

import '../cache/cache_policy.dart';
import '../cache/response_cache.dart';

class CacheInterceptor extends Interceptor {
  final CachePolicy _policy;
  final ResponseCache _cache;

  CacheInterceptor(this._policy, this._cache);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() != 'GET') {
      handler.next(options);
      return;
    }

    final cacheable = options.extra['cacheable'] as bool? ?? _policy.enabled;
    if (!cacheable) {
      handler.next(options);
      return;
    }

    final key = ResponseCache.makeKey(options.method, options.uri);
    final cached = _cache.get(key);

    if (cached != null) {
      handler.resolve(
        Response(
          requestOptions: options,
          data: cached.data,
          statusCode: cached.statusCode,
          headers: cached.headers,
          extra: {...cached.extra, 'fromCache': true},
        ),
      );
      return;
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;

    if (options.method.toUpperCase() != 'GET') {
      handler.next(response);
      return;
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      handler.next(response);
      return;
    }

    final cacheable = options.extra['cacheable'] as bool? ?? _policy.enabled;
    if (!cacheable) {
      handler.next(response);
      return;
    }

    final ttl = options.extra['cacheTtl'] as Duration? ?? _policy.ttl;
    final key = ResponseCache.makeKey(options.method, options.uri);
    _cache.put(key, response, ttl);

    handler.next(response);
  }
}
