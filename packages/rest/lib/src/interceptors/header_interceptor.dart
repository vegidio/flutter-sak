import 'package:dio/dio.dart';

class HeaderInterceptor extends Interceptor {
  final Map<String, String> _defaultHeaders;

  HeaderInterceptor(this._defaultHeaders);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Apply default headers first, then let per-request headers override
    final perRequestHeaders = Map<String, dynamic>.from(options.headers);
    options.headers = {..._defaultHeaders, ...perRequestHeaders};
    handler.next(options);
  }
}
