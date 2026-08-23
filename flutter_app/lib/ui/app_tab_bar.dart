// Нижнее меню приложения — тот же таб-бар, что и в макете, но переключает
// вкладки навигатора.
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/routes.dart';
import '../app/stage.dart';
import '../fig/tab_bar.dart';

class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.active});

  /// Индекс активной вкладки — как `SCREEN_TAB` в прототипе. null на экранах,
  /// которые открывают не из меню: там подсвечивать нечего.
  final int? active;

  @override
  Widget build(BuildContext context) {
    // Под меню — полоса системной навигации Android: три кнопки или жест.
    // Белый фон уходит под неё, а само меню поднимается выше, чтобы подписи не
    // попадали под кнопки. Внутри FigStage полосу забирает себе сцена, и там
    // этот отступ нулевой.
    final bottomSafe = bottomSafeInset(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / kDesignWidth;
        return Container(
          color: const Color(0xffffffff),
          padding: EdgeInsets.only(bottom: bottomSafe),
          height: kTabBarHeight * scale + bottomSafe,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: FigTabBar.clipWidth,
              // ниже kTabBarHeight у макета пустая полоса — ClipRect её срежет
              height: kTabBarHeight,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xffffffff)),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: FigTabBar(
                        active: active,
                        // Кадр меню нарисован с выбранным «Поиском». Когда
                        // выбранной вкладки нет, гасим и её: -1 не совпадает ни
                        // с одной ячейкой, поэтому акцент снимается со всех.
                        mockupTab: active == null ? -1 : null,
                        onTap: (tab) => _go(context, tab),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _go(BuildContext context, int tab) {
    final targetRoute = kTabRoutes[tab];
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == targetRoute) return;
    // Просто открываем вкладку, не сбрасывая стек: системная кнопка «назад»
    // должна возвращать на экран, с которого пришли, а не выходить из
    // приложения.
    Navigator.of(context).pushNamed(targetRoute);
  }
}
