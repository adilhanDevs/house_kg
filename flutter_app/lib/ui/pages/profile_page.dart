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

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
    state.logOut();
    navigator.pushNamedAndRemoveUntil(Routes.welcome, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
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
          label: 'Уведомление',
          onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
        ),
        // Клик по кнопке макета «Продать недвижимость» (Y=652)
        FigZone(
          101.0, 652.0, 185.3, 30.0,
          label: 'Продать недвижимость',
          onTap: () => Navigator.of(context).pushNamed(Routes.ad),
        ),

        // На месте «Служба безопасности» (Y=601) размещаем «Выйти из аккаунта»
        Positioned(
          left: _rowLeft,
          top: 601.0,
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
