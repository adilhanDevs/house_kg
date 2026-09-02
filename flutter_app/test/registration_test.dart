// Регистрация обычного пользователя: экран есть, код проверяется, пароль
// задаётся один раз.
//
// До этих правок кнопка «Зарегистрироваться» вела в онбординг и возвращала на
// приветствие, а экран кода уходил на главную при любом введённом коде.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/stage.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/code_page.dart';
import 'package:house_kgz/ui/pages/register_page.dart';
import 'package:house_kgz/ui/pages/welcome_page.dart';

/// «Сервер», который ведёт себя как настоящий: код 1234, всё прочее — 400.
class _AuthServer extends http.BaseClient {
  _AuthServer({this.termsVersion = '3', this.expectedCode = '1234'});

  final String? termsVersion;
  final String expectedCode;

  Map<String, dynamic>? lastVerifyBody;
  Map<String, dynamic>? lastRequestBody;
  int verifyCalls = 0;

  http.StreamedResponse _json(Object body, int status) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final body = request is http.Request && request.body.isNotEmpty
        ? jsonDecode(request.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (path == '/api/v1/app/config/') {
      return _json({
        'documents': termsVersion == null
            ? <String, dynamic>{}
            : {
                'terms': {'url': '/api/v1/app/pages/terms/', 'version': termsVersion},
              },
      }, 200);
    }

    if (path == '/api/v1/auth/otp/request/') {
      lastRequestBody = body;
      return _json({'expires_in': 300, 'resend_after': 60, 'is_new_user': true}, 200);
    }

    if (path == '/api/v1/auth/otp/verify/') {
      verifyCalls += 1;
      lastVerifyBody = body;
      if (body['code'] != expectedCode) {
        return _json({
          'error': {
            'code': 'validation_error',
            'message': 'Неверный код',
            'details': {'attempts_left': 4},
          }
        }, 400);
      }
      return _json({
        'access': 'access-token',
        'refresh': 'refresh-token',
        'user': {'name': body['name'] ?? '', 'phone': body['phone'], 'is_pro': false},
        'is_new_user': true,
      }, 200);
    }

    if (path == '/api/v1/users/me/') {
      return _json({'name': 'Азамат', 'phone': '+996700111222', 'is_pro': false}, 200);
    }

    return _json(<String, dynamic>{}, 200);
  }
}

Widget _app(AppState state, {String initialRoute = Routes.register}) {
  return AppScope(
    state: state,
    child: MaterialApp(
      initialRoute: initialRoute,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (context) => switch (settings.name) {
          Routes.welcome => const WelcomePage(),
          Routes.register => const RegisterPage(),
          Routes.code => Builder(
              builder: (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                return CodePage(
                  phone: args is String ? args : null,
                  draft: args is RegistrationDraft ? args : null,
                );
              },
            ),
          _ => const Scaffold(body: Center(child: Text('ГЛАВНАЯ'))),
        },
      ),
    ),
  );
}

/// Зона макета ищется по метке: сам кадр нарисован растром, текста в дереве нет.
Finder _zone(String label) =>
    find.byWidgetPredicate((w) => w is FigZone && w.label == label);

AppState _state(http.BaseClient client) => AppState(
      apiClient: ListingApiClient(baseUrl: 'http://test.com', client: client),
    );

Future<void> _fillForm(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), '+996700111222');
  await tester.enterText(fields.at(1), 'Азамат');
  await tester.enterText(fields.at(2), 'Дом-Бишкек-2026');
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('кнопка «Зарегистрироваться» открывает форму регистрации', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_state(_AuthServer()), initialRoute: Routes.welcome));
    await tester.pump();

    await tester.tap(_zone('Зарегистрироваться'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('без согласия регистрация не начинается', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final server = _AuthServer();
    await tester.pumpWidget(_app(_state(server)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await _fillForm(tester);
    await tester.tap(_zone('Далее'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(server.lastRequestBody, isNull, reason: 'код не должен запрашиваться');
    expect(find.textContaining('Примите соглашение'), findsOneWidget);
  });

  testWidgets('согласие отправляется той версии, что пришла с сервера', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final server = _AuthServer(termsVersion: '3');
    await tester.pumpWidget(_app(_state(server)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await _fillForm(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(_zone('Далее'));
    await tester.pumpAndSettle();

    expect(server.lastRequestBody?['purpose'], 'register');
    expect(find.byType(CodePage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.pumpAndSettle();

    expect(server.lastVerifyBody?['accepted_terms_version'], '3');
    expect(server.lastVerifyBody?['password'], 'Дом-Бишкек-2026');
    expect(server.lastVerifyBody?['name'], 'Азамат');
  });

  testWidgets('неверный код оставляет на экране и показывает причину', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final server = _AuthServer(expectedCode: '1234');
    await tester.pumpWidget(
      AppScope(
        state: _state(server),
        child: const MaterialApp(home: CodePage(phone: '+996700111222')),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '9999');
    await tester.pumpAndSettle();

    expect(find.byType(CodePage), findsOneWidget);
    expect(find.textContaining('Неверный код'), findsOneWidget);
    expect(find.textContaining('Осталось попыток: 4'), findsOneWidget);
  });

  testWidgets('соглашения нет — регистрация заблокирована', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final server = _AuthServer(termsVersion: null);
    await tester.pumpWidget(_app(_state(server)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await _fillForm(tester);
    await tester.tap(_zone('Далее'));
    await tester.pump();

    expect(server.lastRequestBody, isNull);
    expect(find.textContaining('Соглашение недоступно'), findsWidgets);
  });
}
