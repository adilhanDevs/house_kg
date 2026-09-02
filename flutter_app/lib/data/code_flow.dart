// Что именно подтверждает четырёхзначный код и что делать после подтверждения.
//
// Сервер ищет код по паре «номер + цель»: код, выписанный на регистрацию,
// при проверке с целью «вход» просто не находится. Поэтому цель едет вместе
// с формой, а не подставляется на экране кода наугад.
import 'package:flutter/foundation.dart';

enum CodeFlowKind {
  /// Регистрация обычного пользователя: аккаунт заводится после кода.
  register,

  /// Регистрация исполнителя: аккаунт уже заведён, кодом включается is_pro.
  proRegister,

  /// Забытый пароль: код разрешает задать новый.
  passwordReset,
}

extension CodeFlowKindApi on CodeFlowKind {
  /// Значение `purpose`, которое понимает сервер.
  String get otpPurpose => switch (this) {
        CodeFlowKind.register => 'register',
        CodeFlowKind.proRegister => 'pro_register',
        CodeFlowKind.passwordReset => 'password_reset',
      };
}

/// Заполненная форма, которую экран кода доводит до конца.
@immutable
class CodeFlow {
  const CodeFlow({
    required this.kind,
    required this.phone,
    this.name = '',
    this.password = '',
    this.termsVersion = '',
    this.resendAfter = 60,
  });

  final CodeFlowKind kind;
  final String phone;

  /// Имя пользователя — только у регистрации.
  final String name;

  /// Пароль: новый при регистрации, новый же при восстановлении.
  final String password;

  /// Версия принятого соглашения — только у регистрации.
  final String termsVersion;

  /// Через сколько секунд сервер разрешит следующий код (`resend_after`).
  /// Своего числа клиент не придумывает.
  final int resendAfter;

  CodeFlow withResendAfter(int seconds) => CodeFlow(
        kind: kind,
        phone: phone,
        name: name,
        password: password,
        termsVersion: termsVersion,
        resendAfter: seconds,
      );

  String get otpPurpose => kind.otpPurpose;
}
