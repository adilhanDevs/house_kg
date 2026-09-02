// «Забыли пароль» — новый пароль по коду из SMS.
//
// Отдельного кадра в макете нет: экран собран из тех же элементов, что и
// кадры входа и регистрации — заголовок 21/600, пояснение 15/500 серым,
// поля 324×36 и оранжевая кнопка 324×36 с радиусом 10.
//
// Вход у нас парольный, поэтому забытый пароль означал потерю аккаунта:
// задать новый было негде.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_exceptions.dart';
import '../../data/code_flow.dart';
import '../../data/wait_time.dart';
import '../../fig/fig.dart';
import '../fig_controls.dart';

/// Оранжевый акцент приложения.
const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);
const Color _danger = Color(0xffd93025);

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSending = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _errorText(Object error) {
    if (error is ApiException) {
      // У запроса кода несколько ограничений сразу; сервер уже свёл их к
      // одному retry_after, его и показываем — человеческим текстом, а не
      // «Повторите через 3062 секунды».
      final wait = error.retryAfter;
      if (error.isThrottled && wait != null) return waitMessage(wait);
      return error.message;
    }
    if (error is NetworkException) return error.message;
    return error.toString();
  }

  void _complain(String message) {
    // Предыдущее сообщение убираем: при нескольких отказах подряд баннеры
    // выстраивались в очередь и человек читал устаревшее время.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _danger,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Сколько секунд до следующего кода — по ответу сервера.
  int _resendSeconds(Map<String, dynamic> response) {
    final value = response['resend_after'];
    return value is num ? value.toInt() : 60;
  }

  Future<void> _onNext() async {
    if (_isSending) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      _complain('Введите номер телефона и новый пароль');
      return;
    }

    setState(() => _isSending = true);
    final state = AppScope.read(context);
    try {
      final otp = await state.startPasswordReset(phone);
      if (!mounted) return;
      // Новый пароль едет с формой и применяется только после кода: до него
      // мы не знаем, владеет ли человек этим номером.
      Navigator.of(context).pushNamed(
        Routes.code,
        arguments: CodeFlow(
          kind: CodeFlowKind.passwordReset,
          phone: phone,
          password: password,
          resendAfter: _resendSeconds(otp),
        ),
      );
    } catch (e) {
      if (mounted) _complain(_errorText(e));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed(Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xffffffff),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25.0, 40.0, 25.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackLink(onTap: _onBack),
              const SizedBox(height: 24.0),
              Text(
                'Забыли пароль?',
                style: figStyle(
                  fontSize: 21.0,
                  family: FigFont.display,
                  weight: 600,
                  height: 1.0,
                  color: const Color(0xff000000),
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Введите номер телефона и новый пароль. Мы пришлём код '
                'подтверждения — после него пароль сменится.',
                style: figStyle(
                  fontSize: 15.0,
                  family: FigFont.display,
                  weight: 500,
                  height: 1.333,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 24.0),
              FigInputBox(
                width: 324.0,
                controller: _phoneController,
                hint: 'Номер телефона',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12.0),
              FigInputBox(
                width: 324.0,
                controller: _passwordController,
                hint: 'Новый пароль',
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: 12.0),
              _PrimaryButton(
                label: 'Получить код',
                busy: _isSending,
                onTap: _onNext,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Кнопка макета: 324×36, радиус 10, текст 17/600 белым.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        width: 324.0,
        height: 36.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: busy ? _accent.withValues(alpha: 0.6) : _accent,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: busy
            ? const SizedBox(
                width: 16.0,
                height: 16.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Color(0xffffffff),
                ),
              )
            : Text(
                label,
                style: figStyle(
                  fontSize: 17.0,
                  family: FigFont.display,
                  weight: 600,
                  height: 1.294,
                  color: const Color(0xffffffff),
                ),
              ),
      ),
    );
  }
}

/// «Вернуться назад» — та же подпись и цвет, что на экране кода.
class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        'Вернуться назад',
        style: figStyle(
          fontSize: 15.0,
          family: FigFont.display,
          weight: 500,
          height: 1.333,
          color: _accent,
        ),
      ),
    );
  }
}
