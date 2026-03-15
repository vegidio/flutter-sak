import 'package:dio/dio.dart';

import '../auth/token_manager.dart';
import '../rest_error.dart';

class AuthInterceptor extends Interceptor {
  final TokenManager _tokenManager;
  final Dio _dio;

  AuthInterceptor(this._tokenManager, this._dio);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }

    try {
      final token = await _tokenManager.getValidToken();
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: TokenRefreshError(cause: e),
        ),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || err.requestOptions.extra['skipAuth'] == true) {
      handler.next(err);
      return;
    }

    // Prevent infinite retry loops
    if (err.requestOptions.extra['_authRetried'] == true) {
      handler.next(err);
      return;
    }

    try {
      final newToken = await _tokenManager.refreshToken();
      final options = err.requestOptions;
      options.headers['Authorization'] = 'Bearer $newToken';
      options.extra['_authRetried'] = true;

      final response = await _dio.fetch(options);
      handler.resolve(response);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: TokenRefreshError(cause: e),
        ),
      );
    }
  }
}
