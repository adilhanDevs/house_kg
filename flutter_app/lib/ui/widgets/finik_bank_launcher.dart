import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Утилита открытия мобильных банков Кыргызстана для оплаты через Finik Pay.
class FinikBankLauncher {
  const FinikBankLauncher();

  /// Возвращает список candidate URIs для выбранного банка.
  static List<Uri> buildCandidateUris({
    required String bankId,
    required String paymentUrl,
    String qrPayload = '',
  }) {
    if (paymentUrl.isEmpty) return const [];
    final encodedUrl = Uri.encodeComponent(paymentUrl);
    final payload = qrPayload.isNotEmpty ? qrPayload : paymentUrl;
    final encodedPayload = Uri.encodeComponent(payload);

    switch (bankId.toLowerCase()) {
      case 'mbank':
        return [
          Uri.parse('mbank://pay?url=$encodedUrl'),
          Uri.parse('mbank://qr?data=$encodedPayload'),
          Uri.parse('mbank://pay'),
          Uri.parse('mbank://'),
        ];
      case 'bakai':
        return [
          Uri.parse('bakai://pay?url=$encodedUrl'),
          Uri.parse('bakai://qr?data=$encodedPayload'),
          Uri.parse('bakaimobile://pay?url=$encodedUrl'),
          Uri.parse('bakai24://pay?url=$encodedUrl'),
          Uri.parse('bakai://'),
        ];
      case 'optima':
      case 'optima24':
        return [
          Uri.parse('optima24://pay?url=$encodedUrl'),
          Uri.parse('optima24://'),
        ];
      case 'odengi':
      case 'omoney':
        return [
          Uri.parse('omoney://pay?url=$encodedUrl'),
          Uri.parse('omoney://'),
        ];
      case 'megapay':
        return [
          Uri.parse('megapay://pay?url=$encodedUrl'),
          Uri.parse('megapay://'),
        ];
      case 'card':
      default:
        return [
          Uri.parse(paymentUrl),
        ];
    }
  }

  /// Запускает приложение банка или делает безопасный переход в браузер.
  Future<bool> launchBank({
    required String bankId,
    required String paymentUrl,
    String qrPayload = '',
    String explicitDeeplink = '',
  }) async {
    if (paymentUrl.isEmpty && explicitDeeplink.isEmpty) return false;

    // 1. Если бэкенд явно прислал персональный диплинк для банка
    if (explicitDeeplink.isNotEmpty) {
      final explicitUri = Uri.tryParse(explicitDeeplink);
      if (explicitUri != null) {
        try {
          final launched = await launchUrl(
            explicitUri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        } catch (e) {
          debugPrint('Не удалось открыть явный диплинк $explicitDeeplink: $e');
        }
      }
    }

    // 2. Пробуем нативные схемы приложений банков Кыргызстана
    final candidates = buildCandidateUris(
      bankId: bankId,
      paymentUrl: paymentUrl,
      qrPayload: qrPayload,
    );

    for (final candidate in candidates) {
      if (candidate.scheme == 'http' || candidate.scheme == 'https') {
        continue; // Браузерный URL оставляем на fallback
      }
      try {
        final canLaunch = await canLaunchUrl(candidate);
        if (canLaunch) {
          final launched = await launchUrl(
            candidate,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return true;
        }
      } catch (e) {
        debugPrint('Ошибка запуска схемы $candidate: $e');
      }
    }

    // 3. Fallback: веб-страница чекаута Finik Pay
    final fallbackUri = Uri.tryParse(paymentUrl);
    if (fallbackUri != null) {
      try {
        return await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('Ошибка запуска fallback URL $paymentUrl: $e');
      }
    }

    return false;
  }
}
