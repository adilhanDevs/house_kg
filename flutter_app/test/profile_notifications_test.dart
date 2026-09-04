import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/l10n/app_localizations.dart';
import 'package:house_kgz/ui/pages/chat_page.dart';
import 'package:house_kgz/ui/pages/notifications_page.dart';
import 'package:house_kgz/ui/pages/profile_page.dart';
import 'package:house_kgz/ui/pages/pro_profile_page.dart';
import 'package:house_kgz/ui/widgets/profile_latest_notifications.dart';

const String kConversationId = '11111111-1111-1111-1111-111111111111';

class _MockHttpServer extends http.BaseClient {
  _MockHttpServer({
    this.notifications = const [],
    this.unreadCount = 0,
    this.failNotifications = false,
  });

  List<Map<String, dynamic>> notifications;
  int unreadCount;
  bool failNotifications;

  final List<String> visitedPaths = [];
  List<int>? markedReadIds;

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

    if (path.contains('/api/v1/users/me/')) {
      return _json({
        'id': 1,
        'phone': '+996555123456',
        'name': 'Тестовый Пользователь',
        'is_pro': false,
        'role': 'client',
      });
    }

    if (path.contains('/api/v1/notifications/unread-count/')) {
      return _json({'count': unreadCount});
    }

    if (path.contains('/api/v1/notifications/read/')) {
      if (request is http.Request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        markedReadIds = (body['ids'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList();
      }
      return _json({'status': 'ok'});
    }

    if (path.contains('/api/v1/notifications/')) {
      if (failNotifications) {
        return _json({'error': 'server_error'}, 500);
      }
      return _json({
        'count': notifications.length,
        'next': null,
        'previous': null,
        'results': notifications,
      });
    }

    if (path.contains('/api/v1/listings/me/')) {
      return _json({'active': [], 'sold': []});
    }

    if (path.contains('/api/v1/catalog/filter-options/')) {
      return _json({'districts': [], 'series': [], 'property_types': []});
    }

    if (path.contains('/api/v1/favourites/')) {
      return _json({'results': []});
    }

    if (path.contains('/api/v1/view-history/')) {
      return _json({'results': []});
    }

    return _json({'detail': 'Not found'}, 404);
  }
}

Widget _wrapWithApp(
  Widget child,
  AppState state, {
  Locale? locale,
}) {
  if (locale != null && locale.languageCode != state.languageCode) {
    state.setLanguageCode(locale.languageCode);
  }
  return AppScope(
    state: state,
    child: ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        locale: state.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          Routes.notifications: (context) => const NotificationsPage(),
          Routes.conversation: (context) {
            final args = ModalRoute.of(context)!.settings.arguments as ChatArgs;
            return Scaffold(
              body: Text(
                'Chat with ${args.peerName}, ID: ${args.conversationId}',
              ),
            );
          },
          Routes.listing: (context) {
            final args =
                ModalRoute.of(context)!.settings.arguments as ListingArgs;
            return Scaffold(body: Text('Listing Slug: ${args.id}'));
          },
        },
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'valid_token',
      'refresh_token': 'valid_refresh',
      'user_phone': '+996555123456',
      'user_name': 'Тестовый Пользователь',
    });
  });

  group('Profile Latest Notifications Tests', () {
    testWidgets(
      'Regular Profile renders real backend notifications and no mock data',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('overflowed')) return;
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        final server = _MockHttpServer(
          notifications: [
            {
              'id': 101,
              'type': 'new_message',
              'title': 'Азамат Сообщение',
              'body': 'Здравствуйте! Квартира свободна?',
              'payload': {'conversation_id': kConversationId, 'sender_id': 42},
              'is_read': false,
              'created_at': '2026-09-02T10:00:00Z',
            },
            {
              'id': 102,
              'type': 'price_drop',
              'title': 'Снижение цены',
              'body': 'Цена снизилась на 3000 USD',
              'payload': {'listing_slug': 'tokmok-house-12'},
              'listing_slug': 'tokmok-house-12',
              'is_read': true,
              'created_at': '2026-09-02T09:00:00Z',
            },
          ],
        );

        final state = AppState(
          apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
        );

        await tester.pumpWidget(_wrapWithApp(const ProfilePage(), state));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(kProfileNotificationsSectionKey), findsOneWidget);
        expect(find.text('Азамат Сообщение'), findsOneWidget);
        expect(find.text('Здравствуйте! Квартира свободна?'), findsOneWidget);
        expect(find.text('Снижение цены'), findsOneWidget);
        expect(find.text('Цена снизилась на 3000 USD'), findsOneWidget);

        expect(find.byKey(kProfileNotificationTileKey(101)), findsOneWidget);
        expect(find.byKey(kProfileNotificationTileKey(102)), findsOneWidget);
      },
    );

    testWidgets('Pro Profile renders real notifications and no mock data', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({
        'access_token': 'valid_token',
        'refresh_token': 'valid_refresh',
        'is_pro': true,
        'user_phone': '+996555123456',
        'user_name': 'Pro Агент',
      });

      final server = _MockHttpServer(
        notifications: [
          {
            'id': 201,
            'type': 'new_message',
            'title': 'Канат Клиент',
            'body': 'Хочу посмотреть квартиру сегодня',
            'payload': {'conversation_id': kConversationId, 'sender_id': 99},
            'is_read': false,
            'created_at': '2026-09-02T11:00:00Z',
          },
        ],
      );

      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
      );

      await tester.pumpWidget(_wrapWithApp(const ProProfilePage(), state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationsSectionKey), findsOneWidget);
      expect(find.text('Канат Клиент'), findsOneWidget);
      expect(find.text('Хочу посмотреть квартиру сегодня'), findsOneWidget);
    });

    testWidgets(
      'Kyrgyz Pro Profile localizes listings header and test push text',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({
          'access_token': 'valid_token',
          'refresh_token': 'valid_refresh',
          'is_pro': true,
          'user_phone': '+996555123456',
          'user_name': 'Pro Агент',
        });

        final server = _MockHttpServer(
          notifications: [
            {
              'id': 202,
              'type': 'system',
              'title': 'House KG — проверка прочтения',
              'body':
                  'Контрольное уведомление. Нажмите, чтобы открыть чат и обновить счётчик.',
              'payload': {'kind': 'test_push'},
              'is_read': false,
              'created_at': '2026-09-02T11:00:00Z',
            },
          ],
        );

        final state = AppState(
          apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            const ProProfilePage(),
            state,
            locale: const Locale('ky'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Бардык жарыялар'), findsOneWidget);
        expect(find.text('House KG — окулганын текшерүү'), findsOneWidget);
        expect(
          find.text(
            'Көзөмөл билдирмеси. Чатты ачып, эсептегичти жаңыртуу үчүн басыңыз.',
          ),
          findsOneWidget,
        );
        expect(find.text('House KG — проверка прочтения'), findsNothing);
      },
    );

    testWidgets(
      'Profile screen dynamically localizes test push notification without payload kind on language switch',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final server = _MockHttpServer(
          notifications: [
            {
              'id': 205,
              'type': 'system',
              'title': 'House KG - проверка прочтения',
              'body':
                  'Контрольное уведомление. Нажмите, чтобы открыть чат и обновить счётчик.',
              'payload': <String, dynamic>{},
              'is_read': false,
              'created_at': '2026-09-02T11:00:00Z',
            },
          ],
        );

        final state = AppState(
          apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            const ProfilePage(),
            state,
            locale: const Locale('ru'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Initial Russian state
        expect(find.text('House KG — проверка прочтения'), findsOneWidget);
        expect(
          find.text(
            'Контрольное уведомление. Нажмите, чтобы открыть чат и обновить счётчик.',
          ),
          findsOneWidget,
        );

        // Switch to Kyrgyz
        await tester.tap(find.text('Кыргызча'));
        await tester.pumpAndSettle();

        // Notification is now localized in Kyrgyz
        expect(find.text('House KG — окулганын текшерүү'), findsOneWidget);
        expect(
          find.text(
            'Көзөмөл билдирмеси. Чатты ачып, эсептегичти жаңыртуу үчүн басыңыз.',
          ),
          findsOneWidget,
        );
        expect(find.text('House KG - проверка прочтения'), findsNothing);
        expect(find.text('House KG — проверка прочтения'), findsNothing);

        // Switch back to Russian
        await tester.tap(find.text('Орусча'));
        await tester.pumpAndSettle();

        expect(find.text('House KG — проверка прочтения'), findsOneWidget);
        expect(
          find.text(
            'Контрольное уведомление. Нажмите, чтобы открыть чат и обновить счётчик.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Test push with only Russian title_i18n in payload localizes to Kyrgyz on ky locale',
      (tester) async {
        final server = _MockHttpServer(
          notifications: [
            {
              'id': 206,
              'type': 'system',
              'title': 'House KG — проверка прочтения',
              'body':
                  'Контрольное уведомление. Нажмите, чтобы открыть чат и обновить счётчик.',
              'payload': {
                'kind': 'test_push',
                'title_i18n': {'ru': 'House KG — проверка прочтения'},
                'body_i18n': {
                  'ru':
                      'Контрольное уведомление. Нажмите, чтобы открыть чат и обновить счётчик.',
                },
              },
              'is_read': false,
              'created_at': '2026-09-02T11:00:00Z',
            },
          ],
        );

        final state = AppState(
          apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            const ProfileLatestNotifications(),
            state,
            locale: const Locale('ky'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('House KG — окулганын текшерүү'), findsOneWidget);
        expect(
          find.text(
            'Көзөмөл билдирмеси. Чатты ачып, эсептегичти жаңыртуу үчүн басыңыз.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Empty state shows "У вас пока нет уведомлений"', (
      tester,
    ) async {
      final server = _MockHttpServer(notifications: []);
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
      );

      await tester.pumpWidget(
        _wrapWithApp(const ProfileLatestNotifications(), state),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationsEmptyKey), findsOneWidget);
      expect(find.text('У вас пока нет уведомлений'), findsOneWidget);
    });

    testWidgets('Error state shows error message without mock fallback', (
      tester,
    ) async {
      final server = _MockHttpServer(failNotifications: true);
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
      );

      await tester.pumpWidget(
        _wrapWithApp(const ProfileLatestNotifications(), state),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationsErrorKey), findsOneWidget);
      expect(find.text('Не удалось загрузить уведомления'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
    });

    testWidgets('Tap "Посмотреть все" opens NotificationsPage', (tester) async {
      final server = _MockHttpServer(notifications: []);
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
      );

      await tester.pumpWidget(
        _wrapWithApp(const ProfileLatestNotifications(), state),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(kProfileNotificationsSeeAllKey));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets(
      'Tap new_message notification opens ChatPage and marks as read',
      (tester) async {
        final server = _MockHttpServer(
          notifications: [
            {
              'id': 301,
              'type': 'new_message',
              'title': 'Азамат',
              'body': 'Вопрос по объекту',
              'payload': {'conversation_id': kConversationId, 'sender_id': 42},
              'is_read': false,
              'created_at': '2026-09-02T10:00:00Z',
            },
          ],
        );

        final state = AppState(
          apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
        );

        await tester.pumpWidget(
          _wrapWithApp(const ProfileLatestNotifications(), state),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(kProfileNotificationTileKey(301)), findsOneWidget);
        await tester.tap(find.byKey(kProfileNotificationTileKey(301)));
        await tester.pumpAndSettle();

        expect(
          find.text('Chat with Азамат, ID: $kConversationId'),
          findsOneWidget,
        );
        expect(server.markedReadIds, contains(301));
      },
    );

    testWidgets('Tap listing notification opens ListingPage', (tester) async {
      final server = _MockHttpServer(
        notifications: [
          {
            'id': 401,
            'type': 'price_drop',
            'title': 'Цена снизилась',
            'body': 'Дом в Бишкеке подешевел',
            'payload': {'listing_slug': 'bishkek-house-55'},
            'listing_slug': 'bishkek-house-55',
            'is_read': false,
            'created_at': '2026-09-02T10:00:00Z',
          },
        ],
      );

      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
      );

      await tester.pumpWidget(
        _wrapWithApp(const ProfileLatestNotifications(), state),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(kProfileNotificationTileKey(401)));
      await tester.pumpAndSettle();

      expect(find.text('Listing Slug: bishkek-house-55'), findsOneWidget);
      expect(server.markedReadIds, contains(401));
    });
  });
}
