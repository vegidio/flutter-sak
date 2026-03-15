import 'package:dio/dio.dart';
import 'package:flutter_sak_rest/rest.dart';
import 'package:flutter_sak_rest/src/interceptors/log_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

class MockLogger extends Mock {
  void call(String message);
}

void main() {
  late Dio dio;
  late MockHttpAdapter mockAdapter;
  late MockLogger mockLogger;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    mockAdapter = MockHttpAdapter();
    dio.httpClientAdapter = mockAdapter;
    mockLogger = MockLogger();
  });

  group('LoggingInterceptor', () {
    test('does not log when level is none', () async {
      dio.interceptors.add(LoggingInterceptor(const LogPolicy(logLevel: LogLevel.none), logger: mockLogger.call));

      await dio.get('/test');

      verifyNever(() => mockLogger.call(any()));
    });

    test('logs request and response lines at basic level', () async {
      dio.interceptors.add(LoggingInterceptor(const LogPolicy(logLevel: LogLevel.basic), logger: mockLogger.call));

      await dio.get('/test');

      verify(() => mockLogger.call(any(that: contains('--> GET')))).called(1);
      verify(() => mockLogger.call(any(that: contains('<-- 200')))).called(1);
    });

    test('logs headers at headers level', () async {
      dio.interceptors.add(LoggingInterceptor(const LogPolicy(logLevel: LogLevel.headers), logger: mockLogger.call));

      await dio.get('/test', options: Options(headers: {'X-Custom': 'value'}));

      verify(() => mockLogger.call(any(that: contains('--> GET')))).called(1);
      verify(() => mockLogger.call(any(that: contains('X-Custom')))).called(1);
      verify(() => mockLogger.call(any(that: contains('<-- 200')))).called(1);
    });

    test('logs body at body level', () async {
      dio.interceptors.add(LoggingInterceptor(const LogPolicy(logLevel: LogLevel.body), logger: mockLogger.call));

      await dio.post('/test', data: {'name': 'John'});

      verify(() => mockLogger.call(any(that: contains('--> POST')))).called(1);
      verify(() => mockLogger.call(any(that: contains('John')))).called(1);
      verify(() => mockLogger.call(any(that: contains('<-- 200')))).called(1);
    });

    test('logs response body at body level', () async {
      mockAdapter.nextResponse = Response(
        requestOptions: RequestOptions(path: '/test'),
        data: '{"result": "ok"}',
        statusCode: 200,
      );

      dio.interceptors.add(LoggingInterceptor(const LogPolicy(logLevel: LogLevel.body), logger: mockLogger.call));

      await dio.get('/test');

      verify(() => mockLogger.call(any(that: contains('result')))).called(1);
    });

    test('logs errors', () async {
      mockAdapter.nextError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/test'),
        message: 'Connection timeout',
      );

      dio.interceptors.add(LoggingInterceptor(const LogPolicy(logLevel: LogLevel.basic), logger: mockLogger.call));

      try {
        await dio.get('/test');
      } catch (_) {}

      verify(() => mockLogger.call(any(that: contains('--> GET')))).called(1);
      verify(() => mockLogger.call(any(that: contains('<-- ERROR')))).called(1);
    });

    test('does not log body at headers level', () async {
      dio.interceptors.add(LoggingInterceptor(const LogPolicy(logLevel: LogLevel.headers), logger: mockLogger.call));

      await dio.post('/test', data: {'secret': 'data'});

      verifyNever(() => mockLogger.call(any(that: contains('secret'))));
    });

    test('does not log headers at basic level', () async {
      dio.interceptors.add(LoggingInterceptor(const LogPolicy(logLevel: LogLevel.basic), logger: mockLogger.call));

      await dio.get('/test', options: Options(headers: {'X-Secret': 'hidden'}));

      verifyNever(() => mockLogger.call(any(that: contains('X-Secret'))));
    });
  });
}
