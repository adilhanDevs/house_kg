/// Адрес бэкенда. Единственный источник правды для всего приложения.
///
/// Переопределяется при сборке без правки кода:
/// `flutter run --dart-define=API_BASE_URL=http://139.59.224.34`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://139.59.224.34',
);
