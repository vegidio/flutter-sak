import 'package:jwt_decoder/jwt_decoder.dart';

class JwtUtility {
  JwtUtility._();

  static DateTime? expiryDate(String token) {
    try {
      return JwtDecoder.getExpirationDate(token);
    } catch (_) {
      return null;
    }
  }

  static bool isExpiringSoon(String token, int leadSeconds) {
    final expiry = expiryDate(token);
    if (expiry == null) return true;
    return DateTime.now().add(Duration(seconds: leadSeconds)).isAfter(expiry);
  }

  static bool isExpired(String token) {
    final expiry = expiryDate(token);
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }
}
