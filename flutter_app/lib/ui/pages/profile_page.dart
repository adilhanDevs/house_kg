// «Ваш профиль» — кадр 15 макета с работающими строками настроек и выходом.
//
// Кнопки «Выйти из аккаунта» в макете нет: она встаёт в пустое место между
// «Настройками» и «Продать недвижимость» и повторяет размер и радиус соседней
// кнопки, только контуром и красным — как принято у необратимых действий.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import 'pro_profile_page.dart';

/// Строки «Настроек» — в кадре они одинаковой высоты и идут через 44 pt.
const double _rowLeft = 23;
const double _rowWidth = 327;
const double _rowHeight = 26;

/// «Посмотреть все» под последними уведомлениями.
const Rect _seeAll = Rect.fromLTWH(24, 314, 326, 24);

/// «Продать недвижимость».
const Rect _sell = Rect.fromLTWH(101, 698, 185.3, 30);

/// «Выйти из аккаунта» — своя кнопка на месте, которое макет оставил пустым.
const Rect _logOut = Rect.fromLTWH(101, 652, 185.3, 30);

const Color _danger = Color(0xffd93025);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _confirmLogOut(BuildContext context) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xffffffff),
        surfaceTintColor: Colors.transparent,
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Избранное и фильтры этого сеанса будут забыты.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (leave != true) return;
    await state.logout();
    if (mounted) {
      navigator.pushNamedAndRemoveUntil(Routes.welcome, (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xffffffff),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xffea812e)),
        ),
      );
    }
    if (state.pro || state.isPro) {
      return const ProProfilePage();
    }
    return FigStage(
      frame: frame('15'),
      bottomBar: const AppTabBar(active: 4),
      overlays: [
        FigZone(
          _seeAll.left, _seeAll.top, _seeAll.width, _seeAll.height,
          label: 'Посмотреть все уведомления',
          onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
        ),
        FigZone(
          _rowLeft, 381, _rowWidth, _rowHeight,
          label: 'Вам понравилось',
          onTap: () => Navigator.of(context).pushNamed(Routes.favourites),
        ),
        FigZone(
          _rowLeft, 425, _rowWidth, _rowHeight,
          label: 'Тарифы',
          onTap: () => Navigator.of(context).pushNamed(Routes.tariffs),
        ),
        FigZone(
          _rowLeft, 469, _rowWidth, _rowHeight,
          label: 'Уведомление',
          onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
        ),
        FigZone(
          _rowLeft, 513, _rowWidth, _rowHeight,
          label: 'Аккаунт',
          onTap: () => Navigator.of(context).pushNamed(Routes.account),
        ),
        FigZone(
          _rowLeft, 557, _rowWidth, _rowHeight,
          label: 'Служба поддержки',
          onTap: () => Navigator.of(context).pushNamed(Routes.support),
        ),

        // Маска для закрашивания статичной плашки макета и линии (Y=594)
        const Positioned(
          left: 150.0,
          top: 594.0,
          width: 225.0,
          height: 48.0,
          child: ColoredBox(color: Color(0xffffffff)),
        ),

        // Полноценная пересверстанная кнопка-переключатель языка (Y=605)
        const Positioned(
          left: 175.0,
          top: 605.0,
          child: LanguageToggleWidget(),
        ),
        // Клик по кнопке макета «Продать недвижимость» (Y=696)
        FigZone(
          101.0, 696.0, 185.3, 30.0,
          label: 'Продать недвижимость',
          onTap: () => Navigator.of(context).pushNamed(Routes.ad),
        ),

        // На месте «Служба безопасности» (Y=645) размещаем «Выйти из аккаунта»
        Positioned(
          left: _rowLeft,
          top: 645.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _confirmLogOut(context),
            child: Container(
              width: _rowWidth,
              height: 40.0,
              color: const Color(0xffffffff),
              child: Row(
                children: [
                  Container(
                    width: 24.0,
                    height: 24.0,
                    decoration: BoxDecoration(
                      color: const Color(0xfffde8e8),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.logout,
                      size: 16.0,
                      color: _danger,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  const Text(
                    'Выйти из аккаунта',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      color: _danger,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14.0,
                    color: Color(0xffc7c7cc),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LanguageToggleWidget extends StatefulWidget {
  final String initialLang;
  final ValueChanged<String>? onChanged;

  const LanguageToggleWidget({
    super.key,
    this.initialLang = 'ru',
    this.onChanged,
  });

  @override
  State<LanguageToggleWidget> createState() => _LanguageToggleWidgetState();
}

class _LanguageToggleWidgetState extends State<LanguageToggleWidget> {
  late String _selectedLang;

  @override
  void initState() {
    super.initState();
    _selectedLang = widget.initialLang;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170.0,
      height: 28.0,
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: const Color(0xffe3e3e8),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _selectedLang = 'ru');
                widget.onChanged?.call('ru');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _selectedLang == 'ru' ? const Color(0xff78787c) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Русский',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _selectedLang == 'ru' ? FontWeight.bold : FontWeight.w500,
                    color: _selectedLang == 'ru' ? Colors.white : const Color(0xff7d7d7d),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _selectedLang = 'kg');
                widget.onChanged?.call('kg');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _selectedLang == 'kg' ? const Color(0xff78787c) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Кыргызский',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _selectedLang == 'kg' ? FontWeight.bold : FontWeight.w500,
                    color: _selectedLang == 'kg' ? Colors.white : const Color(0xff7d7d7d),
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
