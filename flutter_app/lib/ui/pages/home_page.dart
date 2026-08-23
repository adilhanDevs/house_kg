// «Главная» — кадр 09 макета, в котором работает всё, что на нём нарисовано.
//
// Координаты сняты с кадра: колокол, поиск, четыре категории, вкладки «Новых
// позиций», карточки и «Посмотреть все». Категория задаёт фильтр и уводит в
// каталог, вкладка меняет список прямо здесь, карточки открывают объект.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import '../listing_grid.dart';

/// Колокол уведомлений.
const Rect _bell = Rect.fromLTWH(320, 44, 30, 30);

/// Плашка поиска.
const Rect _search = Rect.fromLTWH(25, 236, 325, 50);

/// Лента фотографий 82×82.
const double _stripTop = 138;
const double _stripSize = 82;
const List<double> _stripX = [25, 117, 209, 301];

/// Категории: иконка 60×60 и подпись под ней.
const double _categoryTop = 302;
const double _categoryBottom = 384;
const List<(PropertyKind, double, double)> _categories = [
  (PropertyKind.house, 25, 60),
  (PropertyKind.apartment, 109.7, 60),
  (PropertyKind.plot, 194.3, 60),
  (PropertyKind.newBuilding, 279, 74),
];

/// Вкладки «Новых позиций»: подпись 15/500 и черта под выбранной.
const double _tabsTop = 458;
const double _tabsHeight = 22;
const List<(PropertyKind, String, double, double)> _newTabs = [
  (PropertyKind.apartment, 'Квартиры', 23, 68),
  (PropertyKind.plot, 'Участки', 121, 58.8),
  (PropertyKind.house, 'Дома', 209.8, 39.8),
];

/// Область, где кадр рисует четыре карточки.
const double _cardsTop = 512;
const double _cardsBottom = 945;

/// «Посмотреть все».
const Rect _seeAll = Rect.fromLTWH(133, 957, 110, 22);

const Color _page = Color(0xfffefefe);
const Color _tabActive = Color(0xffea812f);
const Color _tabIdle = Color(0xff7d7d7d);
const Color _underline = Color(0xffee9a59);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PropertyKind _tab = PropertyKind.apartment;

  void _openCatalog(BuildContext context, {PropertyKind? kind}) {
    final state = AppScope.read(context);
    state.resetFilter();
    if (kind != null) state.toggleKind(kind);
    // без сброса стека — «назад» возвращает на «Главную»
    Navigator.of(context).pushNamed(Routes.catalog);
  }

  void _openListing(BuildContext context, Listing listing) => Navigator.of(context)
      .pushNamed(Routes.listing, arguments: ListingArgs(listing.id));

  @override
  Widget build(BuildContext context) {
    final selection = kListings.where((l) => l.kind == _tab).take(4).toList();
    final strip = kListings.take(_stripX.length).toList();

    return FigStage(
      frame: frame('09'),
      background: _page,
      bottomBar: const AppTabBar(active: 0),
      overlays: [
        FigZone(
          _bell.left, _bell.top, _bell.width, _bell.height,
          label: 'Уведомления',
          onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
        ),
        FigZone(
          _search.left, _search.top, _search.width, _search.height,
          label: 'Поиск',
          onTap: () => _openCatalog(context),
        ),
        for (var i = 0; i < strip.length; i++)
          FigZone(
            _stripX[i], _stripTop, _stripSize, _stripSize,
            label: strip[i].district,
            onTap: () => _openListing(context, strip[i]),
          ),
        for (final (kind, x, w) in _categories)
          FigZone(
            x, _categoryTop, w, _categoryBottom - _categoryTop,
            label: kind.label,
            onTap: () => _openCatalog(context, kind: kind),
          ),
        // вкладки: подписи перерисовываем, чтобы выбранная была акцентной
        for (final (kind, label, x, w) in _newTabs)
          Positioned(
            left: x,
            top: _tabsTop,
            child: _NewTab(
              label: label,
              width: w,
              selected: kind == _tab,
              onTap: () => setState(() => _tab = kind),
            ),
          ),
        // карточки вместо нарисованных
        Positioned(
          left: 0,
          top: _cardsTop,
          right: 0,
          height: _cardsBottom - _cardsTop,
          child: ColoredBox(
            color: _page,
            child: ListingGrid(
              listings: selection,
              scrollable: false,
              onOpen: (listing) => _openListing(context, listing),
            ),
          ),
        ),
        FigZone(
          _seeAll.left, _seeAll.top, _seeAll.width, _seeAll.height,
          label: 'Посмотреть все',
          onTap: () => _openCatalog(context, kind: _tab),
        ),
      ],
    );
  }
}

/// Вкладка «Новых позиций»: подпись и черта под выбранной. Рисуется поверх
/// нарисованной, поэтому сначала закрывает её цветом страницы.
class _NewTab extends StatelessWidget {
  const _NewTab({
    required this.label,
    required this.width,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: _tabsHeight + 2,
          // ширина взята из макета; подпись в шрифте устройства может выйти за
          // неё — в вёрстке она так же торчит, а не обрезается
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(child: ColoredBox(color: _page)),
              Positioned(
                left: 0,
                top: 0,
                child: FigText(
                  noWrap: true,
                  opacity: 0.8,
                  span: TextSpan(
                    text: label,
                    style: figStyle(
                      fontSize: 15.0,
                      family: FigFont.display,
                      weight: 500,
                      height: 1.467,
                      color: selected ? _tabActive : _tabIdle,
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 1,
                  top: _tabsHeight,
                  child: SizedBox(
                    width: width - 1,
                    height: 1,
                    child: const ColoredBox(color: _underline),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
