import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import 'profile_page.dart';

import '../../data/listings.dart';
import 'category_page.dart';

import '../../data/listing_repository.dart';
import '../object_card.dart';

class ProProfilePage extends StatefulWidget {
  const ProProfilePage({super.key});

  @override
  State<ProProfilePage> createState() => _ProProfilePageState();
}

class _ProProfilePageState extends State<ProProfilePage> {
  late final ListingRepository _repository;
  List<Listing> _listings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _repository = ListingRepository(state.apiClient);
    _loadListings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppScope.read(context).pro = true;
      }
    });
  }

  Future<void> _loadListings() async {
    try {
      final response = await _repository.getListings();
      if (mounted) {
        setState(() {
          _listings = response.results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final state = AppScope.of(context);

    return FigStage(
      frame: frame('38'),
      bottomBar: const AppTabBar(active: 4),
      background: const Color(0xfffefefe),
      overlays: [
        // Табы категорий (Y=318): Новостройки, Квартиры, Коммерция
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

        // Карточки объектов продавца (Y=480)
        Positioned(
          left: 0,
          top: 480.0,
          right: 0,
          height: 220.0,
          child: Container(
            color: const Color(0xfffefefe),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xffea812e)))
                : (_listings.isEmpty
                    ? const Center(child: Text('Нет активных объектов', style: TextStyle(color: Color(0xff7d7d7d))))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Row(
                          children: _listings.map((l) => Padding(
                            padding: const EdgeInsets.only(right: 15.0),
                            child: ObjectCard(
                              listing: l,
                              favourite: state.isFavourite(l.id),
                              onTap: () => Navigator.of(context).pushNamed(
                                Routes.adPreview,
                                arguments: l.slug,
                              ),
                              onFavourite: () => state.toggleFavourite(l.id),
                            ),
                          )).toList(),
                        ),
                      )),
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

        // Белая маска поверх баланса на макете
        Positioned(
          left: 25.0,
          top: 725.0,
          width: 200.0,
          height: 55.0,
          child: ColoredBox(color: const Color(0xffffffff)),
        ),

        // Настоящий баланс кошелька
        Positioned(
          left: 25.0,
          top: 725.0,
          width: 200.0,
          height: 55.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.history),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${state.walletBalance} кирпичей',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffea812e),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2.0),
                const Text(
                  'Баланс',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: Color(0x993c3c43),
                    height: 1.1,
                  ),
                ),
              ],
            ),
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

        // Клик по настройке «Тарифы»
        Positioned(
          left: 25.0,
          top: 960.0,
          width: 325.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.tariffs),
          ),
        ),

        // Клик по настройке «Уведомление»
        Positioned(
          left: 25.0,
          top: 1004.0,
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
          top: 1048.0,
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
          top: 1092.0,
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
          top: 1136.0,
          width: 325.0,
          height: 40.0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pushNamed(Routes.history),
          ),
        ),

        // Маска для закрашивания статичной плашки макета и линии (Y=1174)
        const Positioned(
          left: 150.0,
          top: 1174.0,
          width: 225.0,
          height: 48.0,
          child: ColoredBox(color: Color(0xffffffff)),
        ),

        // Полноценная пересверстанная кнопка-переключатель языка (Y=1184)
        const Positioned(
          left: 175.0,
          top: 1184.0,
          child: LanguageToggleWidget(),
        ),

        // Строка «Выйти из аккаунта» у собственника (Y=1224)
        Positioned(
          left: 25.0,
          top: 1224.0,
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
