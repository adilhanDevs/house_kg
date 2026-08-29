// «Вам понравилось» — кадр 16 макета со списком из избранного.
//
// Заголовок и хром остаются от макета, четыре статичные карточки закрываются
// списком, который ведёт сердце на карточке.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/listing_repository.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import '../listing_grid.dart';

const double _gridTop = 88.0;
const double _gridFirstCard = 99.0;
const double _tabBarTop = 728.0;

class FavouritesPage extends StatefulWidget {
  const FavouritesPage({super.key});

  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage> {
  final ScrollController _scrollController = ScrollController();
  List<Listing> _listings = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextCursor;
  late AppState _appState;
  late ListingRepository _repository;

  @override
  void initState() {
    super.initState();
    _appState = AppScope.read(context);
    _repository = ListingRepository(_appState.apiClient);
    _scrollController.addListener(_onScroll);
    _loadListings(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      final response = await _repository.getFavourites(
        cursor: _nextCursor,
      );
      
      if (mounted) {
        _appState.syncFavourites(response.results);
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: We don't filter _listings by state.isFavourite locally because 
    // the user might want to see the item they just un-favourited until they refresh.
    // Or we could hide them instantly. But keeping them until reload is standard.
    return FigStage(
      frame: frame('16'),
      background: const Color(0xfffefefe),
      bottomBar: const AppTabBar(active: 3),
      overlays: [
        Positioned(
          left: 0,
          top: _gridTop,
          right: 0,
          height: _tabBarTop - _gridTop,
          child: ColoredBox(
            color: const Color(0xfffefefe),
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xffea812f)))
                : ListingGrid(
                    controller: _scrollController,
                    listings: _listings,
                    padding: const EdgeInsets.only(
                      top: _gridFirstCard - _gridTop,
                      bottom: 16,
                    ),
                    empty: const _NoFavourites(),
                    onOpen: (listing) => Navigator.of(context)
                        .pushNamed(Routes.listingVideo, arguments: ListingArgs(listing.id)),
                  ),
          ),
        ),
      ],
    );
  }
}

class _NoFavourites extends StatelessWidget {
  const _NoFavourites();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: kGridLeft, right: kGridLeft, top: 24),
      child: FigText(
        width: 325,
        span: TextSpan(
          text: 'Пока пусто. Нажмите сердце на карточке, чтобы сохранить объект.',
          style: figStyle(
            fontSize: 15.0,
            family: FigFont.display,
            weight: 500,
            height: 1.333,
            color: const Color(0xff7d7d7d),
          ),
        ),
      ),
    );
  }
}
