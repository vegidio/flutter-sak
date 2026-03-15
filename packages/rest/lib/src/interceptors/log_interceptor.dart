import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../log/log_policy.dart';

class LoggingInterceptor extends Interceptor {
  final LogPolicy _policy;
  final void Function(String message) _logger;

  LoggingInterceptor(this._policy, {void Function(String message)? logger})
    : _logger = logger ?? ((msg) => developer.log(msg, name: 'RestClient'));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_policy.logLevel == LogLevel.none) {
      handler.next(options);
      return;
    }

    options.extra['_requestStartTime'] = DateTime.now().millisecondsSinceEpoch;

    final method = options.method.toUpperCase();
    final url = options.uri.toString();

    _logger('--> $method $url');

    if (_policy.logLevel.index >= LogLevel.headers.index) {
      options.headers.forEach((key, value) {
        _logger('$key: $value');
      });
    }

    if (_policy.logLevel == LogLevel.body && options.data != null) {
      _logger('');
      _logger(options.data.toString());
    }

    _logger('');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_policy.logLevel == LogLevel.none) {
      handler.next(response);
      return;
    }

    final elapsed = _elapsed(response.requestOptions);
    final status = response.statusCode;
    final url = response.requestOptions.uri.toString();

    _logger('<-- $status $url (${elapsed}ms)');

    if (_policy.logLevel.index >= LogLevel.headers.index) {
      response.headers.forEach((name, values) {
        _logger('$name: ${values.join(', ')}');
      });
    }

    if (_policy.logLevel == LogLevel.body && response.data != null) {
      _logger('');
      _logger(response.data.toString());
    }

    _logger('');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_policy.logLevel == LogLevel.none) {
      handler.next(err);
      return;
    }

    final elapsed = _elapsed(err.requestOptions);
    final url = err.requestOptions.uri.toString();

    _logger('<-- ERROR $url (${elapsed}ms)');
    _logger('${err.type}: ${err.message}');

    if (_policy.logLevel.index >= LogLevel.headers.index && err.response != null) {
      err.response!.headers.forEach((name, values) {
        _logger('$name: ${values.join(', ')}');
      });
    }

    if (_policy.logLevel == LogLevel.body && err.response?.data != null) {
      _logger('');
      _logger(err.response!.data.toString());
    }

    _logger('');
    handler.next(err);
  }

  int _elapsed(RequestOptions options) {
    final startTime = options.extra['_requestStartTime'] as int?;
    if (startTime == null) return 0;
    return DateTime.now().millisecondsSinceEpoch - startTime;
  }
}
