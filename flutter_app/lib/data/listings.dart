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
  room('Квартиры'),
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
class ListingMedia {
  const ListingMedia({
    required this.url,
    this.thumbnailUrl,
    this.title,
    this.description,
  });

  final String url;
  final String? thumbnailUrl;
  final String? title;
  final String? description;

  factory ListingMedia.fromJson(Map<String, dynamic> json) {
    var u = (json['url'] ?? json['file'] ?? json['url_original'] ?? '').toString();
    var thumb = (json['thumbnail_url'] ?? json['url_thumb'] ?? json['thumbnail'] ?? json['url_medium'])?.toString();
    if (u.startsWith('/')) {
      u = 'https://adilhan1234.pythonanywhere.com$u';
    }
    if (thumb != null && thumb.startsWith('/')) {
      thumb = 'https://adilhan1234.pythonanywhere.com$thumb';
    }
    return ListingMedia(
      url: u,
      thumbnailUrl: thumb,
      title: json['title'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      };
}

@immutable
class ListingRoom {
  const ListingRoom({
    required this.name,
    required this.area,
    this.order = 0,
  });

  final String name;
  final double area;
  final int order;

  factory ListingRoom.fromJson(Map<String, dynamic> json) {
    double parseArea(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseOrder(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return ListingRoom(
      name: json['name']?.toString() ?? '',
      area: parseArea(json['area']),
      order: parseOrder(json['order']),
    );
  }
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
    this.slug = '',
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
    this.videos = const [],
    this.viewsCount = 0,
    this.sellerPhone,
    this.isFavourite = false,
    this.livingRoomArea,
    this.hallArea,
    this.kitchenArea,
    this.bedroomArea,
    this.bedroom2Area,
    this.balconyArea,
    this.bathroomArea,
    this.furniture = 'Полностью',
    List<String>? landmarks,
    this.latitude,
    this.longitude,
    this.hasDirectSale = true,
    this.hasMortgage = true,
    List<ListingRoom>? roomsBreakdown,
    this.viewedAt,
  })  : _landmarks = landmarks,
        _roomsBreakdown = roomsBreakdown;

  final String slug;
  String get coverPhoto => photo;
  String get videoUrl => videos.isNotEmpty ? videos.first.url : '';

  factory Listing.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return double.tryParse(val)?.toInt() ?? int.tryParse(val) ?? 0;
      return 0;
    }

    int? parseIntOrNull(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      if (val is String) return double.tryParse(val)?.toInt() ?? int.tryParse(val);
      return null;
    }

    double? parseDoubleOrNull(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    final districtName = (json['district'] != null && json['district'] is Map) 
        ? json['district']['name'] as String? ?? 'Неизвестно' 
        : 'Неизвестно';
    final slug = json['slug'] as String? ?? json['id']?.toString() ?? '';

    String pickPhoto(dynamic coverUrl) {
      if (coverUrl != null && coverUrl.toString().isNotEmpty) {
        return coverUrl.toString();
      }
      final d = districtName.toLowerCase();
      final s = slug.toLowerCase();
      if (d.contains('асанбай') || s.contains('asanbay')) {
        return ListingPhotos.asanbay;
      }
      if (d.contains('южные') || s.contains('yuzhnye') || s.contains('house')) {
        return ListingPhotos.villa;
      }
      return ListingPhotos.technopark;
    }

    final mediaList = (json['media'] as List<dynamic>?) ?? [];
    final photoUrls = <String>[];
    for (final m in mediaList) {
      if (m is Map) {
        final kind = m['kind']?.toString();
        final isVideo = kind == 'video' || m['is_video'] == true;
        if (!isVideo) {
          final u = m['url_original'] ?? m['url_medium'] ?? m['url'] ?? m['file'] ?? m['url_thumb'] ?? m['image'];
          if (u != null && u.toString().isNotEmpty) {
            var str = u.toString();
            if (str.startsWith('/')) {
              str = 'https://adilhan1234.pythonanywhere.com$str';
            }
            if (!photoUrls.contains(str)) {
              photoUrls.add(str);
            }
          }
        }
      }
    }

    if (json['photos'] is List) {
      for (final p in json['photos']) {
        if (p is String && p.isNotEmpty) {
          var str = p;
          if (str.startsWith('/')) str = 'https://adilhan1234.pythonanywhere.com$str';
          if (!photoUrls.contains(str)) photoUrls.add(str);
        } else if (p is Map) {
          final u = p['url_original'] ?? p['url_medium'] ?? p['url'] ?? p['file'] ?? p['url_thumb'] ?? p['image'];
          if (u != null && u.toString().isNotEmpty) {
            var str = u.toString();
            if (str.startsWith('/')) str = 'https://adilhan1234.pythonanywhere.com$str';
            if (!photoUrls.contains(str)) photoUrls.add(str);
          }
        }
      }
    }

    final coverVal = json['cover_url'] ?? json['photo'];
    if (coverVal != null && coverVal.toString().isNotEmpty) {
      var str = coverVal.toString();
      if (str.startsWith('/')) str = 'https://adilhan1234.pythonanywhere.com$str';
      if (!photoUrls.contains(str)) {
        photoUrls.insert(0, str);
      }
    }

    final String photo;
    final List<String> morePhotos;
    if (photoUrls.isNotEmpty) {
      photo = photoUrls.first;
      morePhotos = photoUrls.skip(1).toList();
    } else {
      photo = pickPhoto(json['cover_url'] ?? json['photo']);
      morePhotos = const <String>[];
    }

    final sellerMap = json['seller'] as Map?;
    final ownerMap = json['owner'] as Map?;
    final sellerName = sellerMap?['name'] as String? ?? ownerMap?['name'] as String? ?? 'Адилхан Сатымкулов';

    final roomsBreakdownRaw = json['rooms_breakdown'] as List<dynamic>?;
    final List<ListingRoom> parsedRooms;
    if (roomsBreakdownRaw != null && roomsBreakdownRaw.isNotEmpty) {
      parsedRooms = roomsBreakdownRaw
          .whereType<Map>()
          .map((m) => ListingRoom.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } else {
      final legacyList = <ListingRoom>[];
      if (json['living_room_area'] != null) {
        legacyList.add(ListingRoom(name: 'Гостинная', area: parseDoubleOrNull(json['living_room_area']) ?? 35.0));
      }
      if (json['hall_area'] != null) {
        legacyList.add(ListingRoom(name: 'Холл', area: parseDoubleOrNull(json['hall_area']) ?? 23.0));
      }
      if (json['kitchen_area'] != null) {
        legacyList.add(ListingRoom(name: 'Кухня', area: parseDoubleOrNull(json['kitchen_area']) ?? 17.0));
      }
      if (json['bedroom_area'] != null) {
        legacyList.add(ListingRoom(name: 'Спальная', area: parseDoubleOrNull(json['bedroom_area']) ?? 25.0));
      }
      if (json['bedroom_2_area'] != null) {
        legacyList.add(ListingRoom(name: 'Спальная 2', area: parseDoubleOrNull(json['bedroom_2_area']) ?? 15.0));
      }
      if (json['balcony_area'] != null) {
        legacyList.add(ListingRoom(name: 'Балкон', area: parseDoubleOrNull(json['balcony_area']) ?? 7.0));
      }
      if (json['bathroom_area'] != null) {
        legacyList.add(ListingRoom(name: 'Сан.узел', area: parseDoubleOrNull(json['bathroom_area']) ?? 10.0));
      }
      if (legacyList.isNotEmpty) {
        parsedRooms = legacyList;
      } else {
        parsedRooms = const [
          ListingRoom(name: 'Гостинная', area: 35.0),
          ListingRoom(name: 'Холл', area: 23.0),
          ListingRoom(name: 'Кухня', area: 17.0),
          ListingRoom(name: 'Спальная', area: 25.0),
          ListingRoom(name: 'Спальная 2', area: 15.0),
          ListingRoom(name: 'Балкон', area: 7.0),
          ListingRoom(name: 'Сан.узел', area: 10.0),
        ];
      }
    }

    return Listing(
      id: slug,
      slug: slug,
      district: districtName,
      priceUsd: parseInt(json['price'] ?? json['price_usd']),
      oldPriceUsd: parseIntOrNull(json['old_price']),
      rooms: parseInt(json['rooms']),
      area: parseInt(json['area']),
      floor: parseInt(json['floor']),
      floors: parseInt(json['floors']),
      photo: photo,
      more: morePhotos,
      agent: sellerName,
      kind: PropertyKind.values.firstWhere(
        (e) => e.name == json['kind'] || (e == PropertyKind.newBuilding && json['kind'] == 'new_building'),
        orElse: () => PropertyKind.apartment,
      ),
      seller: SellerKind.values.firstWhere(
        (e) => e.name == json['seller_kind'],
        orElse: () => SellerKind.owner,
      ),
      secondary: json['is_secondary'] as bool? ?? false,
      series: json['series_code'] as String?,
      belowMarket: json['below_market'] as bool? ?? false,
      redBook: json['red_book'] as bool? ?? false,
      description: json['description'] as String? ?? kFillerDescription,
      address: json['address'] as String? ?? 'Бишкек, Октябрьский район,\nул.Бакаева 178/4',
      viewsCount: parseInt(json['views_count']),
      sellerPhone: sellerMap?['phone'] as String? ?? sellerMap?['phone_number'] as String? ?? ownerMap?['phone'] as String?,
      videos: ((json['videos'] as List<dynamic>?) ??
              (json['media'] as List<dynamic>?)
                  ?.where((m) => m is Map && m['kind'] == 'video')
                  .toList())
          ?.map((e) => ListingMedia.fromJson(e as Map<String, dynamic>))
          .toList() ??
          const [],
      isFavourite: json['is_favourite'] as bool? ?? false,
      livingRoomArea: parseDoubleOrNull(json['living_room_area']),
      hallArea: parseDoubleOrNull(json['hall_area']),
      kitchenArea: parseDoubleOrNull(json['kitchen_area']),
      bedroomArea: parseDoubleOrNull(json['bedroom_area']),
      bedroom2Area: parseDoubleOrNull(json['bedroom_2_area']),
      balconyArea: parseDoubleOrNull(json['balcony_area']),
      bathroomArea: parseDoubleOrNull(json['bathroom_area']),
      landmarks: (json['landmarks'] is List && (json['landmarks'] as List).isNotEmpty)
          ? (json['landmarks'] as List)
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .cast<String>()
              .toList()
          : const ['Школа 56', 'Магистраль-Бакаева', 'Клиника Эскулап'],
      latitude: parseDoubleOrNull(json['latitude']),
      longitude: parseDoubleOrNull(json['longitude']),
      hasDirectSale: json['has_direct_sale'] as bool? ?? true,
      hasMortgage: json['has_mortgage'] as bool? ?? true,
      roomsBreakdown: parsedRooms,
      viewedAt: json['viewed_at'] != null
          ? DateTime.tryParse(json['viewed_at'].toString())?.toLocal()
          : null,
    );
  }

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
  final bool isFavourite;

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

  /// Описание объекта.
  final String description;

  /// Остальные фотографии «Фотообзора» — первой идёт [photo].
  final List<String> more;

  /// Видео и их метаданные (Reels)
  final List<ListingMedia> videos;

  final int viewsCount;
  final String? sellerPhone;

  final double? livingRoomArea;
  final double? hallArea;
  final double? kitchenArea;
  final double? bedroomArea;
  final double? bedroom2Area;
  final double? balconyArea;
  final double? bathroomArea;
  final String furniture;
  final List<String>? _landmarks;
  final double? latitude;
  final double? longitude;
  final bool hasDirectSale;
  final bool hasMortgage;
  final List<ListingRoom>? _roomsBreakdown;
  final DateTime? viewedAt;

  List<String> get landmarks => (_landmarks != null && _landmarks!.isNotEmpty)
      ? _landmarks!
      : const ['Школа 56', 'Магистраль-Бакаева', 'Клиника Эскулап'];

  List<ListingRoom> get roomsBreakdown => _roomsBreakdown ?? const [];

  List<String> get photos {
    final list = <String>[];
    if (photo.isNotEmpty) list.add(photo);
    for (final m in more) {
      if (!list.contains(m)) list.add(m);
    }
    if (list.isEmpty) {
      list.add(ListingPhotos.technopark);
    }
    return list;
  }

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
