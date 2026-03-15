import 'package:flutter_sak_rest/src/auth/jwt_utility.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('JwtUtility', () {
    group('expiryDate', () {
      test('returns expiration date for a valid token', () {
        final futureDate = DateTime.now().add(const Duration(hours: 1));
        final token = createTestJwt(expiresAt: futureDate);
        final expiry = JwtUtility.expiryDate(token);

        expect(expiry, isNotNull);
        // Allow 1 second tolerance due to second-level precision
        expect(expiry!.difference(futureDate).inSeconds.abs(), lessThanOrEqualTo(1));
      });

      test('returns null for an invalid token', () {
        expect(JwtUtility.expiryDate('not.a.jwt'), isNull);
      });

      test('returns null for empty string', () {
        expect(JwtUtility.expiryDate(''), isNull);
      });
    });

    group('isExpired', () {
      test('returns false for a valid non-expired token', () {
        final token = createValidJwt();
        expect(JwtUtility.isExpired(token), false);
      });

      test('returns true for an expired token', () {
        final token = createExpiredJwt();
        expect(JwtUtility.isExpired(token), true);
      });

      test('returns true for an invalid token', () {
        expect(JwtUtility.isExpired('invalid'), true);
      });
    });

    group('isExpiringSoon', () {
      test('returns false for token expiring far in the future', () {
        final token = createValidJwt(); // expires in 1 hour
        expect(JwtUtility.isExpiringSoon(token, 60), false);
      });

      test('returns true for token expiring within lead time', () {
        final token = createExpiringSoonJwt(expiresIn: const Duration(seconds: 30));
        expect(JwtUtility.isExpiringSoon(token, 60), true);
      });

      test('returns true for already expired token', () {
        final token = createExpiredJwt();
        expect(JwtUtility.isExpiringSoon(token, 60), true);
      });

      test('returns true for invalid token', () {
        expect(JwtUtility.isExpiringSoon('invalid', 60), true);
      });
    });
  });
}
