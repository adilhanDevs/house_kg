import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import 'profile_page.dart';

import '../../data/listings.dart';
import 'category_page.dart';

class ProProfilePage extends StatefulWidget {
  const ProProfilePage({super.key});

  @override
  State<ProProfilePage> createState() => _ProProfilePageState();
}

class _ProProfilePageState extends State<ProProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppScope.read(context).pro = true;
      }
    });
  }

  Future<void> _confirmLogOut(BuildContext context) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xffffffff),
        surfaceTintColor: Colors.transparent,
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы перейдёте в режим клиента.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти', style: TextStyle(color: Color(0xffd93025))),
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
    const dangerColor = Color(0xffd93025);

    return FigStage(
      frame: frame('38'),
      bottomBar: const AppTabBar(active: 4),
      background: const Color(0xfffefefe),
      overlays: [
        // Табы категорий (Y=318): Новостройки, Комната, Коммерция
        Positioned(
          left: 25.0,
          top: 318.0,
          width: 110.0,
          height: 30.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(
              Routes.category,
              arguments: const CategoryPageArgs(PropertyKind.newBuilding),
            ),
          ),
        ),
        Positioned(
          left: 143.0,
          top: 318.0,
          width: 82.0,
          height: 30.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(
              Routes.category,
              arguments: const CategoryPageArgs(PropertyKind.room),
            ),
          ),
        ),
        Positioned(
          left: 233.0,
          top: 318.0,
          width: 101.0,
          height: 30.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(
              Routes.category,
              arguments: const CategoryPageArgs(PropertyKind.commercial),
            ),
          ),
        ),
        // Клик по баннеру «Добавить объявление» (Y=371)
        Positioned(
          left: 25.0,
          top: 371.0,
          width: 325.0,
          height: 64.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.ad),
          ),
        ),

        // Клик по карточке объекта 1 («Технопарк») (Y=480)
        Positioned(
          left: 25.0,
          top: 480.0,
          width: 160.0,
          height: 210.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.listing),
          ),
        ),

        // Клик по карточке объекта 2 («Асанбай») (Y=480)
        Positioned(
          left: 195.0,
          top: 480.0,
          width: 160.0,
          height: 210.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.listing),
          ),
        ),

        // Клик по кнопке «Пополнить» на панели баланса (Y=725)
        Positioned(
          left: 230.0,
          top: 725.0,
          width: 120.0,
          height: 55.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.topup),
          ),
        ),

        // Клик по тексту баланса «16.700 кирпичей Баланс» -> на историю пополнений (Y=725)
        Positioned(
          left: 25.0,
          top: 725.0,
          width: 200.0,
          height: 55.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.history),
          ),
        ),

        // Клик по «Последние уведомления» / «Посмотреть все» (Y=807)
        Positioned(
          left: 25.0,
          top: 807.0,
          width: 325.0,
          height: 100.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
          ),
        ),

        // Клик по настройке «Уведомление»
        Positioned(
          left: 25.0,
          top: 960.0,
          width: 325.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
          ),
        ),

        // Клик по настройке «Аккаунт»
        Positioned(
          left: 25.0,
          top: 1004.0,
          width: 325.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.account),
          ),
        ),

        // Клик по настройке «Служба поддержки»
        Positioned(
          left: 25.0,
          top: 1048.0,
          width: 325.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.support),
          ),
        ),

        // Клик по настройке «История пополнения и трат»
        Positioned(
          left: 25.0,
          top: 1092.0,
          width: 325.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.history),
          ),
        ),

        // Маска для закрашивания статичной плашки макета и линии (Y=1130)
        const Positioned(
          left: 150.0,
          top: 1130.0,
          width: 225.0,
          height: 48.0,
          child: ColoredBox(color: Color(0xffffffff)),
        ),

        // Полноценная пересверстанная кнопка-переключатель языка (Y=1140)
        const Positioned(
          left: 175.0,
          top: 1140.0,
          child: LanguageToggleWidget(),
        ),

        // Строка «Выйти из аккаунта» у собственника (Y=1180)
        Positioned(
          left: 25.0,
          top: 1180.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _confirmLogOut(context),
            child: Container(
              width: 325.0,
              height: 44.0,
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
                      color: dangerColor,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  const Text(
                    'Выйти из аккаунта',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      color: dangerColor,
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
