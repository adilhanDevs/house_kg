// «Добро пожаловать!» — экран входа по номеру и паролю (Frame 05).
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/api_exceptions.dart';
import '../fig_controls.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  /// Вход только по паролю: пароль задаётся один раз при регистрации.
  ///
  /// Раньше пустой пароль означал вход по коду `0000` — вместе с серверной
  /// затычкой, выдававшей этот код на любой номер, это был вход в любой
  /// аккаунт по одному телефону.
  void _onLogin() async {
    if (_isLoading) return;
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      _complain('Введите номер телефона и пароль');
      return;
    }

    setState(() => _isLoading = true);
    final state = AppScope.read(context);
    try {
      await state.loginWithPassword(phone, password);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (route) => false);
      }
    } catch (e) {
      if (mounted) _complain(_errorText(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _errorText(Object error) {
    if (error is ApiException) return error.message;
    if (error is NetworkException) return error.message;
    return error.toString();
  }

  void _complain(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xffd93025),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onRegister() {
    Navigator.of(context).pushNamed(Routes.register);
  }

  void _onForgotPassword() {
    Navigator.of(context).pushNamed(Routes.passwordReset);
  }

  void _onProMode() {
    final state = AppScope.read(context);
    state.pro = true;
    Navigator.of(context).pushNamed(Routes.proSignup);
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold нужен не ради оформления: SnackBar показывается через
    // ближайший зарегистрированный Scaffold, а FigStage — это Material.
    // Без него сообщения об ошибках просто не появлялись на экране.
    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      // Отступ под клавиатуру считает сама сцена.
      resizeToAvoidBottomInset: false,
      body: FigStage(
      frame: frame('05'),
      background: const Color(0xffffffff),
      overlays: [
        // Поле номера телефона
        Positioned(
          left: 25.0,
          top: 555.0,
          child: FigInputBox(
            width: 324.0,
            controller: _phoneController,
            hint: 'Номер телефона',
            keyboardType: TextInputType.phone,
          ),
        ),
        // Поле пароля
        Positioned(
          left: 25.0,
          top: 603.0,
          child: FigInputBox(
            width: 324.0,
            controller: _passwordController,
            hint: 'Пароль',
            keyboardType: TextInputType.visiblePassword,
          ),
        ),
        // Кнопка Войти (FigZone сама создаёт Positioned)
        FigZone(
          25.0,
          656.0,
          324.0,
          48.0,
          label: 'Войти',
          onTap: _onLogin,
        ),
        // Кнопка Зарегистрироваться
        FigZone(
          116.0,
          717.0,
          143.0,
          20.0,
          label: 'Зарегистрироваться',
          onTap: _onRegister,
        ),
        // «Забыли пароль?» — в макете этой строки нет: пароль там негде было
        // и задать. Ставим под кнопками входа, тем же оранжевым.
        Positioned(
          left: 0.0,
          top: 780.0,
          width: 375.0,
          height: 22.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onForgotPassword,
            child: Container(
              color: const Color(0xffffffff),
              alignment: Alignment.center,
              child: const Text(
                'Забыли пароль?',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xffea812e),
                ),
              ),
            ),
          ),
        ),
        // Кнопка Режим исполнителя
        FigZone(
          118.0,
          753.0,
          140.0,
          20.0,
          label: 'Режим исполнителя',
          onTap: _onProMode,
        ),
      ],
      ),
    );
  }
}
