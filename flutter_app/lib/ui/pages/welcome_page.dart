// «Добро пожаловать!» — экран входа по номеру и паролю (Frame 05).
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/api_exceptions.dart';
import '../../l10n/l10n.dart';
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

  void _onLogin() async {
    if (_isLoading) return;
    final l10n = context.l10n;
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      _complain(l10n.fillAllFields);
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
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xffffffff),
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
            hint: l10n.phone,
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
            hint: l10n.password,
            keyboardType: TextInputType.visiblePassword,
          ),
        ),
        // Кнопка Войти
        Positioned(
          left: 25.0,
          top: 656.0,
          width: 324.0,
          height: 48.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onLogin,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffea812e),
                borderRadius: BorderRadius.circular(10.0),
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                    )
                  : Text(
                      l10n.login,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        // Кнопка Зарегистрироваться
        Positioned(
          left: 25.0,
          top: 715.0,
          width: 324.0,
          height: 24.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onRegister,
            child: Container(
              color: const Color(0xffffffff),
              alignment: Alignment.center,
              child: Text(
                l10n.register,
                style: const TextStyle(
                  color: Color(0xffea812e),
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        // «Забыли пароль?»
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
              child: Text(
                l10n.forgotPassword,
                style: const TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xffea812e),
                ),
              ),
            ),
          ),
        ),
        // Кнопка Режим исполнителя
        Positioned(
          left: 25.0,
          top: 748.0,
          width: 324.0,
          height: 24.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onProMode,
            child: Container(
              color: const Color(0xffffffff),
              alignment: Alignment.center,
              child: Text(
                l10n.rolePro,
                style: const TextStyle(
                  color: Color(0xff7d7d7d),
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
