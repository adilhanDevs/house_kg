import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:house_kgz/app/app.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/chat_page.dart';
import 'package:house_kgz/ui/pages/listing_page.dart';
import 'package:house_kgz/ui/pages/notifications_page.dart';
import 'package:house_kgz/ui/widgets/notification_badge.dart';
import 'push_coordinator_test.dart' show FakeMessaging, message;

class Server {
  int unread = 2;
  int user = 7;
  int? deviceOwner;
  bool active = false;
  final registrations = <String>[];
  final marked = <int>[];
  bool failRead = false;
  Completer<http.Response>? readGate;
  late final api = ListingApiClient(
    baseUrl: 'https://test.invalid',
    client: MockClient((r) async {
      final path = r.url.path;
      if (path == '/api/v1/users/me/') {
        return http.Response(jsonEncode({'id': user}), 200);
      }
      if (path == '/api/v1/auth/password/login/') {
        return http.Response(
          jsonEncode({
            'access': 'test-$user',
            'refresh': 'test-refresh-$user',
            'user': {'id': user},
          }),
          200,
        );
      }
      if (path == '/api/v1/notifications/devices/') {
        final body = jsonDecode(r.body);
        registrations.add(body['token']);
        active = true;
        deviceOwner = user;
      }
      if (path == '/api/v1/notifications/devices/current/') {
        active = false;
        return http.Response('', 204);
      }
      if (path == '/api/v1/notifications/read/') {
        final id = (jsonDecode(r.body)['ids'] as List).single as int;
        if (failRead) return http.Response('{}', 503);
        if (!marked.contains(id)) {
          marked.add(id);
          unread--;
        }
        return readGate == null
            ? http.Response(jsonEncode({'unread_count': unread}), 200)
            : readGate!.future;
      }
      if (path == '/api/v1/notifications/unread-count/') {
        return http.Response(jsonEncode({'count': unread}), 200);
      }
      return http.Response('{"results":[],"count":0}', 200);
    }),
  );
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
    }),
  );
  for (final type in ['new_message', 'price_drop']) {
    testWidgets(
      '$type system tap marks exact ID once and reconciles server badge',
      (tester) async {
        final server = Server();
        final messaging = FakeMessaging();
        await tester.pumpWidget(
          HouseKgzAppScope(
            initialRoute: Routes.notifications,
            apiClient: server.api,
            pushMessaging: messaging,
          ),
        );
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(NotificationsPage))).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: NotificationBadge()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);
        messaging.received.add(message(type: type));
        await tester.pumpAndSettle();
        expect(server.unread, 2);
        expect(server.marked, isEmpty);
        messaging.opened.add(message(type: type));
        await tester.pumpAndSettle();
        expect(server.marked, [12]);
        expect(server.unread, 1);
        if (type == 'new_message') {
          expect(
            tester.widget<ChatPage>(find.byType(ChatPage)).args.conversationId,
            message()['conversation_id'],
          );
        } else {
          expect(
            tester.widget<ListingPage>(find.byType(ListingPage)).id,
            'home-42',
          );
        }
        messaging.opened.add(message(type: type));
        await tester.pumpAndSettle();
        expect(server.marked, [12]);
        expect(server.unread, 1);
        expect(
          find.descendant(
            of: find.byType(NotificationBadge, skipOffstage: false),
            matching: find.text('1', skipOffstage: false),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('cold start performs one navigation and one mark-read', (
    tester,
  ) async {
    final server = Server();
    final messaging = FakeMessaging()..initial = message();
    await tester.pumpWidget(
      HouseKgzAppScope(apiClient: server.api, pushMessaging: messaging),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    messaging.opened.add(message());
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage, skipOffstage: false), findsOneWidget);
    expect(server.marked, [12]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('missing notification ID still navigates without marking read', (
    tester,
  ) async {
    final server = Server();
    final messaging = FakeMessaging();
    await tester.pumpWidget(
      HouseKgzAppScope(
        initialRoute: Routes.notifications,
        apiClient: server.api,
        pushMessaging: messaging,
      ),
    );
    await tester.pumpAndSettle();
    messaging.opened.add({...message()}..remove('notification_id'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
    expect(server.marked, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('slow mark-read does not delay navigation', (tester) async {
    final server = Server()..readGate = Completer<http.Response>();
    final messaging = FakeMessaging();
    await tester.pumpWidget(
      HouseKgzAppScope(
        initialRoute: Routes.notifications,
        apiClient: server.api,
        pushMessaging: messaging,
      ),
    );
    await tester.pumpAndSettle();
    messaging.opened.add(message());
    await tester.pumpAndSettle();
    expect(server.readGate!.isCompleted, false);
    expect(find.byType(ChatPage), findsOneWidget);
    server.readGate!.complete(http.Response('{"unread_count":1}', 200));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'mark-read failure never blocks navigation or decrements unread',
    (tester) async {
      final server = Server()..failRead = true;
      final messaging = FakeMessaging();
      await tester.pumpWidget(
        HouseKgzAppScope(
          initialRoute: Routes.notifications,
          apiClient: server.api,
          pushMessaging: messaging,
        ),
      );
      await tester.pumpAndSettle();
      messaging.opened.add(message());
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      expect(server.unread, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'unchanged token reactivates across real AppState login/logout/account switch',
    (tester) async {
      final server = Server();
      final messaging = FakeMessaging();
      await tester.pumpWidget(
        HouseKgzAppScope(
          initialRoute: Routes.notifications,
          apiClient: server.api,
          pushMessaging: messaging,
        ),
      );
      await tester.pumpAndSettle();
      final state = AppScope.read(
        tester.element(find.byType(NotificationsPage)),
      );
      expect(server.active, true);
      for (final user in [7, 8, 7]) {
        await state.logout();
        await tester.pumpAndSettle();
        expect(server.active, false);
        server.user = user;
        await state.loginWithPassword('test-phone', 'test-password');
        await tester.pumpAndSettle();
        expect(server.active, true);
        expect(server.deviceOwner, user);
      }
      expect(server.registrations, [
        'token-a',
        'token-a',
        'token-a',
        'token-a',
      ]);
      expect(messaging.deleted, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
