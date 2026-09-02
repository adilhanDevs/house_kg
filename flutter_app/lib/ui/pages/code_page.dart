import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_exceptions.dart';
import '../../data/code_flow.dart';
import '../../data/wait_time.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';
import '../widgets/auth_bottom_illustration.dart';

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
  void _startResendCountdown(int seconds) {
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
  void _focusCode() {
    if (_focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      return;
    }
    _focusNode.requestFocus();
  }

  String _errorText(Object error) {
    if (error is ApiException) {
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

  Future<void> _onCodeChanged(String value) async {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 4) return;
    setState(() {
      _code = digits;
      _error = null;
    });

    if (digits.length == 4) {
      await _verifyCode(digits);
    }
  }

  Future<void> _verifyCode(String code) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    final state = AppScope.read(context);

    try {
      final flow = widget.flow;
      if (flow != null) {
        switch (flow.kind) {
          case CodeFlowKind.register:
            await state.confirmRegistration(
              phone: flow.phone,
              code: code,
              name: flow.name ?? '',
              password: flow.password ?? '',
              termsVersion: flow.termsVersion ?? '',
            );
          case CodeFlowKind.passwordReset:
            await state.confirmPasswordReset(
              phone: flow.phone,
              code: code,
              password: flow.password ?? '',
            );
          case CodeFlowKind.proRegister:
            await state.verifyAndLogin(
              flow.phone,
              code,
              name: flow.name,
            );
        }
      } else {
        await state.verifyAndLogin(
          widget.targetPhone ?? '',
          code,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        widget.nextRoute,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorText(e);
        _code = '';
        _codeController.clear();
      });
      _focusCode();
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resend() async {
    if (_isResending || _resendIn > 0) return;
    setState(() => _isResending = true);
    final state = AppScope.read(context);
    final phone = widget.targetPhone ?? '';

    try {
      final purpose = widget.flow?.kind == CodeFlowKind.passwordReset
          ? 'password_reset'
          : (widget.flow?.kind == CodeFlowKind.register ? 'register' : null);
      final resp = await state.sendOtp(phone, purpose: purpose);
      final resendAfter = resp['resend_after'];
      final seconds = resendAfter is num ? resendAfter.toInt() : 60;
      _startResendCountdown(seconds);
      if (mounted) {
        setState(() {
          _error = null;
          _code = '';
          _codeController.clear();
        });
        _focusCode();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = _errorText(e));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _onGoBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(25.0, 24.0, 25.0, 0.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.codeTitle,
                      style: figStyle(
                        fontSize: 21.0,
                        family: FigFont.display,
                        weight: 600,
                        height: 1.0,
                        color: const Color(0xff000000),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      l10n.codeSubtitle(_prettyPhone),
                      style: figStyle(
                        fontSize: 15.0,
                        family: FigFont.display,
                        weight: 500,
                        height: 1.333,
                        color: _muted,
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
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            l10n.back,
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
                    const SizedBox(height: 16.0),
                  ],
                ),
              ),
            ),
            const AuthBottomIllustration(),
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
    final l10n = context.l10n;
    final blocked = secondsLeft > 0 || busy;
    final label = busy
        ? l10n.codeSending
        : (secondsLeft > 0
            ? l10n.resendCodeIn(secondsLeft)
            : l10n.resendCode);

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
