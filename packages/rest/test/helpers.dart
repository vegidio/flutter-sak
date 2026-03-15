import 'dart:convert';

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
