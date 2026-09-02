class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.code = '', this.details = const {}});

  final int statusCode;
  final String message;

  /// Машиночитаемый код из тела ответа: `insufficient_funds`, `conflict`,
  /// `validation_error` и так далее (§1.5 ТЗ).
  final String code;

  /// Подробности от сервера. При нехватке средств здесь лежит, сколько нужно,
  /// сколько есть и сколько не хватает, — приложению этого достаточно, чтобы
  /// открыть пополнение на недостающую сумму, ничего не пересчитывая.
  final Map<String, dynamic> details;

  /// Сколько секунд ждать до следующей попытки — при 429.
  ///
  /// Сервер отдаёт ОДНО значение: DRF берёт максимум по всем сработавшим
  /// ограничениям (см. APIView.check_throttles), поэтому придумывать на
  /// клиенте собственный отсчёт поверх него нельзя — получатся два разных
  /// времени на один и тот же запрет.
  int? get retryAfter {
    final value = details['retry_after'];
    if (value is num) return value.ceil();
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed?.ceil();
  }

  /// Запрос отклонён по частоте.
  bool get isThrottled => statusCode == 429 || code == 'throttled';

  /// Не хватило кирпичей на балансе.
  bool get isInsufficientFunds =>
      statusCode == 402 || code == 'insufficient_funds';

  /// Сколько кирпичей не хватает.
  ///
  /// Сервер называет это поле `shortfall` (см. InsufficientFundsError);
  /// `required` — это полная стоимость, и подставлять её вместо недостачи
  /// нельзя: пользователь заплатил бы дважды за то, что уже на балансе.
  int? get missingBricks {
    final value = details['shortfall'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

class NetworkException implements Exception {
  NetworkException([this.message = 'Network error']);
  final String message;
  
  @override
  String toString() => 'NetworkException: $message';
}
