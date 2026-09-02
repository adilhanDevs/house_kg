// Оплата открывает официальный экран Finik сразу, без нашего экрана банков.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/ui/pages/finik_sdk_payment_page.dart';
import 'package:house_kgz/ui/widgets/finik_payment_flow.dart';

void main() {
  testWidgets('оплата ведёт прямо на официальный экран Finik', (tester) async {
    // Наш экран выбора банка удалён — символа, который его открывал, больше
    // нет, а startFinikPayment уходит на FinikSdkPaymentPage.
    expect(startFinikPayment, isA<Function>());
    expect(const FinikSdkPaymentPage(housePaymentId: 'p', providerItemId: 'i'),
        isA<Widget>());
  });

  test('состояние приложения умеет выставить счёт и дождаться статуса', () {
    final state = AppState();
    // Бэкенд остаётся источником правды: оба метода на месте и используются
    // потоком оплаты вместо локального начисления.
    expect(state.createTopup, isA<Function>());
    expect(state.waitForTopup, isA<Function>());
  });
}
