// Какие поля объявления применимы к какому типу недвижимости.
//
// Зеркало серверной таблицы `backend/apps/catalog/field_rules.py`: при правке
// здесь правьте и там. Клиент держит копию, чтобы форма и фильтр решали, что
// рисовать, без похода на сервер.
import 'listings.dart';

enum ListingField {
  rooms,
  floor,
  floors,
  series,
  isSecondary,
  builder,
  interior, // площади комнат, мебель, ремонт, отопление, газ — одним блоком
  exchange, // возможен обмен — применим к любому типу
  landArea,
  redBook,
  plotPurpose,
  commercialPurpose,
  separateEntrance,
  buildingLine,
  ceilingHeight,
}

const Map<PropertyKind, Set<ListingField>> kindFields = {
  PropertyKind.apartment: {
    ListingField.exchange,
    ListingField.rooms,
    ListingField.floor,
    ListingField.floors,
    ListingField.series,
    ListingField.isSecondary,
    ListingField.interior,
  },
  PropertyKind.room: {
    ListingField.exchange,
    ListingField.floor,
    ListingField.floors,
    ListingField.series,
    ListingField.isSecondary,
    ListingField.interior,
  },
  PropertyKind.house: {
    ListingField.exchange,
    ListingField.rooms,
    ListingField.floors,
    ListingField.isSecondary,
    ListingField.interior,
    ListingField.landArea,
    ListingField.redBook,
  },
  PropertyKind.newBuilding: {
    ListingField.exchange,
    ListingField.rooms,
    ListingField.floor,
    ListingField.floors,
    ListingField.builder,
    ListingField.interior,
  },
  PropertyKind.plot: {
    ListingField.exchange,
    ListingField.landArea,
    ListingField.redBook,
    ListingField.plotPurpose,
  },
  PropertyKind.commercial: {
    ListingField.exchange,
    ListingField.floor,
    ListingField.floors,
    ListingField.commercialPurpose,
    ListingField.separateEntrance,
    ListingField.buildingLine,
    ListingField.ceilingHeight,
  },
};

bool showsField(PropertyKind kind, ListingField field) =>
    kindFields[kind]?.contains(field) ?? false;

/// Объединение полей нескольких типов — для фильтра с мультивыбором.
///
/// Пустой набор типов означает «ищем везде», поэтому показываются все поля:
/// иначе экран фильтра при первом открытии оказался бы почти пустым.
Set<ListingField> fieldsForKinds(Set<PropertyKind> kinds) {
  if (kinds.isEmpty) return ListingField.values.toSet();
  return kinds.fold<Set<ListingField>>(
    <ListingField>{},
    (acc, kind) => acc..addAll(kindFields[kind] ?? const <ListingField>{}),
  );
}

/// Подписи назначений участка — значения совпадают с `PlotPurpose` на бэкенде.
const Map<String, String> plotPurposeLabels = {
  'ihs': 'ИЖС',
  'garden': 'Садовый',
  'agricultural': 'Сельхозназначение',
  'commercial': 'Коммерческий',
};

/// Подписи назначений помещения — значения совпадают с `CommercialPurpose`.
const Map<String, String> commercialPurposeLabels = {
  'office': 'Офис',
  'shop': 'Магазин',
  'warehouse': 'Склад',
  'production': 'Производство',
  'catering': 'Общепит',
  'free': 'Свободного назначения',
};

/// Подписи линий — значения совпадают с `BuildingLine`.
const Map<String, String> buildingLineLabels = {
  'first': 'Первая линия',
  'second': 'Вторая линия',
  'inside': 'Внутри квартала',
};
