// «Каталог» — кадр 11 макета с живым поиском, фильтром и списком.
//
// Кадр рисует четыре статичные карточки; приложение закрывает эту область
// своей — того же цвета — и раскладывает в ней карточки из данных. Всё
// остальное на экране остаётся ровно тем, что нарисовал макет.
//
// Выборку целиком делает сервер: клиент отправляет параметры фильтра и
// показывает то, что вернулось. Локально список не фильтруется и не
// сортируется — иначе на второй странице пропали бы объявления, которые
// сервер уже посчитал подходящими.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api_exceptions.dart';
import '../../data/listing_repository.dart';
import '../../data/listings.dart';
import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../app_tab_bar.dart';
import '../listing_grid.dart';
import '../search_field.dart';
import '../../l10n/l10n.dart';

/// Что кадр рисует статикой и что приложение закрывает своим списком.
const double _gridTop = 95.0;
const double _gridFirstCard = 107.0;
const double _tabBarTop = 728.0;

/// Плашка поиска и иконка фильтра в координатах кадра.
const Rect _searchBox = Rect.fromLTWH(25, 45, 285, 40);
const Rect _filterIcon = Rect.fromLTWH(331, 55.9, 18.1, 18.2);

/// Пауза перед запросом: набор текста и серия переключений в фильтре
/// схлопываются в один поход на сервер.
const Duration _requestDebounce = Duration(milliseconds: 350);

const Color _accent = Color(0xffea812f);
const Color _muted = Color(0xff8e8e93);

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final TextEditingController _search;
  late final ListingRepository _repository;
  late final AppState _appState;
  final ScrollController _scrollController = ScrollController();

  List<Listing> _listings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  String? _error;

  /// Отпечаток запроса, на который загружен текущий список.
  String _signature = '';

  Timer? _debounce;

  /// Номер последнего отправленного запроса.
  ///
  /// Ответы приходят не в том порядке, в каком уходили запросы: пользователь
  /// быстро меняет фильтр, ответ по старому фильтру возвращается позже нового
  /// и затирает его. Поэтому применяется только ответ на самый свежий запрос.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _appState = AppScope.read(context);
    _search = TextEditingController(text: _appState.query);
    _repository = ListingRepository(_appState.apiClient);
    _signature = _appState.filterSignature;
    _scrollController.addListener(_onScroll);
    _appState.addListener(_onAppStateChanged);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scrollController.dispose();
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  /// AppState шлёт уведомления на всё подряд — профиль, кошелёк, избранное.
  /// Перезагружаемся только когда изменился сам запрос.
  void _onAppStateChanged() {
    final signature = _appState.filterSignature;
    if (signature == _signature) return;
    _signature = signature;

    _debounce?.cancel();
    _debounce = Timer(_requestDebounce, () {
      if (mounted) _load(refresh: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _debounce?.cancel();
    } else if (!_hasMore || _isLoadingMore || _isLoading) {
      return;
    }

    final requestId = ++_requestId;
    final filters = _appState.filterParams;

    setState(() {
      if (refresh) {
        _isLoading = true;
        _error = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final response = await _repository.getListings(
        filters: filters,
        cursor: refresh ? null : _nextCursor,
        sessionId: _appState.recommendationSessionId,
      );

      // Ответ на устаревший запрос применять нельзя: фильтр уже другой.
      if (!mounted || requestId != _requestId) return;

      setState(() {
        if (refresh) {
          _listings = response.results;
        } else {
          _listings.addAll(response.results);
        }
        _nextCursor = response.nextCursor;
        _hasMore = _nextCursor != null;
        _isLoading = false;
        _isLoadingMore = false;
        _error = null;
      });

      // Отметки избранного приходят вместе с карточками; это уведомление
      // отпечаток запроса не меняет, поэтому лишней перезагрузки не будет.
      _appState.syncFavourites(response.results);
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        if (refresh) {
          _listings = [];
        }
        _error = _describe(e);
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _describe(Object error) {
    if (error is ApiException) return error.message;
    if (error is NetworkException) return error.message;
    return context.l10n.error;
  }

  String _searchHint(AppState state, dynamic l10n) {
    if (state.selectedKinds.length == 1) {
      final kind = state.selectedKinds.first;
      return kind.localized(l10n);
    }
    return l10n.catalogTitle;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = context.l10n;

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
            child: _content(l10n),
          ),
        ),
        // живой поиск поверх нарисованной плашки
        Positioned(
          left: _searchBox.left,
          top: _searchBox.top,
          child: FigSearchField(
            width: _searchBox.width,
            controller: _search,
            hint: _searchHint(state, l10n),
            onChanged: state.setQuery,
          ),
        ),
        FigZone(
          _filterIcon.left - 8,
          _filterIcon.top - 8,
          _filterIcon.width + 16,
          _filterIcon.height + 16,
          label: l10n.catalogFilters,
          onTap: () => Navigator.of(context).pushNamed(Routes.filter),
        ),
      ],
    );
  }

  Widget _content(dynamic l10n) {
    if (_isLoading) {
      return _Centered(
        children: [
          const CircularProgressIndicator(color: _accent, strokeWidth: 3),
          const SizedBox(height: 14),
          _label(l10n.loading),
        ],
      );
    }

    if (_error != null && _listings.isEmpty) {
      return _Centered(
        children: [
          _label(_error!),
          const SizedBox(height: 12),
          _action(l10n.retry, () => _load(refresh: true)),
        ],
      );
    }

    // Пустой результат объясняет сама сетка — текст там уже свой и общий
    // для всех списков объявлений.
    return ListingGrid(
      controller: _scrollController,
      listings: _listings,
      padding: const EdgeInsets.only(
        top: _gridFirstCard - _gridTop,
        bottom: 16,
      ),
      onOpen: (listing) => Navigator.of(
        context,
      ).pushNamed(Routes.listing, arguments: ListingArgs(listing.id)),
    );
  }

  Widget _label(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 13,
      color: _muted,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _action(String text, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        color: _accent,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
