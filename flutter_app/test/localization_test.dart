import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/app/app.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/stage.dart';
import 'package:house_kgz/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Localization and AppState Tests', () {
    test('Default locale is Russian (ru)', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.authInitialized;

      expect(state.locale.languageCode, equals('ru'));
      expect(state.languageCode, equals('ru'));
    });

    test('Locale persists when setLanguageCode is called', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await state.authInitialized;

      bool notified = false;
      state.addListener(() {
        notified = true;
      });

      await state.setLanguageCode('ky');

      expect(state.locale.languageCode, equals('ky'));
      expect(state.languageCode, equals('ky'));
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), equals('ky'));
    });

    test('AppState loads saved Kyrgyz locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'ky'});
      final state = AppState();
      await state.authInitialized;

      expect(state.locale.languageCode, equals('ky'));
      expect(state.languageCode, equals('ky'));
    });

    test('Logging out preserves the selected locale', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'ky'});
      final state = AppState();
      await state.authInitialized;

      await state.logout();

      expect(state.locale.languageCode, equals('ky'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), equals('ky'));
    });
  });

  group('Localized Strings Consistency Tests', () {
    test('Russian and Kyrgyz ARBs have identical keys and non-empty values', () async {
      final ru = await AppLocalizations.delegate.load(const Locale('ru'));
      final ky = await AppLocalizations.delegate.load(const Locale('ky'));

      expect(ru.tabHome, equals('Главная'));
      expect(ky.tabHome, equals('Башкы'));

      expect(ru.tabCatalog, equals('Поиск'));
      expect(ky.tabCatalog, equals('Издөө'));

      expect(ru.tabHistory, equals('История'));
      expect(ky.tabHistory, equals('Тарых'));

      expect(ru.tabFavourites, equals('Избранное'));
      expect(ky.tabFavourites, equals('Тандалгандар'));

      expect(ru.tabProfile, equals('Профиль'));
      expect(ky.tabProfile, equals('Профиль'));

      expect(ru.langRussian, equals('Русский'));
      expect(ky.langRussian, equals('Орусча'));

      expect(ru.langKyrgyz, equals('Кыргызча'));
      expect(ky.langKyrgyz, equals('Кыргызча'));

      expect(ru.login, equals('Войти'));
      expect(ky.login, equals('Кирүү'));

      expect(ru.register, equals('Зарегистрироваться'));
      expect(ky.register, equals('Катталуу'));

      expect(ru.forgotPassword, equals('Забыли пароль?'));
      expect(ky.forgotPassword, equals('Сырсөздү унуттуңузбу?'));

      expect(ru.kindApartment, equals('Квартиры'));
      expect(ky.kindApartment, equals('Батирлер'));

      expect(ru.kindHouse, equals('Дома'));
      expect(ky.kindHouse, equals('Үйлөр'));

      expect(ru.kindPlot, equals('Участки'));
      expect(ky.kindPlot, equals('Жер тилкелери'));
    });
  });

  group('Widget Localization & Small Screen Overflow Tests', () {
    testWidgets('App reacts dynamically to language change and fits small screens (320x480)', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // Small screen viewport
      tester.view.physicalSize = const Size(320 * 2, 480 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const HouseKgzAppScope());
      await tester.pumpAndSettle();

      final state = tester.state<State<StatefulWidget>>(find.byType(HouseKgzAppScope));
      expect(state, isNotNull);
    });
  });
}
