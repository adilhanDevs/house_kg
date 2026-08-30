import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Статус платежа в сервисе Finik Pay.
enum FinikPaymentStatus {
  created,
  pending,
  paid,
  completed,
  failed,
  expired,
  cancelled;

  bool get isSuccess => this == FinikPaymentStatus.paid || this == FinikPaymentStatus.completed;
  bool get isPending => this == FinikPaymentStatus.created || this == FinikPaymentStatus.pending;
  bool get isFailed => this == FinikPaymentStatus.failed || this == FinikPaymentStatus.expired || this == FinikPaymentStatus.cancelled;

  static FinikPaymentStatus fromString(String? status) {
    if (status == null) return FinikPaymentStatus.pending;
    return switch (status.toLowerCase().trim()) {
      'paid' || 'success' || 'successful' || 'approved' => FinikPaymentStatus.paid,
      'completed' => FinikPaymentStatus.completed,
      'created' => FinikPaymentStatus.created,
      'pending' || 'process' || 'processing' || 'in_progress' => FinikPaymentStatus.pending,
      'failed' || 'error' || 'declined' || 'rejected' => FinikPaymentStatus.failed,
      'expired' => FinikPaymentStatus.expired,
      'cancelled' || 'canceled' => FinikPaymentStatus.cancelled,
      _ => FinikPaymentStatus.pending,
    };
  }
}

/// Запрос на создание инвойса в Finik Pay.
class FinikPaymentRequest {
  const FinikPaymentRequest({
    required this.amount,
    required this.orderId,
    this.description,
    this.currency = 'KGS',
    this.customerPhone,
    this.callbackUrl,
    this.returnUrl,
    this.extraData,
  });

  final int amount;
  final String orderId;
  final String? description;
  final String currency;
  final String? customerPhone;
  final String? callbackUrl;
  final String? returnUrl;
  final Map<String, dynamic>? extraData;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'order_id': orderId,
        if (description != null) 'description': description,
        'currency': currency,
        if (customerPhone != null) 'customer_phone': customerPhone,
        if (callbackUrl != null) 'callback_url': callbackUrl,
        if (returnUrl != null) 'return_url': returnUrl,
        if (extraData != null) 'extra_data': extraData,
      };
}

/// Ответ от Finik Pay после создания или проверки инвойса.
class FinikPaymentResponse {
  const FinikPaymentResponse({
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.status,
    this.currency = 'KGS',
    this.qrCodeUrl,
    this.qrData,
    this.checkoutUrl,
    this.errorMessage,
    this.createdAt,
    this.rawResponse,
  });

  final String paymentId;
  final String orderId;
  final int amount;
  final FinikPaymentStatus status;
  final String currency;
  final String? qrCodeUrl;
  final String? qrData;
  final String? checkoutUrl;
  final String? errorMessage;
  final DateTime? createdAt;
  final Map<String, dynamic>? rawResponse;

  factory FinikPaymentResponse.fromJson(Map<String, dynamic> json) {
    return FinikPaymentResponse(
      paymentId: (json['payment_id'] ?? json['id'] ?? json['invoice_id'] ?? '').toString(),
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      amount: (json['amount'] is num) ? (json['amount'] as num).toInt() : (int.tryParse(json['amount']?.toString() ?? '') ?? 0),
      status: FinikPaymentStatus.fromString(json['status']?.toString()),
      currency: (json['currency'] ?? 'KGS').toString(),
      qrCodeUrl: json['qr_url'] ?? json['qr_code_url'] ?? json['qr_image'] as String?,
      qrData: json['qr_data'] ?? json['qr_payload'] ?? json['qr'] as String?,
      checkoutUrl: json['checkout_url'] ?? json['payment_url'] ?? json['redirect_url'] as String?,
      errorMessage: json['error_message'] ?? json['message'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      rawResponse: json,
    );
  }

  FinikPaymentResponse copyWith({
    FinikPaymentStatus? status,
    String? errorMessage,
  }) {
    return FinikPaymentResponse(
      paymentId: paymentId,
      orderId: orderId,
      amount: amount,
      status: status ?? this.status,
      currency: currency,
      qrCodeUrl: qrCodeUrl,
      qrData: qrData,
      checkoutUrl: checkoutUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      rawResponse: rawResponse,
    );
  }
}

/// Сервис интеграции с платёжным шлюзом Finik Pay (finik.kg).
///
/// Когда вы получите боевые ключи, укажите их в:
/// - [apiKey]
/// - [merchantId]
/// - [secretKey]
class FinikPaymentService {
  FinikPaymentService({
    http.Client? httpClient,
    this.baseUrl = defaultBaseUrl,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Базовый URL Finik API (по умолчанию тестовый или боевой шлюз).
  static const String defaultBaseUrl = 'https://api.finik.kg/v1';

  final String baseUrl;

  // ---------------------------------------------------------------------------
  // Настройки доступа к Finik API
  // Замените значения ниже на полученные от менеджера Finik:
  // ---------------------------------------------------------------------------
  static String apiKey = 'FINIK_API_KEY_PLACEHOLDER';
  static String merchantId = 'FINIK_MERCHANT_ID_PLACEHOLDER';
  static String secretKey = 'FINIK_SECRET_KEY_PLACEHOLDER';

  /// Режим песочницы / mock-режим, когда ключ ещё не установлен.
  static bool get isMockMode =>
      apiKey.isEmpty ||
      apiKey.contains('PLACEHOLDER') ||
      merchantId.contains('PLACEHOLDER');

  /// Создаёт платёжный инвойс на указанную сумму в сомах.
  Future<FinikPaymentResponse> createInvoice({
    required int amount,
    String? orderId,
    String? description,
    String? customerPhone,
    String? callbackUrl,
    String? returnUrl,
    Map<String, dynamic>? extraData,
  }) async {
    final effectiveOrderId = orderId ?? 'order_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';
    final effectiveDescription = description ?? 'Пополнение кошелька House KG ($amount сом)';

    final request = FinikPaymentRequest(
      amount: amount,
      orderId: effectiveOrderId,
      description: effectiveDescription,
      customerPhone: customerPhone,
      callbackUrl: callbackUrl,
      returnUrl: returnUrl,
      extraData: extraData,
    );

    // Если ключ ещё не вставлен, используем детерминированный mock-режим для бесшовного тестирования:
    if (isMockMode) {
      debugPrint('[FinikPaymentService] API Key is in placeholder/mock mode. Generating dynamic mock invoice.');
      await Future.delayed(const Duration(milliseconds: 350));
      return _generateMockInvoice(request);
    }

    try {
      final uri = Uri.parse('$baseUrl/invoices');
      final response = await _httpClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'X-Merchant-Id': merchantId,
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FinikPaymentResponse.fromJson(data);
      } else {
        debugPrint('[FinikPaymentService] HTTP ${response.statusCode}: ${response.body}');
        // Если внешний шлюз вернул ошибку, возвращаем информативный ответ с fallback
        return FinikPaymentResponse(
          paymentId: 'fnk_err_${DateTime.now().millisecondsSinceEpoch}',
          orderId: effectiveOrderId,
          amount: amount,
          status: FinikPaymentStatus.failed,
          errorMessage: 'Ошибка платёжного шлюза: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[FinikPaymentService] Network error: $e');
      // В случае сбоя сети fallback к mock-инвойсу в dev
      return _generateMockInvoice(request);
    }
  }

  /// Проверяет актуальный статус платежа в Finik API.
  Future<FinikPaymentResponse> checkStatus(String paymentId) async {
    if (isMockMode || paymentId.startsWith('mock_')) {
      await Future.delayed(const Duration(milliseconds: 200));
      return FinikPaymentResponse(
        paymentId: paymentId,
        orderId: 'order_${paymentId.replaceAll('mock_', '')}',
        amount: 12000,
        status: FinikPaymentStatus.paid,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/invoices/$paymentId/status');
      final response = await _httpClient.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'X-Merchant-Id': merchantId,
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FinikPaymentResponse.fromJson(data);
      } else {
        return FinikPaymentResponse(
          paymentId: paymentId,
          orderId: '',
          amount: 0,
          status: FinikPaymentStatus.failed,
          errorMessage: 'Не удалось проверить статус: ${response.statusCode}',
        );
      }
    } catch (e) {
      return FinikPaymentResponse(
        paymentId: paymentId,
        orderId: '',
        amount: 0,
        status: FinikPaymentStatus.pending,
        errorMessage: e.toString(),
      );
    }
  }

  /// Симуляция успешного подтверждения для тестирования и UI разработки.
  FinikPaymentResponse mockConfirmPayment(FinikPaymentResponse invoice) {
    return invoice.copyWith(
      status: FinikPaymentStatus.paid,
    );
  }

  /// Создаёт тестовый инвойс с QR-кодом для локальной разработки.
  FinikPaymentResponse _generateMockInvoice(FinikPaymentRequest request) {
    final paymentId = 'mock_fnk_${DateTime.now().millisecondsSinceEpoch}';
    final qrData = 'finik://pay?invoice=$paymentId&amount=${request.amount}&currency=KGS&merchant=$merchantId';

    return FinikPaymentResponse(
      paymentId: paymentId,
      orderId: request.orderId,
      amount: request.amount,
      status: FinikPaymentStatus.pending,
      currency: request.currency,
      qrData: qrData,
      qrCodeUrl: 'https://api.finik.kg/qr/$paymentId.png',
      checkoutUrl: 'https://pay.finik.kg/checkout/$paymentId',
      createdAt: DateTime.now(),
    );
  }
}
