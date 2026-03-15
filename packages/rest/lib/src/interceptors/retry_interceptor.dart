import 'package:dio/dio.dart';

import '../retry/retry_policy.dart';

class RetryInterceptor extends Interceptor {
  final RetryPolicy _policy;
  final Dio _dio;

  RetryInterceptor(this._policy, this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryCount = (err.requestOptions.extra['_retryCount'] as int?) ?? 0;

    if (retryCount >= _policy.maxAttempts || !_policy.shouldRetry(err)) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(_policy.delay);

    err.requestOptions.extra['_retryCount'] = retryCount + 1;

    try {
      final response = await _dio.fetch(err.requestOptions);
      handler.resolve(response);
    } catch (e) {
      handler.next(err);
    }
  }
}
