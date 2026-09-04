import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:house_kgz/data/api_client.dart';

void main() {
  test(
    'expired device request never refreshes into a different account',
    () async {
      var refreshCalls = 0;
      final server = MockClient((request) async => http.Response('{}', 401));
      final api = ListingApiClient(
        baseUrl: 'https://test.invalid',
        client: server,
      )..setToken('old-session');
      api.setTokenRefreshCallback(() async {
        refreshCalls++;
        return 'new-session';
      });
      await expectLater(
        api.registerPushDevice(
          token: 'synthetic',
          deviceId: 'install',
          locale: 'ru',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(refreshCalls, 0);
    },
  );
  test(
    'device registration sends only real contract fields with session auth',
    () async {
      final requests = <http.Request>[];
      final api = ListingApiClient(
        baseUrl: 'https://test.invalid',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', request.method == 'DELETE' ? 204 : 200);
        }),
      )..setToken('test-session');
      await api.registerPushDevice(
        token: 'synthetic',
        deviceId: 'install',
        locale: 'ky',
      );
      await api.deactivatePushDevice('install');
      expect(jsonDecode(requests.first.body), {
        'token': 'synthetic',
        'device_id': 'install',
        'platform': 'android',
        'locale': 'ky',
      });
      expect(requests.first.headers['Authorization'], 'Bearer test-session');
      expect(requests.last.url.path, '/api/v1/notifications/devices/current/');
      expect(jsonDecode(requests.last.body), {'device_id': 'install'});
    },
  );
}
