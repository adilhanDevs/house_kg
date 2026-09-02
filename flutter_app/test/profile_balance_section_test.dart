import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/l10n/l10n.dart';
import 'package:house_kgz/ui/pages/profile_page.dart';
import 'package:house_kgz/ui/pages/pro_profile_page.dart';
import 'package:house_kgz/ui/widgets/profile_balance_section.dart';

class _MockHttpServer extends http.BaseClient {
  _MockHttpServer({this.balance = 16700});

  int balance;

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
        'wallet_balance': {'balance': balance},
      });
    }

    if (path.contains('/api/v1/wallet/balance/')) {
      return _json({'balance': balance});
    }

    if (path.contains('/api/v1/notifications/unread-count/')) {
      return _json({'count': 0});
    }

    if (path.contains('/api/v1/notifications/')) {
      return _json({
        'count': 0,
        'next': null,
        'previous': null,
        'results': [],
      });
    }

    if (path.contains('/api/v1/listings/me/')) {
      return _json({
        'count': 0,
        'results': [],
      });
    }

    return _json({'detail': 'Not found'}, 404);
  }
}

Widget _wrap(Widget child, AppState state, {Locale locale = const Locale('ru'), VoidCallback? onTopupTap}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      Routes.topup: (context) {
        onTopupTap?.call();
        return const Scaffold(body: Text('Topup Screen'));
      },
      Routes.favourites: (context) => const Scaffold(body: Text('Favourites')),
      Routes.notifications: (context) => const Scaffold(body: Text('Notifications')),
      Routes.account: (context) => const Scaffold(body: Text('Account')),
      Routes.support: (context) => const Scaffold(body: Text('Support')),
      Routes.tariffs: (context) => const Scaffold(body: Text('Tariffs')),
      Routes.ad: (context) => const Scaffold(body: Text('Ad')),
    },
    home: AppScope(
      state: state,
      child: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'test_token'});
  });

  testWidgets('ProfileBalanceSection displays formatted balance, title and orange topup button', (tester) async {
    final mockHttp = _MockHttpServer(balance: 16700);
    final apiClient = ListingApiClient(baseUrl: 'http://localhost', client: mockHttp);
    apiClient.setToken('test_token');
    final state = AppState(apiClient: apiClient);
    state.isInitializing = false;
    state.userName = 'Бакыт Байке';
    state.userPhone = '+996555123456';
    state.walletBalance = 16700;

    await tester.pumpWidget(_wrap(const Scaffold(body: ProfileBalanceSection()), state));
    await tester.pumpAndSettle();

    expect(find.byKey(kProfileBalanceSectionKey), findsOneWidget);
    expect(find.text('16 700 кирпичей'), findsOneWidget);
    expect(find.text('Баланс'), findsOneWidget);
    expect(find.text('Пополнить'), findsOneWidget);

    // Verify button styling (orange background, white text)
    final btnFinder = find.byKey(kProfileBalanceTopupButtonKey);
    expect(btnFinder, findsOneWidget);
    final elevatedBtn = tester.widget<ElevatedButton>(btnFinder);
    final bgColor = elevatedBtn.style?.backgroundColor?.resolve({});
    expect(bgColor, equals(const Color(0xffea812e)));
  });

  testWidgets('ProfileBalanceSection updates dynamically when balance changes', (tester) async {
    final mockHttp = _MockHttpServer(balance: 1250);
    final apiClient = ListingApiClient(baseUrl: 'http://localhost', client: mockHttp);
    apiClient.setToken('test_token');
    final state = AppState(apiClient: apiClient);
    state.isInitializing = false;
    state.walletBalance = 1250;

    await tester.pumpWidget(_wrap(const Scaffold(body: ProfileBalanceSection()), state));
    await tester.pumpAndSettle();

    expect(find.text('1 250 кирпичей'), findsOneWidget);

    // Change balance
    state.walletBalance = 1250000;
    state.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.text('1 250 000 кирпичей'), findsOneWidget);
  });

  testWidgets('Tapping "Пополнить" navigates to existing Routes.topup', (tester) async {
    var topupOpened = false;
    final mockHttp = _MockHttpServer(balance: 16700);
    final apiClient = ListingApiClient(baseUrl: 'http://localhost', client: mockHttp);
    apiClient.setToken('test_token');
    final state = AppState(apiClient: apiClient);
    state.isInitializing = false;
    state.walletBalance = 16700;

    await tester.pumpWidget(_wrap(
      const Scaffold(body: ProfileBalanceSection()),
      state,
      onTopupTap: () => topupOpened = true,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(kProfileBalanceTopupButtonKey));
    await tester.pumpAndSettle();

    expect(topupOpened, isTrue);
    expect(find.text('Topup Screen'), findsOneWidget);
  });

  testWidgets('ProfileBalanceSection supports Kyrgyz localization (KY)', (tester) async {
    final mockHttp = _MockHttpServer(balance: 16700);
    final apiClient = ListingApiClient(baseUrl: 'http://localhost', client: mockHttp);
    apiClient.setToken('test_token');
    final state = AppState(apiClient: apiClient);
    state.isInitializing = false;
    state.walletBalance = 16700;

    await tester.pumpWidget(_wrap(
      const Scaffold(body: ProfileBalanceSection()),
      state,
      locale: const Locale('ky'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('16 700 кирпич'), findsOneWidget);
    expect(find.text('Баланс'), findsOneWidget);
    expect(find.text('Толуктоо'), findsOneWidget);
  });

  testWidgets('ProfilePage (Client) does NOT contain ProfileBalanceSection', (tester) async {
    final mockHttp = _MockHttpServer(balance: 16700);
    final apiClient = ListingApiClient(baseUrl: 'http://localhost', client: mockHttp);
    apiClient.setToken('test_token');
    final state = AppState(apiClient: apiClient);
    state.isInitializing = false;
    state.isPro = false;
    state.pro = false;
    state.userName = 'Тест Клиент';
    state.userPhone = '+996555123456';
    state.walletBalance = 16700;

    await tester.pumpWidget(_wrap(const ProfilePage(), state));
    await tester.pumpAndSettle();

    expect(find.byKey(kProfileBalanceSectionKey), findsNothing);
  });

  testWidgets('ProProfilePage (Seller) contains ProfileBalanceSection between listings and notifications', (tester) async {
    final mockHttp = _MockHttpServer(balance: 16700);
    final apiClient = ListingApiClient(baseUrl: 'http://localhost', client: mockHttp);
    apiClient.setToken('test_token');
    final state = AppState(apiClient: apiClient);
    state.isInitializing = false;
    state.isPro = true;
    state.pro = true;
    state.sellerKind = 'realtor';
    state.userName = 'Тест Риелтор';
    state.userPhone = '+996700100022';
    state.walletBalance = 16700;

    await tester.pumpWidget(_wrap(const ProProfilePage(), state));
    await tester.pumpAndSettle();

    expect(find.byKey(kProfileBalanceSectionKey), findsOneWidget);
    expect(find.text('16 700 кирпичей'), findsOneWidget);
    expect(find.text('Пополнить'), findsOneWidget);
  });

  testWidgets('No RenderFlex overflow on small screens with very large balance', (tester) async {
    final mockHttp = _MockHttpServer(balance: 999999999);
    final apiClient = ListingApiClient(baseUrl: 'http://localhost', client: mockHttp);
    apiClient.setToken('test_token');
    final state = AppState(apiClient: apiClient);
    state.isInitializing = false;
    state.walletBalance = 999999999;

    // Test 320x480
    tester.view.physicalSize = const Size(320 * 2, 480 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_wrap(const Scaffold(body: ProfileBalanceSection()), state));
    await tester.pumpAndSettle();

    expect(find.byKey(kProfileBalanceSectionKey), findsOneWidget);
    expect(find.text('999 999 999 кирпичей'), findsOneWidget);
    expect(find.text('Пополнить'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
