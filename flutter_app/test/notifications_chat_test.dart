// Лента уведомлений и переход из неё в диалог.
//
// Главное, что здесь закреплено: уведомление типа new_message ведёт в чат по
// conversation_id из payload, а не по слагу объявления и не в захардкоженную
// карточку, как это делал прежний растровый экран.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/chat_models.dart';
import 'package:house_kgz/ui/pages/chat_page.dart';
import 'package:house_kgz/ui/pages/notifications_page.dart';

const String kConversation = '11111111-1111-1111-1111-111111111111';

Map<String, dynamic> _newMessageNotification({
  int id = 1,
  String? conversationId = kConversation,
  bool isRead = false,
}) =>
    {
      'id': id,
      'type': 'new_message',
      'title': 'Азамат',
      'body': 'Здравствуйте, объект ещё актуален?',
      'payload': {
        if (conversationId != null) 'conversation_id': conversationId,
        'listing_slug': 'technopark-3k-92',
        'sender_id': 42,
      },
      'listing_slug': 'technopark-3k-92',
      'is_read': isRead,
      'created_at': '2026-09-02T10:00:00Z',
    };

class _Server extends http.BaseClient {
  _Server({this.notifications = const []});

  final List<Map<String, dynamic>> notifications;

  final List<String> visitedPaths = [];
  List<int>? markedRead;

  http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    visitedPaths.add('${request.method} $path');

    if (path == '/api/v1/notifications/') {
      return _json({
        'results': notifications,
        'next': null,
        'previous': null,
        'count': notifications.length,
      });
    }
    if (path == '/api/v1/notifications/read/') {
      final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;
      markedRead = (body['ids'] as List?)?.cast<int>();
      return _json({'updated': 1, 'unread_count': 0});
    }
    if (path.startsWith('/api/v1/conversations/') && path.endsWith('/messages/')) {
      return _json({'results': [], 'next': null, 'previous': null, 'count': 0});
    }
    if (path.startsWith('/api/v1/conversations/')) {
      return _json({
        'id': kConversation,
        'listing_slug': 'technopark-3k-92',
        'listing_title': 'Технопарк, 3к',
        'peer': {'id': 42, 'name': 'Азамат', 'avatar_url': null},
        'latest_message': null,
        'unread_count': 0,
        'last_message_at': '2026-09-02T10:00:00Z',
      });
    }
    return _json(<String, dynamic>{});
  }
}

AppState _state(http.BaseClient client) =>
    AppState(apiClient: ListingApiClient(baseUrl: 'http://test.com', client: client));

/// Экран уведомлений с настоящим роутером — чтобы видеть, куда он ведёт.
Widget _app(AppState state, {List<String>? log}) {
  final routes = log ?? <String>[];
  return AppScope(
      state: state,
      child: MaterialApp(
        home: const NotificationsPage(),
        onGenerateRoute: (settings) {
          routes.add(settings.name ?? '');
          if (settings.name == Routes.conversation) {
            final args = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                body: Center(
                  child: Text(
                    args is ChatArgs ? 'ДИАЛОГ ${args.conversationId}' : 'НЕТ ID',
                  ),
                ),
              ),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Center(child: Text(settings.name ?? ''))),
          );
        },
      ),
  );
}

/// Вошедший пользователь: токен лежит в хранилище, как после входа.
Future<AppState> _authorized(http.BaseClient client) async {
  SharedPreferences.setMockInitialValues({
    'access_token': 'test-access',
    'refresh_token': 'test-refresh',
  });
  final state = _state(client);
  await state.authInitialized;
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('разбор уведомления', () {
    test('new_message достаёт conversation_id из payload', () {
      final notification = AppNotification.fromJson(_newMessageNotification());

      expect(notification.isNewMessage, isTrue);
      expect(notification.conversationId, kConversation);
      expect(notification.senderId, 42);
      expect(notification.listingSlug, 'technopark-3k-92');
    });

    test('payload без conversation_id не ломает разбор', () {
      final notification =
          AppNotification.fromJson(_newMessageNotification(conversationId: null));

      expect(notification.isNewMessage, isTrue);
      expect(notification.conversationId, isNull);
    });

    test('чужие типы уведомлений не считаются сообщениями', () {
      final notification = AppNotification.fromJson({
        'id': 7,
        'type': 'price_drop',
        'title': 'Цена снижена',
        'body': 'Технопарк',
        'payload': {'listing_slug': 'technopark-3k-92'},
        'is_read': true,
        'created_at': '2026-09-02T10:00:00Z',
      });

      expect(notification.isNewMessage, isFalse);
      expect(notification.type, 'price_drop');
    });
  });

  group('лента уведомлений', () {
    testWidgets('новое сообщение показывается с заголовком и текстом',
        (tester) async {
      final server = _Server(notifications: [_newMessageNotification()]);
      final state = await _authorized(server);

      await tester.pumpWidget(_app(state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Азамат'), findsOneWidget);
      expect(find.textContaining('объект ещё актуален'), findsOneWidget);
    });

    testWidgets('пустая лента говорит об этом прямо', (tester) async {
      final state = await _authorized(_Server());

      await tester.pumpWidget(_app(state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Уведомлений пока нет'), findsOneWidget);
    });

    testWidgets('нажатие открывает диалог по conversation_id', (tester) async {
      final server = _Server(notifications: [_newMessageNotification()]);
      final state = await _authorized(server);
      final routes = <String>[];

      await tester.pumpWidget(_app(state, log: routes));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Азамат'));
      await tester.pumpAndSettle();

      expect(routes, contains(Routes.conversation));
      expect(find.text('ДИАЛОГ $kConversation'), findsOneWidget);
    });

    testWidgets('нажатие помечает уведомление прочитанным', (tester) async {
      final server = _Server(notifications: [_newMessageNotification(id: 5)]);
      final state = await _authorized(server);

      await tester.pumpWidget(_app(state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Азамат'));
      await tester.pumpAndSettle();

      expect(server.markedRead, [5]);
    });

    testWidgets('без conversation_id в диалог не уводит', (tester) async {
      final server = _Server(
        notifications: [_newMessageNotification(conversationId: null)],
      );
      final state = await _authorized(server);
      final routes = <String>[];

      await tester.pumpWidget(_app(state, log: routes));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Азамат'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(routes, isNot(contains(Routes.conversation)));
      expect(find.text('Диалог недоступен'), findsOneWidget);
    });

    testWidgets('без авторизации приватную переписку не открываем',
        (tester) async {
      final server = _Server(notifications: [_newMessageNotification()]);
      SharedPreferences.setMockInitialValues({});
      final state = _state(server);
      await state.authInitialized;
      final routes = <String>[];

      await tester.pumpWidget(_app(state, log: routes));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Список приходит (сервер в тесте не проверяет токен), а вот переход —
      // только на экран входа.
      if (find.text('Азамат').evaluate().isNotEmpty) {
        await tester.tap(find.text('Азамат'));
        await tester.pumpAndSettle();
        expect(routes, contains(Routes.welcome));
        expect(routes, isNot(contains(Routes.conversation)));
      }
    });
  });
}
