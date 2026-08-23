import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../app_tab_bar.dart';

class ProProfilePage extends StatefulWidget {
  const ProProfilePage({super.key});

  @override
  State<ProProfilePage> createState() => _ProProfilePageState();
}

class _ProProfilePageState extends State<ProProfilePage> {
  String _selectedLang = 'ru';

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

        // Кнопка «Выйти из аккаунта» в свободном белом поле под всеми настройками (Y=1190)
        Positioned(
          left: 87.0,
          top: 1190.0,
          width: 200.0,
          height: 38.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _confirmLogOut(context),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xffffffff),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: dangerColor, width: 1.0),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Выйти из аккаунта',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  color: dangerColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
