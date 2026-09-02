import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/l10n/app_localizations.dart';
import 'package:house_kgz/ui/pages/welcome_page.dart';
import 'package:house_kgz/ui/widgets/auth_top_illustration.dart';

const _welcomeTitle = 'Добро пожаловать!';
const _welcomeDescription =
    'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам '
    'планета в Солнечной системе после Юпитера.';

Future<void> _loadRoboto() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final font = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  );
  final bytes = Future<ByteData>.value(
    font.readAsBytesSync().buffer.asByteData(),
  );
  await (FontLoader('Roboto')..addFont(bytes)).load();
}

class _FakeAuthClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<Widget> _wrap(Widget child, {Locale locale = const Locale('ru')}) async {
  SharedPreferences.setMockInitialValues({});
  final client = ListingApiClient(
    baseUrl: 'http://localhost:8000',
    client: _FakeAuthClient(),
  );
  final state = AppState(apiClient: client);

  return AppScope(
    state: state,
    child: MaterialApp(
      locale: locale,
      theme: ThemeData(fontFamily: 'Roboto'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void _setViewport(
  WidgetTester tester,
  Size size, {
  double viewInsetBottom = 0,
}) {
  tester.platformDispatcher.textScaleFactorTestValue = 1.0;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.view.viewInsets = FakeViewPadding(bottom: viewInsetBottom);
}

Future<void> _pumpWelcome(
  WidgetTester tester,
  Size size, {
  Locale locale = const Locale('ru'),
  double viewInsetBottom = 0,
}) async {
  _setViewport(tester, size, viewInsetBottom: viewInsetBottom);
  await tester.pumpWidget(await _wrap(const WelcomePage(), locale: locale));
  await tester.pumpAndSettle();
}

Rect _actionRect(WidgetTester tester, String label) {
  return tester.getRect(
    find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first,
  );
}

Rect _fieldRect(WidgetTester tester, int index) {
  return tester.getRect(
    find
        .ancestor(
          of: find.byType(TextField).at(index),
          matching: find.byType(Row),
        )
        .first,
  );
}

void _expectGap(
  String name,
  double actual, {
  required double min,
  required double max,
}) {
  expect(
    actual,
    inInclusiveRange(min, max),
    reason: '$name must stay in the Figma-like $min–$max range; actual=$actual',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRoboto);

  group('Welcome Page Figma geometry and responsiveness', () {
    tearDown(() {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      dispatcher.clearTextScaleFactorTestValue();
      dispatcher.views.first.reset();
    });

    testWidgets('390x844 keeps the complete composition close to Figma', (
      tester,
    ) async {
      await _pumpWelcome(tester, const Size(390, 844));

      expect(tester.takeException(), isNull);

      final progressRect = tester.getRect(
        find.byType(FractionallySizedBox).first,
      );
      final illustrationRect = tester.getRect(find.byType(AuthTopIllustration));
      final titleRect = tester.getRect(find.text(_welcomeTitle));
      final descriptionRect = tester.getRect(find.text(_welcomeDescription));
      final firstInputRect = _fieldRect(tester, 0);
      final secondInputRect = _fieldRect(tester, 1);
      final loginRect = _actionRect(tester, 'Войти');
      final registerRect = _actionRect(tester, 'Зарегистрироваться');
      final forgotRect = _actionRect(tester, 'Забыли пароль?');
      final executorRect = _actionRect(tester, 'Режим исполнителя');
      final mediaQuery = tester.widget<MediaQuery>(
        find.byType(MediaQuery).first,
      );

      debugPrint(
        'WELCOME_GEOMETRY '
        'scaled22=${mediaQuery.data.textScaler.scale(22)} '
        'progress=$progressRect illustration=$illustrationRect title=$titleRect '
        'description=$descriptionRect firstInput=$firstInputRect '
        'secondInput=$secondInputRect login=$loginRect register=$registerRect '
        'forgot=$forgotRect executor=$executorRect',
      );

      expect(progressRect.top, inInclusiveRange(12.0, 28.0));
      expect(illustrationRect.height / 844, inInclusiveRange(0.45, 0.49));
      expect(illustrationRect.height, inInclusiveRange(380.0, 410.0));

      _expectGap(
        'progress to illustration',
        illustrationRect.top - progressRect.bottom,
        min: 8,
        max: 18,
      );
      _expectGap(
        'illustration to title',
        titleRect.top - illustrationRect.bottom,
        min: 8,
        max: 24,
      );
      _expectGap(
        'title to description',
        descriptionRect.top - titleRect.bottom,
        min: 2,
        max: 12,
      );
      _expectGap(
        'description to first input',
        firstInputRect.top - descriptionRect.bottom,
        min: 10,
        max: 24,
      );
      _expectGap(
        'input fields',
        secondInputRect.top - firstInputRect.bottom,
        min: 8,
        max: 14,
      );
      _expectGap(
        'password to login',
        loginRect.top - secondInputRect.bottom,
        min: 10,
        max: 20,
      );
      _expectGap(
        'login to register',
        registerRect.top - loginRect.bottom,
        min: 12,
        max: 28,
      );
      _expectGap(
        'register to forgot password',
        forgotRect.top - registerRect.bottom,
        min: 4,
        max: 16,
      );
      _expectGap(
        'forgot password to executor',
        executorRect.top - forgotRect.bottom,
        min: 16,
        max: 32,
      );
      _expectGap(
        'executor to viewport bottom',
        844 - executorRect.bottom,
        min: 16,
        max: 48,
      );
    });

    testWidgets(
      'height-only resize scales the illustration instead of one internal gap',
      (tester) async {
        await _pumpWelcome(tester, const Size(390, 650));
        final image650 = tester.getRect(find.byType(AuthTopIllustration));
        final forgot650 = _actionRect(tester, 'Забыли пароль?');
        final executor650 = _actionRect(tester, 'Режим исполнителя');

        await _pumpWelcome(tester, const Size(390, 844));
        final image844 = tester.getRect(find.byType(AuthTopIllustration));
        final forgot844 = _actionRect(tester, 'Забыли пароль?');
        final executor844 = _actionRect(tester, 'Режим исполнителя');

        await _pumpWelcome(tester, const Size(390, 950));
        final image950 = tester.getRect(find.byType(AuthTopIllustration));
        final forgot950 = _actionRect(tester, 'Забыли пароль?');
        final executor950 = _actionRect(tester, 'Режим исполнителя');

        expect(image650.height, inInclusiveRange(180.0, 230.0));
        expect(image844.height, inInclusiveRange(380.0, 410.0));
        expect(image950.height, inInclusiveRange(460.0, 500.0));
        expect(image844.height - image650.height, greaterThan(140.0));
        expect(image950.height - image844.height, greaterThan(70.0));

        for (final gap in [
          executor650.top - forgot650.bottom,
          executor844.top - forgot844.bottom,
          executor950.top - forgot950.bottom,
        ]) {
          expect(gap, inInclusiveRange(16.0, 32.0));
        }
        expect(650 - executor650.bottom, lessThanOrEqualTo(48.0));
        expect(844 - executor844.bottom, lessThanOrEqualTo(48.0));
        expect(950 - executor950.bottom, lessThanOrEqualTo(48.0));
      },
    );

    testWidgets('width constrains the illustration on a narrow viewport', (
      tester,
    ) async {
      await _pumpWelcome(tester, const Size(280, 844));
      final narrowHeight = tester
          .getRect(find.byType(AuthTopIllustration))
          .height;

      await _pumpWelcome(tester, const Size(390, 844));
      final referenceHeight = tester
          .getRect(find.byType(AuthTopIllustration))
          .height;

      expect(narrowHeight, lessThan(referenceHeight));
      expect(referenceHeight - narrowHeight, greaterThan(30.0));
    });

    testWidgets(
      'viewport matrix has no overflow and no giant image-title gap',
      (tester) async {
        const sizes = [
          Size(390, 950),
          Size(412, 915),
          Size(390, 844),
          Size(375, 812),
          Size(390, 750),
          Size(390, 700),
          Size(390, 650),
          Size(390, 600),
        ];

        for (final size in sizes) {
          await _pumpWelcome(tester, size);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Unexpected exception at $size',
          );

          final illustrationRect = tester.getRect(
            find.byType(AuthTopIllustration),
          );
          final titleRect = tester.getRect(find.text(_welcomeTitle));
          expect(
            titleRect.top - illustrationRect.bottom,
            inInclusiveRange(8.0, 24.0),
            reason: 'Image-title gap drifted at $size',
          );
        }
      },
    );

    testWidgets('390x500 scrolls until every action is reachable', (
      tester,
    ) async {
      await _pumpWelcome(tester, const Size(390, 500));

      expect(tester.takeException(), isNull);
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));

      await tester.ensureVisible(find.text('Режим исполнителя'));
      await tester.pumpAndSettle();

      expect(find.text('Войти'), findsOneWidget);
      expect(find.text('Зарегистрироваться'), findsOneWidget);
      expect(find.text('Забыли пароль?'), findsOneWidget);
      expect(find.text('Режим исполнителя'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard leaves fields and login reachable without overflow', (
      tester,
    ) async {
      await _pumpWelcome(tester, const Size(390, 844), viewInsetBottom: 300);

      await tester.ensureVisible(find.text('Войти'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Войти'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('height resize preserves input text and focus state', (
      tester,
    ) async {
      await _pumpWelcome(tester, const Size(390, 650));

      await tester.enterText(find.byType(TextField).at(0), '+996700123456');
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(find.byType(TextField).at(1));
      await tester.pump();

      _setViewport(tester, const Size(390, 950));
      await tester.pumpAndSettle();

      final phone = tester.widget<TextField>(find.byType(TextField).at(0));
      final password = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(phone.controller?.text, '+996700123456');
      expect(password.controller?.text, 'secret');
      expect(password.focusNode?.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('RU and KY remain overflow-free at medium height', (
      tester,
    ) async {
      for (final locale in const [Locale('ru'), Locale('ky')]) {
        await _pumpWelcome(tester, const Size(390, 650), locale: locale);
        expect(tester.takeException(), isNull, reason: 'Overflow for $locale');
        expect(find.byType(TextField), findsNWidgets(2));
      }

      expect(find.text('Сырсөздү унуттуңузбу?'), findsOneWidget);
    });
  });
}
