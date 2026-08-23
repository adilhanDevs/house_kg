import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../fig_controls.dart';

class AdPromoPage extends StatefulWidget {
  const AdPromoPage({super.key});

  @override
  State<AdPromoPage> createState() => _AdPromoPageState();
}

class _AdPromoPageState extends State<AdPromoPage> {
  bool _useTarget = true;
  bool _useClientBase = false;
  bool _useWhatsappBase = false;
  bool _useBricks = false;

  int _selectedDay = 1;
  final TextEditingController _sumController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();

  @override
  void dispose() {
    _sumController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _onNext() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Объявление успешно опубликовано!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xffea812e),
      ),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xffea812e);

    return FigStage(
      frame: frame('50'),
      background: const Color(0xffffffff),
      overlays: [
        // Кнопка [ Пополнение кошелька ] -> ведёт на /wallet/topup
        Positioned(
          left: 25.0,
          top: 235.0,
          width: 155.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.topup),
          ),
        ),

        // Кнопка [ Списать кирпичи ]
        Positioned(
          left: 190.0,
          top: 235.0,
          width: 155.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _useBricks = !_useBricks),
          ),
        ),

        // Интерактивное поле «Введите сумму»
        Positioned(
          left: 23.0,
          top: 304.0,
          width: 139.0,
          height: 34.0,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xffffffff),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _sumController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Color(0xff000000)),
              decoration: const InputDecoration(
                hintText: 'Введите сумму',
                hintStyle: TextStyle(fontSize: 13.0, color: Color(0xff7d7d7d)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        // Интерактивные чипы дней и поле «Введите значение»
        Positioned(
          left: 23.0,
          top: 375.0,
          width: 325.0,
          height: 32.0,
          child: Row(
            children: [
              ...List.generate(5, (i) {
                final day = i + 1;
                final isSel = _selectedDay == day;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                      _daysController.clear();
                    });
                  },
                  child: Container(
                    width: 30.0,
                    height: 30.0,
                    margin: const EdgeInsets.only(right: 4.0),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xfffdf1e8) : const Color(0xffffffff),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: isSel ? orangeColor : const Color(0xffe5e5ea),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        color: isSel ? orangeColor : const Color(0xff7d7d7d),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4.0),
              Expanded(
                child: Container(
                  height: 30.0,
                  decoration: BoxDecoration(
                    color: const Color(0xffffffff),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        setState(() => _selectedDay = 0);
                      }
                    },
                    style: const TextStyle(fontSize: 12.0, color: Color(0xff000000)),
                    decoration: const InputDecoration(
                      hintText: 'Введите значение',
                      hintStyle: TextStyle(fontSize: 12.0, color: Color(0xff7d7d7d)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Тумблер «Использовать точное продвижение» (Y=424)
        Positioned(
          left: 315.0,
          top: 424.0,
          child: FigToggle(
            value: _useTarget,
            label: 'Использовать точное продвижение',
            onChanged: (val) => setState(() => _useTarget = val),
          ),
        ),

        // Тумблер «Использовать клиентскую базу» (Y=447)
        Positioned(
          left: 315.0,
          top: 447.0,
          child: FigToggle(
            value: _useClientBase,
            label: 'Использовать клиентскую базу',
            onChanged: (val) => setState(() => _useClientBase = val),
          ),
        ),

        // Тумблер «Использовать Whatsapp базу» (Y=470)
        Positioned(
          left: 315.0,
          top: 470.0,
          child: FigToggle(
            value: _useWhatsappBase,
            label: 'Использовать Whatsapp базу',
            onChanged: (val) => setState(() => _useWhatsappBase = val),
          ),
        ),

        // Кнопка «Далее» (Завершить создание и опубликовать)
        FigZone(
          25.0,
          720.0,
          325.0,
          48.0,
          label: 'Далее',
          onTap: _onNext,
        ),
      ],
    );
  }
}
