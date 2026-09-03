import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/api_client.dart';
import '../../fig/fig.dart';
import '../fig_controls.dart';
import '../widgets/finik_payment_flow.dart';

/// Какое действие отправляет объявление: публикация с продвижением или без.
enum _PromoAction { next, skip }

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

  /// Предрасчёт с сервера: цена продвижения и баланс кошелька. Пока не
  /// загружен, экран не показывает выдуманных чисел.
  Map<String, dynamic>? _pricing;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = const Uuid().v4();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPricing());
  }

  /// Тянет стоимость продвижения на выбранное число дней.
  Future<void> _loadPricing() async {
    if (!mounted) return;
    final state = AppScope.read(context);
    final days = int.tryParse(_daysController.text.trim()) ?? _selectedDay;
    try {
      final pricing = await state.apiClient.getPromotionPricing(days: days > 0 ? days : 1);
      if (mounted) setState(() => _pricing = pricing);
    } catch (e) {
      debugPrint('Не удалось получить стоимость продвижения: \$e');
    }
  }

  int get _promotionCost => (_pricing?['total_cost'] as num?)?.toInt() ?? 0;

  int get _walletBalance =>
      (_pricing?['balance'] as num?)?.toInt() ?? AppScope.read(context).walletBalance;

  @override
  void dispose() {
    _sumController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  /// Какое из двух действий сейчас выполняется.
  ///
  /// Раньше здесь стоял общий флаг, а индикатор жил только на «Далее» — и
  /// нажатие «Продолжить без продвижения» крутило колесо на соседней кнопке.
  /// Человек не понимал, что именно делает приложение.
  _PromoAction? _submitting;

  bool get _isPublishing => _submitting != null;

  /// Списывает кирпичи за продвижение. При нехватке открывает пополнение
  /// через Finik на недостающую сумму и повторяет попытку.
  ///
  /// Ключ идемпотентности один на обе попытки: повторный запрос с тем же
  /// ключом не спишет дважды.
  Future<bool> _promote(AppState state, String slug, int days) async {
    try {
      await state.apiClient.promoteListing(slug, days, _idempotencyKey);
      return true;
    } on ApiException catch (e) {
      if (!e.isInsufficientFunds || !mounted) {
        if (mounted) _showPromotionError(e.message);
        return false;
      }

      // 1 сом = 1 кирпич при пополнении (§1.2 ТЗ), поэтому недостающие
      // кирпичи — это и есть сумма к оплате.
      final missing = e.missingBricks ?? (_promotionCost - _walletBalance);
      if (missing <= 0) {
        _showPromotionError(e.message);
        return false;
      }

      final paid = await startFinikPayment(
        context: context,
        amountSom: missing,
        purposeTitle: 'Пополнение на продвижение объявления',
        state: state,
      );
      if (paid != true || !mounted) return false;

      await state.fetchWalletBalance();
      try {
        await state.apiClient.promoteListing(slug, days, _idempotencyKey);
        return true;
      } catch (retryError) {
        if (mounted) {
          _showPromotionError(
            retryError is ApiException ? retryError.message : retryError.toString(),
          );
        }
        return false;
      }
    } catch (e) {
      if (mounted) _showPromotionError(e.toString());
      return false;
    }
  }

  void _showPromotionError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Продвижение не оплачено: $message'),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xffd93025),
      ),
    );
  }

  Future<void> _publishListing({
    required bool withPromo,
    _PromoAction action = _PromoAction.next,
  }) async {
    // Обе кнопки заперты на время отправки: второе нажатие не должно
    // отправить объявление дважды.
    if (_isPublishing) return;
    setState(() => _submitting = action);
    final state = AppScope.read(context);
    final slug = state.draftSlug ?? 'draft-slug';
    try {
      await state.apiClient.publishListing(slug);
      state.resetDraft();

      // Продвижение оплачивается кирпичами. Если их не хватает, предлагаем
      // пополнить кошелёк через Finik и повторяем списание — молча
      // проглатывать ошибку нельзя, иначе экран рапортует об успехе, которого
      // не было.
      var promoted = false;
      if (withPromo) {
        final days = int.tryParse(_daysController.text.trim()) ?? _selectedDay;
        promoted = await _promote(state, slug, days);
        if (!promoted && mounted) {
          // Объявление опубликовано, продвижение — нет. Так и говорим.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Объявление опубликовано, но продвижение не оплачено'),
              duration: Duration(seconds: 3),
              backgroundColor: Color(0xffd93025),
            ),
          );
          Navigator.of(context).pushReplacementNamed(Routes.adPreview, arguments: slug);
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(promoted
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
        // Сбрасываем и после ошибки: обе кнопки должны вернуться.
        setState(() => _submitting = null);
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

    // Кадр макета не знает про системную навигацию Android, и нижние кнопки
    // упирались в неё: на 412x915 «Продолжить без продвижения» кончалась в
    // 20 px от края, а жестовая полоса занимает больше. Поднимаем блок
    // действий ровно на величину этой полосы, пересчитанную в координаты
    // макета — раскладка остаётся прежней, кнопки перестают уходить под неё.
    final stageScale = MediaQuery.sizeOf(context).width / kDesignWidth;
    final safeLift = stageScale > 0 ? bottomSafeInset(context) / stageScale : 0.0;

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
                  // Настоящий баланс и цена: раньше здесь стояло зашитое
                  // «8938 кирпичей», одинаковое у всех пользователей.
                  Text(
                    _pricing == null
                        ? 'Ваш баланс: $_walletBalance кирпичей'
                        : 'Баланс: $_walletBalance · продвижение: $_promotionCost кирпичей',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                      color: _pricing != null && _walletBalance < _promotionCost
                          ? const Color(0xffd93025)
                          : const Color(0xff4dba17),
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
                      _loadPricing();
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
        Positioned(
          left: 20.0,
          top: 710.0 - safeLift,
          width: 335.0,
          height: 60.0,
          child: const ColoredBox(color: Color(0xffffffff)),
        ),

        // Кнопка «Далее» (Завершить создание и опубликовать)
        Positioned(
          left: 25.0,
          top: 690.0 - safeLift,
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
            child: _submitting == _PromoAction.next
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
          top: 744.0 - safeLift,
          width: 325.0,
          height: 44.0,
          child: OutlinedButton(
            onPressed: _isPublishing
                ? null
                : () => _publishListing(
                      withPromo: false,
                      action: _PromoAction.skip,
                    ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: orangeColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: _submitting == _PromoAction.skip
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: orangeColor,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
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
