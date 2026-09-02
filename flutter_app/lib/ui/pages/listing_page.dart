// «Объект · полная» — кадр 19 макета с данными выбранного объекта.
//
// Кадр нарисован под «Технопарк»; приложение подставляет фотографию, цену,
// характеристики и метки выбранного объекта, включает сердце и делает
// кликабельными фото, «Фотообзор» и способ покупки.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
import '../../data/kind_fields.dart';
import '../../data/listings.dart';
import '../../fig/fig.dart';
import '../widgets/safe_image.dart';

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

  @override
  void didUpdateWidget(covariant ListingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      setState(() {
        _isLoading = true;
        _listing = null;
      });
      _loadListingDetails();
    }
  }

  Future<void> _loadListingDetails() async {
    final state = AppScope.read(context);
    var targetId = widget.id;

    try {
      if (targetId.isEmpty || targetId == 'technopark' || targetId == 'asanbay') {
        if (state.draftSlug != null && state.draftSlug!.isNotEmpty) {
          targetId = state.draftSlug!;
        } else {
          final listingsResp = await state.apiClient.getListings();
          final first = (listingsResp['results'] as List<dynamic>?)?.firstOrNull;
          if (first != null && first is Map && first['slug'] != null) {
            targetId = first['slug'].toString();
          }
        }
      }
      state.apiClient.recordListingView(targetId);
      final data = await state.apiClient.getListingDetails(targetId);
      if (mounted) {
        final parsed = Listing.fromJson(data);
        state.noteViewed(targetId, listing: parsed);
        setState(() {
          _listing = parsed;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('FAILED TO LOAD LISTING: $e\n$st');
      if (mounted) {
        setState(() {
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

  Widget _buildInfoRow(String label, String value, {bool isPlain = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: figStyle(
              fontSize: 15.0,
              family: FigFont.display,
              weight: 500,
              height: 1.333,
              color: const Color(0xff7d7d7d),
            ),
          ),
          Text(
            value,
            style: figStyle(
              fontSize: 15.0,
              family: FigFont.display,
              weight: 600,
              height: isPlain ? 1.0 : 1.333,
              color: const Color(0xff555555),
            ),
          ),
        ],
      ),
    );
  }

  double _computePinX(double? lon, double width) {
    if (lon == null) return width / 2 - 8;
    const minLon = 74.50;
    const maxLon = 74.70;
    final clamped = lon.clamp(minLon, maxLon);
    final norm = (clamped - minLon) / (maxLon - minLon);
    return (norm * (width - 40) + 12).clamp(16.0, width - 32.0);
  }

  double _computePinY(double? lat, double height) {
    if (lat == null) return height / 2 - 16;
    const minLat = 42.80;
    const maxLat = 42.90;
    final clamped = lat.clamp(minLat, maxLat);
    final norm = 1.0 - ((clamped - minLat) / (maxLat - minLat));
    return (norm * (height - 80) + 16).clamp(16.0, height - 60.0);
  }

  Widget _buildDynamicVideoCard(
    BuildContext context, {
    required ListingMedia? video,
    required int index,
    required Listing listing,
  }) {
    final title = (video?.title != null && video!.title!.isNotEmpty)
        ? video.title!
        : (index == 0
            ? 'Обзор квартиры'
            : (index == 1 ? 'Обзор местности' : 'Инфраструктура района'));

    String thumbUrl = video?.thumbnailUrl ?? '';
    if (thumbUrl.isEmpty && listing.photos.isNotEmpty) {
      final firstPhoto = listing.photos.first;
      if (firstPhoto.startsWith('http://') || firstPhoto.startsWith('https://')) {
        thumbUrl = firstPhoto;
      }
    }
    if (thumbUrl.startsWith('/')) {
      final baseUrl = AppScope.read(context).apiClient.baseUrl;
      final uri = Uri.tryParse(baseUrl);
      if (uri != null) {
        final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
        thumbUrl = '$origin$thumbUrl';
      }
    }

    String videoUrl = video?.url ?? '';
    if (videoUrl.startsWith('/')) {
      final baseUrl = AppScope.read(context).apiClient.baseUrl;
      final uri = Uri.tryParse(baseUrl);
      if (uri != null) {
        final origin = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
        videoUrl = '$origin$videoUrl';
      }
    }

    final hasRealMedia = (thumbUrl.startsWith('http://') || thumbUrl.startsWith('https://')) ||
        (videoUrl.startsWith('http://') || videoUrl.startsWith('https://'));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pushNamed(
          Routes.listingVideo,
          arguments: ListingArgs(listing.id, initialVideoIndex: index),
        );
      },
      child: SizedBox(
        width: 140.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 140.0,
              height: 200.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: const Color(0xff1c1b19),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _VideoCardThumbnail(
                    thumbnailUrl: thumbUrl,
                    videoUrl: videoUrl,
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0.018, 1.009),
                        end: Alignment(-0.018, -1.009),
                        colors: [Color(0x33000000), Color(0x00000000)],
                        stops: [0.243, 0.943],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 32.0,
                      height: 32.0,
                      decoration: const BoxDecoration(
                        color: Color(0x73000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xd9ffffff),
                        size: 22.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: figStyle(
                fontSize: 14.0,
                family: FigFont.display,
                weight: 500,
                height: 1.25,
                color: const Color(0xff7d7d7d),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _listing == null) {
      return const Scaffold(
        backgroundColor: _page,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xffea812e),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Загрузка объявления...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xff8e8e93),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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

    return Scaffold(
      backgroundColor: _page,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фотография объекта во всю ширину со стрелкой «Назад» и кнопкой «Избранное»
            Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pushNamed(
                    Routes.listingPhotos,
                    arguments: ListingArgs(listing.id),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 387.0,
                    child: (listing.photo.startsWith('http://') || listing.photo.startsWith('https://'))
                        ? buildSafeNetworkImage(
                            url: listing.photo,
                            fit: BoxFit.cover,
                            fallback: Container(
                              color: const Color(0xff2c2b2a),
                              child: const Center(
                                child: Icon(Icons.photo_outlined, color: Color(0xff8e8e93), size: 48),
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xff2c2b2a),
                            child: const Center(
                              child: Icon(Icons.photo_outlined, color: Color(0xff8e8e93), size: 48),
                            ),
                          ),
                  ),
                ),
                FigBackButton(
                  left: 25,
                  top: 48,
                  onLight: false,
                  onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(Routes.home, (r) => false),
                ),
                Positioned(
                  right: 25,
                  top: 48,
                  child: Semantics(
                    button: true,
                    label: favourite ? 'Убрать из избранного' : 'В избранное',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => state.toggleFavourite(listing.id),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xd9ffffff),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: FigSvg(
                            width: 15.0,
                            height: 13.0,
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
              ],
            ),

            const SizedBox(height: 16),

            // Метки (Собственник, Цена ниже рыночной, Красная книга)
            if (badges.isNotEmpty) ...[
              SizedBox(
                height: _badgesHeight,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  children: [
                    for (final badge in badges) ...[
                      _BadgeChip(badge),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Цена и характеристики
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    listing.price,
                    style: figStyle(
                      fontSize: 21.0,
                      family: FigFont.display,
                      weight: 600,
                      height: 1.0,
                      letterSpacing: -0.21,
                      color: const Color(0xff000000),
                    ),
                  ),
                  _Specs(listing: listing),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Описание объекта
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                listing.description,
                style: figStyle(
                  fontSize: 15.0,
                  family: FigFont.display,
                  weight: 500,
                  height: 1.333,
                  color: const Color(0xff7d7d7d),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Разделитель
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(height: 1.0, color: const Color(0x337d7d7d)),
            ),

            const SizedBox(height: 16),

            // Карта, адрес и точка на карте
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 214,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/figma/f36bc748a320b1d4.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(color: const Color(0x0d000000)),
                      ),
                      Positioned(
                        left: _computePinX(listing.longitude, 325),
                        top: _computePinY(listing.latitude, 214),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xffea812e),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 15,
                        bottom: 12,
                        right: 15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xffffffff),
                            borderRadius: BorderRadius.circular(8.0),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1a000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            listing.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: figStyle(
                              fontSize: 14.0,
                              family: FigFont.display,
                              weight: 600,
                              height: 1.2,
                              color: const Color(0xff000000),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Ключевые места
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                'Ключевые места',
                style: figStyle(
                  fontSize: 15.0,
                  family: FigFont.display,
                  weight: 500,
                  height: 1.333,
                  color: const Color(0xff7d7d7d),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  for (final place in (listing.landmarks.isNotEmpty ? listing.landmarks : const ['Школа 56', 'Магистраль-Бакаева', 'Клиника Эскулап'])) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x33ea812e),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        place,
                        style: figStyle(
                          fontSize: 13.0,
                          family: FigFont.display,
                          weight: 500,
                          height: 1.077,
                          letterSpacing: 0.065,
                          color: const Color(0xe0ea812e),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Разделитель
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(height: 1.0, color: const Color(0x337d7d7d)),
            ),

            const SizedBox(height: 16),

            // Общая информация (динамический список комнат без лишнего пустого пространства снизу)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Общая информация',
                    style: figStyle(
                      fontSize: 17.0,
                      family: FigFont.display,
                      weight: 600,
                      height: 1.176,
                      color: const Color(0xff000000),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('Общая квадратура', '${listing.area}м²'),
                  for (final room in listing.roomsBreakdown)
                    _buildInfoRow(room.name, '${room.area.toStringAsFixed(0)}м²'),
                  if (showsField(listing.kind, ListingField.interior))
                    _buildInfoRow('Мебель', listing.furniture.isNotEmpty ? listing.furniture : 'Полностью', isPlain: true),
                  // Фолбэка «из 12» здесь быть не должно: у участка этажей нет
                  // вообще, а у дома их столько, сколько указал владелец.
                  if (showsField(listing.kind, ListingField.floor) && listing.floors > 0)
                    _buildInfoRow('Этаж', '${listing.floor} из ${listing.floors}', isPlain: true),
                  if (showsField(listing.kind, ListingField.landArea) && listing.landArea != null)
                    _buildInfoRow('Площадь участка', '${listing.landArea!.toStringAsFixed(0)} соток', isPlain: true),
                  if (listing.plotPurpose.isNotEmpty)
                    _buildInfoRow('Назначение', plotPurposeLabels[listing.plotPurpose] ?? listing.plotPurpose, isPlain: true),
                  if (listing.commercialPurpose.isNotEmpty)
                    _buildInfoRow('Назначение', commercialPurposeLabels[listing.commercialPurpose] ?? listing.commercialPurpose, isPlain: true),
                  if (listing.buildingLine.isNotEmpty)
                    _buildInfoRow('Линия', buildingLineLabels[listing.buildingLine] ?? listing.buildingLine, isPlain: true),
                  if (showsField(listing.kind, ListingField.separateEntrance))
                    _buildInfoRow('Отдельный вход', listing.hasSeparateEntrance ? 'Есть' : 'Нет', isPlain: true),
                  if (listing.ceilingHeight != null)
                    _buildInfoRow('Высота потолков', '${listing.ceilingHeight} м', isPlain: true),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Разделитель — сразу под последней строкой общей информации!
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(height: 1.0, color: const Color(0x337d7d7d)),
            ),

            const SizedBox(height: 16),

            // Варианты покупки
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Варианты покупки',
                    style: figStyle(
                      fontSize: 17.0,
                      family: FigFont.display,
                      weight: 600,
                      height: 1.176,
                      color: const Color(0xff000000),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (listing.hasDirectSale) ...[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _useMortgage = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: !_useMortgage ? const Color(0xfffdf1e8) : const Color(0xffffffff),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: !_useMortgage ? const Color(0x00000000) : const Color(0xffe5e5ea),
                                width: 1.0,
                              ),
                            ),
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
                      ],
                      if (listing.hasMortgage) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _useMortgage = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _useMortgage ? const Color(0xfffdf1e8) : const Color(0xffffffff),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: _useMortgage ? const Color(0x00000000) : const Color(0xffe5e5ea),
                                width: 1.0,
                              ),
                            ),
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    listing.price,
                    style: figStyle(
                      fontSize: 21.0,
                      family: FigFont.display,
                      weight: 600,
                      height: 1.0,
                      letterSpacing: -0.21,
                      color: const Color(0xff000000),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Можно сторговаться',
                    style: figStyle(
                      fontSize: 15.0,
                      family: FigFont.display,
                      weight: 500,
                      height: 1.333,
                      color: const Color(0xff7d7d7d),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Разделитель
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Container(height: 1.0, color: const Color(0x337d7d7d)),
            ),

            const SizedBox(height: 16),

            // Видеообзор
            if (listing.videos.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'Видеообзор',
                  style: figStyle(
                    fontSize: 17.0,
                    family: FigFont.display,
                    weight: 600,
                    height: 1.176,
                    color: const Color(0xff000000),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  children: [
                    for (int i = 0; i < listing.videos.length; i++) ...[
                      if (i > 0) const SizedBox(width: 15),
                      _buildDynamicVideoCard(
                        context,
                        video: listing.videos[i],
                        index: i,
                        listing: listing,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Фотообзор
            if (listing.photos.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Text(
                  'Фотообзор',
                  style: figStyle(
                    fontSize: 17.0,
                    family: FigFont.display,
                    weight: 600,
                    height: 1.176,
                    color: const Color(0xff000000),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: _thumbSize,
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
                          child: (photo.startsWith('http://') || photo.startsWith('https://'))
                              ? buildSafeNetworkImage(
                                  url: photo,
                                  fit: BoxFit.cover,
                                  borderRadius: BorderRadius.circular(6.0),
                                  fallback: const ColoredBox(
                                    color: Color(0xfff0f0f0),
                                  ),
                                )
                              : const ColoredBox(
                                  color: Color(0xfff0f0f0),
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 50),
          ],
        ),
      ),
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

    // Подставлять «3-комн.» и «8 этаж» там, где их нет, нельзя: это выдуманные
    // данные. Показываем только то, что применимо к типу объекта.
    final showRooms =
        showsField(listing.kind, ListingField.rooms) && listing.roomsLabel.isNotEmpty;
    final showFloor =
        showsField(listing.kind, ListingField.floor) && listing.floorLong.isNotEmpty;
    final showLand =
        showsField(listing.kind, ListingField.landArea) && listing.landArea != null;
    final String area = listing.areaLabel;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 7,
      children: [
        if (showRooms) ...[
          FigText(noWrap: true, span: TextSpan(text: listing.roomsLabel, style: style)),
          const _Dot(),
        ],
        FigText(
          span: TextSpan(
            style: style,
            children: [
              TextSpan(text: area, style: style),
              figSuper('2', figStyle(fontSize: 9.36, color: _spec), 13.0),
            ],
          ),
        ),
        if (showLand) ...[
          const _Dot(),
          FigText(
            noWrap: true,
            span: TextSpan(
              text: '${listing.landArea!.toStringAsFixed(0)} сот.',
              style: style,
            ),
          ),
        ],
        if (showFloor) ...[
          const _Dot(),
          FigText(noWrap: true, span: TextSpan(text: listing.floorLong, style: style)),
        ],
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

class _VideoCardThumbnail extends StatefulWidget {
  const _VideoCardThumbnail({
    required this.thumbnailUrl,
    required this.videoUrl,
  });

  final String thumbnailUrl;
  final String videoUrl;

  @override
  State<_VideoCardThumbnail> createState() => _VideoCardThumbnailState();
}

class _VideoCardThumbnailState extends State<_VideoCardThumbnail> {
  VideoPlayerController? _controller;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    if (widget.thumbnailUrl.isEmpty && widget.videoUrl.isNotEmpty) {
      _initVideoFrame();
    }
  }

  @override
  void didUpdateWidget(covariant _VideoCardThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thumbnailUrl.isEmpty && widget.videoUrl != oldWidget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInit = false;
      if (widget.videoUrl.isNotEmpty) {
        _initVideoFrame();
      }
    }
  }

  Future<void> _initVideoFrame() async {
    final rawUrl = widget.videoUrl;
    try {
      final uri = Uri.tryParse(rawUrl);
      if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
        _controller = VideoPlayerController.networkUrl(uri);
      } else if (kIsWeb) {
        final webUri = Uri.base.resolve(rawUrl.startsWith('assets/') ? rawUrl : 'assets/$rawUrl');
        _controller = VideoPlayerController.networkUrl(webUri);
      } else {
        _controller = VideoPlayerController.asset(rawUrl);
      }
      await _controller!.initialize();
      await _controller!.setVolume(0.0);
      await _controller!.pause();
      if (mounted) {
        setState(() => _isInit = true);
      }
    } catch (e) {
      debugPrint('Error generating video thumbnail from frame: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thumbnailUrl.isNotEmpty) {
      final isNet = widget.thumbnailUrl.startsWith('http://') || widget.thumbnailUrl.startsWith('https://');
      if (isNet) {
        return buildSafeNetworkImage(
          url: widget.thumbnailUrl,
          fit: BoxFit.cover,
          fallback: const ColoredBox(color: Color(0xff222222)),
        );
      }
    }

    if (_isInit && _controller != null) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 140,
          height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 200,
          child: VideoPlayer(_controller!),
        ),
      );
    }

    return const ColoredBox(
      color: Color(0xff222222),
      child: Center(
        child: Icon(
          Icons.videocam_outlined,
          color: Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}
