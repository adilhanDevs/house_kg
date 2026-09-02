// Страница регистрации исполнителя / собственника (Frame 56).
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/api_exceptions.dart';
import '../../data/code_flow.dart';
import '../fig_controls.dart';
import '../widgets/consent_row.dart';

class ProSignupPage extends StatefulWidget {
  const ProSignupPage({super.key});

  @override
  State<ProSignupPage> createState() => _ProSignupPageState();
}

class _ProSignupPageState extends State<ProSignupPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _iinController = TextEditingController();

  bool _accepted = false;
  bool _loadingTerms = true;
  String? _termsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTerms());
  }

  /// Согласие на обработку ПДн нужно и исполнителю: сервер не заведёт аккаунт
  /// без версии принятого документа.
  Future<void> _loadTerms() async {
    final state = AppScope.read(context);
    try {
      await state.loadTermsDocument();
      if (!mounted) return;
      setState(() {
        _loadingTerms = false;
        _termsError =
            state.termsVersion == null ? 'Соглашение недоступно. Попробуйте позже.' : null;
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

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _iinController.dispose();
    super.dispose();
  }

  void _onNext() async {
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final iin = _iinController.text.trim();

    if (phone.isEmpty || name.isEmpty || password.isEmpty || iin.isEmpty) {
      _complain('Пожалуйста, заполните все поля');
      return;
    }

    final state = AppScope.read(context);
    final version = state.termsVersion;
    if (version == null) {
      _complain(_termsError ?? 'Соглашение недоступно. Попробуйте позже.');
      return;
    }
    if (!_accepted) {
      _complain('Примите соглашение об обработке персональных данных');
      return;
    }

    try {
      await state.registerPro(phone, name, password, iin);
      if (mounted) {
        // Код выписан с целью pro_register — с ней же его и проверяем,
        // иначе сервер ищет код входа и не находит.
        Navigator.of(context).pushNamed(
          Routes.proCode,
          arguments: CodeFlow(
            kind: CodeFlowKind.proRegister,
            phone: phone,
            name: name,
            password: password,
            termsVersion: version,
          ),
        );
      }
    } catch (e) {
      if (mounted) _complain(_errorText(e));
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
      frame: frame('56'),
      background: const Color(0xffffffff),
      overlays: [
        // Поле ввода Номер телефона (с WhatsApp)
        Positioned(
          left: 25.0,
          top: 184.0,
          child: FigInputBox(
            width: 324.0,
            controller: _phoneController,
            hint: 'Номер телефона (с WhatsApp)',
            keyboardType: TextInputType.phone,
          ),
        ),
        // Поле ввода Ваше имя
        Positioned(
          left: 25.0,
          top: 232.0,
          child: FigInputBox(
            width: 324.0,
            controller: _nameController,
            hint: 'Ваше имя',
            keyboardType: TextInputType.name,
          ),
        ),
        // Поле ввода Пароль
        Positioned(
          left: 25.0,
          top: 280.0,
          child: FigInputBox(
            width: 324.0,
            controller: _passwordController,
            hint: 'Пароль',
            keyboardType: TextInputType.visiblePassword,
          ),
        ),
        // Поле ввода ИИН
        Positioned(
          left: 25.0,
          top: 328.0,
          child: FigInputBox(
            width: 324.0,
            controller: _iinController,
            hint: 'ИИН',
            keyboardType: TextInputType.number,
          ),
        ),
        // Кнопка «Далее» — она в кадре под четырьмя полями: те идут с 184-й
        // через 48 pt, поэтому кнопка начинается на 376-й. Зона по размеру
        // кнопки, иначе она накрывала бы «Пароль» и «ИИН» и в них было бы
        // не написать.
        FigZone(
          25.0, 376.0, 324.0, 36.0,
          label: 'Далее',
          onTap: _onNext,
        ),
        Positioned(
          left: 25.0,
          top: 424.0,
          width: 324.0,
          child: ConsentRow(
            value: _accepted,
            loading: _loadingTerms,
            error: _termsError,
            onChanged: (value) => setState(() => _accepted = value),
          ),
        ),
      ],
      ),
    );
  }
}
