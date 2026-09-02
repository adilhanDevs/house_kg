// Регистрация обычного пользователя — кадр 07 «Добро пожаловать · 2».
//
// Кадр в макете есть с самого начала, но в карте маршрутов его считали дублем
// кадра 05 (вход), поэтому кнопка «Зарегистрироваться» вела в онбординг и
// возвращала обратно на приветствие — по кругу.
//
// Порядок такой: здесь собираются телефон, имя и пароль, сервер высылает код,
// экран кода подтверждает номер — и только тогда заводится аккаунт с паролем.
// Дальше человек входит по паролю, без SMS.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/api_exceptions.dart';
import '../fig_controls.dart';

/// Что экран кода получает от регистрации, чтобы завершить её после ввода кода.
@immutable
class RegistrationDraft {
  const RegistrationDraft({
    required this.phone,
    required this.name,
    required this.password,
    required this.termsVersion,
    this.purpose = 'register',
  });

  final String phone;
  final String name;
  final String password;
  final String termsVersion;

  /// Цель кода: сервер ищет код по паре «номер + цель», и код, выписанный на
  /// регистрацию исполнителя, при проверке с целью «вход» просто не находится.
  final String purpose;
}

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
      await state.startRegistration(phone);
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        Routes.code,
        arguments: RegistrationDraft(
          phone: phone,
          name: name,
          password: password,
          termsVersion: version,
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
    // Scaffold нужен не ради оформления: SnackBar показывается через
    // ближайший зарегистрированный Scaffold, а FigStage — это Material.
    // Без него сообщения об ошибках просто не появлялись на экране.
    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      // Отступ под клавиатуру считает сама сцена.
      resizeToAvoidBottomInset: false,
      body: FigStage(
      frame: frame('07'),
      background: const Color(0xffffffff),
      overlays: [
        // Координаты полей и кнопки сняты с самого кадра, а не подобраны.
        Positioned(
          left: 25.0,
          top: 297.0,
          child: FigInputBox(
            width: 324.0,
            controller: _phoneController,
            hint: 'Номер телефона (с WhatsApp)',
            keyboardType: TextInputType.phone,
          ),
        ),
        Positioned(
          left: 25.0,
          top: 345.0,
          child: FigInputBox(
            width: 324.0,
            controller: _nameController,
            hint: 'Имя',
            keyboardType: TextInputType.name,
          ),
        ),
        Positioned(
          left: 25.0,
          top: 393.0,
          child: FigInputBox(
            width: 324.0,
            controller: _passwordController,
            hint: 'Пароль',
            keyboardType: TextInputType.visiblePassword,
          ),
        ),
        FigZone(
          25.0,
          441.0,
          324.0,
          36.0,
          label: 'Далее',
          onTap: _onNext,
        ),
        // Согласие на обработку ПДн. В макете этой строки нет: раньше клиент
        // отправлял версию соглашения сам, не спрашивая, — то есть принимал
        // документ за пользователя.
        Positioned(
          left: 25.0,
          top: 489.0,
          width: 324.0,
          child: ConsentRow(
            value: _accepted,
            loading: _loadingTerms,
            error: _termsError,
            onChanged: (value) => setState(() => _accepted = value),
          ),
        ),
        Positioned(
          left: 0.0,
          top: 560.0,
          width: 375.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: const Color(0xffffffff),
              alignment: Alignment.center,
              child: const Text(
                'У меня уже есть аккаунт',
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

/// Галка «принимаю соглашение» с ссылкой на текст.
class ConsentRow extends StatelessWidget {
  const ConsentRow({
    super.key,
    required this.value,
    required this.loading,
    required this.error,
    required this.onChanged,
  });

  final bool value;
  final bool loading;
  final String? error;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 22.0,
        child: Row(
          children: [
            SizedBox(
              width: 16.0,
              height: 16.0,
              child: CircularProgressIndicator(strokeWidth: 2.0, color: Color(0xffea812e)),
            ),
            SizedBox(width: 10.0),
            Text(
              'Загружаем соглашение…',
              style: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Text(
        error!,
        style: const TextStyle(fontSize: 13.0, color: Color(0xffd93025)),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24.0,
          height: 24.0,
          child: Checkbox(
            value: value,
            onChanged: (checked) => onChanged(checked ?? false),
            activeColor: const Color(0xffea812e),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: const Text(
              'Принимаю соглашение об обработке персональных данных',
              style: TextStyle(fontSize: 13.0, height: 1.3, color: Color(0xff1c1939)),
            ),
          ),
        ),
      ],
    );
  }
}
