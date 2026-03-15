import 'package:dio/dio.dart';
import 'package:flutter_sak_rest/rest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HttpMethod', () {
    test('has all expected values', () {
      expect(HttpMethod.values, hasLength(5));
      expect(HttpMethod.values, contains(HttpMethod.get));
      expect(HttpMethod.values, contains(HttpMethod.post));
      expect(HttpMethod.values, contains(HttpMethod.put));
      expect(HttpMethod.values, contains(HttpMethod.delete));
      expect(HttpMethod.values, contains(HttpMethod.patch));
    });
  });

  group('RestRequest', () {
    test('creates with required path only', () {
      const request = RestRequest(path: '/users');
      expect(request.path, '/users');
      expect(request.method, HttpMethod.get);
      expect(request.headers, isNull);
      expect(request.queryParameters, isNull);
      expect(request.body, isNull);
      expect(request.skipAuth, false);
      expect(request.cacheTtl, isNull);
      expect(request.cacheable, isNull);
    });

    test('creates with all parameters', () {
      const request = RestRequest(
        path: '/users',
        method: HttpMethod.post,
        headers: {'Content-Type': 'application/json'},
        queryParameters: {'page': 1},
        body: {'name': 'John'},
        skipAuth: true,
        cacheTtl: Duration(seconds: 30),
        cacheable: true,
      );

      expect(request.path, '/users');
      expect(request.method, HttpMethod.post);
      expect(request.headers, {'Content-Type': 'application/json'});
      expect(request.queryParameters, {'page': 1});
      expect(request.body, {'name': 'John'});
      expect(request.skipAuth, true);
      expect(request.cacheTtl, const Duration(seconds: 30));
      expect(request.cacheable, true);
    });

    test('supports all HTTP methods', () {
      for (final method in HttpMethod.values) {
        final request = RestRequest(path: '/test', method: method);
        expect(request.method, method);
      }
    });
  });

  group('RestResponse', () {
    test('creates with required parameters', () {
      const response = RestResponse<String>(body: 'hello', statusCode: 200, headers: {});

      expect(response.body, 'hello');
      expect(response.statusCode, 200);
      expect(response.headers, isEmpty);
    });

    test('stores typed body', () {
      const response = RestResponse<Map<String, dynamic>>(
        body: {'id': 1, 'name': 'John'},
        statusCode: 200,
        headers: {},
      );

      expect(response.body['id'], 1);
      expect(response.body['name'], 'John');
    });

    test('stores headers', () {
      const response = RestResponse<String>(
        body: '',
        statusCode: 200,
        headers: {
          'content-type': ['application/json'],
          'x-request-id': ['abc123'],
        },
      );

      expect(response.headers['content-type'], ['application/json']);
      expect(response.headers['x-request-id'], ['abc123']);
    });
  });

  group('RestError', () {
    test('InvalidUrlError has correct message and url', () {
      final error = InvalidUrlError('http://bad url');
      expect(error.url, 'http://bad url');
      expect(error.message, 'Invalid URL: http://bad url');
      expect(error.toString(), contains('InvalidUrlError'));
      expect(error.toString(), contains('Invalid URL: http://bad url'));
    });

    test('NetworkError with cause', () {
      final error = NetworkError(cause: 'timeout');
      expect(error.cause, 'timeout');
      expect(error.message, 'Network error: timeout');
    });

    test('NetworkError without cause', () {
      final error = NetworkError();
      expect(error.cause, isNull);
      expect(error.message, 'Network error: unknown');
    });

    test('HttpError with status code and body', () {
      final error = HttpError(statusCode: 404, responseBody: 'Not Found');
      expect(error.statusCode, 404);
      expect(error.responseBody, 'Not Found');
      expect(error.message, 'HTTP error 404');
    });

    test('HttpError without response body', () {
      final error = HttpError(statusCode: 500);
      expect(error.statusCode, 500);
      expect(error.responseBody, isNull);
    });

    test('DecodingError with cause', () {
      final cause = FormatException('bad json');
      final error = DecodingError(cause: cause);
      expect(error.cause, cause);
      expect(error.message, contains('Decoding error'));
    });

    test('DecodingError without cause', () {
      final error = DecodingError();
      expect(error.cause, isNull);
      expect(error.message, 'Decoding error: unknown');
    });

    test('TokenRefreshError with cause', () {
      final error = TokenRefreshError(cause: 'expired');
      expect(error.cause, 'expired');
      expect(error.message, contains('Token refresh failed'));
    });

    test('TokenRefreshError without cause', () {
      final error = TokenRefreshError();
      expect(error.cause, isNull);
      expect(error.message, 'Token refresh failed: unknown');
    });

    test('all errors implement Exception', () {
      expect(InvalidUrlError('x'), isA<Exception>());
      expect(NetworkError(), isA<Exception>());
      expect(HttpError(statusCode: 500), isA<Exception>());
      expect(DecodingError(), isA<Exception>());
      expect(TokenRefreshError(), isA<Exception>());
    });

    test('all errors are RestError', () {
      expect(InvalidUrlError('x'), isA<RestError>());
      expect(NetworkError(), isA<RestError>());
      expect(HttpError(statusCode: 500), isA<RestError>());
      expect(DecodingError(), isA<RestError>());
      expect(TokenRefreshError(), isA<RestError>());
    });
  });

  group('CachePolicy', () {
    test('has correct defaults', () {
      const policy = CachePolicy();
      expect(policy.enabled, false);
      expect(policy.ttl, const Duration(seconds: 60));
      expect(policy.maxEntries, 100);
    });

    test('creates with custom values', () {
      const policy = CachePolicy(enabled: true, ttl: Duration(minutes: 5), maxEntries: 50);
      expect(policy.enabled, true);
      expect(policy.ttl, const Duration(minutes: 5));
      expect(policy.maxEntries, 50);
    });
  });

  group('RetryPolicy', () {
    test('has correct defaults', () {
      final policy = RetryPolicy();
      expect(policy.maxAttempts, 3);
      expect(policy.delay, const Duration(seconds: 1));
    });

    test('creates with custom values', () {
      final policy = RetryPolicy(maxAttempts: 5, delay: const Duration(milliseconds: 500));
      expect(policy.maxAttempts, 5);
      expect(policy.delay, const Duration(milliseconds: 500));
    });

    test('default shouldRetry returns true for connection timeout', () {
      final policy = RetryPolicy();
      final error = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(policy.shouldRetry(error), true);
    });

    test('default shouldRetry returns true for send timeout', () {
      final policy = RetryPolicy();
      final error = DioException(
        type: DioExceptionType.sendTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(policy.shouldRetry(error), true);
    });

    test('default shouldRetry returns true for receive timeout', () {
      final policy = RetryPolicy();
      final error = DioException(
        type: DioExceptionType.receiveTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(policy.shouldRetry(error), true);
    });

    test('default shouldRetry returns true for connection error', () {
      final policy = RetryPolicy();
      final error = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: '/test'),
      );
      expect(policy.shouldRetry(error), true);
    });

    test('default shouldRetry returns true for 5xx errors', () {
      final policy = RetryPolicy();
      for (final statusCode in [500, 502, 503, 504]) {
        final error = DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
          ),
        );
        expect(policy.shouldRetry(error), true, reason: 'Should retry $statusCode');
      }
    });

    test('default shouldRetry returns false for 401', () {
      final policy = RetryPolicy();
      final error = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(requestOptions: RequestOptions(path: '/test'), statusCode: 401),
      );
      expect(policy.shouldRetry(error), false);
    });

    test('default shouldRetry returns false for 4xx errors (non-401)', () {
      final policy = RetryPolicy();
      for (final statusCode in [400, 403, 404, 422]) {
        final error = DioException(
          type: DioExceptionType.badResponse,
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
          ),
        );
        expect(policy.shouldRetry(error), false, reason: 'Should not retry $statusCode');
      }
    });

    test('accepts custom shouldRetry predicate', () {
      final policy = RetryPolicy(shouldRetry: (error) => error.response?.statusCode == 429);

      final retryable = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: RequestOptions(path: '/test'),
        response: Response(requestOptions: RequestOptions(path: '/test'), statusCode: 429),
      );

      final nonRetryable = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
      );

      expect(policy.shouldRetry(retryable), true);
      expect(policy.shouldRetry(nonRetryable), false);
    });
  });

  group('RestConfiguration', () {
    test('creates with required baseUrl only', () {
      final config = RestConfiguration(baseUrl: 'https://api.example.com');
      expect(config.baseUrl, 'https://api.example.com');
      expect(config.defaultHeaders, isEmpty);
      expect(config.retryPolicy, isA<RetryPolicy>());
      expect(config.cachePolicy.enabled, false);
      expect(config.tokenProvider, isNull);
      expect(config.tokenRefresher, isNull);
      expect(config.preemptiveRefreshSeconds, 60);
    });

    test('creates with all parameters', () {
      Future<String> provider() async => 'token';
      Future<String> refresher() async => 'new-token';

      final config = RestConfiguration(
        baseUrl: 'https://api.example.com',
        defaultHeaders: {'Accept': 'application/json'},
        retryPolicy: RetryPolicy(maxAttempts: 5),
        cachePolicy: const CachePolicy(enabled: true),
        tokenProvider: provider,
        tokenRefresher: refresher,
        preemptiveRefreshSeconds: 120,
      );

      expect(config.baseUrl, 'https://api.example.com');
      expect(config.defaultHeaders, {'Accept': 'application/json'});
      expect(config.retryPolicy.maxAttempts, 5);
      expect(config.cachePolicy.enabled, true);
      expect(config.tokenProvider, isNotNull);
      expect(config.tokenRefresher, isNotNull);
      expect(config.preemptiveRefreshSeconds, 120);
    });
  });
}
