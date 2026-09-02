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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

}
