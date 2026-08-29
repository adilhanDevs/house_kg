// «Главная» — кадр 09 макета, в котором работает всё, что на нём нарисовано.
//
// Координаты сняты с кадра: колокол, поиск, четыре категории, вкладки «Новых
// позиций», карточки и «Посмотреть все». Категория задаёт фильтр и уводит в
// каталог, вкладка меняет список прямо здесь, карточки открывают объект.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/listing_repository.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import '../listing_grid.dart';
import '../search_field.dart';

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
  late final TextEditingController _searchController;
  late final ListingRepository _repository;
  List<Listing> _listings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _searchController = TextEditingController(text: state.query);
    _repository = ListingRepository(state.apiClient);
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await _repository.getListings(filters: {
        'kind': _tab == PropertyKind.newBuilding ? 'new_building' : _tab.name,
      });
      if (mounted) {
        AppScope.read(context).syncFavourites(response.results);
        setState(() {
          _listings = response.results.take(4).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCatalog(BuildContext context, {PropertyKind? kind}) {
    final state = AppScope.read(context);
    state.resetFilter();
    if (kind != null) state.toggleKind(kind);
    // без сброса стека — «назад» возвращает на «Главную»
    Navigator.of(context).pushNamed(Routes.catalog);
  }

  void _openListing(BuildContext context, Listing listing) => Navigator.of(context)
      .pushNamed(Routes.listingVideo, arguments: ListingArgs(listing.id));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final strip = kListings.take(_stripX.length).toList();

    return FigStage(
      frame: frame('09'),
      background: _page,
      bottomBar: const AppTabBar(active: 0),
      overlays: [
        // Колокол кадр рисует сам — 30×30 с волосяным кольцом #ffac6a 0.962
        // и иконкой 13×14.4 внутри. Сверху нужна только зона нажатия, ровно
        // по его коробке: своя отрисовка макет не повторяет.
        FigZone(
          _bell.left, _bell.top, _bell.width, _bell.height,
          label: 'Уведомления',
          onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
        ),
        Positioned(
          left: _search.left,
          top: _search.top,
          child: FigSearchField(
            width: _search.width,
            fieldHeight: _search.height,
            controller: _searchController,
            hint: 'Что ищете?',
            onChanged: (text) {
              state.setQuery(text);
            },
            onSubmitted: (text) {
              state.setQuery(text);
              Navigator.of(context).pushNamed(Routes.catalog);
            },
          ),
        ),
        // Динамическая лента фотографий с горизонтальным скроллом (закрывает нарисованные в макете 4 фото)
        Positioned(
          left: 0,
          top: _stripTop,
          right: 0,
          height: _stripSize,
          child: ColoredBox(
            color: _page,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 25),
              itemCount: kListings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final listing = kListings[index];
                final isFirst = index == 0;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openListing(context, listing),
                  child: SizedBox(
                    width: _stripSize,
                    height: _stripSize,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isFirst ? const Color(0xffea812e) : const Color(0xffdcdcdc),
                          width: isFirst ? 2.0 : 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6.0),
                        child: Image.asset(
                          listing.photo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, _) => const ColoredBox(
                            color: Color(0xffe5e5ea),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
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
              onTap: () {
                if (_tab != kind) {
                  setState(() => _tab = kind);
                  _loadListings();
                }
              },
            ),
          ),
        // карточки вместо нарисованных
        if (_isLoading)
          Positioned(
            left: 0,
            top: _cardsTop,
            right: 0,
            height: _cardsBottom - _cardsTop,
            child: const Center(child: CircularProgressIndicator()),
          )
        else
          Positioned(
            left: 0,
            top: _cardsTop,
            right: 0,
            height: _cardsBottom - _cardsTop,
            child: ColoredBox(
              color: _page,
              child: ListingGrid(
                listings: _listings,
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
