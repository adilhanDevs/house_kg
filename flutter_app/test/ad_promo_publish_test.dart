import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/ad_promo_page.dart';

class _TestPublishClient extends http.BaseClient {
  final bool shouldFailWithLimit;
  _TestPublishClient({this.shouldFailWithLimit = false});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.contains('/publish/')) {
      if (shouldFailWithLimit) {
        final body = utf8.encode(jsonEncode({
          'error': {
            'code': 'conflict',
            'message': 'Достигнут лимит активных объявлений',
          }
        }));
        return http.StreamedResponse(Stream.value(body), 409, headers: {'content-type': 'application/json'});
      }
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    }
    return http.StreamedResponse(Stream.value([]), 200);
  }
}


/// Клиент, который держит публикацию до разрешения — чтобы поймать состояние
/// «запрос идёт» и увидеть, на какой кнопке крутится индикатор.
class _SlowPublishClient extends http.BaseClient {
  final completer = Completer<http.StreamedResponse>();
  int publishCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.path.contains('/publish/')) {
      publishCalls++;
      return completer.future;
    }
    return Future.value(
      http.StreamedResponse(Stream.value(utf8.encode('{}')), 200),
    );
  }

  void finish() => completer.complete(
        http.StreamedResponse(Stream.value(utf8.encode('{}')), 200),
      );
}

Future<AppState> _pumpPromo(WidgetTester tester, http.Client client) async {
  final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test.com', client: client))
    ..draftSlug = 'test-slug-123';
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const AdPromoPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

/// Крутится ли индикатор внутри кнопки с этим текстом.
bool _spinnerIn(WidgetTester tester, Type buttonType) =>
    find
        .descendant(
          of: find.byType(buttonType),
          matching: find.byType(CircularProgressIndicator),
        )
        .evaluate()
        .isNotEmpty;

void main() {
  testWidgets('кнопки продвижения не уходят под системную навигацию', (
    tester,
  ) async {
    // Жестовая полоса Android: без учёта этого отступа нижняя кнопка
    // оказывалась частично под ней.
    const navInset = 48.0;
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: navInset);
    tester.view.viewPadding = const FakeViewPadding(bottom: navInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    final state = AppState(
      apiClient: ListingApiClient(
        baseUrl: 'http://test.com',
        client: _SlowPublishClient(),
      ),
    )..draftSlug = 'test-slug-123';

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          onGenerateRoute: (_) =>
              MaterialPageRoute(builder: (_) => const AdPromoPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Между кнопкой и полосой навигации нужен видимый зазор, а не касание:
    // без поправки кнопка кончалась в 1.3 px от неё и выглядела прижатой.
    const breathingRoom = 8.0;
    final skip = tester.getRect(find.byType(OutlinedButton));
    expect(
      skip.bottom,
      lessThanOrEqualTo(915.0 - navInset - breathingRoom),
      reason: 'нижняя кнопка прижата к навигации Android',
    );
    expect(tester.getRect(find.byType(ElevatedButton)).bottom,
        lessThan(skip.top), reason: 'кнопки не должны накладываться');
  });

  testWidgets('«Далее» показывает индикатор только на себе', (tester) async {
    final client = _SlowPublishClient();
    await _pumpPromo(tester, client);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Далее'));
    await tester.pump();

    expect(_spinnerIn(tester, ElevatedButton), isTrue);
    expect(_spinnerIn(tester, OutlinedButton), isFalse);
    // Вторая кнопка на время отправки заперта.
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);

    client.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('«Продолжить без продвижения» показывает индикатор на себе', (
    tester,
  ) async {
    final client = _SlowPublishClient();
    await _pumpPromo(tester, client);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Продолжить без продвижения'));
    await tester.pump();

    expect(_spinnerIn(tester, OutlinedButton), isTrue);
    expect(_spinnerIn(tester, ElevatedButton), isFalse,
        reason: 'колесо не должно крутиться на чужой кнопке');
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);

    client.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('повторные нажатия не отправляют объявление дважды', (tester) async {
    final client = _SlowPublishClient();
    await _pumpPromo(tester, client);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Далее'));
    await tester.pump();
    // После первого нажатия текст сменился индикатором, поэтому ищем кнопку
    // по типу: важно, что второе нажатие не уходит в сеть.
    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();

    expect(client.publishCalls, 1);
    client.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('AdPromoPage with limit conflict shows modal dialog with navigation option', (tester) async {
    final client = _TestPublishClient(shouldFailWithLimit: true);
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);
    state.draftSlug = 'test-slug-123';

    String? navigatedRoute;
    Object? navigatedArgs;

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == Routes.adPreview) {
              navigatedRoute = settings.name;
              navigatedArgs = settings.arguments;
              return MaterialPageRoute(builder: (_) => const Scaffold(body: Text('PREVIEW_PAGE')));
            }
            return MaterialPageRoute(builder: (_) => const AdPromoPage());
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap "Далее" button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Далее'));
    await tester.pumpAndSettle();

    // Conflict Dialog should be visible
    expect(find.text('Публикация объявления'), findsOneWidget);
    expect(find.textContaining('Достигнут лимит активных объявлений'), findsOneWidget);
    expect(find.text('К предпросмотру'), findsOneWidget);

    // Tap "К предпросмотру"
    await tester.tap(find.text('К предпросмотру'));
    await tester.pumpAndSettle();

    expect(navigatedRoute, Routes.adPreview);
    expect(navigatedArgs, 'test-slug-123');
    expect(find.text('PREVIEW_PAGE'), findsOneWidget);
  });
}
