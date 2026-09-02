import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/chat_models.dart';
import 'package:house_kgz/l10n/l10n.dart';
import 'package:house_kgz/ui/pages/notifications_page.dart';
import 'package:house_kgz/ui/widgets/price_drop_notification_tile.dart';
import 'package:house_kgz/ui/widgets/profile_latest_notifications.dart';

Map<String, dynamic> _samplePriceDropJson({
  int id = 10,
  bool isRead = false,
  String oldPrice = '107000',
  String newPrice = '102000',
  String currency = 'USD',
  String district = 'Технопарк',
  int rooms = 3,
  String area = '92',
  int floor = 8,
  String slug = 'technopark-3k-92',
}) =>
    {
      'id': id,
      'type': 'price_drop',
      'title': 'Цена снизилась',
      'body': 'Цена снизилась: $district — 102 000\$',
      'is_read': isRead,
      'listing_slug': slug,
      'payload': {
        'listing_id': 42,
        'listing_slug': slug,
        'old_price': oldPrice,
        'new_price': newPrice,
        'currency': currency,
        'district': district,
        'rooms': rooms,
        'area': area,
        'floor': floor,
        'floors': 12,
        'cover_url': 'https://example.com/cover.jpg',
      },
      'created_at': '2026-09-02T10:00:00Z',
    };

Map<String, dynamic> _sampleNewMessageJson({
  int id = 20,
  bool isRead = false,
  String conversationId = 'conv-123',
}) =>
    {
      'id': id,
      'type': 'new_message',
      'title': 'Азамат',
      'body': 'Здравствуйте, объект ещё актуален?',
      'is_read': isRead,
      'payload': {
        'conversation_id': conversationId,
        'sender_id': 5,
      },
      'created_at': '2026-09-02T10:05:00Z',
    };

class _Server extends http.BaseClient {
  _Server({this.notifications = const []});

  final List<Map<String, dynamic>> notifications;
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
      return _json({'updated': markedRead?.length ?? 0, 'unread_count': 0});
    }
    if (path == '/api/v1/users/me/') {
      return _json({
        'id': 1,
        'phone': '+996700000001',
        'name': 'Демо Клиент',
        'is_pro': false,
      });
    }
    return _json({});
  }
}

Widget _wrap(Widget child, AppState state, {List<String>? log}) {
  return AppScope(
    state: state,
    child: MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) {
        if (log != null) log.add(settings.name ?? '');
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => Scaffold(
            body: Center(child: Text('ROUTE: ${settings.name}')),
          ),
        );
      },
      home: Scaffold(body: child),
    ),
  );
}

Future<AppState> _authorized(_Server server) async {
  SharedPreferences.setMockInitialValues({
    'access_token': 'test-access',
    'refresh_token': 'test-refresh',
  });
  final state = AppState(
    apiClient: ListingApiClient(baseUrl: 'http://test.com', client: server),
  );
  await state.authInitialized;
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-access',
      'refresh_token': 'test-refresh',
    });
  });

  group('Price Drop Notification Parsing', () {
    test('parses price_drop attributes and getters properly', () {
      final json = _samplePriceDropJson();
      final notification = AppNotification.fromJson(json);

      expect(notification.isPriceDrop, isTrue);
      expect(notification.isNewMessage, isFalse);
      expect(notification.oldPrice, '107000');
      expect(notification.newPrice, '102000');
      expect(notification.currency, 'USD');
      expect(notification.districtName, 'Технопарк');
      expect(notification.rooms, 3);
      expect(notification.area, '92');
      expect(notification.floor, 8);
      expect(notification.coverUrl, 'https://example.com/cover.jpg');
      expect(notification.listingSlug, 'technopark-3k-92');
    });
  });

  group('Price Drop UI Rendering', () {
    testWidgets('renders cover, title, specs, strikethrough old price, new price, and status in Tile',
        (tester) async {
      final notification = AppNotification.fromJson(_samplePriceDropJson());
      final server = _Server();
      final state = AppState(
        apiClient: ListingApiClient(baseUrl: 'http://test', client: server),
      );
      await state.authInitialized;

      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          PriceDropNotificationTile(
            notification: notification,
            onTap: () => tapped = true,
          ),
          state,
        ),
      );
      await tester.pumpAndSettle();

      // Title/District
      expect(find.text('Технопарк'), findsOneWidget);

      // Specs
      expect(find.text('3-комн. • 92 м² • 8 эт.'), findsOneWidget);

      // Old price formatted with strikethrough
      final oldPriceFinder = find.text('107 000 \$');
      expect(oldPriceFinder, findsOneWidget);
      final oldPriceText = tester.widget<Text>(oldPriceFinder);
      expect(oldPriceText.style?.decoration, TextDecoration.lineThrough);

      // New price
      expect(find.text('102 000 \$'), findsOneWidget);

      // "Цена снизилась"
      expect(find.text('Цена снизилась'), findsOneWidget);

      // Tap
      await tester.tap(find.byType(PriceDropNotificationTile));
      expect(tapped, isTrue);
    });

    testWidgets('ProfileLatestNotifications renders both price_drop and new_message distinct layouts',
        (tester) async {
      final server = _Server(notifications: [
        _samplePriceDropJson(id: 1),
        _sampleNewMessageJson(id: 2),
      ]);
      final state = await _authorized(server);

      await tester.pumpWidget(
        _wrap(const ProfileLatestNotifications(), state),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Price drop card elements
      expect(find.text('Технопарк'), findsOneWidget);
      expect(find.text('3-комн. • 92 м² • 8 эт.'), findsOneWidget);
      expect(find.text('107 000 \$'), findsOneWidget);
      expect(find.text('102 000 \$'), findsOneWidget);
      expect(find.text('Цена снизилась'), findsOneWidget);

      // Message card elements
      expect(find.text('Азамат'), findsOneWidget);
      expect(find.text('Здравствуйте, объект ещё актуален?'), findsOneWidget);
    });

    testWidgets('NotificationsPage renders price_drop tile and navigates to listing on tap',
        (tester) async {
      final server = _Server(notifications: [
        _samplePriceDropJson(id: 1, slug: 'technopark-3k-92'),
      ]);
      final state = await _authorized(server);
      final routes = <String>[];

      await tester.pumpWidget(
        _wrap(const NotificationsPage(), state, log: routes),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Технопарк'), findsOneWidget);
      expect(find.text('102 000 \$'), findsOneWidget);

      await tester.tap(find.text('Технопарк'));
      await tester.pumpAndSettle();

      expect(routes, contains(Routes.listing));
      expect(server.markedRead, contains(1));
    });

    testWidgets('Tap price_drop in ProfileLatestNotifications opens listing and marks read',
        (tester) async {
      final server = _Server(notifications: [
        _samplePriceDropJson(id: 5, slug: 'technopark-3k-92', isRead: false),
      ]);
      final state = await _authorized(server);
      final routes = <String>[];

      await tester.pumpWidget(
        _wrap(const ProfileLatestNotifications(), state, log: routes),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Технопарк'));
      await tester.pumpAndSettle();

      expect(routes, contains(Routes.listing));
      expect(server.markedRead, contains(5));
    });
  });
}
