sealed class RestError implements Exception {
  final String message;
  const RestError(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class InvalidUrlError extends RestError {
  final String url;
  InvalidUrlError(this.url) : super('Invalid URL: $url');
}

class NetworkError extends RestError {
  final Object? cause;
  NetworkError({this.cause}) : super('Network error: ${cause ?? 'unknown'}');
}

class HttpError extends RestError {
  final int statusCode;
  final dynamic responseBody;
  HttpError({required this.statusCode, this.responseBody}) : super('HTTP error $statusCode');
}

class DecodingError extends RestError {
  final Object? cause;
  DecodingError({this.cause}) : super('Decoding error: ${cause ?? 'unknown'}');
}

class TokenRefreshError extends RestError {
  final Object? cause;
  TokenRefreshError({this.cause}) : super('Token refresh failed: ${cause ?? 'unknown'}');
}
