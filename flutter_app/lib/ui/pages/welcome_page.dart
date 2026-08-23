// «Добро пожаловать!» — экран входа по номеру и паролю (Frame 05).
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
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

  void _onLogin() {
    Navigator.of(context).pushNamed(Routes.code);
  }

  void _onRegister() {
    Navigator.of(context).pushNamed(Routes.onboarding);
  }

  void _onProMode() {
    final state = AppScope.read(context);
    state.pro = true;
    Navigator.of(context).pushNamed(Routes.proSignup);
  }

  @override
  Widget build(BuildContext context) {
    return FigStage(
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
    );
  }
}
