// «Объект · полная» — кадр 19 макета с данными выбранного объекта.
//
// Кадр нарисован под «Технопарк»; приложение подставляет фотографию, цену,
// характеристики и метки выбранного объекта, включает сердце и делает
// кликабельными фото, «Фотообзор» и способ покупки.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';

/// Фотография объекта во всю ширину.
const Rect _hero = Rect.fromLTWH(0, 0, 375, 387);

/// Сердце в правом верхнем углу.
const Rect _heart = Rect.fromLTWH(321, 43, 26, 26);

/// Метки под фотографией.
const double _badgesTop = 406;
const double _badgesHeight = 25;

/// Цена и характеристики.
const Rect _price = Rect.fromLTWH(25, 445, 160, 21);
/// Характеристики: в кадре это правая ячейка строки с ценой — она начинается
/// на 206 и, как в вёрстке, может выйти за свою ширину вправо.
const Rect _specs = Rect.fromLTWH(206, 445, 154, 21);

/// Способ покупки.
const Rect _directChip = Rect.fromLTWH(25, 1269, 136, 32);
const Rect _mortgageChip = Rect.fromLTWH(173, 1269, 84, 32);

/// Лента «Фотообзора».
const double _thumbsTop = 1756;
const double _thumbSize = 80;

const Color _page = Color(0xfffefefe);
const Color _spec = Color(0xff555555);
const Color _heartFill = Color(0xccea812e);

/// Контур сердца из макета.
const String _heartOutline =
    'M 0 3.896 C 0 6.643 2.429 9.346 6.267 11.668 C 6.409 11.752 6.614 11.842 6.756 11.842 C 6.899 11.842 7.103 11.752 7.253 11.668 C 11.084 9.346 13.513 6.643 13.513 3.896 C 13.513 1.612 11.86 0 9.655 0 C 8.396 0 7.376 0.568 6.756 1.438 C 6.151 0.574 5.117 0 3.858 0 C 1.653 0 0 1.612 0 3.896 Z M 1.095 3.896 C 1.095 2.18 2.266 1.038 3.844 1.038 C 5.123 1.038 5.858 1.793 6.294 2.438 C 6.477 2.696 6.593 2.767 6.756 2.767 C 6.92 2.767 7.022 2.69 7.219 2.438 C 7.689 1.806 8.396 1.038 9.669 1.038 C 11.247 1.038 12.417 2.18 12.417 3.896 C 12.417 6.295 9.743 8.881 6.899 10.674 C 6.831 10.72 6.784 10.752 6.756 10.752 C 6.729 10.752 6.682 10.72 6.62 10.674 C 3.769 8.881 1.095 6.295 1.095 3.896 Z';
final String _heartFilled =
    _heartOutline.substring(0, _heartOutline.indexOf(' M 1.095'));

/// Метка под фотографией: подпись на цветной плашке.
class _Badge {
  const _Badge(this.text, this.fill, this.ink);
  final String text;
  final Color fill;
  final Color ink;
}

class ListingPage extends StatefulWidget {
  const ListingPage({super.key, required this.id});

  final String id;

  @override
  State<ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<ListingPage> {
  bool _useMortgage = false;
  bool _isLoading = true;
  Listing? _listing;

  @override
  void initState() {
    super.initState();
    _loadListingDetails();
  }

  Future<void> _loadListingDetails() async {
    final state = AppScope.read(context);
    // Record view asynchronously
    state.apiClient.recordListingView(widget.id);

    try {
      final data = await state.apiClient.getListingDetails(widget.id);
      if (mounted) {
        setState(() {
          _listing = Listing.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to load listing details: $e');
      if (mounted) {
        // Fallback to local mock if API fails
        setState(() {
          _listing = listingById(widget.id);
          _isLoading = false;
        });
      }
    }
  }

  void _onCallPressed() {
    if (_listing?.sellerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Номер телефона продавца недоступен')),
      );
      return;
    }
    // Здесь логика звонка, например: launchUrl(Uri.parse('tel:${_listing!.sellerPhone}'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Звоним: ${_listing!.sellerPhone}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _page,
        body: Center(child: CircularProgressIndicator(color: Color(0xffea812e))),
      );
    }

    final state = AppScope.of(context);
    final listing = _listing!;
    final favourite = state.isFavourite(listing.id);

    final badges = <_Badge>[
      if (listing.owner)
        const _Badge('Собственник', Color(0xffe8f0fe), Color(0xff1a73e8)),
      if (listing.belowMarket)
        const _Badge('Цена ниже рыночной', Color(0xffe6f4ea), Color(0xff188038)),
      if (listing.redBook)
        const _Badge('Красная книга', Color(0xfffce8e6), Color(0xffd93025)),
    ];

    return FigStage(
      frame: frame('19'),
      background: _page,
      overlays: [
        // фотография объекта вместо нарисованной
        Positioned(
          left: _hero.left,
          top: _hero.top,
          width: _hero.width,
          height: _hero.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context)
                .pushNamed(Routes.listingPhotos, arguments: ListingArgs(listing.id)),
            child: Semantics(
              button: true,
              label: 'Фотообзор',
              child: FigBox(
                width: _hero.width,
                height: _hero.height,
                clip: true,
                color: const Color(0xffd9d9d9),
                bgImage: FigBgImage(listing.photo),
              ),
            ),
          ),
        ),
        const FigBackButton(left: 25, top: 48, onLight: false),
        Positioned(
          left: _heart.left,
          top: _heart.top,
          child: Semantics(
            button: true,
            label: favourite ? 'Убрать из избранного' : 'В избранное',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => state.toggleFavourite(listing.id),
              child: FigBox(
                width: _heart.width,
                height: _heart.height,
                radius: _heart.width / 2,
                color: const Color(0xd9ffffff),
                child: Center(
                  child: FigSvg(
                    width: 13.513,
                    height: 11.842,
                    vbWidth: 13.513,
                    vbHeight: 11.842,
                    shapes: [
                      FigShape(
                        d: favourite ? _heartFilled : _heartOutline,
                        fill: _heartFill,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // метки: у объекта они свои, поэтому нарисованные закрываем
        Positioned(
          left: 0,
          top: _badgesTop,
          right: 0,
          height: _badgesHeight,
          child: ColoredBox(
            color: _page,
            // меток у объекта может быть больше, чем влезает в ширину экрана,
            // поэтому лента едет вбок, а не обрезается
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                for (final badge in badges) ...[
                  _BadgeChip(badge),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
        // цена и характеристики
        Positioned(
          left: 0,
          top: _price.top,
          right: 0,
          height: 24,
          child: ColoredBox(
            color: _page,
            child: Stack(
              children: [
                Positioned(
                  left: _price.left,
                  top: 0,
                  child: FigText(
                    noWrap: true,
                    span: TextSpan(
                      text: listing.price,
                      style: figStyle(
                        fontSize: 21.0,
                        family: FigFont.display,
                        weight: 600,
                        height: 1.0,
                        letterSpacing: -0.21,
                        color: const Color(0xff000000),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _specs.left,
                  top: 4,
                  child: _Specs(listing: listing),
                ),
              ],
            ),
          ),
        ),
        // Способы покупки: закрываем нарисованные в макете чипы белой плашкой, чтобы не было наложения
        Positioned(
          left: 20,
          top: 1283,
          right: 20,
          height: 36,
          child: ColoredBox(
            color: _page,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 5),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _useMortgage = false),
                  child: Container(
                    width: _directChip.width,
                    height: _directChip.height,
                    decoration: BoxDecoration(
                      color: !_useMortgage ? const Color(0xfffdf1e8) : const Color(0xffffffff),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: !_useMortgage ? const Color(0x00000000) : const Color(0xffe5e5ea),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Прямая покупка',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: !_useMortgage ? FontWeight.w600 : FontWeight.w400,
                        color: !_useMortgage ? const Color(0xffea812e) : const Color(0x993c3c43),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _useMortgage = true),
                  child: Container(
                    width: _mortgageChip.width,
                    height: _mortgageChip.height,
                    decoration: BoxDecoration(
                      color: _useMortgage ? const Color(0xfffdf1e8) : const Color(0xffffffff),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: _useMortgage ? const Color(0x00000000) : const Color(0xffe5e5ea),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Ипотека',
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: _useMortgage ? FontWeight.w600 : FontWeight.w400,
                        color: _useMortgage ? const Color(0xffea812e) : const Color(0x993c3c43),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Лента «Фотообзора»: закрываем нарисованные в макете 4 фото белой плашкой и выводим динамический горизонтальный скролл со всеми фото
        Positioned(
          left: 0,
          top: _thumbsTop - 4,
          right: 0,
          height: _thumbSize + 8,
          child: ColoredBox(
            color: _page,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 25),
              itemCount: listing.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final photo = listing.photos[index];
                final isFirst = index == 0;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      Routes.listingPhotos,
                      arguments: ListingArgs(listing.id),
                    );
                  },
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
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
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, _) => const ColoredBox(
                          color: Color(0xffe5e5ea),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Кнопка позвонить (нижняя липкая кнопка из макета)
        // Размещаем её поверх макета, чтобы была кликабельной
        Positioned(
          left: 20,
          bottom: 40,
          right: 20,
          height: 52,
          child: ElevatedButton(
            onPressed: _onCallPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffea812e),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Позвонить',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip(this.badge);

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    return FigBox(
      height: _badgesHeight,
      radius: 4,
      color: badge.fill,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: FigText(
          noWrap: true,
          span: TextSpan(
            text: badge.text,
            style: figStyle(
              fontSize: 13.0,
              family: FigFont.display,
              weight: 500,
              height: 1.0,
              color: badge.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// «3-комн. · 92м² · 8 этаж» справа от цены.
class _Specs extends StatelessWidget {
  const _Specs({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final style = figStyle(
      fontSize: 13.0,
      family: FigFont.display,
      weight: 600,
      height: 1.0,
      letterSpacing: -0.13,
      color: _spec,
    );

    final String rooms = (listing.roomsLabel.isNotEmpty && !listing.isPlot)
        ? listing.roomsLabel
        : '3-комн.';
    final String area = listing.areaLabel;
    final String floor = (listing.floorLong.isNotEmpty && !listing.isPlot)
        ? listing.floorLong
        : '8 этаж';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 7,
      children: [
        FigText(noWrap: true, span: TextSpan(text: rooms, style: style)),
        const _Dot(),
        FigText(
          span: TextSpan(
            style: style,
            children: [
              TextSpan(text: area, style: style),
              figSuper('2', figStyle(fontSize: 9.36, color: _spec), 13.0),
            ],
          ),
        ),
        const _Dot(),
        FigText(noWrap: true, span: TextSpan(text: floor, style: style)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => const FigBox(
        width: 4,
        height: 4,
        radius: 2,
        color: Color(0xffd9d9d9),
      );
}
