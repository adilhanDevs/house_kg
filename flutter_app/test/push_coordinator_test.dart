import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/push/push_coordinator.dart';

class FakeMessaging implements PushMessaging {
  final refreshed = StreamController<String>.broadcast(sync: true);
  final opened = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final received = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  bool allowed = true;
  int requests = 0;
  int deleted = 0;
  String current = 'token-a';
  Map<String, dynamic>? initial;
  Completer<bool>? permissionGate;
  Completer<Map<String, dynamic>?>? initialGate;
  @override
  Stream<String> get tokenRefresh => refreshed.stream;
  @override
  Stream<Map<String, dynamic>> get taps => opened.stream;
  @override
  Stream<Map<String, dynamic>> get foreground => received.stream;
  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      initialGate == null ? initial : initialGate!.future;
  @override
  Future<bool> permission() async {
    requests++;
    return permissionGate == null ? allowed : permissionGate!.future;
  }

  @override
  Future<String?> token() async => current;
  @override
  Future<void> deleteToken() async {
    deleted++;
  }
}

Map<String, dynamic> message({
  String type = 'new_message',
  String user = '7',
  String id = '12',
}) => {
  'type': type,
  'recipient_id': user,
  'notification_id': id,
  'conversation_id': '9df0be32-75b8-4a76-9fdd-a8d28e7a3a10',
  'listing_slug': 'home-42',
};
void main() {
  test(
    'parses canonical chat and listing identifiers and rejects malformed payloads',
    () {
      expect(
        PushIntent.parse(message())?.conversationId,
        '9df0be32-75b8-4a76-9fdd-a8d28e7a3a10',
      );
      expect(
        PushIntent.parse(message(type: 'price_drop'))?.listingSlug,
        'home-42',
      );
      for (final data in [
        {},
        {...message(), 'conversation_id': ''},
        {...message(), 'recipient_id': null},
        {...message(type: 'price_drop'), 'listing_slug': '../wrong'},
        message(type: 'unknown'),
      ]) {
        expect(PushIntent.parse(Map<String, dynamic>.from(data)), isNull);
      }
    },
  );
  test(
    'malformed notification IDs preserve valid destinations without marking read',
    () {
      for (final id in [
        null,
        [],
        '0',
        '-1',
        'bad',
        '9999999999999999999999999999',
      ]) {
        final intent = PushIntent.parse({...message(), 'notification_id': id});
        expect(intent?.conversationId, message()['conversation_id']);
        expect(intent?.notificationId, isNull);
      }
    },
  );
  late FakeMessaging messaging;
  late PushCoordinator coordinator;
  late List<String> calls;
  setUp(() {
    messaging = FakeMessaging();
    calls = [];
    coordinator = PushCoordinator(
      messaging: messaging,
      register: (token) async {
        calls.add('register:$token');
      },
      deactivate: () async {
        calls.add('deactivate');
      },
      onForeground: () {
        calls.add('foreground');
      },
      onPending: () {},
    );
  });
  tearDown(() async {
    await coordinator.dispose();
  });
  test(
    'guest never registers; login registers once; refresh registers replacement',
    () async {
      await coordinator.start();
      await coordinator.setUser(null);
      expect(calls, isEmpty);
      await coordinator.setUser(7);
      await coordinator.setUser(7);
      expect(calls, ['register:token-a']);
      messaging.current = 'token-b';
      messaging.refreshed.add('token-b');
      await coordinator.idle;
      expect(calls.last, 'register:token-b');
    },
  );
  test(
    'logout deactivates before new account registration and keeps FCM token',
    () async {
      await coordinator.start();
      await coordinator.setUser(7);
      await coordinator.logout();
      await coordinator.setUser(8);
      expect(calls, ['register:token-a', 'deactivate', 'register:token-a']);
      expect(messaging.deleted, 0);
    },
  );
  test(
    'failed backend deactivation invalidates FCM delivery as fallback',
    () async {
      await coordinator.dispose();
      coordinator = PushCoordinator(
        messaging: messaging,
        register: (_) async {},
        deactivate: () async {
          throw Exception('offline');
        },
        onForeground: () {},
        onPending: () {},
      );
      await coordinator.setUser(7);
      await coordinator.logout();
      expect(messaging.deleted, 1);
    },
  );
  test('logout during permission wait cannot register stale session', () async {
    messaging.permissionGate = Completer<bool>();
    await coordinator.start();
    final login = coordinator.setUser(7);
    await Future<void>.delayed(Duration.zero);
    final logout = coordinator.logout();
    messaging.permissionGate!.complete(true);
    await login;
    await logout;
    expect(calls, ['deactivate']);
  });
  test(
    'denied permission is nonblocking and resume can register after settings change',
    () async {
      messaging.allowed = false;
      await coordinator.start();
      await coordinator.setUser(7);
      expect(calls, isEmpty);
      messaging.allowed = true;
      await coordinator.resume();
      expect(calls, ['register:token-a']);
    },
  );
  test('failed registration is retried on resume without throwing', () async {
    await coordinator.dispose();
    int attempts = 0;
    coordinator = PushCoordinator(
      messaging: messaging,
      register: (_) async {
        if (++attempts == 1) throw Exception('offline');
      },
      deactivate: () async {},
      onForeground: () {},
      onPending: () {},
    );
    await coordinator.start();
    await coordinator.setUser(7);
    await coordinator.resume();
    expect(attempts, 2);
  });
  test('cold start waits for user and navigation then consumes once', () async {
    messaging.initial = message();
    await coordinator.start();
    expect(coordinator.takePending(navigationReady: true), isNull);
    await coordinator.setUser(7);
    expect(coordinator.takePending(navigationReady: false), isNull);
    expect(
      coordinator.takePending(navigationReady: true)?.notificationId,
      '12',
    );
    messaging.opened.add(message());
    expect(coordinator.takePending(navigationReady: true), isNull);
  });
  test('slow initial message survives authentication hydration', () async {
    messaging.initialGate = Completer<Map<String, dynamic>?>();
    final startup = coordinator.start();
    await coordinator.setUser(7);
    messaging.initialGate!.complete(message());
    await startup;
    expect(
      coordinator.takePending(navigationReady: true)?.notificationId,
      '12',
    );
  });
  test(
    'old recipient tap cannot open after account switch or logout',
    () async {
      await coordinator.start();
      await coordinator.setUser(7);
      messaging.opened.add(message());
      await coordinator.logout();
      await coordinator.setUser(8);
      expect(coordinator.takePending(navigationReady: true), isNull);
      messaging.opened.add(message());
      expect(coordinator.takePending(navigationReady: true), isNull);
    },
  );
  test(
    'foreground refreshes only current recipient and does not navigate',
    () async {
      await coordinator.start();
      await coordinator.setUser(7);
      messaging.received.add(message(user: '8'));
      messaging.received.add(message());
      expect(calls.where((v) => v == 'foreground').length, 1);
      expect(coordinator.takePending(navigationReady: true), isNull);
    },
  );
}
