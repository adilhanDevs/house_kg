import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../widgets/finik_payment_sheet.dart';

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

  Future<void> _onNext(BuildContext context, AppState state) async {
    if (_step == 1) {
      setState(() => _step = 2);
    } else if (_step == 2) {
      setState(() => _step = 3);
    } else if (_step == 3) {
      await _startPayment(context, state);
    } else {
      _finishFlow(context, state);
    }
  }

  int get _enteredAmount {
    final parsed = int.tryParse(_amountController.text.trim()) ?? 0;
    return parsed > 0 ? parsed : 12000;
  }

  /// Открывает оплату. Экран «Спасибо» показывается только после того, как
  /// бэкенд подтвердил зачисление — раньше сюда попадали по нажатию на макет.
  Future<void> _startPayment(BuildContext context, AppState state) async {
    final amount = _enteredAmount;
    state.setTopupAmount(amount);

    final paid = await showFinikPaymentSheet(
      context: context,
      amountSom: amount,
      purposeTitle: 'Пополнение кошелька House KG',
      state: state,
    );

    if (!mounted) return;
    if (paid == true) {
      setState(() => _step = 5);
    }
  }

  void _finishFlow(BuildContext context, AppState state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Кошелёк пополнен на ${state.topupAmount} сом'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xff4dba17),
      ),
    );

    state.resetTopup();
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.home,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    // Кадр 44 (поп-ап банков из макета) больше не показывается: выбор банка
    // и оплата живут в реальном платёжном окне.
    final String frameId = switch (_step) {
      1 => '41',
      2 => '42',
      3 => '43',
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

        // Кнопка [ Далее ] (Y=711)
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

        if (state.isTopupLoading)
          Positioned.fill(
            child: Container(
              color: const Color(0x66000000),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xffea812e)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
