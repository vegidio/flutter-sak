import 'package:dio/dio.dart';

import 'auth/token_manager.dart';
import 'cache/response_cache.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/header_interceptor.dart';
import 'interceptors/log_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'log/log_policy.dart';
import 'rest_configuration.dart';
import 'rest_error.dart';
import 'rest_request.dart';
import 'rest_response.dart';

class RestClient {
  final Dio _dio;
  TokenManager? _tokenManager;
  final ResponseCache _cache;

  RestClient(RestConfiguration configuration)
    : _dio = Dio(BaseOptions(baseUrl: configuration.baseUrl)),
      _tokenManager = null,
      _cache = ResponseCache(maxEntries: configuration.cachePolicy.maxEntries) {
    // Build the token manager after _dio is initialized, so we can
    // create a RefreshSend that uses the same Dio instance (with skipAuth).
    if (configuration.tokenProvider != null && configuration.tokenRefresher != null) {
      final refresher = configuration.tokenRefresher!;

      Future<Map<String, dynamic>> refreshSend(RestRequest request) async {
        final response = await _dio.request<dynamic>(
          request.path,
          options: Options(
            method: request.method.name.toUpperCase(),
            headers: request.headers,
            extra: {'skipAuth': true},
          ),
          data: request.body,
          queryParameters: request.queryParameters,
        );
        return response.data as Map<String, dynamic>;
      }

      final tokenManager = TokenManager(
        tokenProvider: configuration.tokenProvider!,
        tokenRefresher: refresher,
        send: refreshSend,
        preemptiveRefreshSeconds: configuration.preemptiveRefreshSeconds,
      );
      _tokenManager = tokenManager;
    }

    // Interceptor order: Cache → Headers → Auth → Retry
    _dio.interceptors.add(CacheInterceptor(configuration.cachePolicy, _cache));
    _dio.interceptors.add(HeaderInterceptor(configuration.defaultHeaders));

    final tokenManager = _tokenManager;
    if (tokenManager != null) {
      _dio.interceptors.add(AuthInterceptor(tokenManager, _dio));
      tokenManager.startPreemptiveRefresh();
    }

    _dio.interceptors.add(RetryInterceptor(configuration.retryPolicy, _dio));

    if (configuration.logPolicy.logLevel != LogLevel.none) {
      _dio.interceptors.add(LoggingInterceptor(configuration.logPolicy));
    }
  }

  Future<RestResponse<T>> send<T>(RestRequest request, {T Function(dynamic json)? decoder}) async {
    try {
      final response = await _dio.request<dynamic>(
        request.path,
        options: Options(
          method: request.method.name.toUpperCase(),
          headers: request.headers,
          extra: {
            'skipAuth': request.skipAuth,
            if (request.cacheTtl != null) 'cacheTtl': request.cacheTtl,
            if (request.cacheable != null) 'cacheable': request.cacheable,
          },
        ),
        data: request.body,
        queryParameters: request.queryParameters,
      );

      final body = decoder != null ? decoder(response.data) : response.data as T;

      return RestResponse<T>(body: body, statusCode: response.statusCode ?? 0, headers: response.headers.map);
    } on DioException catch (e) {
      if (e.error is RestError) throw e.error!;

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          throw NetworkError(cause: e);
        case DioExceptionType.badResponse:
          throw HttpError(statusCode: e.response?.statusCode ?? 0, responseBody: e.response?.data);
        default:
          throw NetworkError(cause: e);
      }
    } catch (e) {
      if (e is RestError) rethrow;
      throw DecodingError(cause: e);
    }
  }

  void dispose() {
    _tokenManager?.dispose();
    _dio.close();
  }
}
