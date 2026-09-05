// Сетка карточек объектов — то, что в макете нарисовано четырьмя статичными
// карточками, здесь собирается из данных.
//
// Шаг сетки снят с «Каталога»: две колонки по 160 через 5 pt (x = 25 и 190),
// ряды через 14 pt (201.3 + 14 = 215.3).
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../app/app_state.dart';
import '../data/listings.dart';
import '../fig/fig.dart';
import 'object_card.dart';

/// Отступ сетки от левого края макета.
const double kGridLeft = 25.0;

/// Зазоры между карточками.
const double kGridGap = kCardColumnPitch - kCardWidth;
const double kGridRowGap = kCardRowPitch - kCardHeight;

class ListingGrid extends StatelessWidget {
  const ListingGrid({
    super.key,
    required this.listings,
    required this.onOpen,
    this.padding = EdgeInsets.zero,
    this.empty,
    this.controller,
    this.scrollable = true,
  });

  final List<Listing> listings;
  final void Function(Listing listing) onOpen;
  final EdgeInsets padding;

  /// Что показать, когда под фильтр ничего не подошло.
  final Widget? empty;
  final ScrollController? controller;

  /// Прокручивать ли сетку саму по себе. На «Главной» список конечный и лежит
  /// внутри кадра — там своя прокрутка перехватывала жест, и экран не
  /// листался; прокручивать должен весь кадр.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    if (listings.isEmpty) {
      return Padding(
        padding: padding,
        child: empty ?? const _EmptyResults(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - kGridLeft;
        final gridWidth = availableWidth < 325.0 ? availableWidth : 325.0;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: gridWidth + kGridLeft,
            child: MasonryGridView.count(
              controller: controller,
              physics: scrollable ? null : const NeverScrollableScrollPhysics(),
              shrinkWrap: !scrollable,
              padding: padding + const EdgeInsets.only(left: kGridLeft),
              crossAxisCount: 2,
              mainAxisSpacing: kGridRowGap,
              crossAxisSpacing: kGridGap,
              itemCount: listings.length,
              itemBuilder: (context, index) {
                final listing = listings[index];
                return ObjectCard(
                  listing: listing,
                  favourite: state.isFavourite(listing.id),
                  onTap: () => onOpen(listing),
                  onFavourite: () => state.toggleFavourite(listing.id),
                  adaptive: true,
                );
              },
            ),
          ),
        );
      },
    );
  }


}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: kGridLeft, right: kGridLeft, top: 24),
      child: FigText(
        width: 325,
        span: TextSpan(
          text: 'Ничего не нашлось. Попробуйте изменить фильтр.',
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
