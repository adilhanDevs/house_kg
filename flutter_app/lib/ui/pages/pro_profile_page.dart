import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../auth_guard.dart';
import '../../app/stage.dart';
import '../app_tab_bar.dart';
import 'profile_page.dart';

import '../../data/listings.dart';
import '../../data/listing_repository.dart';
import '../object_card.dart';
import '../widgets/profile_identity.dart';

class ProProfilePage extends StatefulWidget {
  const ProProfilePage({super.key});

  @override
  State<ProProfilePage> createState() => _ProProfilePageState();
}

class _ProProfilePageState extends State<ProProfilePage> {
  late final ListingRepository _repository;
  List<Listing> _listings = [];
  bool _isLoading = true;
  PropertyKind _selectedKind = PropertyKind.newBuilding;
  // Nullable: на вебе после hot reload поле, добавленное в живой State,
  // приходит неинициализированным, и `??` ниже это гасит.
  int? _activeCount;
  int? _soldCount;

  static const _categoryTabs = [
    (PropertyKind.newBuilding, 'Новостройки'),
    (PropertyKind.apartment, 'Квартиры'),
    (PropertyKind.commercial, 'Коммерция'),
  ];

  static String _emptyMessageForKind(PropertyKind kind) => switch (kind) {
    PropertyKind.newBuilding => 'Нет новостроек',
    PropertyKind.apartment => 'Нет квартир',
    PropertyKind.commercial => 'Нет коммерческих объектов',
    PropertyKind.house => 'Нет домов',
    PropertyKind.plot => 'Нет участков',
    PropertyKind.room => 'Нет комнат',
  };

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _repository = ListingRepository(state.apiClient);
    _loadListings();
    state.fetchProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppScope.read(context).pro = true;
      }
    });
  }

  Future<void> _loadListings() async {
    try {
      // Профиль продавца показывает только его собственные объекты —
      // все статусы, включая черновики и объявления на модерации.
      final mine = await _repository.getMyListings();
      if (mounted) {
        setState(() {
          _listings = mine.results;
          _activeCount = mine.count ?? mine.results.length;
          _isLoading = false;
        });
      }
      final sold = await _repository.getMyListings(status: 'sold');
      if (mounted) {
        setState(() => _soldCount = sold.count ?? sold.results.length);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Имя на первой строке, фамилия — на второй.
  static String _nameLines(String? name) {
    final value = (name ?? '').trim();
    if (value.isEmpty) return 'Без имени';
    final space = value.indexOf(' ');
    if (space < 0) return value;
    return '${value.substring(0, space)}\n${value.substring(space + 1).trim()}';
  }

  /// «8 объектов недвижимости» — с правильной формой слова.
  static String _objectsLabel(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return '$count объектов недвижимости';
    if (mod10 == 1) return '$count объект недвижимости';
    if (mod10 >= 2 && mod10 <= 4) return '$count объекта недвижимости';
    return '$count объектов недвижимости';
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

    return RefreshIndicator(
      onRefresh: () async {
        await _loadListings();
        await AppScope.read(context).fetchProfile();
      },
      color: const Color(0xffea812e),
      child: FigStage(
      frame: frame('38'),
      bottomBar: const AppTabBar(active: 4),
      background: const Color(0xfffefefe),
      overlays: [
        // ——— Настоящая шапка профиля вместо статичной из макета ———
        // Аватар пользователя (в кадре — картинка, Y=166).
        Positioned(
          left: 25.0,
          top: 166.0,
          child: ProfileAvatar(
            url: state.userAvatarUrl,
            initials: state.userInitials,
            size: 64.0,
            radius: 12.0,
          ),
        ),

        // Маска поверх имени, счётчиков и плашки роли из макета (Y=238).
        const Positioned(
          left: 25.0,
          top: 232.0,
          width: 325.0,
          height: 84.0,
          child: ColoredBox(color: Color(0xffffffff)),
        ),

        // Имя и статистика по объектам продавца.
        Positioned(
          left: 25.0,
          top: 234.0,
          width: 210.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Имя и фамилия — каждая на своей строке.
              Text(
                _nameLines(state.userName),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21.0,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: -0.21,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                _objectsLabel(_activeCount ?? 0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  color: Color(0xff7d7d7d),
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                'Продано: ${_soldCount ?? 0}',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  color: Color(0xff7d7d7d),
                ),
              ),
            ],
          ),
        ),

        // Плашка роли — реальный тип продавца из профиля.
        Positioned(
          left: 240.0,
          top: 236.0,
          child: RoleBadge(label: state.roleLabel),
        ),

        // Табы категорий (Y=316): Новостройки, Квартиры, Коммерция
        Positioned(
          left: 20.0,
          top: 314.0,
          right: 20.0,
          height: 38.0,
          child: Container(
            color: const Color(0xfffefefe),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final (kind, label) in _categoryTabs) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_selectedKind != kind) {
                        setState(() => _selectedKind = kind);
                      }
                    },
                    child: Container(
                      height: 30.0,
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: _selectedKind == kind
                            ? const Color(0xfffbeee3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          color: _selectedKind == kind
                              ? const Color(0xffea812e)
                              : const Color(0xff7d7d7d),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                ],
              ],
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
            onTap: () {
            if (!requireAuth(context, reason: 'Войдите, чтобы разместить объявление')) return;
            Navigator.of(context).pushNamed(Routes.ad);
          },
          ),
        ),

        // Карточки объектов продавца (Y=480), отфильтрованные по выбранной категории
        Positioned(
          left: 0,
          top: 480.0,
          right: 0,
          height: 220.0,
          child: Container(
            color: const Color(0xfffefefe),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xffea812e)))
                : () {
                    final filtered = _listings.where((l) => l.kind == _selectedKind).toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _emptyMessageForKind(_selectedKind),
                          style: const TextStyle(
                            color: Color(0xff7d7d7d),
                            fontSize: 13.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Row(
                        children: filtered.map((l) => Padding(
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
                    );
                  }(),
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
    ),
    );
  }
}
