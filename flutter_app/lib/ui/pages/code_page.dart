// «Код подтверждения» — по кадру 08/57 макета, 4-значный код из SMS.
//
// Экран обслуживает три случая: регистрацию (аккаунт заводится здесь, после
// проверки кода), регистрацию исполнителя и смену пароля.
//
// Собран настоящими виджетами, а не наложением на растр кадра, и вот почему.
// В кадре нарисованы и сами четыре цифры, и номер телефона — причём номер
// зашит в картинку («+996 997 919 170») одинаковым для всех, подставить туда
// телефон пользователя невозможно в принципе. Наложения при этом стояли по
// фиксированным координатам и на устройстве расходились с рисунком: человек
// видел цифры кадра, тапал по ним и не попадал в настоящее поле.
//
// Отдельная беда была с возвратом фокуса: системная кнопка «Назад» на Android
// закрывает клавиатуру, но фокус с узла не снимает, поэтому повторный
// requestFocus() ничего не делал и клавиатура больше не появлялась.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_exceptions.dart';
import '../../data/code_flow.dart';
import '../../data/wait_time.dart';
import '../../fig/fig.dart';

/// Ключи для тестов: искать поле по порядку в дереве ненадёжно.
const Key kOtpInputKey = Key('registration_otp_input');
const Key kOtpResendKey = Key('registration_otp_resend');

const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);
const Color _danger = Color(0xffd93025);
const Color _digit = Color(0xff071e68);

class CodePage extends StatefulWidget {
  const CodePage({
    super.key,
    this.nextRoute = Routes.home,
    this.phone,
    this.flow,
    this.resendAfter = 60,
  });

  final String nextRoute;
  final String? phone;

  /// Заполненная форма: регистрация, регистрация исполнителя или новый пароль.
  /// Всё это доводится до конца только после того, как код принят.
  final CodeFlow? flow;

  /// Через сколько секунд разрешена повторная отправка — из ответа сервера
  /// на запрос кода (`resend_after`).
  final int resendAfter;

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
  bool _isResending = false;

  Timer? _resendTimer;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();
    _startResendCountdown(widget.resendAfter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCode();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Запускает отсчёт до следующей попытки.
  ///
  /// Сколько ждать, решает сервер: у запроса кода несколько ограничений
  /// (минутное на номер, часовое на номер, часовое на IP), и DRF отдаёт
  /// максимум из сработавших одним числом. Раньше здесь стояло жёсткое 60,
  /// и рядом с серверным «через 52 минуты» шёл собственный отсчёт на минуту —
  /// получалось два разных времени на один и тот же запрет.
  void _startResendCountdown(int seconds) {
    // Таймер всегда один: старый гасим перед запуском нового.
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendIn = seconds);
    if (seconds <= 0) return;

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  /// Возвращает фокус полю кода и открывает клавиатуру.
  ///
  /// Если узел уже в фокусе, requestFocus() не делает ничего — а клавиатуру
  /// система при этом закрыла. Тогда просим её показаться явно, иначе вводить
  /// код становится нечем.
  void _focusCode() {
    if (_focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return;
    }
    _focusNode.requestFocus();
  }

  String _errorText(Object error) {
    if (error is ApiException) {
      // Ограничение по частоте: показываем ОДНО время — то, что назвал сервер.
      final wait = error.retryAfter;
      if (error.isThrottled && wait != null) {
        return waitMessage(wait);
      }
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
    if (_resendIn > 0 || _isChecking || _isResending) return;
    final phone = widget.targetPhone;
    if (phone == null) return;

    final state = AppScope.read(context);
    setState(() => _isResending = true);
    try {
      final response = await state.sendOtp(phone, purpose: widget.flow?.otpPurpose);
      if (!mounted) return;
      setState(() => _error = null);
      final next = response['resend_after'];
      _startResendCountdown(next is num ? next.toInt() : 60);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Код отправлен повторно')));
    } catch (e) {
      if (!mounted) return;
      // Сервер сказал, сколько ждать, — по этому же числу и отсчитываем,
      // чтобы на экране не было двух разных времён.
      final wait = e is ApiException && e.isThrottled ? e.retryAfter : null;
      if (wait != null) _startResendCountdown(wait);
      setState(() => _error = _errorText(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
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
      _focusCode();
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

  /// Номер в человеческом виде: +996 700 111 222.
  String get _prettyPhone {
    final raw = widget.targetPhone ?? '';
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.length < 9) return raw;
    final tail = digits.substring(digits.length - 9);
    final prefix = digits.substring(0, digits.length - 9);
    return '$prefix ${tail.substring(0, 3)} ${tail.substring(3, 6)} ${tail.substring(6)}';
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xffffffff),

    // При открытии клавиатуры нижняя картинка просто уменьшится,
    // а сама страница не станет прокручиваемой.
    resizeToAvoidBottomInset: true,

    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ==========================================
          // ВЕРХНЯЯ ЧАСТЬ — КОД ПОДТВЕРЖДЕНИЯ
          // ==========================================
          Padding(
            padding: const EdgeInsets.fromLTRB(
              25.0,
              24.0,
              25.0,
              0.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Код подтверждения',
                  style: figStyle(
                    fontSize: 21.0,
                    family: FigFont.display,
                    weight: 600,
                    height: 1.0,
                    color: const Color(0xff000000),
                  ),
                ),

                const SizedBox(height: 8.0),

                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _prettyPhone.isEmpty
                            ? 'Напишите 4-значный код из SMS.'
                            : 'Напишите 4-значный код, который был отправлен на номер ',
                      ),

                      if (_prettyPhone.isNotEmpty)
                        TextSpan(
                          text: _prettyPhone,
                          style: figStyle(
                            fontSize: 15.0,
                            family: FigFont.display,
                            weight: 600,
                            height: 1.333,
                            color: _accent,
                          ),
                        ),
                    ],
                    style: figStyle(
                      fontSize: 15.0,
                      family: FigFont.display,
                      weight: 500,
                      height: 1.333,
                      color: _muted,
                    ),
                  ),
                ),

                const SizedBox(height: 28.0),

                _CodeInput(
                  key: kOtpInputKey,
                  controller: _codeController,
                  focusNode: _focusNode,
                  code: _code,
                  onChanged: _onCodeChanged,
                  onTap: _focusCode,
                ),

                // Ошибка неправильного кода
                if (_error != null) ...[
                  const SizedBox(height: 12.0),

                  Text(
                    _error!,
                    style: figStyle(
                      fontSize: 13.0,
                      family: FigFont.display,
                      weight: 500,
                      height: 1.3,
                      color: _danger,
                    ),
                  ),
                ],

                const SizedBox(height: 24.0),

                _ResendButton(
                  key: kOtpResendKey,
                  secondsLeft: _resendIn,
                  busy: _isResending,
                  onTap: _resend,
                ),

                const SizedBox(height: 8.0),

                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onGoBack,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                      ),
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
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Небольшой промежуток перед изображением.
          const SizedBox(height: 12.0),

          // ==========================================
          // НИЖНЯЯ КАРТИНКА
          // ==========================================
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  'assets/login/Register-screen-photo.png',
                  width: double.infinity,

                  // Картинка сохраняет свои пропорции
                  // и занимает всю ширину.
                  fit: BoxFit.fitWidth,

                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

/// Четыре цифры кода. Настоящее поле спрятано, но нажатие ловит вся полоса.
class _CodeInput extends StatelessWidget {
  const _CodeInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.code,
    required this.onChanged,
    required this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String code;
  final ValueChanged<String> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 60.0,
        child: Stack(
          children: [
            // Настоящее поле размером в точку: ввод идёт в него, а рисуем мы
            // сами. Раньше оно занимало всю полосу, лежало под GestureDetector
            // и спорило с ним за нажатия.
            const SizedBox.shrink(),
            Positioned(
              left: 0.0,
              top: 0.0,
              width: 1.0,
              height: 1.0,
              child: Opacity(
                opacity: 0.0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Row(
              children: List.generate(4, (index) {
                final hasInput = index < code.length;
                final isNext = code.length == index;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 3 ? 16.0 : 0.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            hasInput ? code[index] : 'X',
                            style: figStyle(
                              fontSize: 24.0,
                              family: FigFont.display,
                              weight: 700,
                              height: 1.0,
                              color: hasInput ? _digit : const Color(0xff1c1939),
                            ),
                          ),
                        ),
                        Container(height: 2.0, color: isNext ? _accent : _digit),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Повторная отправка кода с обратным отсчётом от серверного времени.
class _ResendButton extends StatelessWidget {
  const _ResendButton({
    super.key,
    required this.secondsLeft,
    required this.busy,
    required this.onTap,
  });

  final int secondsLeft;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blocked = secondsLeft > 0 || busy;
    final label = busy
        ? 'Отправляем…'
        : (secondsLeft > 0
            ? 'Отправить код повторно через ${formatWait(secondsLeft)}'
            : 'Отправить код повторно');

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: blocked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: figStyle(
              fontSize: 14.0,
              family: FigFont.display,
              weight: 500,
              height: 1.3,
              color: blocked ? _muted : _accent,
            ),
          ),
        ),
      ),
    );
  }
}
