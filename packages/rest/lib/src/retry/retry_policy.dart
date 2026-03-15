import 'package:dio/dio.dart';

class RetryPolicy {
  final int maxAttempts;
  final Duration delay;
  final bool Function(DioException) shouldRetry;

  RetryPolicy({this.maxAttempts = 3, this.delay = const Duration(seconds: 1), bool Function(DioException)? shouldRetry})
    : shouldRetry = shouldRetry ?? _defaultShouldRetry;

  static bool _defaultShouldRetry(DioException error) {
    // Don't retry 401s — handled by AuthInterceptor
    if (error.response?.statusCode == 401) return false;

    // Retry on connection/timeout errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on 5xx server errors
    final statusCode = error.response?.statusCode;
    if (statusCode != null && statusCode >= 500) return true;

    return false;
  }
}
