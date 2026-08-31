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
  String toString() => 'ApiException(statusCode: \$statusCode, code: \$code, message: \$message)';
}

class NetworkException implements Exception {
  NetworkException([this.message = 'Network error']);
  final String message;
  
  @override
  String toString() => 'NetworkException: $message';
}
