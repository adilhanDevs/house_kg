// Персонализированная выдача объявлений для главной и каталога.
//
// Проверяется договор с сервером: фильтры уходят как есть, персональный
// эндпоинт — основной, обычная лента — запасной, и человек ни при каком
// отказе не остаётся с пустым экраном.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/listing_repository.dart';

typedef _Reply = ({String body, int status});

_Reply _ok(String body) => (body: body, status: 200);
_Reply _fail(int status) => (body: '{"detail":"нет"}', status: status);

class _FakeClient extends http.BaseClient {
  _FakeClient({this.recommended, this.legacy, this.throwOnRecommended = false});

  final _Reply Function(Uri uri)? recommended;
  final _Reply Function(Uri uri)? legacy;

  /// Обрыв сети на персональном эндпоинте — не HTTP-код, а исключение.
  final bool throwOnRecommended;

  final List<Uri> calls = [];

  Uri? get recommendedCall =>
      calls.where((u) => u.path.contains('/recommendations/')).firstOrNull;
  Uri? get legacyCall =>
      calls.where((u) => !u.path.contains('/recommendations/')).firstOrNull;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls.add(request.url);
    final isRecommended = request.url.path.contains('/recommendations/');
    if (isRecommended && throwOnRecommended) {
      throw const SocketExceptionStub();
    }
    final reply = isRecommended ? recommended!(request.url) : legacy!(request.url);
    return http.StreamedResponse(
      Stream.value(utf8.encode(reply.body)),
      reply.status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// Не тянем dart:io в тест ради одного класса — клиенту довольно любого
/// исключения транспорта, он всё равно оборачивает его в NetworkException.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

String _listingsJson(List<int> ids, {String? next}) => jsonEncode({
      'results': [
        for (final id in ids)
          {
            'id': id,
            'slug': 'listing-$id',
            'price': 100000,
            'district': {'name': 'Технопарк'},
            'media': [],
          },
      ],
      'next': next,
    });

ListingRepository _repo(_FakeClient fake) =>
    ListingRepository(ListingApiClient(baseUrl: 'https://test.local', client: fake));

void main() {
  group('источник выдачи объявлений', () {
    test('A. с сессией идёт персональная выдача', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([1, 2])),
        legacy: (_) => _ok(_listingsJson([99])),
      );

      final page = await _repo(fake).getListings(sessionId: 'session-abcdefgh');

      expect(page.results.map((l) => l.id), ['listing-1', 'listing-2']);
      expect(fake.legacyCall, isNull, reason: 'обычная лента не нужна');
    });

    test('B. без сессии берётся обычная лента', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([1])),
        legacy: (_) => _ok(_listingsJson([99])),
      );

      final page = await _repo(fake).getListings();

      expect(page.results.single.id, 'listing-99');
      expect(fake.recommendedCall, isNull);
    });

    test('C. фильтры уходят на сервер без изменений', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([1])),
        legacy: (_) => _ok(_listingsJson([99])),
      );

      await _repo(fake).getListings(
        sessionId: 'session-abcdefgh',
        filters: const {
          'kind': 'apartment',
          'rooms': '1',
          'price_max': '60000',
          'series': '105',
        },
      );

      final params = fake.recommendedCall!.queryParameters;
      expect(params['kind'], 'apartment');
      expect(params['rooms'], '1');
      expect(params['price_max'], '60000');
      expect(params['series'], '105');
      expect(params['session_id'], 'session-abcdefgh');
    });

    test('D. пустые значения фильтра не засоряют запрос', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([1])),
        legacy: (_) => _ok(_listingsJson([99])),
      );

      await _repo(fake).getListings(
        sessionId: 'session-abcdefgh',
        filters: const {'kind': 'house', 'search': '', 'rooms': null},
      );

      final params = fake.recommendedCall!.queryParameters;
      expect(params.containsKey('search'), isFalse);
      expect(params.containsKey('rooms'), isFalse);
    });

    for (final status in [404, 501, 500, 502, 503]) {
      test('E. откат на обычную ленту при $status', () async {
        final fake = _FakeClient(
          recommended: (_) => _fail(status),
          legacy: (_) => _ok(_listingsJson([99])),
        );

        final page = await _repo(fake).getListings(sessionId: 'session-abcdefgh');

        expect(page.results.single.id, 'listing-99');
        expect(fake.legacyCall, isNotNull);
      });
    }

    test('F. откат при обрыве сети на персональной выдаче', () async {
      final fake = _FakeClient(
        legacy: (_) => _ok(_listingsJson([99])),
        throwOnRecommended: true,
      );

      final page = await _repo(fake).getListings(sessionId: 'session-abcdefgh');

      expect(page.results.single.id, 'listing-99');
    });

    test('G. пустая первая страница уводит на обычную ленту', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([])),
        legacy: (_) => _ok(_listingsJson([99])),
      );

      final page = await _repo(fake).getListings(sessionId: 'session-abcdefgh');

      expect(page.results.single.id, 'listing-99',
          reason: 'пустой каталог — тупик для экрана');
    });

    test('H. пустая страница по курсору — это конец ленты, а не отказ', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([])),
        legacy: (_) => _ok(_listingsJson([99])),
      );

      final page = await _repo(fake)
          .getListings(sessionId: 'session-abcdefgh', cursor: 'rec:token-2');

      expect(page.results, isEmpty);
      expect(fake.legacyCall, isNull,
          reason: 'подмешивать чужую выдачу в конец пролистанного списка нельзя');
    });

    test('I. курсор рекомендаций пробрасывается как есть', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([3], next: 'opaque-token-2')),
        legacy: (_) => _ok(_listingsJson([99])),
      );
      final repo = _repo(fake);

      final first = await repo.getListings(sessionId: 'session-abcdefgh');

      await repo.getListings(sessionId: 'session-abcdefgh', cursor: first.nextCursor);
      final last = fake.calls.last;
      expect(last.path, contains('/recommendations/'));
      expect(last.queryParameters['cursor'], 'opaque-token-2',
          reason: 'метка ленты снимается перед отправкой на сервер');
    });

    test('K. курсор обычной ленты не уходит на персональный эндпоинт', () async {
      // Первая страница уже пришла из обычной ленты — её курсор для
      // рекомендаций бессмыслен, и страница вторая должна идти туда же.
      // Иначе список обрывается на первой дюжине карточек.
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([])),
        legacy: (uri) => _ok(_listingsJson(
              uri.queryParameters.containsKey('cursor') ? [21, 22] : [11, 12],
              next: 'http://test.local/api/v1/listings/?cursor=CURSOR',
            )),
      );
      final repo = _repo(fake);

      final first = await repo.getListings(sessionId: 'session-abcdefgh');
      expect(first.results.map((l) => l.id), ['listing-11', 'listing-12']);

      final second =
          await repo.getListings(sessionId: 'session-abcdefgh', cursor: first.nextCursor);

      expect(second.results.map((l) => l.id), ['listing-21', 'listing-22']);
      expect(fake.calls.last.path, '/api/v1/listings/');
    });

    test('J. ошибка авторизации не подменяется обычной лентой', () async {
      final fake = _FakeClient(
        recommended: (_) => _fail(401),
        legacy: (_) => _ok(_listingsJson([99])),
      );

      await expectLater(
        _repo(fake).getListings(sessionId: 'session-abcdefgh'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'код', 401)),
        reason: 'протухший токен надо чинить, а не прятать',
      );
    });
  });
}
