import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/tariff.dart';
import 'package:house_kgz/ui/pages/tariffs_page.dart';

class _MockTariffClient extends http.BaseClient {
  _MockTariffClient({this.walletBalance = 0});

  /// Баланс, который «сервер» отдаёт после списания за подписку.
  final int walletBalance;

  String? lastSubscribedCode;
  String? lastPaymentMethod;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/tariffs/') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode([
          {'code': 'owner', 'name': 'Собственник', 'price_som': 0, 'listings_limit': 5},
          {'code': 'top', 'name': 'TOP', 'price_som': 1700, 'listings_limit': 15},
          {'code': 'vip', 'name': 'VIP', 'price_som': 3800, 'price_bricks': 3800, 'listings_limit': 20},
          {'code': 'premium', 'name': 'Premium', 'price_som': 9600, 'price_bricks': 9600, 'listings_limit': 20},
        ]))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/api/v1/subscriptions/current/') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'tariff': {'code': 'owner', 'name': 'Собственник'},
          'status': 'active',
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/api/v1/subscriptions/') {
      if (request is http.Request) {
        final body = jsonDecode(request.body);
        lastSubscribedCode = body['tariff_code'];
        lastPaymentMethod = body['payment_method'];
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'status': 'active', 'tariff_code': lastSubscribedCode}))),
        201,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/api/v1/wallet/') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'balance': walletBalance}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value([]), 200);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('TariffPlan default plans contains 4 tiers with exact specifications', () {
    expect(kDefaultTariffPlans.length, 4);
    
    final owner = kDefaultTariffPlans[0];
    expect(owner.code, 'owner');
    expect(owner.name, 'Собственник');
    expect(owner.priceSom, 0);
    expect(owner.maxPosts, 5);

    final top = kDefaultTariffPlans[1];
    expect(top.code, 'top');
    expect(top.name, 'TOP');
    expect(top.priceSom, 1);
    expect(top.maxPosts, 15);
    expect(top.maxReels, 3);

    final vip = kDefaultTariffPlans[2];
    expect(vip.code, 'vip');
    expect(vip.name, 'VIP');
    expect(vip.priceSom, 1);
    expect(vip.priceBricks, 1);
    expect(vip.maxPosts, 20);

    final premium = kDefaultTariffPlans[3];
    expect(premium.code, 'premium');
    expect(premium.name, 'Premium');
    expect(premium.priceSom, 1);
    expect(premium.priceBricks, 1);
    expect(premium.maxReels, 15);
  });

  test('AppState buySubscription with bricks checks and deducts balance', () async {
    final client = _MockTariffClient(walletBalance: 4999);
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);
    // Инициализация состояния асинхронна и сама подтягивает текущий тариф —
    // без ожидания её ответ приходит уже после покупки и затирает её.
    await state.authInitialized;
    state.walletBalance = 5000;

    final vipPlan = kDefaultTariffPlans[2];
    await state.buySubscription(vipPlan, withBricks: true);

    expect(state.currentTariffCode, 'vip');
    expect(state.walletBalance, 4999); // 5000 - 1
    expect(client.lastSubscribedCode, 'vip');
    expect(client.lastPaymentMethod, 'bricks');
  });

  testWidgets('TariffsPage renders all 4 plans and handles brick purchase dialog', (tester) async {
    final client = _MockTariffClient(walletBalance: 9999);
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);
    state.walletBalance = 10000;

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: TariffsPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify all 4 plan names rendered
    expect(find.text('Собственник'), findsOneWidget);
    expect(find.text('TOP'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);

    // Verify current plan button
    expect(find.text('Ваш тариф'), findsOneWidget);

    // Verify brick purchase options
    expect(find.text('1 Кирпичей'), findsNWidgets(3));

    // Tap on VIP brick purchase
    await tester.tap(find.text('1 Кирпичей').at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Dialog appears
    expect(find.text('Подписка «VIP»'), findsOneWidget);
    expect(find.text('Подтвердить'), findsOneWidget);

    // Confirm purchase
    await tester.tap(find.text('Подтвердить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(state.currentTariffCode, 'vip');
    expect(state.walletBalance, 9999);

    // Now tap on 'Собственник' (Выбрать тариф) to switch back
    expect(find.text('Выбрать тариф'), findsOneWidget);
    await tester.tap(find.text('Выбрать тариф'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Смена тарифа'), findsOneWidget);
    expect(find.text('Перейти'), findsOneWidget);

    await tester.tap(find.text('Перейти'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(state.currentTariffCode, 'owner');

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('TariffsPage back button pops to previous route or profile', (tester) async {
    final client = _MockTariffClient();
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          routes: {
            Routes.tariffs: (_) => const TariffsPage(),
            Routes.profile: (_) => const Scaffold(body: Text('Profile Screen')),
          },
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pushNamed(Routes.tariffs),
                child: const Text('Go to Tariffs'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Go to Tariffs'));
    await tester.pumpAndSettle();

    expect(find.text('Тарифы и подписки'), findsOneWidget);

    // Tap back button
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    // Verify we popped back to previous screen
    expect(find.text('Go to Tariffs'), findsOneWidget);
  });
}
