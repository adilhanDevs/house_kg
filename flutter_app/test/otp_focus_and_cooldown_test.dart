// Экран кода: возврат фокуса и одно понятное время ожидания.
//
// На устройстве всплыли два дефекта. Первый: после системной кнопки «Назад»
// клавиатура закрывается, но FocusNode фокус сохраняет — повторный
// requestFocus() ничего не делал, и ввести код становилось нечем. Второй:
// клиент вёл собственный отсчёт на 60 секунд, а сервер отвечал своим
// временем (до часа), поэтому на экране жили два разных таймера.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/code_flow.dart';
import 'package:house_kgz/data/wait_time.dart';
import 'package:house_kgz/ui/pages/code_page.dart';

class _OtpServer extends http.BaseClient {
  _OtpServer({this.retryAfter, this.resendAfter = 60});

  /// Если задано — запрос кода отвечает 429 с этим retry_after.
  final int? retryAfter;
  final int resendAfter;

  int otpRequests = 0;
  Map<String, dynamic>? lastVerifyBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/v1/auth/otp/verify/' && request is http.Request) {
      lastVerifyBody = jsonDecode(request.body) as Map<String, dynamic>;
    }
    final body = jsonEncode(
      request.url.path == '/api/v1/auth/otp/request/' && retryAfter != null
          ? {
              'error': {
                'code': 'throttled',
                'message': 'Повторите через $retryAfter секунд.',
                'details': {'retry_after': retryAfter},
              }
            }
          : {'expires_in': 300, 'resend_after': resendAfter, 'is_new_user': true},
    );
    if (request.url.path == '/api/v1/auth/otp/request/') otpRequests += 1;
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      request.url.path == '/api/v1/auth/otp/request/' && retryAfter != null ? 429 : 200,
      headers: {'content-type': 'application/json'},
    );
  }
}

AppState _state(http.BaseClient client) =>
    AppState(apiClient: ListingApiClient(baseUrl: 'http://test.com', client: client));

Widget _page(AppState state, {int resendAfter = 0}) => AppScope(
      state: state,
      child: MaterialApp(
        // После удачной проверки экран уходит на главную — даём ей заглушку.
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Center(child: Text('ГЛАВНАЯ'))),
        ),
        home: CodePage(
          phone: '+996700111222',
          resendAfter: resendAfter,
          flow: const CodeFlow(kind: CodeFlowKind.register, phone: '+996700111222'),
        ),
      ),
    );

/// Настоящее поле ввода внутри полосы цифр.
Finder get _hiddenField => find.descendant(
      of: find.byKey(kOtpInputKey),
      matching: find.byType(TextField),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('форматирование времени ожидания', () {
    test('секунды, минуты и часы склоняются правильно', () {
      expect(formatWait(1), '1 секунду');
      expect(formatWait(2), '2 секунды');
      expect(formatWait(20), '20 секунд');
      expect(formatWait(42), '42 секунды');
      expect(formatWait(60), '1 минуту');
      expect(formatWait(3062), '52 минуты');
      expect(formatWait(3600), 'час');
      expect(formatWait(7200), '2 часа');
    });

    test('длинное ожидание не показывается в секундах', () {
      expect(waitMessage(3062), 'Повторите через 52 минуты.');
      expect(waitMessage(3062), isNot(contains('3062')));
    });
  });

  group('фокус поля кода', () {
    testWidgets('при открытии экран сразу готов к вводу', (tester) async {
      await tester.pumpWidget(_page(_state(_OtpServer())));
      await tester.pump();

      expect(tester.widget<TextField>(_hiddenField).focusNode?.hasFocus, isTrue);
    });

    testWidgets('после потери фокуса тап по цифрам открывает клавиатуру', (tester) async {
      // Ловим запрос на показ клавиатуры: именно его не было после Back.
      final shown = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.textInput,
        (call) async {
          shown.add(call.method);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.textInput, null));

      await tester.pumpWidget(_page(_state(_OtpServer())));
      await tester.pump();

      // Клавиатуру закрыли системной кнопкой: фокус при этом остаётся.
      final node = tester.widget<TextField>(_hiddenField).focusNode!;
      expect(node.hasFocus, isTrue);
      shown.clear();

      await tester.tap(find.byKey(kOtpInputKey));
      await tester.pump();

      expect(node.hasFocus, isTrue);
      expect(
        shown.contains('TextInput.show'),
        isTrue,
        reason: 'клавиатуру не попросили показаться заново',
      );
    });

    testWidgets('после снятия фокуса тап возвращает его', (tester) async {
      await tester.pumpWidget(_page(_state(_OtpServer())));
      await tester.pump();

      final node = tester.widget<TextField>(_hiddenField).focusNode!;
      node.unfocus();
      await tester.pump();
      expect(node.hasFocus, isFalse);

      await tester.tap(find.byKey(kOtpInputKey));
      await tester.pump();

      expect(node.hasFocus, isTrue);
    });

    testWidgets('после возврата фокуса код вводится и уходит на проверку', (tester) async {
      final server = _OtpServer();
      await tester.pumpWidget(_page(_state(server)));
      await tester.pump();

      final node = tester.widget<TextField>(_hiddenField).focusNode!;
      node.unfocus();
      await tester.pump();

      await tester.tap(find.byKey(kOtpInputKey));
      await tester.pump();
      await tester.enterText(_hiddenField, '1234');
      await tester.pumpAndSettle();

      expect(server.lastVerifyBody?['code'], '1234');
    });
  });

  group('одно время ожидания', () {
    testWidgets('номер подставляется в текст, а не рисуется', (tester) async {
      await tester.pumpWidget(_page(_state(_OtpServer())));
      await tester.pump();

      expect(find.textContaining('+996 700 111 222'), findsOneWidget);
      expect(find.textContaining('997 919 170'), findsNothing);
    });

    testWidgets('отсчёт стартует со значения сервера, а не с жёстких 60',
        (tester) async {
      await tester.pumpWidget(_page(_state(_OtpServer()), resendAfter: 20));
      await tester.pump();

      expect(find.textContaining('через 20 секунд'), findsOneWidget);
      expect(find.textContaining('через 1 минуту'), findsNothing);
    });

    testWidgets('429 показывает одно человеческое время', (tester) async {
      final server = _OtpServer(retryAfter: 3062);
      await tester.pumpWidget(_page(_state(server)));
      await tester.pump();

      await tester.tap(find.byKey(kOtpResendKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Секунд на экране нет, а число одно и то же и в сообщении, и в
      // подписи кнопки — двух разных времён больше не бывает.
      expect(find.textContaining('3062'), findsNothing);
      expect(find.textContaining('52 минуты'), findsNWidgets(2));
      expect(find.textContaining('минут'), findsNWidgets(2));
    });

    testWidgets('повторные нажатия не плодят запросы и таймеры', (tester) async {
      final server = _OtpServer(resendAfter: 30);
      await tester.pumpWidget(_page(_state(server)));
      await tester.pump();

      await tester.tap(find.byKey(kOtpResendKey));
      await tester.pump();
      await tester.tap(find.byKey(kOtpResendKey), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(server.otpRequests, 1);

      // Отсчёт идёт ровно один: за две секунды значение падает на два.
      expect(find.textContaining('через 30 секунд'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('через 28 секунд'), findsOneWidget);
    });
  });
}
