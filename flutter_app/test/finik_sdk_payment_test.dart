// Оплата идёт через официальный экран Finik по счёту, созданному бэкендом.
//
// Часть проверок требует ключа сборки, поэтому набор запускается так:
//   flutter test test/finik_sdk_payment_test.dart \
//     --dart-define=FINIK_SDK_API_KEY=test-key
import 'package:finik_sdk/finik_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/finik_config.dart';
import 'package:house_kgz/data/topup.dart';
import 'package:house_kgz/l10n/app_localizations.dart';
import 'package:house_kgz/ui/pages/finik_sdk_payment_page.dart';

const String _itemId = '863186263_c74b72ba-6996-479c-b32e-82aa6115b799';

Widget _host(Widget child, {Locale locale = const Locale('ru')}) {
  return AppScope(
    state: AppState(),
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  group('счёт от бэкенда', () {
    test('provider_item_id разбирается из ответа', () {
      final intent = TopupIntent.fromJson({
        'payment_id': 'c74b72ba',
        'amount_kgs': '500.00',
        'bricks': 500,
        'bonus_bricks': 50,
        'total_bricks': 550,
        'payment_url': 'https://pay.finik.kg/checkout/$_itemId',
        'provider_item_id': _itemId,
      });

      expect(intent.providerItemId, _itemId);
    });

    test('без поля остаётся пустым, а не гадаем по ссылке', () {
      // Разбирать checkout-URL нельзя: формат ссылки не является контрактом.
      final intent = TopupIntent.fromJson({
        'payment_id': 'c74b72ba',
        'amount_kgs': '500.00',
        'bricks': 500,
        'bonus_bricks': 0,
        'total_bricks': 500,
        'payment_url': 'https://pay.finik.kg/checkout/$_itemId',
      });

      expect(intent.providerItemId, isEmpty);
    });
  });

  group('экран оплаты', () {
    testWidgets('без ключа сборки честно сообщает, а не падает', (tester) async {
      await tester.pumpWidget(
        _host(const FinikSdkPaymentPage(
          housePaymentId: 'c74b72ba',
          providerItemId: _itemId,
        )),
      );
      await tester.pump();

      if (FinikConfig.isConfigured) {
        // Набор запущен с ключом — эту проверку делает соседний тест.
        return;
      }
      expect(find.textContaining('FINIK_SDK_API_KEY'), findsOneWidget);
      expect(find.byType(FinikProvider), findsNothing);
    });

    testWidgets('без идентификатора счёта SDK не открывается', (tester) async {
      await tester.pumpWidget(
        _host(const FinikSdkPaymentPage(
          housePaymentId: 'c74b72ba',
          providerItemId: '',
        )),
      );
      await tester.pump();

      expect(find.byType(FinikProvider), findsNothing);
    });

    testWidgets('открывает существующий счёт, а не создаёт новый', (tester) async {
      if (!FinikConfig.isConfigured) return;

      await tester.pumpWidget(
        _host(const FinikSdkPaymentPage(
          housePaymentId: 'c74b72ba',
          providerItemId: _itemId,
        )),
      );
      await tester.pump();

      final provider = tester.widget<FinikProvider>(find.byType(FinikProvider));

      // Создание счёта в приложении сломало бы сверку: один платёж House
      // должен соответствовать ровно одному счёту Finik.
      expect(provider.widget, isA<GetItemHandlerWidget>());
      expect(find.byType(CreateItemHandlerWidget), findsNothing);

      final handler = provider.widget as GetItemHandlerWidget;
      expect(handler.parameter, isA<ItemId>());
      expect((handler.parameter as ItemId).value, _itemId);
    });

    testWidgets('включены оплата приложением и QR', (tester) async {
      if (!FinikConfig.isConfigured) return;

      await tester.pumpWidget(
        _host(const FinikSdkPaymentPage(
          housePaymentId: 'c74b72ba',
          providerItemId: _itemId,
        )),
      );
      await tester.pump();

      final provider = tester.widget<FinikProvider>(find.byType(FinikProvider));
      expect(provider.paymentMethods, contains(PaymentMethod.APP));
      expect(provider.paymentMethods, contains(PaymentMethod.QR));
      expect(provider.textScenario, TextScenario.REPLENISHMENT);
      // Контур должен совпадать с тем, где бэкенд создал счёт.
      expect(provider.isBeta, FinikConfig.isBeta);
    });

    testWidgets('язык экрана следует за языком приложения', (tester) async {
      if (!FinikConfig.isConfigured) return;

      for (final entry in {'ru': FinikSdkLocale.RU, 'ky': FinikSdkLocale.KY}.entries) {
        await tester.pumpWidget(
          _host(
            const FinikSdkPaymentPage(
              housePaymentId: 'c74b72ba',
              providerItemId: _itemId,
            ),
            locale: Locale(entry.key),
          ),
        );
        await tester.pump();

        final provider = tester.widget<FinikProvider>(find.byType(FinikProvider));
        expect(provider.locale, entry.value, reason: entry.key);
      }
    });
  });
}
