/// Адрес бэкенда. Единственный источник правды для всего приложения.
///
/// Переопределяется при сборке без правки кода:
/// `flutter run --dart-define=API_BASE_URL=https://house.safa-app.com`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://house.safa-app.com',
);
