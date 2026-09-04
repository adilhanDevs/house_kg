import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/listing_repository.dart';
import '../../data/listings.dart';
import '../../l10n/l10n.dart';
import '../app_tab_bar.dart';
import '../listing_grid.dart';

const Color _ink = Color(0xff1c1939);
const Color _accent = Color(0xffea812e);
const Color _muted = Color(0xff8e8e93);
const double _side = 20.0;

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
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

    if (_appState.authInitialized != null) {
      await _appState.authInitialized;
    }

    try {
      final response = await _repository.getFavourites(cursor: _nextCursor);

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
        debugPrint('Favourites load error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      bottomNavigationBar: const AppTabBar(active: 3),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(l10n),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: _accent,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.loading,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadListings(refresh: true),
                      color: _accent,
                      child: ListingGrid(
                        controller: _scrollController,
                        listings: _listings,
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        empty: _NoFavourites(message: l10n.favouritesEmpty),
                        onOpen: (listing) => Navigator.of(context).pushNamed(
                          Routes.listing,
                          arguments: ListingArgs(listing.id),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(dynamic l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(_side, 12, _side, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            l10n.tabFavourites,
            style: const TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
              color: _ink,
              height: 1.2,
            ),
          ),
        ),
      ],
    ),
  );
}

class _NoFavourites extends StatelessWidget {
  const _NoFavourites({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: kGridLeft,
        right: kGridLeft,
        top: 24,
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
          height: 1.333,
          color: Color(0xff7d7d7d),
        ),
      ),
    );
  }
}
