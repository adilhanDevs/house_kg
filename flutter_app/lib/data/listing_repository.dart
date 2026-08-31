import 'api_client.dart';
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

  Future<PaginatedResponse<Listing>> getReelsFeed({String? cursor}) async {
    final data = await _apiClient.getReelsFeed(cursor);
    return PaginatedResponse<Listing>.fromJson(
      data,
      (json) => Listing.fromJson(json),
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
