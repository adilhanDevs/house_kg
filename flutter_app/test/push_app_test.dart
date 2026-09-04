import 'dart:convert';
import 'dart:async';
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
import 'push_coordinator_test.dart' show FakeMessaging, message;

void main() {
  test(
    'profile retry completing after logout cannot restore previous user',
    () async {
      SharedPreferences.setMockInitialValues({'access_token': 'test-access'});
      Completer<http.Response>? delayed;
      final api = ListingApiClient(
        baseUrl: 'https://test.invalid',
        client: MockClient((r) async {
          if (r.url.path == '/api/v1/users/me/') {
            return delayed == null
                ? http.Response('{"id":7,"name":"Previous"}', 200)
                : delayed.future;
          }
          return http.Response('{"results":[]}', 200);
        }),
      );
      final state = AppState(apiClient: api);
      await state.authInitialized;
      delayed = Completer<http.Response>();
      final retry = state.fetchProfile();
      await state.logout();
      delayed.complete(http.Response('{"id":7,"name":"Previous"}', 200));
      await retry;
      expect(state.userId, isNull);
      expect(state.userName, isNull);
      state.dispose();
    },
  );

  testWidgets('older foreground refresh cannot remove a newer notification', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'access_token': 'test-access'});
    final pending = <Completer<http.Response>>[];
    bool delayResponses = false;
    final api = ListingApiClient(
      baseUrl: 'https://test.invalid',
      client: MockClient((r) async {
        if (r.url.path == '/api/v1/users/me/') {
          return http.Response('{"id":7}', 200);
        }
        if (r.url.path == '/api/v1/notifications/' && delayResponses) {
          final c = Completer<http.Response>();
          pending.add(c);
          return c.future;
        }
        return http.Response('{"results":[],"count":0}', 200);
      }),
    );
    final messaging = FakeMessaging();
    await tester.pumpWidget(
      HouseKgzAppScope(
        initialRoute: Routes.notifications,
        apiClient: api,
        pushMessaging: messaging,
      ),
    );
    await tester.pumpAndSettle();
    delayResponses = true;
    messaging.received.add(message());
    messaging.received.add(message(id: '13'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(pending.length, 2);
    pending[1].complete(
      http.Response(
        jsonEncode({
          'results': [
            {
              'id': 12,
              'type': 'system',
              'title': 'Newest event',
              'body': 'Newest body',
              'payload': {},
            },
          ],
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    pending[0].complete(http.Response('{"results":[]}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Newest event'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'offline profile hydration recovers on resume and drains cold-start tap',
    (tester) async {
      SharedPreferences.setMockInitialValues({'access_token': 'test-access'});
      bool online = false;
      int registrations = 0;
      final api = ListingApiClient(
        baseUrl: 'https://test.invalid',
        client: MockClient((r) async {
          if (r.url.path == '/api/v1/users/me/') {
            if (!online) throw Exception('offline');
            return http.Response('{"id":7}', 200);
          }
          if (r.url.path == '/api/v1/notifications/devices/') registrations++;
          return http.Response('{"results":[],"count":0}', 200);
        }),
      );
      final messaging = FakeMessaging()..initial = message();
      await tester.pumpWidget(
        HouseKgzAppScope(
          initialRoute: Routes.notifications,
          apiClient: api,
          pushMessaging: messaging,
        ),
      );
      await tester.pumpAndSettle();
      expect(registrations, 0);
      online = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(registrations, 1);
      expect(find.byType(ChatPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cold-start tap waits for splash then opens existing chat once; logout uses authenticated device API',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'test-access',
        'refresh_token': 'test-refresh',
      });
      final requests = <http.Request>[];
      final api = ListingApiClient(
        baseUrl: 'https://test.invalid',
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path == '/api/v1/users/me/') {
            return http.Response(jsonEncode({'id': 7, 'name': 'Test'}), 200);
          }
          if (r.url.path == '/api/v1/notifications/devices/current/') {
            return http.Response('', 204);
          }
          return http.Response(jsonEncode({'results': [], 'count': 0}), 200);
        }),
      );
      final messaging = FakeMessaging()..initial = message();
      await tester.pumpWidget(
        HouseKgzAppScope(apiClient: api, pushMessaging: messaging),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ChatPage), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChatPage>(find.byType(ChatPage)).args.conversationId,
        message()['conversation_id'],
      );
      final registration = requests
          .where((r) => r.url.path == '/api/v1/notifications/devices/')
          .single;
      final device = jsonDecode(registration.body) as Map;
      expect(device['platform'], 'android');
      expect(device['token'], 'token-a');
      expect(device['device_id'], isNotEmpty);
      expect(registration.headers['Authorization'], 'Bearer test-access');
      final state = AppScope.read(tester.element(find.byType(ChatPage)));
      state.refreshPushNotifications();
      await tester.pumpAndSettle();
      expect(
        requests
            .where((r) => r.url.path == '/api/v1/notifications/devices/')
            .length,
        1,
      );
      messaging.opened.add(message());
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      await state.logout();
      await tester.pumpAndSettle();
      final deactivation = requests
          .where((r) => r.url.path == '/api/v1/notifications/devices/current/')
          .single;
      expect(deactivation.method, 'DELETE');
      expect(jsonDecode(deactivation.body)['device_id'], device['device_id']);
      expect(deactivation.headers['Authorization'], 'Bearer test-access');
      expect(state.userId, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'price drop tap opens existing listing route with canonical slug',
    (tester) async {
      SharedPreferences.setMockInitialValues({'access_token': 'test-access'});
      final api = ListingApiClient(
        baseUrl: 'https://test.invalid',
        client: MockClient((r) async {
          if (r.url.path == '/api/v1/users/me/') {
            return http.Response('{"id":7}', 200);
          }
          return http.Response('{"results":[],"count":0}', 200);
        }),
      );
      final messaging = FakeMessaging();
      await tester.pumpWidget(
        HouseKgzAppScope(
          initialRoute: Routes.notifications,
          apiClient: api,
          pushMessaging: messaging,
        ),
      );
      await tester.pumpAndSettle();
      messaging.opened.add(message(type: 'price_drop'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListingPage>(find.byType(ListingPage)).id,
        'home-42',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
