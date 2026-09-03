// Клиентская часть персонализированной ленты.
//
// Здесь живут два обязательства перед бэкендом: идентификаторы сессии, по
// которым он не показывает одно и то же дважды, и обратная связь о том, что
// человек реально посмотрел. Всё это — доставка по возможности: лента не
// должна замирать из-за неотправленной аналитики.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Типы событий ровно те, что принимает сервер (`InteractionType`).
/// Придумывать свои нельзя: неизвестный тип отклоняет весь батч.
abstract final class ReelEvent {
  static const impression = 'reel_impression';
  static const watch = 'reel_watch';
  static const skip = 'reel_skip';
  static const listingOpen = 'view';
  static const sellerOpen = 'seller_profile';
}

/// Сервер принимает не больше 50 событий за раз; берём с запасом.
const int kRecommendationBatchMax = 20;

/// Просмотр меньше этой доли ролика считаем пропуском.
const double kReelSkipRatio = 0.25;

String _randomId() {
  final rnd = Random();
  const chars = 'abcdef0123456789';
  return List.generate(32, (_) => chars[rnd.nextInt(chars.length)]).join();
}

/// UUID v4 — `client_event_id` на сервере именно UUID, строка другого вида
/// отклоняется вместе со всем батчем.
String newUuidV4() {
  final rnd = Random();
  String hex(int n) => List.generate(n, (_) => '0123456789abcdef'[rnd.nextInt(16)]).join();
  final variant = '89ab'[rnd.nextInt(4)];
  return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
}

/// Одна пользовательская сессия ленты.
///
/// `sessionId` живёт столько же, сколько запуск приложения: по нему сервер
/// собирает краткосрочный интерес. `feedSessionId` — одно открытие ленты; на
/// нём держится защита от повторов, поэтому новый идентификатор на каждый
/// свайп сбросил бы её начисто.
class RecommendationFeed {
  RecommendationFeed({
    required ListingApiClient apiClient,
    String? sessionId,
    Duration flushAfter = const Duration(seconds: 5),
  })  : _api = apiClient,
        sessionId = sessionId ?? 'session-${_randomId()}',
        feedSessionId = 'feed-${_randomId()}',
        _flushAfter = flushAfter;

  final ListingApiClient _api;
  final Duration _flushAfter;

  /// Минимум восемь символов — короче сервер не принимает.
  final String sessionId;
  final String feedSessionId;

  final List<Map<String, dynamic>> _queue = [];
  final Set<String> _impressed = {};
  Timer? _timer;
  bool _sending = false;
  bool _disposed = false;

  /// Сколько событий ждёт отправки — нужно тестам и отладке.
  @visibleForTesting
  int get pending => _queue.length;

  /// Показ ролика. Второй раз для того же объявления в этой ленте не уходит:
  /// PageView перестраивает страницы при каждой перерисовке, и без этой
  /// защиты один показ превращался бы в пять.
  void impression(int listingId) {
    final key = 'imp:$listingId';
    if (!_impressed.add(key)) return;
    _enqueue(ReelEvent.impression, listingId);
  }

  /// Итог просмотра, когда страница уже сменилась.
  ///
  /// Доля считается здесь, а решение о её весе принимает сервер: пороги
  /// живут в его constants, и дублировать их на клиенте значило бы
  /// разъезжаться при первой же правке.
  void watched(int listingId, {required Duration watched, required Duration total}) {
    if (total.inMilliseconds <= 0) return;
    final ratio = (watched.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    if (ratio < kReelSkipRatio) {
      _enqueue(ReelEvent.skip, listingId, {'watch_ratio': ratio});
    } else {
      _enqueue(ReelEvent.watch, listingId, {'watch_ratio': ratio});
    }
  }

  void listingOpened(int listingId) => _enqueue(ReelEvent.listingOpen, listingId);

  void sellerOpened(int listingId) => _enqueue(ReelEvent.sellerOpen, listingId);

  void _enqueue(String type, int listingId, [Map<String, dynamic>? context]) {
    if (_disposed) return;
    _queue.add({
      'session_id': sessionId,
      'feed_session_id': feedSessionId,
      'event_type': type,
      'listing_id': listingId,
      // Идентификатор рождается вместе с событием и переживает повтор
      // отправки: на нём держится защита сервера от дублей.
      'client_event_id': newUuidV4(),
      if (context != null) 'context': context,
    });

    if (_queue.length >= kRecommendationBatchMax) {
      unawaited(flush());
    } else {
      _timer ??= Timer(_flushAfter, () => unawaited(flush()));
    }
  }

  /// Отправляет накопленное. Никогда не бросает: аналитика не важнее ленты.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_sending || _queue.isEmpty) return;

    final batch = _queue.take(kRecommendationBatchMax).toList();
    _sending = true;
    try {
      await _api.sendRecommendationEvents(batch);
      _queue.removeRange(0, batch.length);
    } catch (e) {
      // Одна неудача — не повод копить очередь бесконечно: события ленты
      // ценны свежими, а память телефона дороже.
      debugPrint('Событие ленты не ушло: $e');
      if (_queue.length > kRecommendationBatchMax * 3) {
        _queue.removeRange(0, batch.length);
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> dispose() async {
    await flush();
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
