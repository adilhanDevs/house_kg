// Клиент персонализированной ленты: откат на обычную, идентификаторы сессии,
// защита от повторных показов и то, что аналитика никогда не мешает ленте.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/listing_repository.dart';
import 'package:house_kgz/data/recommendation_feed.dart';

/// Ответ заглушки: тело и код. Кодируем ровно один раз, в UTF-8 — иначе
/// кириллица в районе теряется по дороге и тест падает не по делу.
typedef _Reply = ({String body, int status});

_Reply _ok(String body) => (body: body, status: 200);
_Reply _fail(int status) => (body: '{"detail":"нет"}', status: status);

/// Отвечает по маршруту: что вернуть на рекомендации и что на обычную ленту.
class _FakeClient extends http.BaseClient {
  _FakeClient({this.recommended, this.legacy});

  final _Reply Function(Uri uri)? recommended;
  final _Reply Function(Uri uri)? legacy;

  final List<Uri> calls = [];
  final List<String> postedBodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls.add(request.url);
    if (request is http.Request && request.method == 'POST') {
      postedBodies.add(request.body);
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"status":"ok"}')),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final reply = request.url.path.contains('/recommendations/')
        ? recommended!(request.url)
        : legacy!(request.url);
    return http.StreamedResponse(
      Stream.value(utf8.encode(reply.body)),
      reply.status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
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

ListingApiClient _client(_FakeClient fake) =>
    ListingApiClient(baseUrl: 'https://test.local', client: fake);

void main() {
  group('источник ленты', () {
    test('персонализированная лента используется, когда доступна', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([1, 2], next: 'next')),
        legacy: (_) => _ok(_listingsJson([99])),
      );
      final api = _client(fake);
      final feed = RecommendationFeed(apiClient: api);

      final page = await ListingRepository(api).getReelsFeed(feed: feed);

      expect(page.results.map((l) => l.backendId), [1, 2]);
      expect(fake.calls.single.path, contains('/recommendations/reels/'));
      // Непрозрачный токен курсора должен пережить разбор ответа.
      expect(page.nextCursor, 'next');
    });

    test('404 персонализированной ленты — молча берём обычную', () async {
      final fake = _FakeClient(
        recommended: (_) => _fail(404),
        legacy: (_) => _ok(_listingsJson([99])),
      );
      final api = _client(fake);

      final page = await ListingRepository(api)
          .getReelsFeed(feed: RecommendationFeed(apiClient: api));

      expect(page.results.single.backendId, 99);
      expect(fake.calls.last.path, contains('/listings/reels/'));
    });

    test('500 персонализированной ленты — тоже откат', () async {
      final fake = _FakeClient(
        recommended: (_) => _fail(500),
        legacy: (_) => _ok(_listingsJson([7])),
      );
      final api = _client(fake);

      final page = await ListingRepository(api)
          .getReelsFeed(feed: RecommendationFeed(apiClient: api));

      expect(page.results.single.backendId, 7);
    });

    test('пустая, но корректная лента откатом не подменяется', () async {
      final fake = _FakeClient(
        recommended: (_) => _ok(_listingsJson([])),
        legacy: (_) => _ok(_listingsJson([99])),
      );
      final api = _client(fake);

      final page = await ListingRepository(api)
          .getReelsFeed(feed: RecommendationFeed(apiClient: api));

      expect(page.results, isEmpty);
      expect(fake.calls.length, 1, reason: 'обычную ленту дёргать не должны');
    });

    test('ошибку прав наружу не прячем', () async {
      final fake = _FakeClient(
        recommended: (_) => _fail(403),
        legacy: (_) => _ok(_listingsJson([99])),
      );
      final api = _client(fake);

      expect(
        () => ListingRepository(api).getReelsFeed(feed: RecommendationFeed(apiClient: api)),
        throwsA(isA<ApiException>()),
      );
    });

    test('идентификатор ленты не меняется между страницами', () async {
      final seen = <String>{};
      final fake = _FakeClient(
        recommended: (uri) {
          seen.add(uri.queryParameters['feed_session_id']!);
          return _ok(_listingsJson([1], next: 'next'));
        },
        legacy: (_) => _ok(_listingsJson([])),
      );
      final api = _client(fake);
      final feed = RecommendationFeed(apiClient: api);
      final repo = ListingRepository(api);

      await repo.getReelsFeed(feed: feed);
      await repo.getReelsFeed(cursor: 'next', feed: feed);

      expect(seen.length, 1);
      expect(feed.sessionId.length, greaterThanOrEqualTo(8));
    });
  });

  group('события', () {
    test('повторные перерисовки не множат показ', () async {
      final fake = _FakeClient();
      final feed = RecommendationFeed(apiClient: _client(fake));

      feed.impression(1);
      feed.impression(1);
      feed.impression(2);

      expect(feed.pending, 2);
    });

    test('быстрый свайп даёт пропуск, досмотр — просмотр', () async {
      final fake = _FakeClient();
      final feed = RecommendationFeed(apiClient: _client(fake));

      feed.watched(1,
          watched: const Duration(seconds: 1), total: const Duration(seconds: 30));
      feed.watched(2,
          watched: const Duration(seconds: 25), total: const Duration(seconds: 30));
      await feed.flush();

      final sent = jsonDecode(fake.postedBodies.single)['events'] as List;
      expect(sent[0]['event_type'], ReelEvent.skip);
      expect(sent[1]['event_type'], ReelEvent.watch);
    });

    test('у каждого события свой UUID для защиты от дублей', () async {
      final fake = _FakeClient();
      final feed = RecommendationFeed(apiClient: _client(fake));

      feed.impression(1);
      feed.listingOpened(1);
      await feed.flush();

      final sent = jsonDecode(fake.postedBodies.single)['events'] as List;
      final ids = sent.map((e) => e['client_event_id'] as String).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.first, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('батч не превышает предел сервера', () async {
      final fake = _FakeClient();
      final feed = RecommendationFeed(apiClient: _client(fake));

      for (var i = 0; i < kRecommendationBatchMax + 15; i++) {
        feed.impression(i);
      }
      await feed.flush();

      for (final body in fake.postedBodies) {
        expect((jsonDecode(body)['events'] as List).length,
            lessThanOrEqualTo(kRecommendationBatchMax));
      }
      expect(kRecommendationBatchMax, lessThanOrEqualTo(50));
    });

    test('неудачная отправка не бросает наружу', () async {
      final fake = _FakeClient();
      final api = ListingApiClient(baseUrl: 'https://unreachable.invalid', client: fake);
      final feed = RecommendationFeed(apiClient: api);
      feed.impression(1);

      await expectLater(feed.flush(), completes);
    });
  });
}
