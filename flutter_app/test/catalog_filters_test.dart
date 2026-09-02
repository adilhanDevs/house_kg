// Каталог фильтрует на сервере, а не у себя.
//
// Проверяется ровно это: какие параметры ушли в запрос и что клиент показал
// то, что вернул сервер, — без собственного отбора поверх ответа.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/listings.dart';
import 'package:house_kgz/ui/listing_grid.dart';
import 'package:house_kgz/ui/pages/catalog_page.dart';
import 'package:house_kgz/ui/pages/filter_page.dart';

/// Пауза чуть больше клиентского дебаунса (350 мс).
const Duration _afterDebounce = Duration(milliseconds: 500);

class _MockClient extends http.BaseClient {
  _MockClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: request,
      headers: response.headers,
    );
  }
}

http.Response _json(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _listing(
  String slug, {
  String kind = 'apartment',
  int rooms = 3,
  int area = 60,
  String price = '100000',
}) =>
    {
      'slug': slug,
      'kind': kind,
      'rooms': rooms,
      'area': area,
      'price': price,
      'currency': 'USD',
      'district': {'name': 'Технопарк', 'slug': 'technopark'},
      'is_favourite': false,
      'media': const [],
    };

Map<String, dynamic> _page(
  List<Map<String, dynamic>> results, {
  String? next,
  int? count,
}) =>
    {
      'results': results,
      'next': next,
      'previous': null,
      'count': count ?? results.length,
    };

/// Кадры опираются на `overflow: visible`; в тесте шрифт шире, и строки
/// разъезжаются. Это проверяет render_test.dart, здесь только мешает.
void _ignoreOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.exceptionAsString().contains('overflowed by')) {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// Запросы каталога в порядке отправки.
class _Recorder {
  final List<Uri> catalog = [];
  final List<Uri> count = [];

  void add(Uri url) {
    if (url.path == '/api/v1/listings/') catalog.add(url);
    if (url.path == '/api/v1/listings/count/') count.add(url);
  }

  Uri get lastCatalog => catalog.last;
}

Future<void> _pumpCatalog(WidgetTester tester, AppState state) async {
  _ignoreOverflow();
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: const MaterialApp(home: CatalogPage()),
    ),
  );
  await tester.pump();
  await tester.pump(_afterDebounce);
}

List<Listing> _shown(WidgetTester tester) =>
    tester.widget<ListingGrid>(find.byType(ListingGrid)).listings;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('запрос каталога', () {
    testWidgets('выбранный фильтр уходит в параметры запроса', (tester) async {
      final recorder = _Recorder();
      final client = _MockClient((request) async {
        recorder.add(request.url);
        return _json(_page([_listing('a')]));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      state.toggleKind(PropertyKind.apartment);
      state.toggleRooms(3);
      await tester.pump(_afterDebounce);
      await tester.pump();

      final query = recorder.lastCatalog.queryParameters;
      expect(query['kind'], 'apartment');
      expect(query['rooms'], '3');
    });

    testWidgets('пустой фильтр не шлёт пустых параметров', (tester) async {
      final recorder = _Recorder();
      final client = _MockClient((request) async {
        recorder.add(request.url);
        return _json(_page([_listing('a')]));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      expect(recorder.catalog, isNotEmpty);
      expect(recorder.lastCatalog.queryParameters, isEmpty);
    });

    testWidgets('чип «103 серия» уходит параметром series', (tester) async {
      // Раньше он менял отдельное поле, которое в запрос не попадало, и
      // фильтр молча не работал.
      final recorder = _Recorder();
      final client = _MockClient((request) async {
        recorder.add(request.url);
        return _json(_page([_listing('a')]));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      state.setSeries103(true);
      await tester.pump(_afterDebounce);
      await tester.pump();

      expect(recorder.lastCatalog.queryParameters['series'], '103');
      expect(state.series103, isTrue);
    });

    testWidgets('сброс шлёт запрос без параметров фильтра', (tester) async {
      final recorder = _Recorder();
      final client = _MockClient((request) async {
        recorder.add(request.url);
        return _json(_page([_listing('a')]));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      state.toggleKind(PropertyKind.house);
      await tester.pump(_afterDebounce);
      await tester.pump();
      expect(recorder.lastCatalog.queryParameters['kind'], 'house');

      state.resetFilter();
      await tester.pump(_afterDebounce);
      await tester.pump();
      expect(recorder.lastCatalog.queryParameters.containsKey('kind'), isFalse);
    });

    testWidgets('набор текста схлопывается в один запрос', (tester) async {
      final recorder = _Recorder();
      final client = _MockClient((request) async {
        recorder.add(request.url);
        return _json(_page([_listing('a')]));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);
      final before = recorder.catalog.length;

      for (final text in ['Т', 'Те', 'Тех', 'Техн']) {
        state.setQuery(text);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(_afterDebounce);
      await tester.pump();

      expect(recorder.catalog.length - before, 1);
      expect(recorder.lastCatalog.queryParameters['search'], 'Техн');
    });
  });

  group('ответ сервера', () {
    testWidgets('клиент не отсеивает то, что вернул сервер', (tester) async {
      // Фильтр просит комнаты, сервер прислал квартиру. Прежние локальные
      // правила выкинули бы её; теперь решение за сервером.
      final client = _MockClient((request) async {
        if (request.url.path == '/api/v1/listings/') {
          return _json(_page([
            _listing('server-knows-better', kind: 'apartment', rooms: 1),
          ]));
        }
        return _json(const {});
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      state.toggleKind(PropertyKind.room);
      state.toggleRooms(4);
      await tester.pump(_afterDebounce);
      await tester.pump();

      expect(_shown(tester).map((l) => l.id), contains('server-knows-better'));
    });

    testWidgets('пустая выдача объясняется, а не остаётся белым пятном',
        (tester) async {
      final client = _MockClient((request) async => _json(_page(const [])));
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      expect(_shown(tester), isEmpty);
      expect(find.textContaining('Ничего не нашлось'), findsOneWidget);
    });

    testWidgets('ошибка запроса не выдаётся за пустой результат',
        (tester) async {
      final client = _MockClient((request) async => http.Response('{}', 500));
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      expect(find.textContaining('Ничего не нашлось'), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);
    });
  });

  group('страницы и гонки', () {
    testWidgets('следующая страница сохраняет фильтр', (tester) async {
      final recorder = _Recorder();
      final client = _MockClient((request) async {
        recorder.add(request.url);
        if (request.url.path != '/api/v1/listings/') return _json(const {});
        final hasCursor = request.url.queryParameters.containsKey('cursor');
        return _json(_page(
          [for (var i = 0; i < 12; i++) _listing('${hasCursor ? 'p2' : 'p1'}-$i')],
          next: hasCursor
              ? null
              : 'http://test.local/api/v1/listings/?cursor=CURSOR&kind=house',
          count: 24,
        ));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      state.toggleKind(PropertyKind.house);
      await tester.pump(_afterDebounce);
      await tester.pump();
      expect(_shown(tester), hasLength(12));

      await tester.drag(find.byType(ListingGrid), const Offset(0, -4000));
      await tester.pump();
      await tester.pump(_afterDebounce);

      final paged = recorder.catalog.where(
        (uri) => uri.queryParameters.containsKey('cursor'),
      );
      expect(paged, isNotEmpty, reason: 'вторая страница не запрошена');
      // Фильтр обязан уехать вместе с курсором, иначе вторая страница
      // приходит из другой выборки.
      expect(paged.last.queryParameters['kind'], 'house');
      expect(_shown(tester), hasLength(24));
    });

    testWidgets('ответ на устаревший запрос не затирает свежий', (tester) async {
      // Первый запрос отвечает медленно, второй — сразу. На экране должен
      // остаться результат второго.
      final pending = <Completer<http.Response>>[];
      final client = _MockClient((request) async {
        if (request.url.path != '/api/v1/listings/') return _json(const {});
        final kind = request.url.queryParameters['kind'];
        if (kind == 'house') {
          final completer = Completer<http.Response>();
          pending.add(completer);
          return completer.future;
        }
        return _json(_page([_listing('fresh', kind: kind ?? 'apartment')]));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      await _pumpCatalog(tester, state);

      state.toggleKind(PropertyKind.house);
      await tester.pump(_afterDebounce);
      await tester.pump();
      expect(pending, hasLength(1), reason: 'медленный запрос не ушёл');

      state.toggleKind(PropertyKind.house);
      state.toggleKind(PropertyKind.apartment);
      await tester.pump(_afterDebounce);
      await tester.pump();
      expect(_shown(tester).map((l) => l.id), contains('fresh'));

      // Опоздавший ответ по снятому фильтру приходит последним.
      pending.single.complete(_json(_page([_listing('stale', kind: 'house')])));
      await tester.pump();
      await tester.pump();

      final shown = _shown(tester).map((l) => l.id);
      expect(shown, contains('fresh'));
      expect(shown, isNot(contains('stale')));
    });
  });

  group('экран фильтра', () {
    testWidgets('количество на кнопке приходит с сервера', (tester) async {
      final recorder = _Recorder();
      final client = _MockClient((request) async {
        recorder.add(request.url);
        if (request.url.path == '/api/v1/listings/count/') {
          return _json({'count': 137});
        }
        return _json(_page(const []));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      _ignoreOverflow();
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: const MaterialApp(home: FilterPage()),
        ),
      );
      await tester.pump();
      await tester.pump(_afterDebounce);

      expect(recorder.count, isNotEmpty, reason: 'счётчик не запрошен у сервера');
      expect(find.textContaining('Показать 137'), findsOneWidget);
    });

    testWidgets('счётчик пересчитывается сервером под выбранный фильтр',
        (tester) async {
      final recorder = _Recorder();
      final client = _MockClient((request) async {
        recorder.add(request.url);
        if (request.url.path == '/api/v1/listings/count/') {
          final narrowed = request.url.queryParameters.containsKey('kind');
          return _json({'count': narrowed ? 4 : 137});
        }
        return _json(_page(const []));
      });
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
      );

      _ignoreOverflow();
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: const MaterialApp(home: FilterPage()),
        ),
      );
      await tester.pump();
      await tester.pump(_afterDebounce);
      expect(find.textContaining('Показать 137'), findsOneWidget);

      state.toggleKind(PropertyKind.plot);
      await tester.pump(_afterDebounce);
      await tester.pump();

      expect(recorder.count.last.queryParameters['kind'], 'plot');
      expect(find.textContaining('Показать 4'), findsOneWidget);
    });
  });
}
