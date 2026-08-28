// «Вам понравилось» — кадр 16 макета со списком из избранного.
//
// Заголовок и хром остаются от макета, четыре статичные карточки закрываются
// списком, который ведёт сердце на карточке.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import '../listing_grid.dart';

const double _gridTop = 88.0;
const double _gridFirstCard = 99.0;
const double _tabBarTop = 728.0;

class FavouritesPage extends StatelessWidget {
  const FavouritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

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
            child: ListingGrid(
              listings: state.favouriteListings,
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
