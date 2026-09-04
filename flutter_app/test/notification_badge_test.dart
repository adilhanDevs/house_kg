// Красный счётчик непрочитанных на колокольчике.
//
// Число берётся у сервера: своего счётчика клиент не ведёт, иначе после
// прочтения на другом устройстве цифра врала бы.
import 'dart:convert';
import 'dart:async';
import 'package:http/testing.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/widgets/notification_badge.dart';

class _CountServer extends http.BaseClient {
  _CountServer(this.count);

  final int count;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/notifications/unread-count/') {
      calls += 1;
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'count': count}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

Future<AppState> _authorized(http.BaseClient client) async {
  SharedPreferences.setMockInitialValues({
    'access_token': 'test-access',
    'refresh_token': 'test-refresh',
  });
  final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://t', client: client));
  await state.authInitialized;
  return state;
}

Widget _host(AppState state) => AppScope(
      state: state,
      child: const MaterialApp(
        home: Scaffold(body: Center(child: NotificationBadge())),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('older foreground refresh cannot overwrite newer badge count', (tester) async {
    final pending = <Completer<http.Response>>[];
    final state = await _authorized(MockClient((request) async {
      if (request.url.path == '/api/v1/notifications/unread-count/') {
        final response = Completer<http.Response>(); pending.add(response); return response.future;
      }
      return http.Response('{}', 200);
    }));
    await tester.pumpWidget(_host(state)); await _settle(tester);
    state.refreshPushNotifications(); await _settle(tester);
    expect(pending.length, 2);
    pending[1].complete(http.Response('{"count":2}', 200)); await _settle(tester);
    pending[0].complete(http.Response('{"count":1}', 200)); await _settle(tester);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('показывает количество непрочитанных', (tester) async {
    final state = await _authorized(_CountServer(3));

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(find.byKey(kNotificationBadgeKey), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('без непрочитанных значка нет', (tester) async {
    final state = await _authorized(_CountServer(0));

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(find.byKey(kNotificationBadgeKey), findsNothing);
  });

  testWidgets('больше сотни сокращается до 99+', (tester) async {
    final state = await _authorized(_CountServer(128));

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('без авторизации сервер не опрашивается', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final server = _CountServer(5);
    final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://t', client: server));
    await state.authInitialized;

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(server.calls, 0);
    expect(find.byKey(kNotificationBadgeKey), findsNothing);
  });

  testWidgets('ошибка сервера не роняет экран', (tester) async {
    final state = await _authorized(_BrokenServer());

    await tester.pumpWidget(_host(state));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(kNotificationBadgeKey), findsNothing);
  });
}

class _BrokenServer extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({
        'error': {'code': 'server_error', 'message': 'Сервер недоступен', 'details': {}}
      }))),
      500,
      headers: {'content-type': 'application/json'},
    );
  }
}
