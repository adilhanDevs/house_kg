/// Настройки официального SDK Finik.
///
/// Ключ приходит только при сборке: `--dart-define-from-file=.finik.local.json`.
/// Значения по умолчанию нет намеренно — ключ не должен попасть в репозиторий.
/// Без него экран оплаты честно скажет, что не настроен, вместо тихой поломки.
library;

final class FinikConfig {
  const FinikConfig._();

  /// Ключ клиента Finik. Тот же, которым бэкенд ходит в Finik: так устроена
  /// сама интеграция Finik — SDK работает с этим ключом на стороне приложения.
  static const String apiKey = String.fromEnvironment('FINIK_SDK_API_KEY');

  /// Контур должен совпадать с тем, где бэкенд создал счёт.
  static const bool isBeta = bool.fromEnvironment('FINIK_BETA');

  static bool get isConfigured => apiKey.trim().isNotEmpty;
}
