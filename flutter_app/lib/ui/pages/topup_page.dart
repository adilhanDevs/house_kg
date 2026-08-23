import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';

class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key});

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  int _step = 1;
  final TextEditingController _amountController = TextEditingController(text: '12000');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onNext(BuildContext context, AppState state) {
    if (_step == 1) {
      setState(() => _step = 2);
    } else if (_step == 2) {
      setState(() => _step = 3);
    } else if (_step == 3) {
      setState(() => _step = 4);
    } else if (_step == 4) {
      _selectBankAndPay(context, state);
    } else {
      _finishFlow(context, state);
    }
  }

  void _selectBankAndPay(BuildContext context, AppState state) {
    final parsed = int.tryParse(_amountController.text);
    if (parsed != null && parsed > 0) {
      state.setTopupAmount(parsed);
    }
    state.commitTopup();

    setState(() {
      _step = 5;
    });
  }

  void _finishFlow(BuildContext context, AppState state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Кошелёк успешно пополнен на ${state.topupAmount} сом!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xff4dba17),
      ),
    );

    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.home,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final String frameId = switch (_step) {
      1 => '41',
      2 => '42',
      3 => '43',
      4 => '44',
      5 => '45',
      _ => '45',
    };

    return FigStage(
      frame: frame(frameId),
      background: const Color(0xffffffff),
      overlays: [
        // На шаге 3 — инпут ввода суммы (Y=654)
        if (_step == 3)
          Positioned(
            left: 24.0,
            top: 654.0,
            width: 140.0,
            height: 32.0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xffffffff),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xff7d7d7d), width: 0.8),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff000000),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: '12000',
                    hintStyle: TextStyle(fontSize: 13.0, color: Color(0xff999999)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  ),
                ),
              ),
            ),
          ),

        // На шагах 1, 2, 3 и 5 — кнопка [ Далее ] (Y=711)
        if (_step != 4)
          Positioned(
            left: 25.0,
            top: 711.0,
            width: 324.0,
            height: 54.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _onNext(context, state),
            ),
          ),

        // На шаге 4 (QR-код и поп-ап банков)
        if (_step == 4) ...[
          // Клик вверху мимо модального окна — закрытие и возврат на шаг 3
          Positioned(
            left: 0.0,
            top: 0.0,
            width: 375.0,
            height: 149.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _step = 3),
            ),
          ),
          // Крестик закрытия X в модальном окне (справа вверху модалки Y=160, X=310)
          Positioned(
            left: 300.0,
            top: 155.0,
            width: 60.0,
            height: 50.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _step = 3),
            ),
          ),
          // Клик по любому из банков — завершение оплаты и переход на Шаг 5 (Спасибо за пополнение!)
          Positioned(
            left: 30.0,
            top: 480.0,
            width: 315.0,
            height: 270.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _selectBankAndPay(context, state),
            ),
          ),
        ],
      ],
    );
  }
}
