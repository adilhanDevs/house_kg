import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/api_client.dart';
import '../../fig/fig.dart';
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
  
  late final String _idempotencyKey;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = const Uuid().v4();
  }

  @override
  void dispose() {
    _sumController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  bool _isPublishing = false;

  Future<void> _publishListing({required bool withPromo}) async {
    setState(() => _isPublishing = true);
    final state = AppScope.read(context);
    final slug = state.draftSlug ?? 'draft-slug';
    try {
      await state.apiClient.publishListing(slug);
      
      if (withPromo) {
        final days = int.tryParse(_daysController.text.trim()) ?? _selectedDay;
        try {
          await state.apiClient.promoteListing(slug, days, _idempotencyKey);
        } catch (pe) {
          debugPrint('Promotion warning: $pe');
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(withPromo 
                ? 'Объявление успешно опубликовано и продвинуто!' 
                : 'Объявление успешно опубликовано!'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xffea812e),
          ),
        );
        Navigator.of(context).pushReplacementNamed(
          Routes.adPreview,
          arguments: slug,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is ApiException ? e.message : e.toString();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Публикация объявления'),
            content: Text(errorMsg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushNamed(Routes.tariffs);
                },
                child: const Text('Сменить тариф', style: TextStyle(color: Color(0xfff5222d), fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacementNamed(
                    Routes.adPreview,
                    arguments: slug,
                  );
                },
                child: const Text('К предпросмотру', style: TextStyle(color: Color(0xffea812e))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffea812e)),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Понятно', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Future<void> _onNext() async {
    if (_useBricks) {
      await _publishListing(withPromo: true);
    } else {
      await _publishListing(withPromo: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xffea812e);

    final sumText = _sumController.text.trim().replaceAll(' ', '');
    final int sumValue = int.tryParse(sumText) ?? 0;

    return FigStage(
      frame: frame(_useBricks ? '51' : '50'),
      background: const Color(0xffffffff),
      overlays: [
        // 1. Белая маска под вкладками бюджетирования (Y=226..416)
        const Positioned(
          left: 0.0,
          right: 0.0,
          top: 226.0,
          height: 190.0,
          child: ColoredBox(color: Color(0xffffffff)),
        ),

        // 2. Вкладки бюджетирования (Y=224)
        Positioned(
          left: 20.0,
          top: 224.0,
          width: 335.0,
          height: 38.0,
          child: Row(
            children: [
              // Левая кнопка «Списать кирпичи»
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _useBricks = true);
                  },
                  child: Container(
                    height: 38.0,
                    decoration: BoxDecoration(
                      color: _useBricks ? orangeColor : const Color(0xffffffff),
                      borderRadius: BorderRadius.circular(8.0),
                      border: _useBricks ? null : Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FigBox(
                          width: 24.0,
                          height: 16.0,
                          bgImage: FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
                        ),
                        const SizedBox(width: 4.0),
                        Flexible(
                          child: Text(
                            'Списать кирпичи',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: _useBricks ? const Color(0xffffffff) : const Color(0xff7d7d7d),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              // Правая кнопка «Пополнение кошелька»
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _useBricks = false);
                  },
                  child: Container(
                    height: 38.0,
                    decoration: BoxDecoration(
                      color: !_useBricks ? orangeColor : const Color(0xffffffff),
                      borderRadius: BorderRadius.circular(8.0),
                      border: !_useBricks ? null : Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Пополнение кошелька',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: !_useBricks ? const Color(0xffffffff) : const Color(0xff7d7d7d),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Разделительная линия под кнопками (Y=274)
        Positioned(
          left: 20.0,
          top: 274.0,
          width: 335.0,
          height: 1.0,
          child: Container(color: const Color(0xffe5e5ea)),
        ),

        // 4. Блок баланса / суммы (Y=286)
        if (!_useBricks)
          // Пополнение кошелька: [Введите сумму] + [+X Кирпичей]
          Positioned(
            left: 20.0,
            top: 286.0,
            width: 335.0,
            height: 36.0,
            child: Row(
              children: [
                Container(
                  width: 125.0,
                  height: 36.0,
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
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Color(0xff000000)),
                    decoration: const InputDecoration(
                      hintText: 'Введите сумму',
                      hintStyle: TextStyle(fontSize: 12.0, color: Color(0xff7d7d7d)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 6.0),
                Expanded(
                  child: Container(
                    height: 36.0,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xffe8f6e4),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: const Color(0xffc5e8bc), width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const FigBox(
                          width: 22.0,
                          height: 15.0,
                          bgImage: FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
                        ),
                        const SizedBox(width: 4.0),
                        Flexible(
                          child: Text(
                            '+$sumValue Кирпичей',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff4dba17),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          // Списать кирпичи: [Ваш баланс: 8938 кирпичей]
          Positioned(
            left: 20.0,
            top: 286.0,
            height: 36.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: const Color(0xffe8f6e4),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: const Color(0xffc5e8bc), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const FigBox(
                    width: 24.0,
                    height: 16.0,
                    bgImage: FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
                  ),
                  const SizedBox(width: 6.0),
                  const Text(
                    'Ваш баланс: 8938 кирпичей',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff4dba17),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 5. Заголовок «Количество дней» (Y=338)
        const Positioned(
          left: 20.0,
          top: 338.0,
          child: Text(
            'Количество дней',
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: Color(0xff000000),
            ),
          ),
        ),

        // 6. Интерактивные чипы дней и поле «Введите значение» (Y=368)
        Positioned(
          left: 20.0,
          top: 368.0,
          width: 335.0,
          height: 34.0,
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

        // Маска для скрытия нарисованной на фоне кнопки "Далее"
        const Positioned(
          left: 20.0,
          top: 710.0,
          width: 335.0,
          height: 60.0,
          child: ColoredBox(color: Color(0xffffffff)),
        ),

        // Кнопка «Далее» (Завершить создание и опубликовать)
        Positioned(
          left: 25.0,
          top: 690.0,
          width: 325.0,
          height: 44.0,
          child: ElevatedButton(
            onPressed: _isPublishing ? null : _onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: orangeColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: _isPublishing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
                    'Далее',
                    style: TextStyle(
                      fontSize: 17.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),

        // Кнопка «Продолжить без продвижения»
        Positioned(
          left: 25.0,
          top: 744.0,
          width: 325.0,
          height: 44.0,
          child: OutlinedButton(
            onPressed: _isPublishing ? null : () => _publishListing(withPromo: false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: orangeColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Text(
              'Продолжить без продвижения',
              style: TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
                color: orangeColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
