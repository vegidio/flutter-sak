import 'package:flutter_sak_rest/src/auth/token_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('TokenManager', () {
    group('getValidToken', () {
      test('returns token when not expired', () async {
        final validToken = createValidJwt();
        final manager = TokenManager(
          tokenProvider: () async => validToken,
          tokenRefresher: (_) async => 'should-not-be-called',
          preemptiveRefreshSeconds: 60,
          send: (_) async => {},
        );

        final token = await manager.getValidToken();
        expect(token, validToken);
        manager.dispose();
      });

      test('refreshes token when expired', () async {
        final expiredToken = createExpiredJwt();
        final newToken = createValidJwt();

        final manager = TokenManager(
          tokenProvider: () async => expiredToken,
          tokenRefresher: (_) async => newToken,
          preemptiveRefreshSeconds: 60,
          send: (_) async => {},
        );

        final token = await manager.getValidToken();
        expect(token, newToken);
        manager.dispose();
      });
    });

    group('refreshToken', () {
      test('calls refresher and returns new token', () async {
        final newToken = createValidJwt();
        var refreshCount = 0;

        final manager = TokenManager(
          tokenProvider: () async => createExpiredJwt(),
          tokenRefresher: (_) async {
            refreshCount++;
            return newToken;
          },
          preemptiveRefreshSeconds: 60,
          send: (_) async => {},
        );

        final token = await manager.refreshToken();
        expect(token, newToken);
        expect(refreshCount, 1);
        manager.dispose();
      });

      test('deduplicates concurrent refresh calls', () async {
        var refreshCount = 0;
        final newToken = createValidJwt();

        final manager = TokenManager(
          tokenProvider: () async => createExpiredJwt(),
          tokenRefresher: (_) async {
            refreshCount++;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return newToken;
          },
          preemptiveRefreshSeconds: 60,
          send: (_) async => {},
        );

        // Launch multiple concurrent refresh calls
        final results = await Future.wait([manager.refreshToken(), manager.refreshToken(), manager.refreshToken()]);

        // All should return the same token
        expect(results, everyElement(newToken));
        // But refresher should only be called once
        expect(refreshCount, 1);
        manager.dispose();
      });

      test('propagates error to concurrent callers on failure', () async {
        final manager = TokenManager(
          tokenProvider: () async => createExpiredJwt(),
          tokenRefresher: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            throw Exception('refresh failed');
          },
          preemptiveRefreshSeconds: 60,
          send: (_) async => {},
        );

        // Launch two concurrent refresh calls so the completer's future is listened to
        final results = await Future.wait([
          manager.refreshToken().then((_) => 'ok').catchError((_) => 'error'),
          manager.refreshToken().then((_) => 'ok').catchError((_) => 'error'),
        ]);

        expect(results, everyElement('error'));
        manager.dispose();
      });

      test('allows retry after failed refresh', () async {
        var callCount = 0;
        final newToken = createValidJwt();

        final manager = TokenManager(
          tokenProvider: () async => createExpiredJwt(),
          tokenRefresher: (_) async {
            callCount++;
            if (callCount == 1) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
              throw Exception('first attempt fails');
            }
            return newToken;
          },
          preemptiveRefreshSeconds: 60,
          send: (_) async => {},
        );

        // First call should fail — use two concurrent callers to consume the completer
        final results = await Future.wait([
          manager.refreshToken().then((_) => 'ok').catchError((_) => 'error'),
          manager.refreshToken().then((_) => 'ok').catchError((_) => 'error'),
        ]);
        expect(results, everyElement('error'));

        // Second call should succeed (completer should be reset)
        final token = await manager.refreshToken();
        expect(token, newToken);
        expect(callCount, 2);
        manager.dispose();
      });
    });

    group('dispose', () {
      test('cancels preemptive refresh timer', () {
        final manager = TokenManager(
          tokenProvider: () async => createValidJwt(),
          tokenRefresher: (_) async => createValidJwt(),
          preemptiveRefreshSeconds: 60,
          send: (_) async => {},
        );

        manager.startPreemptiveRefresh();
        // Should not throw
        manager.dispose();
      });

      test('can be called multiple times safely', () {
        final manager = TokenManager(
          tokenProvider: () async => createValidJwt(),
          tokenRefresher: (_) async => createValidJwt(),
          preemptiveRefreshSeconds: 60,
          send: (_) async => {},
        );

        manager.dispose();
        manager.dispose(); // Should not throw
      });
    });
  });
}
