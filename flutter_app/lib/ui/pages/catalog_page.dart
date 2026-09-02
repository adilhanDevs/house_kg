// «Каталог» — кадр 11 макета с живым поиском, фильтром и списком.
//
// Кадр рисует четыре статичные карточки; приложение закрывает эту область
// своей — того же цвета — и раскладывает в ней карточки из данных. Всё
// остальное на экране остаётся ровно тем, что нарисовал макет.
import 'package:flutter/material.dart';

import '../../data/listing_repository.dart';
import '../../data/listings.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../app_tab_bar.dart';
import '../listing_grid.dart';
import '../search_field.dart';

/// Что кадр рисует статикой и что приложение закрывает своим списком.
const double _gridTop = 95.0;
const double _gridFirstCard = 107.0;
const double _tabBarTop = 728.0;

/// Плашка поиска и иконка фильтра в координатах кадра.
const Rect _searchBox = Rect.fromLTWH(25, 45, 285, 40);
const Rect _filterIcon = Rect.fromLTWH(331, 55.9, 18.1, 18.2);

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final TextEditingController _search;
  late final ListingRepository _repository;
  final ScrollController _scrollController = ScrollController();
  
  List<Listing> _listings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppScope.read(context);
    _search = TextEditingController(text: _appState.query);
    _repository = ListingRepository(_appState.apiClient);
    _scrollController.addListener(_onScroll);
    _appState.addListener(_onFilterChanged);
    _loadListings(refresh: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _scrollController.dispose();
    _appState.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    // Reload when filters change
    _loadListings(refresh: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadListings();
    }
  }

  Future<void> _loadListings({bool refresh = false}) async {
    if (refresh) {
      _hasMore = true;
      _nextCursor = null;
    }
    
    if (!_hasMore || (_isLoadingMore && !refresh)) return;

    if (refresh) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final response = await _repository.getListings(
        filters: _appState.filterParams,
        cursor: _nextCursor,
      );
      
      if (mounted) {
        setState(() {
          if (refresh) {
            _listings = response.results;
          } else {
            _listings.addAll(response.results);
          }
          _appState.syncFavourites(response.results);
          _nextCursor = response.nextCursor;
          _hasMore = _nextCursor != null;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (refresh) _listings = [];
          _isLoading = false;
          _isLoadingMore = false;
        });
        debugPrint('Catalog load listings error: $e');
      }
    }
  }

  String _searchHint(AppState state) {
    if (state.kinds.length == 1) {
      return switch (state.kinds.first) {
        PropertyKind.house => 'Дома в Бишкеке',
        PropertyKind.apartment => 'Квартиры в Бишкеке',
        PropertyKind.plot => 'Участки в Бишкеке',
        PropertyKind.newBuilding => 'Новостройки в Бишкеке',
        PropertyKind.room => 'Комнаты в Бишкеке',
        PropertyKind.commercial => 'Коммерция в Бишкеке',
      };
    }
    return 'Недвижимость в Бишкеке';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return FigStage(
      frame: frame('11'),
      background: const Color(0xfffefefe),
      bottomBar: const AppTabBar(active: 1),
      overlays: [
        // список вместо статичных карточек кадра
        Positioned(
          left: 0,
          top: _gridTop,
          right: 0,
          height: _tabBarTop - _gridTop,
          child: ColoredBox(
            color: const Color(0xfffefefe),
            child: _isLoading 
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xffea812f),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Загрузка каталога...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xff8e8e93),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ) 
              : ListingGrid(
                  controller: _scrollController,
                  listings: _listings,
                  padding: const EdgeInsets.only(
                    top: _gridFirstCard - _gridTop,
                    bottom: 16,
                  ),
                  onOpen: (listing) => Navigator.of(context).pushNamed(
                    Routes.listingVideo, 
                    arguments: ListingArgs(listing.id),
                  ),
                ),
          ),
        ),
        // живой поиск поверх нарисованной плашки
        Positioned(
          left: _searchBox.left,
          top: _searchBox.top,
          child: FigSearchField(
            width: _searchBox.width,
            controller: _search,
            hint: _searchHint(state),
            onChanged: state.setQuery,
          ),
        ),
        FigZone(
          _filterIcon.left - 8,
          _filterIcon.top - 8,
          _filterIcon.width + 16,
          _filterIcon.height + 16,
          label: 'Фильтр',
          onTap: () => Navigator.of(context).pushNamed(Routes.filter),
        ),
      ],
    );
  }
}
