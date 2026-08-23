// Данные каталога. Два объекта — «Технопарк» и «Асанбай» — взяты из макета
// вместе с их фотографиями, ценами и характеристиками; остальные добавлены,
// чтобы поиску и фильтру было что фильтровать, и собраны из тех же фотографий
// и того же набора полей.
import 'package:flutter/foundation.dart';

/// «12 000» — тысячи через пробел, как в макете.
String thousands(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Категории с «Главной» и чипы «Фильтра» — один список.
enum PropertyKind {
  house('Дома'),
  apartment('Квартиры'),
  plot('Участки'),
  newBuilding('Новостройки'),
  room('Комната'),
  commercial('Коммерция');

  const PropertyKind(this.label);
  final String label;
}

/// Кто продаёт — три тумблера «Продавца» в «Фильтре».
enum SellerKind {
  owner('Только собственник'),
  realtor('Риелторы'),
  agency('Агенство недвижимости');

  const SellerKind(this.label);

  /// Подпись — как в макете, вместе с его опечаткой в «агенстве».
  final String label;
}

@immutable
class Listing {
  const Listing({
    required this.id,
    required this.district,
    required this.priceUsd,
    required this.rooms,
    required this.area,
    required this.floor,
    required this.floors,
    required this.photo,
    required this.kind,
    this.seller = SellerKind.owner,
    this.secondary = false,
    this.series,
    this.belowMarket = false,
    this.redBook = false,
    this.oldPriceUsd,
    this.address = 'Бишкек, Октябрьский район,\nул.Бакаева 178/4',
    this.agent = 'Садыр Жапаров',
    this.description = kFillerDescription,
    this.more = const [ListingPhotos.livingRoom, ListingPhotos.terrace],
  });

  final String id;
  final String district;
  final int priceUsd;
  final int rooms;
  final int area;
  final int floor;
  final int floors;
  final String photo;
  final PropertyKind kind;
  final SellerKind seller;

  /// «Вторичка» — жильё не в новостройке.
  final bool secondary;

  /// Серия дома: «103», «105». Чип «103 серия» ищет её.
  final String? series;
  final bool belowMarket;
  final bool redBook;
  final int? oldPriceUsd;
  final String address;

  /// Кто показывает объект — подпись под фотографией в «Фотообзоре».
  final String agent;

  /// Описание объекта. В макете у всех объектов один и тот же текст-рыба.
  final String description;

  /// Остальные фотографии «Фотообзора» — первой идёт [photo].
  final List<String> more;

  List<String> get photos => [photo, ...more];

  bool get owner => seller == SellerKind.owner;

  /// У участка нет комнат и этажей — строка характеристик короче.
  bool get isPlot => kind == PropertyKind.plot;

  /// «102 000$» — как в макете: тысячи через неразрывный пробел.
  String get price => '${thousands(priceUsd)}\$';
  String? get oldPrice => oldPriceUsd == null ? null : '${thousands(oldPriceUsd!)}\$';
  String get roomsLabel => '$rooms-комн.';
  String get areaLabel => '$areaм';
  String get floorLabel => '$floor эт.';
  String get floorLong => '$floor этаж';
  String get floorOfLabel => '$floor из $floors';

  static String _thousands(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

/// Текст-рыба из макета — им подписан каждый объект прототипа.
const String kFillerDescription =
    'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам '
    'планета в Солнечной системе после Юпитера.';

/// Фотографии из макета — те же файлы, что стоят в карточках.
abstract final class ListingPhotos {
  static const technopark = 'assets/figma/92b0d143df96c511.jpg';
  static const asanbay = 'assets/figma/2e62acec850fa8b9.jpg';
  static const livingRoom = 'assets/figma/e267d094d7f9a8fc.jpg';
  static const villa = 'assets/figma/ccc665cff0c465a4.jpg';
  static const night = 'assets/figma/b76192aa900c610a.jpg';
  static const terrace = 'assets/figma/231c034e3954a705.jpg';
  static const bedroom = 'assets/figma/b9c2288b4b961f66.jpg';
  static const hall = 'assets/figma/74ca11e3a68b83c9.jpg';
}

const List<Listing> kListings = [
  // из макета
  Listing(
    id: 'technopark',
    district: 'Технопарк',
    priceUsd: 102000,
    oldPriceUsd: 107000,
    rooms: 3,
    area: 92,
    floor: 8,
    floors: 12,
    photo: ListingPhotos.technopark,
    kind: PropertyKind.apartment,
    secondary: true,
    series: '103',
    belowMarket: true,
    redBook: true,
    more: [ListingPhotos.livingRoom, ListingPhotos.bedroom, ListingPhotos.hall],
  ),
  Listing(
    id: 'asanbay',
    district: 'Асанбай',
    priceUsd: 92850,
    rooms: 3,
    area: 92,
    floor: 8,
    floors: 12,
    photo: ListingPhotos.asanbay,
    kind: PropertyKind.apartment,
    secondary: true,
    series: '105',
    more: [ListingPhotos.terrace, ListingPhotos.night],
  ),
  // добавлены для поиска и фильтра
  Listing(
    id: 'djal',
    district: 'Джал',
    priceUsd: 78400,
    rooms: 2,
    area: 70,
    floor: 5,
    floors: 9,
    photo: ListingPhotos.livingRoom,
    kind: PropertyKind.newBuilding,
    belowMarket: true,
  ),
  Listing(
    id: 'vostok',
    district: 'Восток-5',
    priceUsd: 54300,
    rooms: 1,
    area: 45,
    floor: 3,
    floors: 5,
    photo: ListingPhotos.bedroom,
    kind: PropertyKind.room,
    seller: SellerKind.realtor,
    secondary: true,
    series: '103',
  ),
  Listing(
    id: 'kok-jar',
    district: 'Кок-Жар',
    priceUsd: 189000,
    rooms: 5,
    area: 210,
    floor: 2,
    floors: 2,
    photo: ListingPhotos.villa,
    kind: PropertyKind.house,
    secondary: true,
    redBook: true,
    more: [ListingPhotos.terrace, ListingPhotos.hall],
  ),
  Listing(
    id: 'yug-2',
    district: 'Юг-2',
    priceUsd: 96500,
    rooms: 3,
    area: 80,
    floor: 6,
    floors: 10,
    photo: ListingPhotos.night,
    kind: PropertyKind.newBuilding,
  ),
  Listing(
    id: 'center',
    district: 'Центр',
    priceUsd: 143000,
    rooms: 4,
    area: 118,
    floor: 9,
    floors: 14,
    photo: ListingPhotos.terrace,
    kind: PropertyKind.apartment,
    seller: SellerKind.agency,
    secondary: true,
    redBook: true,
  ),
  Listing(
    id: 'orto-say',
    district: 'Орто-Сай',
    priceUsd: 45000,
    rooms: 0,
    area: 600,
    floor: 0,
    floors: 0,
    photo: ListingPhotos.villa,
    kind: PropertyKind.plot,
  ),
  Listing(
    id: 'baytik',
    district: 'Байтик',
    priceUsd: 120000,
    rooms: 0,
    area: 1200,
    floor: 0,
    floors: 0,
    photo: ListingPhotos.terrace,
    kind: PropertyKind.plot,
    redBook: true,
  ),
  Listing(
    id: 'chui',
    district: 'Чуй-Манаса',
    priceUsd: 61200,
    rooms: 2,
    area: 52,
    floor: 4,
    floors: 9,
    photo: ListingPhotos.hall,
    kind: PropertyKind.commercial,
    seller: SellerKind.agency,
    secondary: true,
    belowMarket: true,
  ),
];

/// Диапазон «Квадратуры». Четыре из них нарисованы чипами в «Фильтре»,
/// пятый — то, что вводят в поле «Введите свою квадратуру».
@immutable
class AreaRange {
  const AreaRange(this.from, this.to);

  final int from;
  final int to;

  String get label => '$from-$to';
  bool has(int area) => area >= from && area <= to;

  /// «60-80» — диапазон, «60» — «от 60».
  static AreaRange? parse(String text) {
    final parts = text.split('-').map((s) => int.tryParse(s.trim())).toList();
    if (parts.isEmpty || parts.first == null) return null;
    if (parts.length == 1) return AreaRange(parts.first!, 1 << 30);
    if (parts.length > 2 || parts[1] == null) return null;
    return AreaRange(parts.first!, parts[1]!);
  }

  @override
  bool operator ==(Object other) =>
      other is AreaRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Чипы «Квадратуры» из макета.
const List<AreaRange> kAreaRanges = [
  AreaRange(35, 45),
  AreaRange(45, 55),
  AreaRange(65, 75),
  AreaRange(75, 85),
];

Listing listingById(String id) =>
    kListings.firstWhere((l) => l.id == id, orElse: () => kListings.first);
