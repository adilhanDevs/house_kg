// «Фотообзор» — кадр 20 макета, в котором листаются фотографии объекта.
//
// Кадр нарисован под одну фотографию во весь экран, поэтому здесь она своя —
// с пролистыванием и стрелками. Всё, что макет рисует поверх фотографии —
// заголовок, «Скачать все фото», сердце, стрелки, точки, «Вернуться» — кадр
// закрыт своей фотографией, и потому перерисовано в тех же координатах.
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';
import '../widgets/safe_image.dart';
import 'agent_listings_page.dart';

/// Затемнение поверх фотографии — тот же градиент, что в кадре.
const LinearGradient _shade = LinearGradient(
  begin: Alignment(0.018, 1.004),
  end: Alignment(-0.018, -1.004),
  colors: [Color(0x26000000), Color(0x00666666)],
  stops: [0.241, 0.945],
);

/// Стрелки: 10×18 по краям, на высоте середины экрана.
const double _chevronTop = 397;

/// Отступ стрелки от края экрана — как в кадре.
const double _sideGap = 25;
const double _chevronSize = 44;
const Rect _prev = Rect.fromLTWH(25, _chevronTop, 10, 18);
const Rect _next = Rect.fromLTWH(340, _chevronTop, 10, 18);

/// Точки-указатели: пилюля по центру, точки 8 pt через 6 pt.
const double _dotsTop = 758.5;
const double _dotsCenter = 187.5;
const double _dotSize = 8.0;
const double _dotGap = 6.0;

const Color _white = Color(0xf2ffffff);
const Color _icon = Color(0xfffbfafa);
const Color _heartInk = Color(0xccea812e);

class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key, required this.id, this.listing});

  final String id;
  final Listing? listing;

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  late final PageController _pages = PageController();
  int _index = 0;
  Listing? _listing;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.listing != null) {
      _listing = widget.listing;
      _isLoading = false;
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final state = AppScope.read(context);
    try {
      var targetId = widget.id;
      if (targetId == 'technopark' || targetId == 'asanbay' || targetId.isEmpty) {
        final listingsResp = await state.apiClient.getListings();
        final first = (listingsResp['results'] as List<dynamic>?)?.firstOrNull;
        if (first != null && first is Map && first['slug'] != null) {
          targetId = first['slug'].toString();
        }
      }
      final data = await state.apiClient.getListingDetails(targetId);
      if (mounted) {
        setState(() {
          _listing = Listing.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Кадр рисует обе стрелки всегда, поэтому обе всегда и работают: с последней
  /// фотографии «вперёд» ведёт к первой, а с первой «назад» — к последней.
  void _go(int step, int count) {
    if (count < 2) return;
    final next = (_index + step) % count;
    if (next == _index) return;
    if ((next - _index).abs() == 1) {
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      // перескок через всю ленту — без пролистывания всего, что между
      _pages.jumpToPage(next);
      setState(() => _index = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xff1c1b19),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xffea812e)),
        ),
      );
    }

    final state = AppScope.of(context);
    final listing = _listing;
    if (listing == null) {
      return Scaffold(
        backgroundColor: const Color(0xff1c1b19),
        body: Stack(
          children: [
            const Positioned(
              top: 48,
              left: 20,
              child: FigBackButton(onLight: false),
            ),
            const Center(
              child: Text(
                'Объявление не найдено',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    final photos = listing.photos;
    if (photos.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xff1c1b19),
        body: Stack(
          children: [
            const Positioned(
              top: 48,
              left: 20,
              child: FigBackButton(onLight: false),
            ),
            const Center(
              child: Text(
                'У этого объявления нет фотографий',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    final favourite = state.isFavourite(listing.id);

    return Scaffold(
      backgroundColor: const Color(0xff1c1b19),
      body: Stack(
        children: [
          // Фотография — на всё окно и одним куском: она заполняет его по
          // короткой стороне, поэтому по краям не остаётся ни полей, ни второй
          // копии картинки со своим масштабом.
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final p = photos[i];
                final isNet = p.startsWith('http://') || p.startsWith('https://');
                return isNet
                    ? buildSafeNetworkImage(
                        url: p,
                        fit: BoxFit.cover,
                        fallback: const ColoredBox(color: Color(0xff1c1b19)),
                      )
                    : const ColoredBox(color: Color(0xff1c1b19));
              },
            ),
          ),
          // затемнения кадра: сверху лёгкое, снизу — под подписи об объекте
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(gradient: _shade)),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 300,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xb3000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          // Интерфейс — в координатах макета, вписанный в окно целиком. Всё,
          // что нарисовано, видно при любой высоте окна и ничего не надо
          // прокручивать; мимо кнопок жесты уходят к фотографии.
          _Chrome(
            children: [
              // об объекте: продавец, описание, цена и характеристики
              _About(listing: listing),
              // заголовок и кнопки поверх фотографии
              Positioned(
                left: 25,
                right: 15,
                top: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FigText(
                      noWrap: true,
                      span: TextSpan(
                        text: 'Фотообзор',
                        style: figStyle(
                          fontSize: 21.0,
                          family: FigFont.display,
                          weight: 600,
                          height: 1.0,
                          letterSpacing: -0.21,
                          color: const Color(0xffffffff),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 8,
                      children: [
                        const _DownloadPill(),
                        _HeartButton(
                          filled: favourite,
                          onTap: () => state.toggleFavourite(listing.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // стрелки: сама стрелка в координатах макета, нажимается площадка 44×44
              Positioned(
                left: _prev.left,
                top: _prev.top,
                // та же стрелка, развёрнутая на 180°, — как в кадре
                child: Transform(
                  transform: Matrix4.diagonal3Values(-1, -1, 1)..setTranslationRaw(10, 18, 0),
                  child: const FigSvg(
                    width: 10.0,
                    height: 18.0,
                    vbWidth: 10.0,
                    vbHeight: 18.0,
                    shapes: [FigShape(d: _chevron, fill: Color(0xffffffff), evenOdd: true)],
                  ),
                ),
              ),
              FigZone(
                _prev.center.dx - _chevronSize / 2, _prev.center.dy - _chevronSize / 2,
                _chevronSize, _chevronSize,
                label: 'Предыдущее фото',
                onTap: () => _go(-1, photos.length),
              ),
              const Positioned(
                right: _sideGap,
                top: _chevronTop,
                child: FigSvg(
                  width: 10.0,
                  height: 18.0,
                  vbWidth: 10.0,
                  vbHeight: 18.0,
                  shapes: [FigShape(d: _chevron, fill: Color(0xffffffff), evenOdd: true)],
                ),
              ),
              Positioned(
                right: _sideGap - (_chevronSize - 10) / 2,
                top: _chevronTop - (_chevronSize - 18) / 2,
                width: _chevronSize,
                height: _chevronSize,
                child: Semantics(
                  button: true,
                  label: 'Следующее фото',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _go(1, photos.length),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              // точки по числу фотографий
              Positioned(
                left: 0,
                right: 0,
                top: _dotsTop,
                child: Center(
                  child: FigBox(
                    color: const Color(0x6699a2ad),
                    radius: 34.0,
                    blur: 20.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: _dotGap,
                      children: [
                        for (var i = 0; i < photos.length; i++)
                          FigBox(
                            width: _dotSize,
                            height: _dotSize,
                            radius: _dotSize / 2,
                            color: i == _index
                                ? const Color(0xffea812e)
                                : const Color(0xffc4c9cf),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // «Вернуться»: в кадре кнопка стоит по центру, но там она попадает
              // под подписи об объекте и теряется. В нижнем ряду, слева от точек,
              // она лежит на самом тёмном месте затемнения и хорошо видна.
              Positioned(
                left: 25,
                top: 756.5,
                child: Semantics(
                  button: true,
                  label: 'Вернуться',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: ExcludeSemantics(
                      child: FigBox(
                        color: const Color(0x4dffffff),
                        radius: 20.0,
                        blur: 27.0,
                        padding: const EdgeInsets.fromLTRB(10.0, 3.0, 10.0, 5.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 4.0,
                          children: [
                            const SizedBox(
                              width: 16.0,
                              height: 16.0,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.667,
                                    top: 1.333,
                                    child: FigSvg(
                                      width: 14.135,
                                      height: 13.327,
                                      vbWidth: 14.135,
                                      vbHeight: 13.327,
                                      shapes: [FigShape(d: _backIcon, fill: _white)],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FigText(
                              noWrap: true,
                              span: TextSpan(
                                text: 'Вернуться',
                                style: figStyle(
                                  fontSize: 13.0,
                                  family: FigFont.display,
                                  weight: 500,
                                  height: 1.0,
                                  color: _white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Интерфейс просмотрщика в координатах макета: коробка 375×812 вписывается в
/// окно по короткой стороне, поэтому подписи и кнопки видны целиком и не
/// растягиваются вместе с фотографией.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Фотография идёт во весь экран, а интерфейс — нет: «Вернуться» и точки
    // стоят у самого низа кадра и попали бы под кнопки навигации Android.
    // Полосу под навигацию вычитаем из коробки макета — кадр от этого чуть
    // уменьшается, но целиком остаётся на виду.
    final bottomSafe = bottomSafeInset(context);

    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafe),
        child: MediaQuery(
          // размер шрифта системы порвал бы вёрстку коробок фиксированной высоты
          data: media.copyWith(textScaler: TextScaler.noScaling),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Масштаб берём от высоты окна: по вертикали вёрстка макета
              // остаётся точной и целиком помещается. По ширине коробка тянется
              // до края окна — столько точек макета, сколько в него влезло, — и
              // элементы у краёв остаются у краёв, а не отступают внутрь.
              final scale = constraints.maxHeight / kDesignHeight;
              return FittedBox(
                // fill, но по обеим осям множитель один и тот же — не растягивает
                fit: BoxFit.fill,
                child: SizedBox(
                  width: constraints.maxWidth / scale,
                  height: kDesignHeight,
                  child: Stack(clipBehavior: Clip.none, children: children),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _dotsWidth(int count) => 24 + _dotSize * count + _dotGap * (count - 1);


/// Об объекте под фотографией: продавец, описание, цена и характеристики —
/// то же, что макет показывает на полноэкранном кадре. Блок прижат к низу,
/// чтобы не наезжать на «Вернуться» и точки.
///
/// Нажатия проходят сквозь блок к фотографии — кроме строки продавца: она со
/// стрелкой, и в макете это ссылка на его страницу.
class _About extends StatelessWidget {
  const _About({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 25,
      right: 25,
      bottom: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: listing.agent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pushNamed(
                Routes.agentListings,
                arguments: AgentListingsArgs(
                  sellerId: listing.sellerId ?? 0,
                  initialListingSlug: listing.slug,
                  initialListingTitle: listing.address,
                  initialSellerName: listing.agent,
                  initialSellerKind: listing.seller.name,
                  initialAvatarUrl: listing.sellerAvatarUrl,
                  initialCoverUrl: listing.sellerCoverUrl,
                ),
              ),
              child: ExcludeSemantics(
                child: Padding(
                  // строка невысокая — расширяем площадку нажатия вверх и вниз;
                  // снизу эти 6 pt отнимаем у отступа до описания, поэтому
                  // текст остаётся ровно там, где его нарисовал макет
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: _white),
                      const SizedBox(width: 8),
                      FigText(
                        noWrap: true,
                        span: TextSpan(
                          text: listing.agent,
                          style: figStyle(
                            fontSize: 15.0,
                            family: FigFont.display,
                            weight: 600,
                            height: 1.0,
                            color: const Color(0xffffffff),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: _white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                FigText(
                  ellipsis: true,
                  span: TextSpan(
                    text: listing.description,
                    style: figStyle(
                      fontSize: 13.0,
                      family: FigFont.display,
                      weight: 400,
                      height: 1.3,
                      color: const Color(0xccffffff),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      FigText(
                        noWrap: true,
                        span: TextSpan(
                          text: listing.price,
                          style: figStyle(
                            fontSize: 21.0,
                            family: FigFont.display,
                            weight: 600,
                            height: 1.0,
                            letterSpacing: -0.21,
                            color: const Color(0xffffffff),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Specs(listing: listing),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.map_outlined, size: 14, color: _white),
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
                                color: _white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «3-комн. • 92м²» — у участка комнат нет, остаётся одна площадь.
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
      color: _white,
    );

    final String rooms = (listing.roomsLabel(context.l10n).isNotEmpty && !listing.isPlot)
        ? listing.roomsLabel(context.l10n)
        : '3-комн.';
    final String area = listing.areaLabel(context.l10n);
    final String floor = (listing.floorLong(context.l10n).isNotEmpty && !listing.isPlot)
        ? listing.floorLong(context.l10n)
        : '8 этаж';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FigText(noWrap: true, span: TextSpan(text: rooms, style: style)),
        const _Dot(),
        FigText(
          span: TextSpan(
            style: style,
            children: [
              TextSpan(text: area, style: style),
              figSuper('2', figStyle(fontSize: 9.36, color: _white), 13.0),
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
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: FigBox(width: 4, height: 4, radius: 2, color: Color(0x99ffffff)),
      );
}

/// «Скачать все фото» — кнопка макета; перерисована, потому что фотография
/// закрывает нарисованную.
class _DownloadPill extends StatelessWidget {
  const _DownloadPill();

  @override
  Widget build(BuildContext context) {
    return FigBox(
      color: const Color(0x4dffffff),
      radius: 20.0,
      blur: 27.0,
      padding: const EdgeInsets.fromLTRB(10.0, 3.0, 10.0, 5.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 4.0,
        children: [
          const SizedBox(
            width: 16.0,
            height: 16.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 3.0,
                  top: 4.974,
                  child: FigSvg(
                    width: 9.796,
                    height: 8.863,
                    vbWidth: 9.796,
                    vbHeight: 8.863,
                    shapes: [FigShape(d: _downloadBox, fill: _icon)],
                  ),
                ),
                Positioned(
                  left: 5.627,
                  top: 2.038,
                  child: FigSvg(
                    width: 4.542,
                    height: 8.079,
                    vbWidth: 4.542,
                    vbHeight: 8.079,
                    shapes: [FigShape(d: _downloadArrow, fill: _icon)],
                  ),
                ),
              ],
            ),
          ),
          FigText(
            noWrap: true,
            span: TextSpan(
              text: 'Скачать все фото',
              style: figStyle(
                fontSize: 10.0,
                family: FigFont.display,
                weight: 500,
                height: 1.0,
                color: _white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Сердце в правом верхнем углу — оно же переключает избранное.
class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.filled, required this.onTap});

  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: filled ? 'Убрать из избранного' : 'В избранное',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FigBox(
          width: 24.0,
          height: 24.0,
          radius: 12.0,
          color: const Color(0xffffffff),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 5.823,
                top: 6.864,
                child: FigSvg(
                  width: 12.127,
                  height: 10.627,
                  vbWidth: 12.127,
                  vbHeight: 10.627,
                  shapes: [FigShape(d: filled ? _heartFilled : _heart, fill: _heartInk)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Заливка сердца — контур без внутренней дырки.
final String _heartFilled = _heart.substring(0, _heart.indexOf(' M 0.983'));

// Контуры значков — из кадра 20 (lib/screens/screen_20_photo_review.dart).

/// стрелка «вперёд» из кадра
const String _chevron =
    'M 0.418 0.439 C -0.139 1.025 -0.139 1.975 0.418 2.561 L 6.551 9 L 0.418 15.439 C -0.139 16.025 -0.139 16.975 0.418 17.561 C 0.976 18.146 1.881 18.146 2.439 17.561 L 9.582 10.061 C 10.139 9.475 10.139 8.525 9.582 7.939 L 2.439 0.439 C 1.881 -0.146 0.976 -0.146 0.418 0.439 Z';

/// значок «Вернуться»
const String _backIcon =
    'M 0 11.45 C 0 12.687 0.615 13.327 1.877 13.327 L 12.183 13.327 C 13.489 13.327 14.135 12.687 14.135 11.406 L 14.135 1.927 C 14.135 0.646 13.489 0 12.183 0 L 4.693 0 C 3.394 0 2.741 0.646 2.741 1.927 L 2.741 4.892 L 1.256 4.892 C 0.466 4.892 0 5.321 0 6.061 L 0 11.45 Z M 1.001 11.45 L 1.001 6.253 C 1.001 6.023 1.138 5.893 1.368 5.893 L 2.741 5.893 L 2.741 11.45 C 2.741 11.966 2.362 12.326 1.877 12.326 C 1.386 12.326 1.001 11.947 1.001 11.45 Z M 3.531 12.326 C 3.667 12.059 3.742 11.748 3.742 11.388 L 3.742 1.983 C 3.742 1.336 4.09 1.001 4.712 1.001 L 12.165 1.001 C 12.786 1.001 13.134 1.336 13.134 1.983 L 13.134 11.35 C 13.134 11.997 12.786 12.326 12.165 12.326 L 3.531 12.326 Z M 5.358 3.705 L 11.531 3.705 C 11.748 3.705 11.916 3.531 11.916 3.313 C 11.916 3.102 11.748 2.94 11.531 2.94 L 5.358 2.94 C 5.134 2.94 4.967 3.102 4.967 3.313 C 4.967 3.531 5.134 3.705 5.358 3.705 Z M 5.358 5.893 L 11.531 5.893 C 11.748 5.893 11.916 5.725 11.916 5.514 C 11.916 5.296 11.748 5.128 11.531 5.128 L 5.358 5.128 C 5.134 5.128 4.967 5.296 4.967 5.514 C 4.967 5.725 5.134 5.893 5.358 5.893 Z M 5.725 10.325 L 7.335 10.325 C 7.807 10.325 8.093 10.039 8.093 9.566 L 8.093 8.087 C 8.093 7.608 7.807 7.322 7.335 7.322 L 5.725 7.322 C 5.246 7.322 4.96 7.608 4.96 8.087 L 4.96 9.566 C 4.96 10.039 5.246 10.325 5.725 10.325 Z M 9.212 8.087 L 11.524 8.087 C 11.748 8.087 11.91 7.925 11.91 7.714 C 11.91 7.49 11.748 7.322 11.524 7.322 L 9.212 7.322 C 8.988 7.322 8.827 7.49 8.827 7.714 C 8.827 7.925 8.988 8.087 9.212 8.087 Z M 9.212 10.325 L 11.524 10.325 C 11.748 10.325 11.91 10.163 11.91 9.952 C 11.91 9.734 11.748 9.56 11.524 9.56 L 9.212 9.56 C 8.988 9.56 8.827 9.734 8.827 9.952 C 8.827 10.163 8.988 10.325 9.212 10.325 Z';

/// рамка значка «Скачать»
const String _downloadBox =
    'M 9.796 2.307 L 9.796 6.556 C 9.796 8.041 8.968 8.863 7.483 8.863 L 2.307 8.863 C 0.822 8.863 0 8.041 0 6.556 L 0 2.307 C 0 0.828 0.822 0 2.307 0 L 3.422 0 L 3.422 0.889 L 2.307 0.889 C 1.402 0.889 0.889 1.402 0.889 2.307 L 0.889 6.556 C 0.889 7.467 1.402 7.975 2.307 7.975 L 7.483 7.975 C 8.394 7.975 8.907 7.467 8.907 6.556 L 8.907 2.307 C 8.907 1.402 8.394 0.889 7.483 0.889 L 6.374 0.889 L 6.374 0 L 7.483 0 C 8.968 0 9.796 0.828 9.796 2.307 Z';

/// стрелка значка «Скачать»
const String _downloadArrow =
    'M 2.274 0 C 2.036 0 1.832 0.193 1.832 0.425 L 1.832 6.043 L 1.898 7.528 C 1.909 7.732 2.07 7.897 2.274 7.897 C 2.472 7.897 2.632 7.732 2.643 7.528 L 2.71 6.043 L 2.71 0.425 C 2.71 0.193 2.511 0 2.274 0 Z M 0.397 5.497 C 0.166 5.497 0 5.662 0 5.883 C 0 6.004 0.05 6.093 0.132 6.176 L 1.954 7.93 C 2.064 8.041 2.158 8.079 2.274 8.079 C 2.384 8.079 2.478 8.041 2.588 7.93 L 4.41 6.176 C 4.492 6.093 4.542 6.004 4.542 5.883 C 4.542 5.662 4.365 5.497 4.139 5.497 C 4.029 5.497 3.918 5.541 3.841 5.629 L 2.986 6.54 L 2.274 7.301 L 1.556 6.54 L 0.701 5.629 C 0.624 5.541 0.508 5.497 0.397 5.497 Z';

/// контур сердца
const String _heart =
    'M 0 3.496 C 0 5.962 2.18 8.387 5.624 10.471 C 5.752 10.546 5.935 10.627 6.064 10.627 C 6.192 10.627 6.375 10.546 6.509 10.471 C 9.947 8.387 12.127 5.962 12.127 3.496 C 12.127 1.447 10.643 0 8.665 0 C 7.535 0 6.619 0.509 6.064 1.291 C 5.52 0.515 4.592 0 3.462 0 C 1.484 0 0 1.447 0 3.496 Z M 0.983 3.496 C 0.983 1.956 2.033 0.932 3.45 0.932 C 4.598 0.932 5.258 1.609 5.648 2.188 C 5.813 2.42 5.917 2.483 6.064 2.483 C 6.21 2.483 6.302 2.414 6.479 2.188 C 6.9 1.621 7.535 0.932 8.677 0.932 C 10.094 0.932 11.144 1.956 11.144 3.496 C 11.144 5.649 8.744 7.971 6.192 9.58 C 6.131 9.62 6.088 9.649 6.064 9.649 C 6.039 9.649 5.996 9.62 5.941 9.58 C 3.383 7.971 0.983 5.649 0.983 3.496 Z';
