import 'cache/cache_policy.dart';
import 'retry/retry_policy.dart';

class RestConfiguration {
  final String baseUrl;
  final Map<String, String> defaultHeaders;
  final RetryPolicy retryPolicy;
  final CachePolicy cachePolicy;
  final Future<String> Function()? tokenProvider;
  final Future<String> Function()? tokenRefresher;
  final int preemptiveRefreshSeconds;

  RestConfiguration({
    required this.baseUrl,
    this.defaultHeaders = const {},
    RetryPolicy? retryPolicy,
    this.cachePolicy = const CachePolicy(),
    this.tokenProvider,
    this.tokenRefresher,
    this.preemptiveRefreshSeconds = 60,
  }) : retryPolicy = retryPolicy ?? RetryPolicy();
}
