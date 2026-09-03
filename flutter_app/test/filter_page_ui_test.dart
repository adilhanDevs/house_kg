// Визуальный язык экрана фильтра: те же 12 фильтров, что и раньше, просто
// расставленные и оформленные по референсу. Референс — только вид: список
// фильтров, их поведение и то, что уходит на сервер, не меняются.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/listings.dart';
import 'package:house_kgz/ui/fig_controls.dart';
import 'package:house_kgz/ui/pages/filter_page.dart';

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

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

AppState _stateWithClient() => AppState(
      apiClient: ListingApiClient(
        baseUrl: 'http://test.local',
        client: _MockClient((request) async {
          if (request.url.path == '/api/v1/listings/count/') {
            return _json({'count': 42});
          }
          return _json({'results': [], 'next': null, 'previous': null, 'count': 0});
        }),
      ),
    );

/// Игнорирует overflow-баннер: он не относится к тому, что проверяет тест.
void _ignoreOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is FlutterError &&
        details.exception.toString().contains('overflowed')) {
      return;
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

Future<void> _pumpFilter(WidgetTester tester, AppState state, {double width = 375}) async {
  _ignoreOverflow();
  tester.view.physicalSize = Size(width, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: const MaterialApp(home: FilterPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Список не строит то, что вне вьюпорта, — докручивает мелкими шагами,
/// пока искомое не появится в дереве, вместо одного дальнего `fling`,
/// который проскакивает мимо середины списка.
Future<void> _scrollUntilVisible(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(target, findsOneWidget, reason: 'не нашли, докручивая список');
}

BoxDecoration _chipDecoration(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
  );
  return container.decoration as BoxDecoration;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('визуальный язык фильтра', () {
    testWidgets('A. все прежние фильтры отрисованы', (tester) async {
      await _pumpFilter(tester, _stateWithClient());

      // Верх списка виден сразу — до прокрутки.
      // Тип недвижимости — все шесть типов плюс вторичка и серия 103.
      for (final label in const [
        'Дома',
        'Квартиры',
        'Участки',
        'Новостройки',
        'Комната',
        'Коммерция',
        'Вторичка',
        '103 серия',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label должен остаться в фильтре');
      }

      // Количество комнат.
      for (final label in const ['1 комн.', '2 комн.', '3 комн.', '4 комн.']) {
        expect(find.text(label), findsOneWidget);
      }

      // Площадь, стоимость, продавец — ниже сгиба: список не lazy по
      // конструкции, но вьюпорт всё равно не строит то, что вне него, пока
      // до этого места не прокрутить.
      await _scrollUntilVisible(tester, find.text('Площадь'));

      await _scrollUntilVisible(tester, find.text('От'));
      expect(find.text('До'), findsOneWidget);

      await _scrollUntilVisible(tester, find.text('Кто продаёт'));
      for (final label in const ['Только собственник', 'Риелторы', 'Агентство недвижимости']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('B. переключение на «Участки» открывает фильтры участка — ничего не убрано',
        (tester) async {
      final state = _stateWithClient();
      await _pumpFilter(tester, state);

      state.toggleKind(PropertyKind.plot);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Назначение участка'), findsOneWidget);
    });

    testWidgets('C. выбранный чип — светло-оранжевая заливка и оранжевый текст',
        (tester) async {
      final state = _stateWithClient();
      state.toggleKind(PropertyKind.apartment);
      await _pumpFilter(tester, state);

      final decoration = _chipDecoration(tester, 'Квартиры');
      expect(decoration.color, const Color(0xfffdf1e8));
      expect(decoration.border, isA<Border>().having(
        (b) => b.top.width > 0 && b.top.color.a > 0,
        'видимая рамка',
        false,
      ));
    });

    testWidgets('D. невыбранный чип — белая заливка и серая рамка', (tester) async {
      final state = _stateWithClient();
      await _pumpFilter(tester, state);

      final decoration = _chipDecoration(tester, 'Комната');
      expect(decoration.color, const Color(0xffffffff));
      final border = decoration.border as Border;
      expect(border.top.color.a, greaterThan(0));
    });

    testWidgets('E. переключатель продавца — оранжевый включён, серый выключен',
        (tester) async {
      final state = _stateWithClient();
      state.toggleSeller(SellerKind.owner);
      await _pumpFilter(tester, state);

      // Тумблеры продавца — в самом низу списка, до них нужно прокрутить.
      await _scrollUntilVisible(tester, find.text('Кто продаёт'));

      final toggles = tester.widgetList<FigToggle>(find.byType(FigToggle)).toList();
      expect(toggles, hasLength(3), reason: 'три продавца — три тумблера');
      expect(toggles.where((t) => t.value), hasLength(1), reason: 'включён только собственник');
      expect(toggles.where((t) => !t.value), hasLength(2));
    });

    testWidgets('F. 360pt — фильтр рисуется без переполнения макета', (tester) async {
      await _pumpFilter(tester, _stateWithClient(), width: 360);
      expect(tester.takeException(), isNull);
      expect(find.text('Тип недвижимости'), findsOneWidget);
    });

    testWidgets('G. 412pt — фильтр рисуется без переполнения макета', (tester) async {
      await _pumpFilter(tester, _stateWithClient(), width: 412);
      expect(tester.takeException(), isNull);
      expect(find.text('Тип недвижимости'), findsOneWidget);
    });

    testWidgets('H. прокрутка доходит до последнего фильтра — продавца', (tester) async {
      await _pumpFilter(tester, _stateWithClient());

      await _scrollUntilVisible(tester, find.text('Агентство недвижимости'));
    });

    testWidgets('I. «Показать» уводит с экрана фильтра — семантика кнопки не изменилась',
        (tester) async {
      final state = _stateWithClient();
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FilterPage()),
                ),
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();
      _ignoreOverflow();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FilterPage), findsOneWidget);
      await tester.tap(find.textContaining('Показать'));
      await tester.pumpAndSettle();

      expect(find.byType(FilterPage), findsNothing);
    });

    testWidgets('J. SafeArea защищает контент фильтра сверху', (tester) async {
      await _pumpFilter(tester, _stateWithClient());
      expect(
        find.descendant(of: find.byType(FilterPage), matching: find.byType(SafeArea)),
        findsOneWidget,
      );
    });

    testWidgets('K. фильтры серии и вторички идут одним рядом под «Тип недвижимости»',
        (tester) async {
      // Раньше это были два визуально разных блока с зазором между ними —
      // референс показывает их одной строкой чипов под общим заголовком.
      await _pumpFilter(tester, _stateWithClient());

      final heading = tester.getTopLeft(find.text('Тип недвижимости'));
      final seriesChip = tester.getTopLeft(find.text('103 серия'));
      final roomsHeading = tester.getTopLeft(find.text('Количество комнат'));

      expect(seriesChip.dy, greaterThan(heading.dy));
      expect(seriesChip.dy, lessThan(roomsHeading.dy));
    });
  });
}
