// Оплата: счёт создаёт бэкенд, показывает его официальный экран Finik.
//
// Своего экрана выбора банка больше нет. Он показывал наш список — MBank,
// Bakai, Optima — и кнопку «Оплатить», после которой всё равно открывался
// официальный интерфейс Finik. Лишний шаг: список приложений и передачу в
// банк делает сам SDK, и делает это правильно.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../data/api_exceptions.dart';
import '../../data/tariff.dart';
import '../../data/topup.dart';
import '../pages/finik_sdk_payment_page.dart';

/// Выставляет счёт и открывает официальный экран оплаты Finik.
///
/// Возвращает `true`, только когда зачисление подтвердил бэкенд: он остаётся
/// единственным, кто решает, оплачено ли. `tariff` — если после пополнения
/// нужно подключить тариф.
Future<bool?> startFinikPayment({
  required BuildContext context,
  required int amountSom,
  required String purposeTitle,
  TariffPlan? tariff,
  AppState? state,
  VoidCallback? onSuccess,
}) async {
  final appState = state ?? AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  final intent = await _createIntent(appState, amountSom, messenger);
  if (intent == null) return false;

  await navigator.push<FinikSdkOutcome>(
    MaterialPageRoute(
      builder: (_) => FinikSdkPaymentPage(
        housePaymentId: intent.paymentId,
        providerItemId: intent.providerItemId,
      ),
    ),
  );

  // Экран Finik закрылся — дальше спрашиваем свой бэкенд. Закрыть окно и
  // отменить платёж не одно и то же: деньги могли уже уйти.
  final result = await appState.waitForTopup(intent.paymentId);
  if (!result.status.isSuccess) return false;

  if (tariff != null) {
    try {
      await appState.buySubscription(tariff, withBricks: true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Оплата прошла и кирпичи зачислены, но тариф подключить не '
            'удалось: ${e is ApiException ? e.message : e}. '
            'Попробуйте подключить его на экране тарифов.',
          ),
        ),
      );
      return false;
    }
  }

  onSuccess?.call();
  return true;
}

Future<TopupIntent?> _createIntent(
  AppState state,
  int amountSom,
  ScaffoldMessengerState messenger,
) async {
  try {
    final intent = await state.createTopup(amountSom);
    if (intent.providerItemId.isEmpty) {
      // Без счёта у провайдера открывать нечего. Прежний экран со списком
      // банков здесь не показываем: он и был причиной, по которой оплата
      // уходила мимо приложения банка.
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось выставить счёт. Попробуйте ещё раз.')),
      );
      return null;
    }
    return intent;
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(state.topupError ?? 'Не удалось выставить счёт')),
    );
    return null;
  }
}
