// Сборка тела запроса для черновика объявления — одна на все формы.
//
// Раньше форма создания и форма редактирования собирали payload независимо,
// каждая своим набором строковых ключей. Из-за этого редактирование годами
// отправляло `floors_total` вместо `floors` (DRF молча игнорирует неизвестные
// ключи, запрос возвращает 200, этажность не сохраняется) и ещё пять полей,
// которых в API не существует. Здесь ключи объявлены один раз; тест
// `test_listing_payload_keys` сверяет их со списком полей
// `ListingUpdateSerializer` на бэкенде.
import 'kind_fields.dart';
import 'listings.dart';

/// Код типа недвижимости для API. `PropertyKind.name` не подходит:
/// `newBuilding` должен уехать как `new_building`.
String propertyKindCode(PropertyKind kind) => switch (kind) {
      PropertyKind.house => 'house',
      PropertyKind.apartment => 'apartment',
      PropertyKind.plot => 'plot',
      PropertyKind.newBuilding => 'new_building',
      PropertyKind.room => 'room',
      PropertyKind.commercial => 'commercial',
    };

/// Собирает тело PATCH/POST для черновика.
///
/// Значения, неприменимые к типу, не отправляются: сервер их всё равно
/// отбросит (`apps/catalog/field_rules.py`), но и мусора в запросе быть не
/// должно. Пустые строки тоже опускаются — иначе заполненное поле затрётся
/// пустым при частичном сохранении формы.
Map<String, dynamic> buildListingPayload({
  required PropertyKind kind,
  String? districtSlug,
  String? address,
  String? description,
  bool? usd,
  String? sellerKind,
  num? price,
  num? area,
  String? landArea,
  int? rooms,
  int? floor,
  int? floors,
  String? seriesCode,
  String? builderSlug,
  bool? isSecondary,
  String? furniture,
  String? condition,
  String? heating,
  bool? hasGas,
  bool? exchangePossible,
  bool? hasDirectSale,
  bool? hasMortgage,
  String? plotPurpose,
  String? commercialPurpose,
  bool? separateEntrance,
  String? buildingLine,
  String? ceilingHeight,
  String? contactName,
  String? contactPhone,
  List<String>? landmarks,
  Map<String, String>? roomAreas,
}) {
  final data = <String, dynamic>{'kind': propertyKindCode(kind)};

  void put(String key, Object? value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    data[key] = value is String ? value.trim() : value;
  }

  /// Кладёт значение, только если поле применимо к типу.
  void putIf(ListingField field, String key, Object? value) {
    if (!showsField(kind, field)) return;
    put(key, value);
  }

  put('district', districtSlug);
  put('address', address);
  put('description', description);
  put('price', price);
  put('area', area);
  put('contact_name', contactName);
  put('contact_phone', contactPhone);
  if (usd != null) data['currency'] = usd ? 'USD' : 'KGS';
  put('seller_kind', sellerKind);
  if (hasDirectSale != null) data['has_direct_sale'] = hasDirectSale;
  if (hasMortgage != null) data['has_mortgage'] = hasMortgage;
  if (landmarks != null) {
    data['landmarks'] = landmarks.where((l) => l.trim().isNotEmpty).toList();
  }

  putIf(ListingField.rooms, 'rooms', rooms);
  putIf(ListingField.floor, 'floor', floor);
  putIf(ListingField.floors, 'floors', floors);
  putIf(ListingField.series, 'series', seriesCode);
  putIf(ListingField.builder, 'builder', builderSlug);
  putIf(ListingField.landArea, 'land_area', landArea);
  putIf(ListingField.plotPurpose, 'plot_purpose', plotPurpose);
  putIf(ListingField.commercialPurpose, 'commercial_purpose', commercialPurpose);
  putIf(ListingField.buildingLine, 'building_line', buildingLine);
  putIf(ListingField.ceilingHeight, 'ceiling_height', ceilingHeight);

  if (isSecondary != null && showsField(kind, ListingField.isSecondary)) {
    data['is_secondary'] = isSecondary;
  }
  if (separateEntrance != null && showsField(kind, ListingField.separateEntrance)) {
    data['has_separate_entrance'] = separateEntrance;
  }
  if (exchangePossible != null && showsField(kind, ListingField.exchange)) {
    data['exchange_possible'] = exchangePossible;
  }

  if (showsField(kind, ListingField.interior)) {
    put('furniture', furniture);
    put('condition', condition);
    put('heating', heating);
    if (hasGas != null) data['has_gas'] = hasGas;
    roomAreas?.forEach(put);
  }

  return data;
}

/// Ключи площадей комнат — те же имена, что в модели.
const Map<String, String> roomAreaLabels = {
  'living_room_area': 'Гостиная',
  'hall_area': 'Холл',
  'kitchen_area': 'Кухня',
  'bedroom_area': 'Спальная',
  'bedroom_2_area': 'Спальная 2',
  'balcony_area': 'Балкон',
  'bathroom_area': 'Сан.узел',
};

/// Подписи меблировки — значения совпадают с `FurnitureKind` на бэкенде.
const Map<String, String> furnitureLabels = {
  'full': 'Полностью меблирована',
  'partial': 'Частично с мебелью',
  'none': 'Без мебели',
};

/// Подписи состояния — значения совпадают с `ListingCondition`.
const Map<String, String> conditionLabels = {
  'euro': 'Евроремонт',
  'good': 'Хорошее состояние',
  'shell': 'Под самоотделку',
  'medium': 'Среднее состояние',
  'none': 'Без ремонта',
};

/// Подписи отопления — значения совпадают с `HeatingKind`.
const Map<String, String> heatingLabels = {
  'central': 'Центральное',
  'gas': 'Газовое',
  'electric': 'Электрическое',
  'autonomous': 'Автономное',
};
