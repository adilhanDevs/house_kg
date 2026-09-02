import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/notifications_page.dart';
import 'package:house_kgz/ui/pages/profile_page.dart';
import 'package:house_kgz/ui/pages/pro_profile_page.dart';
import 'package:house_kgz/ui/widgets/profile_latest_notifications.dart';

class _DynamicMockHttpServer extends http.BaseClient {
  _DynamicMockHttpServer({
    this.notifications = const [],
    this.failNotifications = false,
  });

  List<Map<String, dynamic>> notifications;
  bool failNotifications;

  http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (path.contains('/api/v1/users/me/')) {
      return _json({
        'id': 1,
        'phone': '+996555123456',
        'name': 'Бакыт Байке',
        'is_pro': false,
        'role': 'client',
      });
    }

    if (path.contains('/api/v1/notifications/unread-count/')) {
      return _json({'count': 0});
    }

    if (path.contains('/api/v1/notifications/read/')) {
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
      return _json({
        'count': 0,
        'results': [],
      });
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

Widget _wrapApp(Widget child, AppState state) {
  return MaterialApp(
    routes: {
      Routes.notifications: (context) => const NotificationsPage(),
    },
    home: AppScope(
      state: state,
      child: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'valid_token',
      'refresh_token': 'valid_refresh',
      'user_phone': '+996555123456',
      'user_name': 'Бакыт Байке',
    });
  });

  group('Profile Dynamic Notifications Layout Tests', () {
    testWidgets('Regular Profile: 0 notifications -> empty state & Settings positioned naturally', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final server = _DynamicMockHttpServer(notifications: []);
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server));

      await tester.pumpWidget(_wrapApp(const ProfilePage(), state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationsEmptyKey), findsOneWidget);
      expect(find.text('У вас пока нет уведомлений'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);

      final emptyBottom = tester.getBottomLeft(find.byKey(kProfileNotificationsEmptyKey)).dy;
      final settingsTop = tester.getTopLeft(find.text('Настройки')).dy;

      // Settings should be positioned below the notifications section with no large mock gap (< 100px)
      expect(settingsTop, greaterThan(emptyBottom));
      expect(settingsTop - emptyBottom, lessThan(100.0));
    });

    testWidgets('Regular Profile: 1 notification -> single card & natural settings placement', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final server1 = _DynamicMockHttpServer(
        notifications: [
          {
            'id': 1,
            'type': 'new_message',
            'title': 'Первое сообщение',
            'body': 'Здравствуйте! Интересует объект',
            'is_read': false,
            'created_at': '2026-09-02T12:00:00Z',
          }
        ],
      );
      final state1 = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server1));

      await tester.pumpWidget(_wrapApp(const ProfilePage(), state1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationTileKey(1)), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);

      final tileBottom = tester.getBottomLeft(find.byKey(kProfileNotificationTileKey(1))).dy;
      final settingsTop = tester.getTopLeft(find.text('Настройки')).dy;
      expect(settingsTop, greaterThan(tileBottom));
    });

    testWidgets('Regular Profile: 2 notifications -> Settings moves further down naturally', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final server2 = _DynamicMockHttpServer(
        notifications: [
          {
            'id': 1,
            'type': 'new_message',
            'title': 'Первое сообщение',
            'body': 'Здравствуйте! Интересует объект',
            'is_read': false,
            'created_at': '2026-09-02T12:00:00Z',
          },
          {
            'id': 2,
            'type': 'price_drop',
            'title': 'Цена снижена',
            'body': 'Объект подешевел на 5000 USD',
            'is_read': true,
            'created_at': '2026-09-02T11:00:00Z',
          }
        ],
      );
      final state2 = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server2));

      await tester.pumpWidget(_wrapApp(const ProfilePage(), state2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationTileKey(1)), findsOneWidget);
      expect(find.byKey(kProfileNotificationTileKey(2)), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('Regular Profile: Long text notification wraps without overflow and pushes settings', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final server = _DynamicMockHttpServer(
        notifications: [
          {
            'id': 99,
            'type': 'new_message',
            'title': 'Очень длинный заголовок уведомления от риелтора по новостройке в центре Бишкека',
            'body': 'Очень подробное описание сообщения с деталями объекта, условиями рассрочки и контактами для связи в WhatsApp и звонков.',
            'is_read': false,
            'created_at': '2026-09-02T12:00:00Z',
          }
        ],
      );
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server));

      await tester.pumpWidget(_wrapApp(const ProfilePage(), state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationTileKey(99)), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);

      final cardBottom = tester.getBottomLeft(find.byKey(kProfileNotificationTileKey(99))).dy;
      final settingsTop = tester.getTopLeft(find.text('Настройки')).dy;
      expect(settingsTop, greaterThan(cardBottom));
    });

    testWidgets('Regular Profile: Error state displays retry without fixed blank gap', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final server = _DynamicMockHttpServer(failNotifications: true);
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server));

      await tester.pumpWidget(_wrapApp(const ProfilePage(), state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationsErrorKey), findsOneWidget);
      expect(find.text('Не удалось загрузить уведомления'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('Pro Profile: 0 notifications -> empty state & Settings positioned naturally', (tester) async {
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

      final server = _DynamicMockHttpServer(notifications: []);
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server));

      await tester.pumpWidget(_wrapApp(const ProProfilePage(), state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationsEmptyKey), findsOneWidget);
      expect(find.text('У вас пока нет уведомлений'), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('Pro Profile: 1 notification -> single card & natural settings placement', (tester) async {
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

      final server = _DynamicMockHttpServer(
        notifications: [
          {
            'id': 201,
            'type': 'new_message',
            'title': 'Канат Клиент',
            'body': 'Хочу посмотреть объект сегодня в 15:00',
            'is_read': false,
            'created_at': '2026-09-02T13:00:00Z',
          }
        ],
      );
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server));

      await tester.pumpWidget(_wrapApp(const ProProfilePage(), state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationTileKey(201)), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('Pro Profile: Long text notification wraps without overflow', (tester) async {
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

      final server = _DynamicMockHttpServer(
        notifications: [
          {
            'id': 202,
            'type': 'new_message',
            'title': 'Очень длинный заголовок от покупателя недвижимости с вопросами по документам',
            'body': 'Текст сообщения с вопросами про красную книгу, технический паспорт, коммуникации и рассрочку платежа.',
            'is_read': false,
            'created_at': '2026-09-02T13:00:00Z',
          }
        ],
      );
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server));

      await tester.pumpWidget(_wrapApp(const ProProfilePage(), state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationTileKey(202)), findsOneWidget);
      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('Small screen support: 320x480 renders without overflow and scrolls', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final server = _DynamicMockHttpServer(
        notifications: [
          {
            'id': 1,
            'type': 'new_message',
            'title': 'Сообщение',
            'body': 'Тестовое сообщение',
            'is_read': false,
            'created_at': '2026-09-02T12:00:00Z',
          }
        ],
      );
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server));

      await tester.pumpWidget(_wrapApp(const ProfilePage(), state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kProfileNotificationTileKey(1)), findsOneWidget);
      // Can scroll down on small screen
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Продать недвижимость'), findsOneWidget);
    });
  });
}
