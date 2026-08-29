// Страница регистрации исполнителя / собственника (Frame 56).
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../fig_controls.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, заполните все поля')),
      );
      return;
    }

    final state = AppScope.read(context);
    try {
      await state.registerPro(phone, name, password, iin);
      if (mounted) {
        Navigator.of(context).pushNamed(Routes.proCode, arguments: phone);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FigStage(
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
      ],
    );
  }
}
