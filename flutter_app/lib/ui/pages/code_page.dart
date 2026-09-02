// «Код подтверждения» — кадр 08/57 макета с 4-значным вводом СМС-кода.
//
// Экран обслуживает три случая: подтверждение регистрации (тогда приходит
// RegistrationDraft и аккаунт заводится здесь), регистрация исполнителя и
// вход по коду. Неверный код раньше проглатывался пустым `catch (_) {}`, и
// экран всё равно уходил на главную — человек оказывался внутри без токенов
// и упирался в 401 на каждом действии.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/api_exceptions.dart';
import '../../data/code_flow.dart';

class CodePage extends StatefulWidget {
  const CodePage({super.key, this.nextRoute = Routes.home, this.phone, this.flow});

  final String nextRoute;
  final String? phone;

  /// Заполненная форма: регистрация, регистрация исполнителя или новый пароль.
  /// Всё это доводится до конца только после того, как код принят.
  final CodeFlow? flow;

  String? get targetPhone => flow?.phone ?? phone;

  @override
  State<CodePage> createState() => _CodePageState();
}

class _CodePageState extends State<CodePage> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _code = '';
  String? _error;
  bool _isChecking = false;

  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Сервер разрешает следующий код через минуту — столько и ждём.
  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  String _errorText(Object error) {
    if (error is ApiException) {
      final left = error.details['attempts_left'];
      if (left is num) {
        return '${error.message}. Осталось попыток: ${left.toInt()}';
      }
      return error.message;
    }
    if (error is NetworkException) return error.message;
    return error.toString();
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _isChecking) return;
    final phone = widget.targetPhone;
    if (phone == null) return;

    final state = AppScope.read(context);
    try {
      await state.sendOtp(phone, purpose: widget.flow?.otpPurpose);
      if (!mounted) return;
      setState(() => _error = null);
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен повторно')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  void _onCodeChanged(String value) async {
    if (value.length > 4) {
      value = value.substring(0, 4);
      _codeController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    setState(() {
      _code = value;
      if (value.length < 4) _error = null;
    });

    if (value.length != 4 || _isChecking) return;

    final phone = widget.targetPhone;
    if (phone == null) {
      // Номера нет — подтверждать нечего; это возможно только у кадра-заглушки.
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (route) => false);
      return;
    }

    setState(() => _isChecking = true);
    final state = AppScope.read(context);
    final flow = widget.flow;
    try {
      switch (flow?.kind) {
        case CodeFlowKind.register:
        case CodeFlowKind.proRegister:
          await state.confirmRegistration(
            phone: flow!.phone,
            code: value,
            name: flow.name,
            password: flow.password,
            termsVersion: flow.termsVersion,
            purpose: flow.otpPurpose,
          );
        case CodeFlowKind.passwordReset:
          await state.confirmPasswordReset(
            phone: flow!.phone,
            code: value,
            password: flow.password,
          );
        case null:
          await state.verifyAndLogin(phone, value);
      }
    } catch (e) {
      if (!mounted) return;
      // Код не подошёл — остаёмся на экране и говорим почему. Поле чистим,
      // чтобы следующая цифра начинала новый ввод, а не дописывала старый.
      setState(() {
        _isChecking = false;
        _error = _errorText(e);
        _code = '';
        _codeController.clear();
      });
      _focusNode.requestFocus();
      return;
    }

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (widget.nextRoute == Routes.home) {
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (route) => false);
    } else {
      Navigator.of(context).pushNamed(widget.nextRoute);
    }
  }

  void _onGoBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushReplacementNamed(Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProFlow = widget.nextRoute == Routes.proPhoto1;
    final frameId = isProFlow ? '57' : '08';

    // Scaffold нужен не ради оформления: SnackBar показывается через
    // ближайший зарегистрированный Scaffold, а FigStage — это Material.
    // Без него сообщения об ошибках просто не появлялись на экране.
    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      // Отступ под клавиатуру считает сама сцена.
      resizeToAvoidBottomInset: false,
      body: FigStage(
      frame: frame(frameId),
      background: const Color(0xffffffff),
      overlays: [
        // Дисплей 4 цифр кода (ручной ввод с клавиатуры)
        Positioned(
          left: 26.0,
          top: isProFlow ? 200.0 : 610.0,
          child: SizedBox(
            width: 272.0,
            height: 60.0,
            child: Stack(
              children: [
                // Скрытый фокусный TextField для получения ввода клавиатуры
                Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _codeController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    onChanged: _onCodeChanged,
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
                // Интерактивное наложение ручного ввода
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _focusNode.requestFocus(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(4, (index) {
                        final hasInput = index < _code.length;
                        final digit = hasInput ? _code[index] : 'X';
                        final isFocused = _code.length == index || (_code.length == 4 && index == 3);

                        return Container(
                          width: 56.0,
                          height: 60.0,
                          margin: EdgeInsets.only(right: index < 3 ? 16.0 : 0.0),
                          color: const Color(0xffffffff),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  digit,
                                  style: TextStyle(
                                    fontSize: 24.0,
                                    fontWeight: FontWeight.bold,
                                    color: hasInput
                                        ? const Color(0xff071e68)
                                        : const Color(0xff1c1939),
                                  ),
                                ),
                              ),
                              Container(
                                height: 2.0,
                                color: isFocused ? const Color(0xffea812e) : const Color(0xff071e68),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Ошибка ввода — под полем кода, а не в проглоченном исключении.
        if (_error != null)
          Positioned(
            left: 26.0,
            top: isProFlow ? 262.0 : 676.0,
            width: 323.0,
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 13.0, height: 1.3, color: Color(0xffd93025)),
            ),
          ),

        // Повторная отправка: сервер разрешает следующий код через минуту.
        Positioned(
          left: 0.0,
          top: isProFlow ? 306.0 : 694.0,
          width: 375.0,
          height: 32.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _resendIn > 0 ? null : _resend,
            child: Container(
              color: const Color(0xffffffff),
              alignment: Alignment.center,
              child: Text(
                _resendIn > 0
                    ? 'Отправить код повторно через $_resendIn с'
                    : 'Отправить код повторно',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: _resendIn > 0 ? const Color(0xff7d7d7d) : const Color(0xffea812e),
                ),
              ),
            ),
          ),
        ),

        // Кликбельная кнопка «Вернуться назад»
        Positioned(
          left: 0.0,
          top: isProFlow ? 280.0 : 726.0,
          width: 375.0,
          height: 44.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onGoBack,
            child: Container(
              color: const Color(0xffffffff),
              alignment: Alignment.center,
              child: const Text(
                'Вернуться назад',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xffea812e),
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
