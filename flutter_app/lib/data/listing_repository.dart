import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'recommendation_feed.dart';
import 'listings.dart';
import 'pagination.dart';

class ListingRepository {
  ListingRepository(this._apiClient);

  final ListingApiClient _apiClient;

  Future<PaginatedResponse<Listing>> getListings({Map<String, dynamic>? filters, String? cursor}) async {
    final data = await _apiClient.getListings(filters: filters, cursor: cursor);
    return PaginatedResponse<Listing>.fromJson(
      data,
      (json) => Listing.fromJson(json),
    );
  }

  /// Объявления текущего пользователя. `status` — draft | pending | active |
  /// rejected | archived | sold.
  Future<PaginatedResponse<Listing>> getMyListings({String? status, String? cursor}) async {
    final data = await _apiClient.getMyListings(status: status, cursor: cursor);
    return PaginatedResponse<Listing>.fromJson(
      data,
      (json) => Listing.fromJson(json),
    );
  }

  /// Лента роликов: сначала персонализированная, при её отсутствии — обычная.
  ///
  /// Оба эндпоинта отдают объявление одним и тем же сериализатором, поэтому
  /// разбор общий, а вызывающему коду знать, откуда приехала лента, не нужно.
  ///
  /// Откат делаем только тогда, когда персонализированной ленты на сервере
  /// нет или он не смог её отдать. Пустая, но корректная лента — это ответ, а
  /// не отказ: подменять её обычной значило бы показывать человеку то, что
  /// рекомендатель сознательно отфильтровал.
  Future<PaginatedResponse<Listing>> getReelsFeed({
    String? cursor,
    RecommendationFeed? feed,
  }) async {
    if (feed != null) {
      try {
        final data = await _apiClient.getRecommendedReels(
          sessionId: feed.sessionId,
          feedSessionId: feed.feedSessionId,
          cursor: cursor,
        );
        final page = _reelsFromRecommendations(data);

        // Пустая ПЕРВАЯ страница — это тупик: экран остаётся с одним
        // роликом, который открыли, и листать нечего. Рекомендатель может
        // отдать пусто законно (всё уже показано в этой сессии, мало
        // объявлений с видео), но человеку от этого не легче. На первой
        // странице подстраховываемся обычной лентой; дальше пусто означает
        // просто конец ленты и подмены не требует.
        if (page.results.isEmpty && (cursor == null || cursor.isEmpty)) {
          debugPrint('Персонализированная лента пуста на первой странице — беру обычную');
        } else {
          return page;
        }
      } on ApiException catch (e) {
        if (!_shouldFallBack(e.statusCode)) rethrow;
        debugPrint('Персонализированная лента недоступна (${e.statusCode}) — беру обычную');
      } on NetworkException catch (e) {
        debugPrint('Персонализированная лента недоступна ($e) — беру обычную');
      }
    }

    final data = await _apiClient.getReelsFeed(cursor);
    return PaginatedResponse<Listing>.fromJson(
      data,
      (json) => Listing.fromJson(json),
    );
  }

  /// 404 — эндпоинта ещё нет на этом сервере (прод обновляется отдельно),
  /// 501 — не поддерживается, 5xx — сервер не справился. Ошибки прав и
  /// валидации прячем не мы: их должен увидеть вызывающий.
  static bool _shouldFallBack(int status) =>
      status == 404 || status == 501 || status >= 500;

  /// У рекомендаций `next` — непрозрачный токен, а не ссылка со страницей,
  /// поэтому общий разбор курсора здесь не годится: он ищет в строке
  /// параметр `cursor` и на токене вернул бы null, оборвав ленту на первой
  /// странице.
  static PaginatedResponse<Listing> _reelsFromRecommendations(Map<String, dynamic> data) {
    final results = (data['results'] as List<dynamic>?)
            ?.map((e) => Listing.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <Listing>[];
    final next = data['next'] as String?;
    return PaginatedResponse<Listing>(
      results: results,
      nextCursor: (next != null && next.isNotEmpty) ? next : null,
    );
  }

  Future<PaginatedResponse<Listing>> getFavourites({String? cursor}) async {
    final data = await _apiClient.getFavourites(cursor: cursor);
    return PaginatedResponse<Listing>.fromJson(
      data,
      (json) => Listing.fromJson(json),
    );
  }

  Future<PaginatedResponse<Listing>> getViewHistory({String? cursor}) async {
    final data = await _apiClient.getViewHistory(cursor: cursor);
    final resultsRaw = data['results'] as List<dynamic>? ?? [];
    final List<Listing> listings = [];
    for (final item in resultsRaw) {
      if (item is Map) {
        final itemMap = Map<String, dynamic>.from(item);
        if (itemMap.containsKey('items') && itemMap['items'] is List) {
          for (final sub in itemMap['items']) {
            if (sub is Map) {
              listings.add(Listing.fromJson(Map<String, dynamic>.from(sub)));
            }
          }
        } else {
          listings.add(Listing.fromJson(itemMap));
        }
      }
    }
    return PaginatedResponse<Listing>(
      results: listings,
      nextCursor: PaginatedResponse.extractCursor(data['next'] as String?),
    );
  }

  Future<Listing> getListingDetails(String slug) async {
    final data = await _apiClient.getListingDetails(slug);
    return Listing.fromJson(data);
  }
}
