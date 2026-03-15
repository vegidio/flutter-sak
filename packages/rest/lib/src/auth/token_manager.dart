import 'dart:async';

import 'jwt_utility.dart';

class TokenManager {
  final Future<String> Function() _tokenProvider;
  final Future<String> Function() _tokenRefresher;
  final int _preemptiveRefreshSeconds;

  Timer? _refreshTimer;
  Completer<String>? _refreshCompleter;

  TokenManager({
    required Future<String> Function() tokenProvider,
    required Future<String> Function() tokenRefresher,
    required int preemptiveRefreshSeconds,
  }) : _tokenProvider = tokenProvider,
       _tokenRefresher = tokenRefresher,
       _preemptiveRefreshSeconds = preemptiveRefreshSeconds;

  void startPreemptiveRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        final token = await _tokenProvider();
        if (JwtUtility.isExpiringSoon(token, _preemptiveRefreshSeconds)) {
          await refreshToken();
        }
      } catch (_) {
        // Silently ignore preemptive refresh failures
      }
    });
  }

  Future<String> getValidToken() async {
    final token = await _tokenProvider();
    if (!JwtUtility.isExpired(token)) return token;
    return refreshToken();
  }

  Future<String> refreshToken() async {
    // Deduplicate concurrent refresh calls
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String>();

    try {
      final newToken = await _tokenRefresher();
      _refreshCompleter!.complete(newToken);
      return newToken;
    } catch (e) {
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
}
