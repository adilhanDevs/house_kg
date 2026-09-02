// Официальный экран оплаты Finik поверх счёта, который создал наш бэкенд.
//
// Банковские приложения открывает сам SDK. Собственных ссылок вида
// `mbank://pay?url=…` здесь нет и быть не должно: такого контракта банки не
// публикуют, и именно поэтому прежний способ уводил пользователя в браузер.
//
// Счёт уже существует — открываем его через GetItemHandlerWidget. Создавать
// счёт из приложения нельзя: тогда на один платёж House пришлось бы два счёта
// Finik, и сверка на бэкенде перестала бы сходиться.
import 'dart:async';

import 'package:finik_sdk/finik_sdk.dart';
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../data/finik_config.dart';
import '../../data/topup.dart';
import '../../l10n/l10n.dart';

/// Чем закончился экран оплаты.
enum FinikSdkOutcome { paid, pending, cancelled }

class FinikSdkPaymentPage extends StatefulWidget {
  const FinikSdkPaymentPage({
    super.key,
    required this.housePaymentId,
    required this.providerItemId,
  });

  /// Наш платёж — по нему и только по нему сверяется результат.
  final String housePaymentId;

  /// Счёт у провайдера, созданный бэкендом.
  final String providerItemId;

  @override
  State<FinikSdkPaymentPage> createState() => _FinikSdkPaymentPageState();
}

class _FinikSdkPaymentPageState extends State<FinikSdkPaymentPage>
    with WidgetsBindingObserver {
  Timer? _resumeDebounce;
  bool _checking = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _resumeDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Вернулись из банковского приложения — спрашиваем бэкенд, что там с
  /// платежом. Пауза нужна, чтобы не дёргать сервер на каждое мигание окна.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _finished) return;
    _resumeDebounce?.cancel();
    _resumeDebounce = Timer(const Duration(milliseconds: 600), _refreshStatus);
  }

  /// SDK сообщил об оплате.
  ///
  /// Балансом это не считается: начисляет бэкенд после собственной проверки
  /// суммы, аккуратно и ровно один раз. Здесь только повод переспросить.
  void _onPayment(Map<String, dynamic>? data) {
    if (data == null || _finished) return;
    final status = (data['status'] ?? '').toString().toUpperCase();
    if (status == 'SUCCEEDED') {
      _refreshStatus();
    } else if (status == 'FAILED') {
      _finish(FinikSdkOutcome.pending);
    }
  }

  Future<void> _refreshStatus() async {
    if (_checking || _finished || !mounted) return;
    _checking = true;
    try {
      final result = await AppScope.read(context).fetchTopupStatus(
        widget.housePaymentId,
      );
      if (!mounted) return;
      if (result.status == TopupStatus.succeeded) {
        _finish(FinikSdkOutcome.paid);
      }
    } catch (_) {
      // Молча: не дозвонились до бэкенда — пользователь остаётся на экране
      // оплаты, а не получает ложный отказ.
    } finally {
      _checking = false;
    }
  }

  void _finish(FinikSdkOutcome outcome) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(outcome);
  }

  /// Назад — это не отказ от платежа: счёт остаётся, статус переспросим.
  void _onBackPressed() {
    if (_finished) return;
    unawaited(_refreshStatus());
    _finish(FinikSdkOutcome.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (!FinikConfig.isConfigured) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Оплата не настроена в этой сборке: не передан FINIK_SDK_API_KEY.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xff7d7d7d)),
            ),
          ),
        ),
      );
    }

    if (widget.providerItemId.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xff7d7d7d)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: FinikProvider(
        apiKey: FinikConfig.apiKey,
        isBeta: FinikConfig.isBeta,
        locale: _locale(context),
        // Пополнение кошелька, а не оплата заказа — от этого зависят подписи
        // внутри официального экрана.
        textScenario: TextScenario.REPLENISHMENT,
        paymentMethods: const [PaymentMethod.APP, PaymentMethod.QR],
        enableShimmer: true,
        enableShare: true,
        enableSupportButtons: true,
        tapableSupportButtons: true,
        onBackPressed: _onBackPressed,
        onPayment: _onPayment,
        widget: GetItemHandlerWidget(
          parameter: ItemId(widget.providerItemId),
        ),
      ),
    );
  }

  FinikSdkLocale _locale(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    // Незнакомый язык показываем по-русски — так же, как остальное приложение.
    return code == 'ky' ? FinikSdkLocale.KY : FinikSdkLocale.RU;
  }
}
