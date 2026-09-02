// Регистрация обычного пользователя — по кадру 07 «Добро пожаловать · 2».
//
// Экран собран настоящими виджетами, а не наложением на растр кадра, и вот
// почему. Кадр 07 свёрстан потоком: заголовок, описание и колонка полей идут
// друг за другом с отступами. Высота описания зависит от шрифта, поэтому
// поля кадра стоят на разной высоте в тестовом окружении и на устройстве —
// разница доходила до сотни точек. Наложения были прибиты к координатам,
// снятым в тестах, и на реальном экране разъезжались с рисунком: пользователь
// видел два поля телефона и два поля имени, нарисованные поля не реагировали
// на нажатие, а оранжевую кнопку «Далее» закрывала белая подложка соседнего
// поля — нажимать было буквально не на что.
//
// Оформление повторяет кадр: заголовок 21/600, описание 15/500 серым, поля
// высотой 36 с радиусом 10, оранжевая кнопка 324×36.
//
// Порядок такой: здесь собираются телефон, имя и пароль, сервер высылает код,
// экран кода подтверждает номер — и только тогда заводится аккаунт с паролем.
// Дальше человек входит по паролю, без SMS.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/api_exceptions.dart';
import '../../data/code_flow.dart';
import '../../data/wait_time.dart';
import '../../fig/fig.dart';
import '../fig_controls.dart';
import '../widgets/consent_row.dart';

/// Ключи для тестов и отладки: искать поля по порядку в дереве ненадёжно.
const Key kRegisterPhoneFieldKey = Key('registration_phone_field');
const Key kRegisterNameFieldKey = Key('registration_name_field');
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

  /// Версия соглашения приходит с сервера. Принять документ, которого нет,
  /// нельзя — поэтому без него регистрация не начинается.
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

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed(Routes.welcome);
    }
  }

  Future<void> _onNext() async {
    if (_isSending) return;

    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final state = AppScope.read(context);
    final version = state.termsVersion;

    if (phone.isEmpty || name.isEmpty || password.isEmpty) {
      _complain('Заполните телефон, имя и пароль');
      return;
    }
    if (version == null) {
      _complain(_termsError ?? 'Соглашение недоступно. Попробуйте позже.');
      return;
    }
    if (!_accepted) {
      _complain('Примите соглашение об обработке персональных данных');
      return;
    }

    setState(() => _isSending = true);
    try {
      final otp = await state.startRegistration(phone);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xffffffff),
        // Форма прокручивается, поэтому клавиатуре можно подвинуть содержимое:
        // кнопка «Далее» не должна оставаться под ней на невысоких экранах.
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25.0, 24.0, 25.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Полоса шага — как в макете: оранжевый отрезок на светлом фоне.
                const _StepBar(progress: 0.18),
                const SizedBox(height: 40.0),
                Text(
                  'Добро пожаловать!',
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
                  'Зарегистрируйтесь по номеру телефона. Мы пришлём код '
                  'подтверждения, а войти потом можно будет по паролю.',
                  style: figStyle(
                    fontSize: 15.0,
                    family: FigFont.display,
                    weight: 500,
                    height: 1.333,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 28.0),
                _Field(
                  fieldKey: kRegisterPhoneFieldKey,
                  controller: _phoneController,
                  hint: 'Номер телефона (с WhatsApp)',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12.0),
                _Field(
                  fieldKey: kRegisterNameFieldKey,
                  controller: _nameController,
                  hint: 'Имя',
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 12.0),
                _Field(
                  fieldKey: kRegisterPasswordFieldKey,
                  controller: _passwordController,
                  hint: 'Пароль',
                  keyboardType: TextInputType.visiblePassword,
                ),
                const SizedBox(height: 12.0),
                ConsentRow(
                  key: kRegisterConsentKey,
                  value: _accepted,
                  loading: _loadingTerms,
                  error: _termsError,
                  onChanged: (value) => setState(() => _accepted = value),
                ),
                const SizedBox(height: 12.0),
                _PrimaryButton(
                  buttonKey: kRegisterSubmitKey,
                  label: 'Далее',
                  busy: _isSending,
                  onTap: _onNext,
                ),
                const SizedBox(height: 20.0),
                Center(
                  child: _Link(
                    label: 'У меня уже есть аккаунт',
                    onTap: _onBack,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Полоса прогресса шага из макета: 7 в высоту, скруглённая, оранжевый отрезок.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.progress});

  /// Доля заполнения от 0 до 1.
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

/// Поле формы: та же плитка, что в кадре, — высота 36, радиус 10.
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
    // Ширину берём у фактических ограничений, а не у размера экрана и не из
    // 375-точечного макета: иначе поле вылезает за край на узких устройствах.
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

/// Кнопка кадра: 36 в высоту, радиус 10, текст 17/600 белым.
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
      // Пока запрос в пути, повторное нажатие не проходит — второй SMS-код
      // сбросил бы первый и упёрся бы в лимит на стороне сервера.
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

/// Текстовая ссылка тем же оранжевым, что и на остальных экранах входа.
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap});

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
