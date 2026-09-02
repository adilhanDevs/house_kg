// Оплата через Finik: счёт выставляет бэкенд, зачисление подтверждает вебхук
// Finik. Приложение только показывает счёт и опрашивает статус — «подтвердить»
// оплату из клиента нельзя, и тесты проверяют именно это.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/tariff.dart';
import 'package:house_kgz/data/topup.dart';
import 'package:house_kgz/ui/widgets/finik_bank_launcher.dart';
import 'package:house_kgz/ui/widgets/finik_payment_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Бэкенд-заглушка: выставляет счёт и отдаёт статусы по очереди.
class _MockBillingClient extends http.BaseClient {
  _MockBillingClient({
    this.providers = const [],
    this.statuses = const ['succeeded'],
    this.expiresInSeconds = 1800,
  });

  /// Способы оплаты в ответе на счёт (`providers`).
  final List<Map<String, dynamic>> providers;

  /// Статусы счёта в порядке опроса.
  final List<String> statuses;
  final int expiresInSeconds;

  String? lastIdempotencyKey;
  String? lastSubscribedCode;
  String? lastSubscriptionPaymentMethod;
  int topupRequests = 0;
  int statusRequests = 0;
  int subscriptionRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (path == '/api/v1/wallet/topup/' && request.method == 'POST') {
      topupRequests += 1;
      lastIdempotencyKey = request.headers['Idempotency-Key'];
      return _json({
        'payment_id': 'pay-1',
        'amount_kgs': '12000.00',
        'bricks': 12000,
        'bonus_bricks': 1200,
        'total_bricks': 13200,
        'payment_url': 'https://pay.finik.kg/checkout/item-1',
        'qr_code_url': '',
        'qr_data': '',
        'expires_at': DateTime.now()
            .toUtc()
            .add(Duration(seconds: expiresInSeconds))
            .toIso8601String(),
        'providers': providers,
      }, 201);
    }

    if (path.startsWith('/api/v1/wallet/topup/') && request.method == 'GET') {
      final index = statusRequests < statuses.length
          ? statusRequests
          : statuses.length - 1;
      statusRequests += 1;
      final status = statuses[index];
      return _json({
        'status': status,
        'balance': status == 'succeeded' ? 13200 : 0,
        'credited_bricks': status == 'succeeded' ? 13200 : 0,
      }, 200);
    }

    if (path == '/api/v1/wallet/') {
      return _json({'balance': 13200}, 200);
    }

    if (path == '/api/v1/subscriptions/' && request.method == 'POST') {
      subscriptionRequests += 1;
      if (request is http.Request) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        lastSubscribedCode = body['tariff_code']?.toString();
        lastSubscriptionPaymentMethod = body['payment_method']?.toString();
      }
      return _json({
        'id': 1,
        'tariff': {'code': lastSubscribedCode, 'name': lastSubscribedCode},
        'status': 'active',
      }, 201);
    }

    return _json(const <String, dynamic>{}, 200);
  }

  http.StreamedResponse _json(Object body, int code) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    code,
    headers: {'content-type': 'application/json'},
  );
}

AppState _stateWith(_MockBillingClient client) => AppState(
  apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
);

Future<void> _openSheet(WidgetTester tester, AppState state) async {
  // Лист высокий: на дефолтных 800x600 кнопки уезжают за пределы экрана и
  // тесты «не попадают» по ним.
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFinikPaymentSheet(
                context: context,
                amountSom: 12000,
                purposeTitle: 'Пополнение кошелька House KG',
                state: state,
              ),
              child: const Text('Открыть Finik'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Открыть Finik'));
  await tester.pump();
  // Лист выезжает анимацией: без неё кнопки остаются ниже экрана и тапы
  // не доходят. pumpAndSettle тут нельзя — счёт тикает таймером.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

/// Закрывает лист, чтобы не оставлять после теста тикающий таймер счёта.
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FinikBankLauncher URI Construction', () {
    const paymentUrl = 'https://pay.finik.kg/checkout/863186263_item-123';
    const qrPayload = 'https://pay.finik.kg/checkout/863186263_item-123';

    test('MBank constructs valid candidate schemes and pay URIs', () {
      final uris = FinikBankLauncher.buildCandidateUris(
        bankId: 'mbank',
        paymentUrl: paymentUrl,
        qrPayload: qrPayload,
      );

      expect(uris.length, 4);
      expect(uris[0].toString(), startsWith('mbank://pay?url='));
      expect(uris[0].queryParameters['url'], paymentUrl);
      expect(uris[1].toString(), startsWith('mbank://qr?data='));
      expect(uris[2].toString(), 'mbank://pay');
      expect(uris[3].toString(), 'mbank://');
    });

    test('Bakai Bank constructs valid candidate schemes and pay URIs', () {
      final uris = FinikBankLauncher.buildCandidateUris(
        bankId: 'bakai',
        paymentUrl: paymentUrl,
        qrPayload: qrPayload,
      );

      expect(uris.length, 5);
      expect(uris[0].toString(), startsWith('bakai://pay?url='));
      expect(uris[0].queryParameters['url'], paymentUrl);
      expect(uris[1].toString(), startsWith('bakai://qr?data='));
      expect(uris[2].toString(), startsWith('bakaimobile://pay?url='));
      expect(uris[3].toString(), startsWith('bakai24://pay?url='));
      expect(uris[4].toString(), 'bakai://');
    });

    test('Optima24, O!Money and MegaPay construct valid candidate schemes', () {
      final optima = FinikBankLauncher.buildCandidateUris(
        bankId: 'optima',
        paymentUrl: paymentUrl,
      );
      expect(optima[0].toString(), startsWith('optima24://pay?url='));

      final odengi = FinikBankLauncher.buildCandidateUris(
        bankId: 'odengi',
        paymentUrl: paymentUrl,
      );
      expect(odengi[0].toString(), startsWith('omoney://pay?url='));

      final megapay = FinikBankLauncher.buildCandidateUris(
        bankId: 'megapay',
        paymentUrl: paymentUrl,
      );
      expect(megapay[0].toString(), startsWith('megapay://pay?url='));
    });

    test('Card / fallback returns generic payment URL', () {
      final card = FinikBankLauncher.buildCandidateUris(
        bankId: 'card',
        paymentUrl: paymentUrl,
      );
      expect(card.single.toString(), paymentUrl);
    });
  });

  group('Счёт Finik', () {
    test(
      'TopupIntent: QR кодирует ссылку оплаты, если провайдер не дал payload',
      () {
        final intent = TopupIntent.fromJson({
          'payment_id': 'pay-1',
          'amount_kgs': '12000.00',
          'bricks': 12000,
          'bonus_bricks': 1200,
          'total_bricks': 13200,
          'payment_url': 'https://pay.finik.kg/checkout/item-1',
          'qr_data': '',
          'providers': [
            {
              'code': 'mbank',
              'name': 'MBank',
              'deeplink': 'mbank://pay?target=item-1',
            },
          ],
        });

        expect(intent.qrPayload, 'https://pay.finik.kg/checkout/item-1');
        expect(intent.providers.single.deeplink, 'mbank://pay?target=item-1');
      },
    );

    test('createTopup передаёт Idempotency-Key', () async {
      final client = _MockBillingClient();
      final state = _stateWith(client);

      final intent = await state.createTopup(12000);

      expect(intent.paymentId, 'pay-1');
      expect(intent.totalBricks, 13200);
      expect(client.lastIdempotencyKey, isNotNull);
      expect(client.lastIdempotencyKey, isNotEmpty);
    });
  });

  group('Платёжный лист', () {
    testWidgets(
      'по умолчанию открывает вкладку «Банки Кыргызстана» со списком банков',
      (tester) async {
        final state = _stateWith(_MockBillingClient());
        await _openSheet(tester, state);

        expect(find.text('Finik Pay'), findsOneWidget);
        expect(find.text('Банки Кыргызстана'), findsOneWidget);
        expect(find.text('MBank'), findsOneWidget);
        expect(find.text('Bakai Bank'), findsOneWidget);
        expect(find.text('Optima24'), findsOneWidget);
        expect(find.text('О!Деньги'), findsOneWidget);
        expect(find.text('MegaPay'), findsOneWidget);
        expect(find.text('Оплатить 12000 сом'), findsOneWidget);

        await _closeSheet(tester);
      },
    );

    testWidgets('выбор другого банка (Bakai) и переключение на QR вкладку', (
      tester,
    ) async {
      final state = _stateWith(_MockBillingClient());
      await _openSheet(tester, state);

      expect(find.text('MBank'), findsOneWidget);
      expect(find.text('Bakai Bank'), findsOneWidget);

      // Тап по Bakai Bank
      await tester.tap(find.text('Bakai Bank'));
      await tester.pump();

      // Переключение на QR вкладку
      await tester.tap(find.text('QR-код для оплаты'));
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);

      await _closeSheet(tester);
    });

    testWidgets('успех показывается только после статуса succeeded', (
      tester,
    ) async {
      final client = _MockBillingClient(
        statuses: const ['pending', 'succeeded'],
      );
      final state = _stateWith(client);
      await _openSheet(tester, state);

      await tester.tap(find.text('Я уже оплатил — проверить статус'));
      await tester.pump();

      // Первый ответ — pending: успеха ещё нет.
      expect(find.text('Оплата прошла успешно!'), findsNothing);
      expect(find.text('Ждём подтверждения оплаты…'), findsOneWidget);

      // Второй опрос через 3 секунды приносит succeeded.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Оплата прошла успешно!'), findsOneWidget);
      expect(find.text('Начислено 13200 кирпичей'), findsOneWidget);
      expect(state.walletBalance, 13200);

      // После успеха лист сам закрывается через 600 мс.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Finik Pay'), findsNothing);
    });

    testWidgets('после успешной оплаты тарифа подключает подписку за кирпичи', (
      tester,
    ) async {
      final client = _MockBillingClient(statuses: const ['succeeded']);
      final state = _stateWith(client);

      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showFinikPaymentSheet(
                    context: context,
                    amountSom: 1,
                    purposeTitle: 'Подписка на тариф «VIP» (1 месяц)',
                    state: state,
                    tariff: kDefaultTariffPlans[2],
                  ),
                  child: const Text('Открыть тариф'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Открыть тариф'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Я уже оплатил — проверить статус'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Оплата прошла успешно!'), findsOneWidget);
      expect(client.subscriptionRequests, 1);
      expect(client.lastSubscribedCode, 'vip');
      expect(client.lastSubscriptionPaymentMethod, 'bricks');
      expect(state.currentTariffCode, 'vip');

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('Finik Pay'), findsNothing);
    });

    testWidgets('отказ провайдера не выдаётся за оплату', (tester) async {
      final client = _MockBillingClient(statuses: const ['failed']);
      final state = _stateWith(client);
      await _openSheet(tester, state);

      await tester.tap(find.text('Я уже оплатил — проверить статус'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Оплата прошла успешно!'), findsNothing);
      expect(
        find.text('Оплата не прошла. Попробуйте ещё раз.'),
        findsOneWidget,
      );

      await _closeSheet(tester);
    });

    testWidgets('истёкший счёт предлагает выставить новый', (tester) async {
      final client = _MockBillingClient(expiresInSeconds: -10);
      final state = _stateWith(client);
      await _openSheet(tester, state);

      expect(find.text('счёт истёк'), findsOneWidget);
      expect(find.text('Выставить новый счёт'), findsOneWidget);
      expect(find.text('Я уже оплатил — проверить статус'), findsNothing);

      // Кнопка выставляет именно новый счёт, а не переиспользует истёкший.
      await tester.tap(find.text('Выставить новый счёт'));
      await tester.pump();
      await tester.pump();
      expect(client.topupRequests, 2);

      await _closeSheet(tester);
    });
  });
}
