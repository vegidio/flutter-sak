# rest

A high-level HTTP client for REST APIs built on [Dio](https://github.com/cfug/dio). Handles retry, caching, default headers, and automatic token refresh so you only write request logic.

## Quick start

```dart
import 'package:rest/rest.dart';

final client = RestClient(
  RestConfiguration(baseUrl: 'https://api.example.com'),
);

final response = await client.send<Map<String, dynamic>>(
  RestRequest(path: '/users/1'),
);

print(response.body['name']);  // "Alice"
print(response.statusCode);   // 200
```

### With Freezed / JSON decoding

Pass a `decoder` to deserialize the response into a typed model:

```dart
final response = await client.send<User>(
  RestRequest(path: '/users/1'),
  decoder: (json) => User.fromJson(json as Map<String, dynamic>),
);

print(response.body.name);  // "Alice"
```

## Sending requests

### GET with query parameters

```dart
final response = await client.send<List<dynamic>>(
  RestRequest(
    path: '/users',
    queryParameters: {'page': 1, 'limit': 20},
  ),
);
```

### POST with a JSON body

Pass any JSON-encodable value as `body`:

```dart
final response = await client.send<User>(
  RestRequest(
    path: '/users',
    method: HttpMethod.post,
    body: {'name': 'Alice'},
  ),
  decoder: (json) => User.fromJson(json as Map<String, dynamic>),
);
```

### Custom per-request headers

Per-request headers always take priority over `defaultHeaders`:

```dart
final response = await client.send<User>(
  RestRequest(
    path: '/users/1',
    headers: {'X-Request-ID': 'abc-123'},
  ),
  decoder: (json) => User.fromJson(json as Map<String, dynamic>),
);
```

## Error handling

All failures are thrown as subtypes of `RestError`:

| Type | When |
|------|------|
| `InvalidUrlError(url)` | The URL string could not be parsed |
| `NetworkError(cause)` | A transport-level failure (no connection, timeout, etc.) |
| `HttpError(statusCode, responseBody)` | Server returned a non-2xx status after all retries |
| `DecodingError(cause)` | Response body could not be decoded into `T` |
| `TokenRefreshError(cause)` | Token refresh was attempted but failed |

```dart
try {
  final response = await client.send<User>(
    RestRequest(path: '/users/1'),
    decoder: (json) => User.fromJson(json as Map<String, dynamic>),
  );
} on HttpError catch (e) {
  print('Server error ${e.statusCode}: ${e.responseBody}');
} on NetworkError catch (e) {
  print('Network failure: ${e.cause}');
} on TokenRefreshError {
  print('Session expired — redirect to login');
}
```

## Configuration

All behaviour is controlled through `RestConfiguration`, passed once at init time.

### Default headers

Headers added to every request. A header already present on an individual request takes priority.

```dart
final client = RestClient(
  RestConfiguration(
    baseUrl: 'https://api.example.com',
    defaultHeaders: {
      'Accept': 'application/json',
      'X-API-Version': '2',
    },
  ),
);
```

### Retry

Failed requests are retried automatically. The default policy retries up to 3 times with a 1-second delay on network failures and 5xx server errors.

```dart
final client = RestClient(
  RestConfiguration(
    baseUrl: 'https://api.example.com',
    retryPolicy: RetryPolicy(
      maxAttempts: 5,
      delay: Duration(seconds: 2),
    ),
  ),
);
```

### Caching

GET responses can be cached in memory with a configurable TTL. Once enabled, every GET request is eligible for caching — the second call with the same URL returns the cached response without hitting the network.

```dart
final client = RestClient(
  RestConfiguration(
    baseUrl: 'https://api.example.com',
    cachePolicy: CachePolicy(
      enabled: true,
      ttl: Duration(seconds: 60),  // cache entries expire after 60 seconds
      maxEntries: 100,             // evict oldest entry when limit is reached
    ),
  ),
);

// First call hits the network and stores the response.
// Subsequent calls within the TTL return the cached response.
final response = await client.send<List<dynamic>>(
  RestRequest(path: '/users', queryParameters: {'page': 1}),
);
```

#### Per-request cache overrides

Override the global cache policy on individual requests:

```dart
// Cache this specific request with a longer TTL
final response = await client.send<Map<String, dynamic>>(
  RestRequest(
    path: '/config',
    cacheable: true,                    // enable caching even if globally disabled
    cacheTtl: Duration(minutes: 10),    // custom TTL for this request
  ),
);
```

## Authentication

### Attaching a token to every request

Use `tokenProvider` to supply the current token. Once configured, every request automatically receives an `Authorization: Bearer <token>` header.

```dart
final client = RestClient(
  RestConfiguration(
    baseUrl: 'https://api.example.com',
    tokenProvider: () async => secureStorage.read('jwt'),
  ),
);
```

### Skipping auth on specific requests

Set `skipAuth: true` to opt out of token injection — useful for login or public endpoints:

```dart
final response = await client.send<LoginResponse>(
  RestRequest(
    path: '/auth/login',
    method: HttpMethod.post,
    body: {'email': email, 'password': password},
    skipAuth: true,  // no token attached
  ),
  decoder: (json) => LoginResponse.fromJson(json as Map<String, dynamic>),
);
```

### Automatic token refresh on 401

Provide `tokenRefresher` to fetch a new token when a 401 is received. The callback receives a `send` function that lets you make HTTP requests using the client's own connection — no need to create a separate client or deal with Dio directly. The client refreshes the token once and retries the original request automatically. Concurrent requests that all hit 401 share a single refresh call.

```dart
final client = RestClient(
  RestConfiguration(
    baseUrl: 'https://api.example.com',
    tokenProvider: () async => secureStorage.read('jwt'),
    tokenRefresher: (send) async {
      final refreshToken = await secureStorage.read('refreshToken');
      final response = await send(
        RestRequest(
          path: '/auth/refresh',
          headers: {'Authorization': 'Bearer $refreshToken'},
        ),
      );
      final newToken = response['accessToken'] as String;
      await secureStorage.write('jwt', newToken);
      return newToken;
    },
  ),
);
```

The `send` function accepts a `RestRequest` (the same type used with `client.send()`) and returns the response body as `Map<String, dynamic>`. Auth is automatically skipped on refresh requests so there is no risk of infinite loops.

### Preemptive JWT refresh

Avoid 401 errors entirely by refreshing the token before it expires. Use `preemptiveRefreshSeconds` to control how far in advance to refresh (default: 60 seconds). The client polls the token expiry in the background and refreshes automatically when it falls within the threshold.

```dart
final client = RestClient(
  RestConfiguration(
    baseUrl: 'https://api.example.com',
    tokenProvider: () async => secureStorage.read('jwt'),
    tokenRefresher: (send) async {
      final refreshToken = await secureStorage.read('refreshToken');
      final response = await send(
        RestRequest(
          path: '/auth/refresh',
          headers: {'Authorization': 'Bearer $refreshToken'},
        ),
      );
      final newToken = response['accessToken'] as String;
      await secureStorage.write('jwt', newToken);
      return newToken;
    },
    preemptiveRefreshSeconds: 60,  // refresh 60 s before expiry
  ),
);
```

> **Note:** Call `client.dispose()` when the client is no longer needed (e.g. on logout) to cancel the background refresh timer and release resources.

## Key types

| Type | Role |
|------|------|
| `RestClient` | Main entry point — create once, reuse everywhere |
| `RestConfiguration` | All client behaviour in one place |
| `RestRequest` | Describes a single HTTP request |
| `RestResponse<T>` | Decoded response body + `statusCode` + `headers` |
| `RetryPolicy` | `maxAttempts` + `delay` + `shouldRetry` predicate |
| `CachePolicy` | `enabled`, `ttl`, `maxEntries` |
| `RefreshSend` | Typedef for the `send` function passed to `tokenRefresher` |
| `RestError` | Sealed error hierarchy thrown on failure |
