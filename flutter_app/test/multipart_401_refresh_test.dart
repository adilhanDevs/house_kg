// Multipart-загрузка (медиа) и протухший токен: сервер выдаёт 401,
// клиент обновляет токен и должен отправить исходный multipart-запрос
// заново — ровно один раз. Сейчас это не так: см. AuthInterceptorClient.send
// в lib/data/api_client.dart — `if (request is! http.MultipartRequest)`
// пропускает повтор целиком для multipart, и вызывающий получает 401.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:house_kgz/data/api_client.dart';

class _FlakyUploadServer extends http.BaseClient {
  int uploadAttempts = 0;
  int refreshCalls = 0;
  final List<int> receivedBodySizes = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && request.url.path.contains('/media/')) {
      uploadAttempts++;
      // Байты тела реально дошли — не пустой повтор после однократного
      // потока.
      final bytes = await request.finalize().toBytes();
      receivedBodySizes.add(bytes.length);

      if (uploadAttempts == 1) {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"detail":"expired"}')),
          401,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"id": 1, "kind": "photo"}')),
        201,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }
}

void main() {
  _extraTests();
  test('multipart upload retries once after a successful token refresh', () async {
    final server = _FlakyUploadServer();
    final client = ListingApiClient(baseUrl: 'https://test.local', client: server);
    client.setToken('stale-token');
    client.setTokenRefreshCallback(() async {
      server.refreshCalls++;
      return 'fresh-token';
    });

    final result = await client.uploadMedia(
      'listing-1',
      bytes: List<int>.filled(1024, 1),
      filename: 'photo.jpg',
      kind: 'photo',
    );

    expect(result['id'], 1);
    expect(server.uploadAttempts, 2, reason: 'должно быть ровно два запроса: неудача + один повтор');
    expect(server.refreshCalls, 1);
    expect(server.receivedBodySizes[1], greaterThan(0),
        reason: 'повторный запрос должен нести тело файла, а не пустой multipart');
  });
}

class _AlwaysUnauthorizedServer extends http.BaseClient {
  int uploadAttempts = 0;
  int refreshCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && request.url.path.contains('/media/')) {
      uploadAttempts++;
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"detail":"expired"}')),
        401,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 404);
  }
}

void _extraTests() {
  test('a second 401 after the retry does not loop — fails cleanly once', () async {
    final server = _AlwaysUnauthorizedServer();
    final client = ListingApiClient(baseUrl: 'https://test.local', client: server);
    client.setToken('stale-token');
    client.setTokenRefreshCallback(() async {
      server.refreshCalls++;
      return 'still-bad-token';
    });

    await expectLater(
      client.uploadMedia('listing-1', bytes: [1, 2, 3], kind: 'photo'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'код', 401)),
    );

    expect(server.uploadAttempts, 2,
        reason: 'ровно попытка + один повтор, не бесконечный цикл');
  });
}
