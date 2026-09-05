import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_exceptions.dart';
import '../../data/code_flow.dart';
import '../../data/wait_time.dart';
import '../../fig/fig.dart';
import '../../l10n/l10n.dart';
import '../fig_controls.dart';
import '../widgets/auth_bottom_illustration.dart';
import '../widgets/consent_row.dart';

/// Ключи для тестов и отладки.
const Key kRegisterPhoneFieldKey = Key('registration_phone_field');
const Key kRegisterNameFieldKey = Key('registration_name_field');
/// Столько же требует бэкенд (MinimumLengthValidator).
const int kMinPasswordLength = 8;

const Key kRegisterPasswordFieldKey = Key('registration_password_field');
const Key kRegisterSubmitKey = Key('registration_submit_button');
const Key kRegisterConsentKey = Key('registration_consent');

const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff7d7d7d);
const Color _danger = Color(0xffd93025);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _accepted = false;
  bool _isSending = false;
  bool _loadingTerms = true;
  String? _termsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTerms());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadTerms() async {
    final state = AppScope.read(context);
    try {
      await state.loadTermsDocument();
      if (!mounted) return;
      setState(() {
        _loadingTerms = false;
        _termsError = state.termsVersion == null
            ? 'Соглашение недоступно. Попробуйте позже.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTerms = false;
        _termsError = _errorText(e);
      });
    }
  }

  String _errorText(Object error) {
    if (error is ApiException) {
      final wait = error.retryAfter;
      if (error.isThrottled && wait != null) {
        return waitMessage(wait);
      }
      return error.message;
    }
    if (error is NetworkException) {
      return error.message;
    }
    return error.toString();
  }

  void _complain(String message) {
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

  int _resendSeconds(Map<String, dynamic> response) {
    final value = response['resend_after'];
    return value is num ? value.toInt() : 60;
  }

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed(Routes.welcome);
    }
  }

  Future<void> _onNext() async {
    if (_isSending) return;
    final l10n = context.l10n;

    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;

    final state = AppScope.read(context);
    final version = state.termsVersion;

    if (phone.isEmpty || name.isEmpty || password.isEmpty) {
      _complain(l10n.fillAllFields);
      return;
    }

    // Длину проверяем здесь, а не после ввода кода из СМС: раньше короткий
    // пароль проходил дальше, человек тратил код, и отказ приходил только на
    // экране подтверждения — а возвращаться было уже некуда.
    if (password.length < kMinPasswordLength) {
      _complain(l10n.passwordTooShort);
      return;
    }

    if (version == null) {
      _complain(_termsError ?? 'Соглашение недоступно. Попробуйте позже.');
      return;
    }

    if (!_accepted) {
      _complain(l10n.consentRequired);
      return;
    }

    setState(() => _isSending = true);
    try {
      final otp = await state.startRegistration(phone, password: password, name: name);
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        Routes.code,
        arguments: CodeFlow(
          kind: CodeFlowKind.register,
          phone: phone,
          name: name,
          password: password,
          termsVersion: version,
          resendAfter: _resendSeconds(otp),
        ),
      );
    } catch (e) {
      if (mounted) _complain(_errorText(e));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xffffffff),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AuthBottomIllustration(),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        25.0, 
                        16.0, 
                        25.0, 
                        // Даём возможность скроллить контент, когда клавиатура открыта,
                        // плюс оставляем место, чтобы картинка не перекрывала самый нижний элемент.
                        MediaQuery.viewInsetsOf(context).bottom + 120.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _StepBar(progress: 0.18),
                          const SizedBox(height: 20.0),
                          Text(
                            l10n.register,
                            style: figStyle(
                              fontSize: 21.0,
                              family: FigFont.display,
                              weight: 600,
                              height: 1.0,
                              color: const Color(0xff000000),
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            l10n.welcomeSubtitle,
                            style: figStyle(
                              fontSize: 15.0,
                              family: FigFont.display,
                              weight: 500,
                              height: 1.333,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          _Field(
                            fieldKey: kRegisterPhoneFieldKey,
                            controller: _phoneController,
                            hint: l10n.phone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10.0),
                          _Field(
                            fieldKey: kRegisterNameFieldKey,
                            controller: _nameController,
                            hint: l10n.name,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 10.0),
                          _Field(
                            fieldKey: kRegisterPasswordFieldKey,
                            controller: _passwordController,
                            hint: l10n.password,
                            keyboardType: TextInputType.visiblePassword,
                          ),
                          const SizedBox(height: 10.0),
                          ConsentRow(
                            key: kRegisterConsentKey,
                            value: _accepted,
                            loading: _loadingTerms,
                            error: _termsError,
                            onChanged: (value) => setState(() => _accepted = value),
                          ),
                          const SizedBox(height: 10.0),
                          _PrimaryButton(
                            buttonKey: kRegisterSubmitKey,
                            label: l10n.next,
                            busy: _isSending,
                            onTap: _onNext,
                          ),
                          const SizedBox(height: 10.0),
                          Center(
                            child: _Link(
                              label: l10n.alreadyHaveAccount,
                              onTap: _onBack,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Полоса прогресса.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4.0),
      child: SizedBox(
        height: 7.0,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: const Color(0xffe8e8f0),
          valueColor: const AlwaysStoppedAnimation<Color>(_accent),
        ),
      ),
    );
  }
}

/// Поле ввода.
class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FigInputBox(
        key: fieldKey,
        width: constraints.maxWidth,
        controller: controller,
        hint: hint,
        keyboardType: keyboardType,
      ),
    );
  }
}

/// Основная оранжевая кнопка.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.buttonKey,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
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

/// Ссылка назад на авторизацию.
class _Link extends StatelessWidget {
  const _Link({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
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