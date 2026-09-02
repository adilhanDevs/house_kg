// Блок «Последние уведомления» в профиле.
//
// В кадре эти карточки нарисованы — два одинаковых «Технопарка» со снижением
// цены у всех пользователей одинаково. Панель должна показывать то, что
// действительно пришло с сервера, и вести туда, куда указывает уведомление.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/chat_page.dart';
import 'package:house_kgz/ui/pages/profile_page.dart';
import 'package:house_kgz/ui/widgets/latest_notifications.dart';

const String kConversation = '11111111-1111-1111-1111-111111111111';

Map<String, dynamic> _notification({
  int id = 1,
  String type = 'price_drop',
  String title = 'Цена снизилась',
  String body = 'Технопарк, 3-комн.',
  Map<String, dynamic> payload = const {},
  String? listingSlug = 'technopark-3k-92',
  bool isRead = false,
}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'payload': payload,
      'listing_slug': listingSlug,
      'is_read': isRead,
      'created_at': '2026-09-02T10:00:00Z',
    };

class _Server extends http.BaseClient {
  _Server({this.notifications = const [], this.fails = false});

  final List<Map<String, dynamic>> notifications;
  final bool fails;
  int listCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/notifications/') {
      listCalls += 1;
      if (fails) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'error': {'code': 'server_error', 'message': 'Сервер недоступен', 'details': {}}
          }))),
          500,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'results': notifications,
          'next': null,
          'previous': null,
          'count': notifications.length,
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

Future<AppState> _authorized(http.BaseClient client) async {
  SharedPreferences.setMockInitialValues({
    'access_token': 'a',
    'refresh_token': 'r',
  });
  final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://t', client: client));
  await state.authInitialized;
  return state;
}

Widget _host(AppState state, {int maxItems = 2, List<String>? log}) {
  final routes = log ?? <String>[];
  return AppScope(
    state: state,
    child: MaterialApp(
      home: Scaffold(
        body: LatestNotifications(width: 326, height: 143, maxItems: maxItems),
      ),
      onGenerateRoute: (settings) {
        routes.add(settings.name ?? '');
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) {
            final args = settings.arguments;
            return Scaffold(
              body: Center(
                child: Text(
                  args is ChatArgs ? 'ДИАЛОГ ${args.conversationId}' : (settings.name ?? ''),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('показывает уведомления с сервера, а не из кадра', (tester) async {
    final state = await _authorized(_Server(notifications: [
      _notification(id: 1, title: 'Цена снизилась', body: 'Асанбай, 2-комн.'),
      _notification(id: 2, type: 'new_message', title: 'Азамат', body: 'Объект актуален?'),
    ]));

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(find.text('Асанбай, 2-комн.'), findsOneWidget);
    expect(find.text('Азамат'), findsOneWidget);
    // Нарисованного в кадре образца среди настоящих данных быть не должно.
    expect(find.text('Технопарк, 3-комн.'), findsNothing);
  });

  testWidgets('берёт не больше, чем помещается в полосу', (tester) async {
    final state = await _authorized(_Server(notifications: [
      _notification(id: 1, body: 'Первое'),
      _notification(id: 2, body: 'Второе'),
      _notification(id: 3, body: 'Третье'),
    ]));

    await tester.pumpWidget(_host(state, maxItems: 2));
    await _settle(tester);

    expect(find.text('Первое'), findsOneWidget);
    expect(find.text('Второе'), findsOneWidget);
    expect(find.text('Третье'), findsNothing);
  });

  testWidgets('pro-профиль показывает одно уведомление', (tester) async {
    final state = await _authorized(_Server(notifications: [
      _notification(id: 1, body: 'Первое'),
      _notification(id: 2, body: 'Второе'),
    ]));

    await tester.pumpWidget(_host(state, maxItems: 1));
    await _settle(tester);

    expect(find.text('Первое'), findsOneWidget);
    expect(find.text('Второе'), findsNothing);
  });

  testWidgets('пусто — так и написано', (tester) async {
    final state = await _authorized(_Server());

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(find.text('Уведомлений пока нет'), findsOneWidget);
  });

  testWidgets('без авторизации сервер не опрашивается', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final server = _Server(notifications: [_notification()]);
    final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://t', client: server));
    await state.authInitialized;

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(server.listCalls, 0);
    expect(find.text('Уведомлений пока нет'), findsOneWidget);
  });

  testWidgets('ошибка сервера показывается текстом, экран цел', (tester) async {
    final state = await _authorized(_Server(fails: true));

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Сервер недоступен'), findsOneWidget);
  });

  testWidgets('нажатие на сообщение открывает диалог', (tester) async {
    final state = await _authorized(_Server(notifications: [
      _notification(
        id: 1,
        type: 'new_message',
        title: 'Азамат',
        body: 'Объект актуален?',
        payload: const {'conversation_id': kConversation},
      ),
    ]));
    final routes = <String>[];

    await tester.pumpWidget(_host(state, maxItems: 1, log: routes));
    await _settle(tester);

    await tester.tap(find.text('Азамат'));
    await tester.pumpAndSettle();

    expect(routes, contains(Routes.conversation));
    expect(find.text('ДИАЛОГ $kConversation'), findsOneWidget);
  });

  testWidgets('панель накрывает нарисованные в кадре карточки', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(AppScope(
      state: AppState(apiClient: ListingApiClient(baseUrl: 'http://t', client: _Server())),
      child: const MaterialApp(home: ProfilePage()),
    ));
    await tester.pump();

    final panel = find.byKey(kLatestNotificationsKey);
    expect(panel, findsOneWidget);
    _expectCovers(tester, panel, find.textContaining('Цена снизилась'), 'Цена снизилась');
    _expectCovers(tester, panel, find.textContaining('Технопарк'), 'Технопарк');

    // А ссылку «Посмотреть все» перекрывать нельзя — она ниже панели.
    final seeAll = tester.getRect(find.textContaining('Посмотреть все').first);
    expect(tester.getRect(panel).bottom, lessThanOrEqualTo(seeAll.top));
  });

  testWidgets('нажатие на прочее уведомление открывает объявление', (tester) async {
    final state = await _authorized(_Server(notifications: [
      _notification(id: 1, body: 'Асанбай'),
    ]));
    final routes = <String>[];

    await tester.pumpWidget(_host(state, maxItems: 1, log: routes));
    await _settle(tester);

    await tester.tap(find.text('Асанбай'));
    await tester.pumpAndSettle();

    expect(routes, contains(Routes.listing));
  });
}

// -- геометрия наложения ------------------------------------------------------
//
// Карточки в кадре нарисованы, панель их перекрывает. Если панель окажется
// меньше нарисованного, из-под неё полезут чужие данные — именно так уже
// ломались экран регистрации и экран кода. Проверяем размеры, а не верим им.

void _expectCovers(WidgetTester tester, Finder panel, Finder drawn, String what) {
  final area = tester.getRect(panel);
  for (var i = 0; i < drawn.evaluate().length; i++) {
    final rect = tester.getRect(drawn.at(i));
    expect(
      area.left <= rect.left &&
          area.right >= rect.right &&
          area.top <= rect.top &&
          area.bottom >= rect.bottom,
      isTrue,
      reason: 'панель $area не накрывает «$what» #$i $rect',
    );
  }
}
