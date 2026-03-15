import 'dart:convert';

import 'package:dio/dio.dart';

/// Creates a test JWT token with the given expiration time.
/// The token is structurally valid but not cryptographically signed.
String createTestJwt({required DateTime expiresAt}) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '');
  final payload = base64Url
      .encode(utf8.encode('{"sub":"test","exp":${expiresAt.millisecondsSinceEpoch ~/ 1000}}'))
      .replaceAll('=', '');
  const signature = 'fakesignature';
  return '$header.$payload.$signature';
}

/// Creates a JWT that expires far in the future.
String createValidJwt() => createTestJwt(expiresAt: DateTime.now().add(const Duration(hours: 1)));

/// Creates a JWT that has already expired.
String createExpiredJwt() => createTestJwt(expiresAt: DateTime.now().subtract(const Duration(hours: 1)));

/// Creates a JWT that expires within the given duration.
String createExpiringSoonJwt({Duration expiresIn = const Duration(seconds: 10)}) =>
    createTestJwt(expiresAt: DateTime.now().add(expiresIn));

/// A mock HTTP adapter that returns configurable responses.
class MockHttpAdapter implements HttpClientAdapter {
  Response<dynamic>? nextResponse;
  DioException? nextError;
  int callCount = 0;
  List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    requests.add(options);

    if (nextError != null) {
      throw nextError!;
    }

    final response = nextResponse ?? Response(requestOptions: options, data: '{"ok": true}', statusCode: 200);

    return ResponseBody.fromString(
      response.data?.toString() ?? '',
      response.statusCode ?? 200,
      headers: response.headers.map.map((key, value) => MapEntry(key, value)),
    );
  }

  @override
  void close({bool force = false}) {}
}
