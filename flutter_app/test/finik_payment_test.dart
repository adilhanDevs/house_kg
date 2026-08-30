import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/stage.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/finik_payment_service.dart';
import 'package:house_kgz/data/tariff.dart';
import 'package:house_kgz/ui/pages/topup_page.dart';
import 'package:house_kgz/ui/widgets/finik_payment_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPaymentHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/tariffs/') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode([
          {'code': 'owner', 'name': 'Собственник', 'price_som': 0, 'listings_limit': 5},
          {'code': 'top', 'name': 'TOP', 'price_som': 1, 'listings_limit': 15},
          {'code': 'vip', 'name': 'VIP', 'price_som': 1, 'price_bricks': 1, 'listings_limit': 20},
          {'code': 'premium', 'name': 'Premium', 'price_som': 1, 'price_bricks': 1, 'listings_limit': 20},
        ]))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/api/v1/subscriptions/') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'status': 'active', 'tariff_code': 'top'}))),
        201,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/api/v1/wallet/') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'balance': 1000, 'tariff': 'top'}))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode({}))), 200, headers: {'content-type': 'application/json'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FinikPaymentService', () {
    test('FinikPaymentStatus enum parsing and helpers', () {
      expect(FinikPaymentStatus.fromString('paid').isSuccess, isTrue);
      expect(FinikPaymentStatus.fromString('SUCCESS').isSuccess, isTrue);
      expect(FinikPaymentStatus.fromString('completed').isSuccess, isTrue);
      expect(FinikPaymentStatus.fromString('pending').isPending, isTrue);
      expect(FinikPaymentStatus.fromString('failed').isFailed, isTrue);
      expect(FinikPaymentStatus.fromString('expired').isFailed, isTrue);
      expect(FinikPaymentStatus.fromString('cancelled').isFailed, isTrue);
    });

    test('createInvoice in mock mode generates valid dynamic payment invoice', () async {
      final service = FinikPaymentService();
      final response = await service.createInvoice(
        amount: 15000,
        orderId: 'test_order_123',
        description: 'Пополнение 15 000 сом',
      );

      expect(response.paymentId, isNotEmpty);
      expect(response.orderId, equals('test_order_123'));
      expect(response.amount, equals(15000));
      expect(response.status, equals(FinikPaymentStatus.pending));
      expect(response.currency, equals('KGS'));
      expect(response.qrData, contains('finik://pay'));
      expect(response.qrData, contains('amount=15000'));
    });

    test('mockConfirmPayment marks invoice as paid', () async {
      final service = FinikPaymentService();
      final invoice = await service.createInvoice(amount: 5000);
      expect(invoice.status, equals(FinikPaymentStatus.pending));

      final confirmed = service.mockConfirmPayment(invoice);
      expect(confirmed.status, equals(FinikPaymentStatus.paid));
      expect(confirmed.status.isSuccess, isTrue);
    });

    test('checkStatus returns updated status', () async {
      final service = FinikPaymentService();
      final statusResp = await service.checkStatus('mock_12345');
      expect(statusResp.status.isSuccess, isTrue);
    });
  });

  group('AppState Finik Topup Integration', () {
    test('createFinikTopup and confirmFinikTopup credits wallet and adds bonus', () async {
      final state = AppState();
      final initialBricks = state.walletBalance;

      final payment = await state.createFinikTopup(10000);
      expect(state.topupAmount, equals(10000));
      expect(state.topupBonus, equals(1000));
      expect(state.currentFinikPayment, isNotNull);

      await state.confirmFinikTopup(payment);

      // 10000 + 10% bonus (1000) = 11000 bricks added
      expect(state.walletBalance, equals(initialBricks + 11000));
      expect(state.wallet.first.kind, equals(WalletEntryKind.topup));
      expect(state.wallet.first.bricks, equals(10000));
      expect(state.wallet[1].kind, equals(WalletEntryKind.bonus));
      expect(state.wallet[1].bricks, equals(1000));
    });
  });

  group('TopUpPage Widget Flow with Finik Pay', () {
    testWidgets('completes full 5-step flow with Finik payment', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final state = AppState();

      await tester.pumpWidget(
        MaterialApp(
          home: AppScope(
            state: state,
            child: const Scaffold(
              body: TopUpPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Click Далее (Y=711)
      final nextButtonFinder = find.byWidgetPredicate(
        (w) => w is Positioned && w.top == 711.0 && w.height == 54.0,
      );
      expect(nextButtonFinder, findsOneWidget);
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      // Step 2: Click Далее
      await tester.tap(nextButtonFinder);
      await tester.pumpAndSettle();

      // Step 3: Enter amount and click Далее to create Finik payment
      final amountFieldFinder = find.byType(TextField);
      expect(amountFieldFinder, findsOneWidget);
      await tester.enterText(amountFieldFinder, '20000');

      await tester.tap(nextButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Step 4: Bank selection & pay
      expect(state.topupAmount, equals(20000));
      expect(state.currentFinikPayment, isNotNull);

      // Tap on bank selection area to confirm payment
      final bankItemFinder = find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.top == 480.0,
      );
      expect(bankItemFinder, findsOneWidget);
      await tester.tap(bankItemFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Step 5: Finished and bricks credited
      expect(state.walletBalance, greaterThanOrEqualTo(22000)); // 20000 + 2000 bonus
    });

    testWidgets('showFinikPaymentSheet renders interactive Finik Pay sheet and completes payment', (tester) async {
      final mockClient = _MockPaymentHttpClient();
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: mockClient);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;
      state.walletBalance = 1000;

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
                    purposeTitle: 'Подписка на тариф «TOP» (1 месяц)',
                    tariff: kDefaultTariffPlans[1],
                    state: state,
                  ),
                  child: const Text('Открыть Finik'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Открыть Finik'));
      await tester.pumpAndSettle();

      // Verify Finik Pay Header and details
      expect(find.text('Finik Pay'), findsOneWidget);
      expect(find.text('1 сом'), findsOneWidget);
      expect(find.text('Подписка на тариф «TOP» (1 месяц)'), findsOneWidget);
      expect(find.text('MBank'), findsOneWidget);
      expect(find.text('Optima24'), findsOneWidget);

      // Switch to QR tab
      await tester.tap(find.text('QR-код для оплаты'));
      await tester.pumpAndSettle();
      expect(find.text('Национальный стандарт QR (ELQR / Finik)'), findsOneWidget);

      // Switch back to banks
      await tester.tap(find.text('Банки Кыргызстана'));
      await tester.pumpAndSettle();

      // Pay button
      expect(find.text('Оплатить 1 сом'), findsOneWidget);
      await tester.tap(find.text('Оплатить 1 сом'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      // Verify subscription activated
      expect(state.currentTariffCode, 'top');
    });
  });
}

