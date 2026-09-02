// Карточка объекта — та же, что в макете, но с данными снаружи.
//
// Размеры, цвета, радиусы и интервалы сняты с карточки «Каталога»: фото
// 160×160 с радиусом 10, подпись района на фото в 12/132, сердце 26×26 в
// правом верхнем углу, цена 17/600 и строка характеристик 13/600 с точками
// 4×4 между значениями.
import 'package:flutter/material.dart';

import '../data/kind_fields.dart';
import '../data/listings.dart';
import '../fig/fig.dart';
import 'widgets/safe_image.dart';

/// Контур сердца из макета (иконка «в избранное» на карточке).
const String _heartOutline =
    'M 0 3.896 C 0 6.643 2.429 9.346 6.267 11.668 C 6.409 11.752 6.614 11.842 6.756 11.842 C 6.899 11.842 7.103 11.752 7.253 11.668 C 11.084 9.346 13.513 6.643 13.513 3.896 C 13.513 1.612 11.86 0 9.655 0 C 8.396 0 7.376 0.568 6.756 1.438 C 6.151 0.574 5.117 0 3.858 0 C 1.653 0 0 1.612 0 3.896 Z M 1.095 3.896 C 1.095 2.18 2.266 1.038 3.844 1.038 C 5.123 1.038 5.858 1.793 6.294 2.438 C 6.477 2.696 6.593 2.767 6.756 2.767 C 6.92 2.767 7.022 2.69 7.219 2.438 C 7.689 1.806 8.396 1.038 9.669 1.038 C 11.247 1.038 12.417 2.18 12.417 3.896 C 12.417 6.295 9.743 8.881 6.899 10.674 C 6.831 10.72 6.784 10.752 6.756 10.752 C 6.729 10.752 6.682 10.72 6.62 10.674 C 3.769 8.881 1.095 6.295 1.095 3.896 Z';

/// Тот же контур без внутренней линии — заполненное сердце для «в избранном».
final String _heartFilled = _heartOutline.substring(
  0,
  _heartOutline.indexOf(' M 1.095'),
);

const Color _accent = Color(0xccea812e);
const Color _spec = Color(0xff555555);
const Color _dot = Color(0xffd9d9d9);

/// Ширина и высота карточки в координатах макета.
const double kCardWidth = 160.0;
const double kCardHeight = 201.3;

/// Шаг сетки каталога: две колонки через 5 pt, ряды через 24 pt.
const double kCardColumnPitch = 165.0;
const double kCardRowPitch = 225.3;

class ObjectCard extends StatelessWidget {
  const ObjectCard({
    super.key,
    required this.listing,
    required this.favourite,
    this.onTap,
    this.onFavourite,
    this.adaptive = false,
  });

  final Listing listing;
  final bool favourite;
  final VoidCallback? onTap;
  final VoidCallback? onFavourite;

  /// Opt-in sizing for grids whose columns follow the available viewport width.
  /// The default preserves the 160×201.3 catalogue geometry.
  final bool adaptive;

  @override
  Widget build(BuildContext context) {
    if (!adaptive) return _buildFixedCard();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : kCardWidth;
        final height = width * kCardHeight / kCardWidth;
        return SizedBox(
          width: width,
          height: height,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: kCardWidth,
              height: kCardHeight,
              child: _buildFixedCard(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFixedCard() {
    return Container(
      color: const Color(0xfffefefe),
      width: kCardWidth,
      height: kCardHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: kCardWidth,
            height: kCardWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: IgnorePointer(
                child:
                    (listing.photo.startsWith('http://') ||
                        listing.photo.startsWith('https://'))
                    ? buildSafeNetworkImage(
                        url: listing.photo,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(10.0),
                        fallback: Container(
                          color: const Color(0xfff0f0f0),
                          child: const Center(
                            child: Icon(
                              Icons.home_work_outlined,
                              color: Color(0xffb0b0b0),
                              size: 32,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xfff0f0f0),
                        child: const Center(
                          child: Icon(
                            Icons.home_work_outlined,
                            color: Color(0xffb0b0b0),
                            size: 32,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
            ),
          ),
          if (listing.status.isNotEmpty && listing.status != 'active')
            Positioned(
              left: 8,
              top: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    color: listing.isDraft
                        ? const Color(0xffea812e)
                        : (listing.isArchived
                              ? const Color(0xff8e8e93)
                              : (listing.status == 'rejected'
                                    ? const Color(0xffd32f2f)
                                    : const Color(0xff1976d2))),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    listing.isDraft
                        ? 'Черновик'
                        : (listing.isArchived
                              ? 'В архиве'
                              : (listing.status == 'rejected'
                                    ? 'Отклонено'
                                    : 'Модерация')),
                    style: const TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            top: 131,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                FigText(
                  noWrap: true,
                  span: TextSpan(
                    text: listing.district,
                    style: figStyle(
                      fontSize: 13.0,
                      family: FigFont.display,
                      weight: 600,
                      height: 1.0,
                      letterSpacing: -0.13,
                      color: const Color(0xffffffff),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 122,
            top: 12,
            child: Semantics(
              button: true,
              label: favourite ? 'Убрать из избранного' : 'В избранное',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onFavourite,
                child: FigBox(
                  width: 26.0,
                  height: 26.0,
                  radius: 13.0,
                  color: const Color(0xd9ffffff),
                  child: Center(
                    child: FigSvg(
                      width: 13.513,
                      height: 11.842,
                      vbLeft: 0.0,
                      vbTop: 0.0,
                      vbWidth: 13.513,
                      vbHeight: 11.842,
                      shapes: [
                        FigShape(
                          d: favourite ? _heartFilled : _heartOutline,
                          fill: _accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 166,
            width: kCardWidth,
            child: SizedBox(
              width: kCardWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  listing.price,
                  maxLines: 1,
                  style: figStyle(
                    fontSize: 17.0,
                    family: FigFont.display,
                    weight: 600,
                    height: 1.0,
                    letterSpacing: -0.17,
                    color: const Color(0xff000000),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 186.7,
            width: kCardWidth,
            child: SizedBox(
              width: kCardWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 7.0,
                  children: [
                    // Что показывать в строке характеристик, решает тип
                    // объекта: см. lib/data/kind_fields.dart.
                    if (showsField(listing.kind, ListingField.rooms) &&
                        listing.rooms > 0) ...[
                      _spec7(listing.roomsLabel),
                      const FigBox(
                        width: 4.0,
                        height: 4.0,
                        color: _dot,
                        radius: 2.0,
                      ),
                    ],
                    if (listing.isPlot) ...[
                      _spec7('Участок'),
                      const FigBox(
                        width: 4.0,
                        height: 4.0,
                        color: _dot,
                        radius: 2.0,
                      ),
                    ],
                    _areaWidget(listing.areaLabel),
                    if (showsField(listing.kind, ListingField.landArea) &&
                        listing.landArea != null) ...[
                      const FigBox(
                        width: 4.0,
                        height: 4.0,
                        color: _dot,
                        radius: 2.0,
                      ),
                      _spec7('${listing.landArea!.toStringAsFixed(0)} сот.'),
                    ],
                    if (showsField(listing.kind, ListingField.floor) &&
                        listing.floor > 0) ...[
                      const FigBox(
                        width: 4.0,
                        height: 4.0,
                        color: _dot,
                        radius: 2.0,
                      ),
                      _spec7(
                        listing.floorLong.isNotEmpty
                            ? listing.floorLong
                            : '${listing.floor} этаж',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _spec7(String text) => FigText(
    noWrap: true,
    span: TextSpan(
      text: text,
      style: figStyle(
        fontSize: 13.0,
        family: FigFont.display,
        weight: 600,
        height: 1.0,
        letterSpacing: -0.13,
        color: _spec,
      ),
    ),
  );

  static Widget _areaWidget(String areaLabel) => FigText(
    span: TextSpan(
      style: figStyle(
        fontSize: 13.0,
        family: FigFont.display,
        weight: 600,
        height: 1.0,
        letterSpacing: -0.13,
        color: _spec,
      ),
      children: [
        TextSpan(
          text: areaLabel,
          style: figStyle(fontSize: 13.0, color: _spec),
        ),
        figSuper('2', figStyle(fontSize: 9.36, color: _spec), 13.0),
      ],
    ),
  );
}
