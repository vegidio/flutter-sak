enum HttpMethod { get, post, put, delete, patch }

class RestRequest {
  final String path;
  final HttpMethod method;
  final Map<String, String>? headers;
  final Map<String, dynamic>? queryParameters;
  final dynamic body;
  final bool skipAuth;
  final Duration? cacheTtl;
  final bool? cacheable;

  const RestRequest({
    required this.path,
    this.method = HttpMethod.get,
    this.headers,
    this.queryParameters,
    this.body,
    this.skipAuth = false,
    this.cacheTtl,
    this.cacheable,
  });
}
