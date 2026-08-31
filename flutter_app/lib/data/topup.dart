/// Модели пополнения кошелька.
///
/// Счёт выставляет бэкенд: он ходит в платёжный шлюз своими ключами и отдаёт
/// клиенту только ссылку на оплату и данные для QR. Приложение не знает ни
/// секретов Finik, ни его протокола — и не может «подтвердить» оплату само.
library;

/// Статус счёта. Значения совпадают с `PaymentStatus` на бэкенде.
enum TopupStatus {
  pending,
  succeeded,
  failed,
  expired,
  refunded;

  bool get isSuccess => this == TopupStatus.succeeded;
  bool get isPending => this == TopupStatus.pending;
  bool get isFinal => this != TopupStatus.pending;

  static TopupStatus fromString(String? value) {
    return switch ((value ?? '').toLowerCase().trim()) {
      'succeeded' => TopupStatus.succeeded,
      'failed' => TopupStatus.failed,
      'expired' => TopupStatus.expired,
      'refunded' => TopupStatus.refunded,
      _ => TopupStatus.pending,
    };
  }
}

/// Способ оплаты на экране выбора: банк с диплинком в своё приложение.
class TopupProvider {
  const TopupProvider({
    required this.code,
    required this.name,
    this.logoUrl,
    this.deeplink = '',
  });

  final String code;
  final String name;
  final String? logoUrl;
  final String deeplink;

  factory TopupProvider.fromJson(Map<String, dynamic> json) {
    return TopupProvider(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logoUrl: json['logo_url'] as String?,
      deeplink: (json['deeplink'] ?? '').toString(),
    );
  }
}

/// Выставленный счёт на пополнение.
class TopupIntent {
  const TopupIntent({
    required this.paymentId,
    required this.amountKgs,
    required this.bricks,
    required this.bonusBricks,
    required this.totalBricks,
    required this.paymentUrl,
    this.qrCodeUrl = '',
    this.qrData = '',
    this.expiresAt,
    this.providers = const [],
  });

  final String paymentId;
  final String amountKgs;
  final int bricks;
  final int bonusBricks;
  final int totalBricks;

  /// Ссылка на страницу оплаты у провайдера.
  final String paymentUrl;

  /// Готовая картинка QR, если провайдер её отдал.
  final String qrCodeUrl;

  /// Строка, которую клиент сам рисует как QR-код.
  final String qrData;

  final DateTime? expiresAt;
  final List<TopupProvider> providers;

  /// Что кодировать в QR: провайдерский payload, иначе ссылка на оплату.
  String get qrPayload => qrData.isNotEmpty ? qrData : paymentUrl;

  /// Сколько секунд осталось до истечения счёта.
  int get secondsLeft {
    final until = expiresAt;
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds;
    return left > 0 ? left : 0;
  }

  factory TopupIntent.fromJson(Map<String, dynamic> json) {
    final rawProviders = json['providers'];
    return TopupIntent(
      paymentId: (json['payment_id'] ?? '').toString(),
      amountKgs: (json['amount_kgs'] ?? '0').toString(),
      bricks: _asInt(json['bricks']),
      bonusBricks: _asInt(json['bonus_bricks']),
      totalBricks: _asInt(json['total_bricks']),
      paymentUrl: (json['payment_url'] ?? '').toString(),
      qrCodeUrl: (json['qr_code_url'] ?? '').toString(),
      qrData: (json['qr_data'] ?? '').toString(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())?.toLocal()
          : null,
      providers: rawProviders is List
          ? rawProviders
              .whereType<Map>()
              .map((e) => TopupProvider.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

/// Ответ поллинга статуса счёта.
class TopupStatusResult {
  const TopupStatusResult({
    required this.status,
    required this.balance,
    required this.creditedBricks,
  });

  final TopupStatus status;

  /// Актуальный баланс кошелька в кирпичах — источник правды на бэкенде.
  final int balance;
  final int creditedBricks;

  factory TopupStatusResult.fromJson(Map<String, dynamic> json) {
    return TopupStatusResult(
      status: TopupStatus.fromString(json['status'] as String?),
      balance: _asInt(json['balance']),
      creditedBricks: _asInt(json['credited_bricks']),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
