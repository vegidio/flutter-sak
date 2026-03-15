import 'package:dio/dio.dart';
import 'package:flutter_sak_rest/src/cache/response_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResponseCache', () {
    late ResponseCache cache;

    setUp(() {
      cache = ResponseCache(maxEntries: 3);
    });

    Response<dynamic> _makeResponse(String data, {int statusCode = 200}) {
      return Response(
        requestOptions: RequestOptions(path: '/test'),
        data: data,
        statusCode: statusCode,
      );
    }

    test('stores and retrieves a response', () {
      final response = _makeResponse('hello');
      cache.put('key1', response, const Duration(seconds: 60));

      final cached = cache.get('key1');
      expect(cached, isNotNull);
      expect(cached!.data, 'hello');
    });

    test('returns null for missing key', () {
      expect(cache.get('nonexistent'), isNull);
    });

    test('returns null for expired entry', () async {
      final response = _makeResponse('data');
      cache.put('key1', response, const Duration(milliseconds: 1));

      // Wait for entry to expire
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cache.get('key1'), isNull);
    });

    test('evicts oldest entry when at capacity', () {
      cache.put('key1', _makeResponse('first'), const Duration(seconds: 60));
      cache.put('key2', _makeResponse('second'), const Duration(seconds: 60));
      cache.put('key3', _makeResponse('third'), const Duration(seconds: 60));

      // At capacity (3), adding another should evict 'key1'
      cache.put('key4', _makeResponse('fourth'), const Duration(seconds: 60));

      expect(cache.get('key1'), isNull);
      expect(cache.get('key2'), isNotNull);
      expect(cache.get('key3'), isNotNull);
      expect(cache.get('key4'), isNotNull);
    });

    test('evicts multiple entries to stay within capacity', () {
      final smallCache = ResponseCache(maxEntries: 1);
      smallCache.put('key1', _makeResponse('first'), const Duration(seconds: 60));
      smallCache.put('key2', _makeResponse('second'), const Duration(seconds: 60));

      expect(smallCache.get('key1'), isNull);
      expect(smallCache.get('key2')?.data, 'second');
    });

    test('overwrites existing key', () {
      cache.put('key1', _makeResponse('original'), const Duration(seconds: 60));
      cache.put('key1', _makeResponse('updated'), const Duration(seconds: 60));

      expect(cache.get('key1')?.data, 'updated');
    });

    test('clear removes all entries', () {
      cache.put('key1', _makeResponse('a'), const Duration(seconds: 60));
      cache.put('key2', _makeResponse('b'), const Duration(seconds: 60));

      cache.clear();

      expect(cache.get('key1'), isNull);
      expect(cache.get('key2'), isNull);
    });
  });

  group('ResponseCache.makeKey', () {
    test('creates key from method and URI', () {
      final uri = Uri.parse('https://api.example.com/users');
      final key = ResponseCache.makeKey('GET', uri);
      expect(key, 'GET:https://api.example.com/users');
    });

    test('uppercases the method', () {
      final uri = Uri.parse('https://api.example.com/users');
      final key = ResponseCache.makeKey('get', uri);
      expect(key, 'GET:https://api.example.com/users');
    });

    test('sorts query parameters for consistent keys', () {
      final uri1 = Uri.parse('https://api.example.com/users?b=2&a=1');
      final uri2 = Uri.parse('https://api.example.com/users?a=1&b=2');

      final key1 = ResponseCache.makeKey('GET', uri1);
      final key2 = ResponseCache.makeKey('GET', uri2);

      expect(key1, key2);
    });

    test('handles URI without query parameters', () {
      final uri = Uri.parse('https://api.example.com/users');
      final key = ResponseCache.makeKey('GET', uri);
      expect(key, contains('/users'));
      expect(key, isNot(contains('?')));
    });

    test('different methods produce different keys', () {
      final uri = Uri.parse('https://api.example.com/users');
      final getKey = ResponseCache.makeKey('GET', uri);
      final postKey = ResponseCache.makeKey('POST', uri);
      expect(getKey, isNot(equals(postKey)));
    });

    test('different paths produce different keys', () {
      final uri1 = Uri.parse('https://api.example.com/users');
      final uri2 = Uri.parse('https://api.example.com/posts');
      final key1 = ResponseCache.makeKey('GET', uri1);
      final key2 = ResponseCache.makeKey('GET', uri2);
      expect(key1, isNot(equals(key2)));
    });
  });
}
