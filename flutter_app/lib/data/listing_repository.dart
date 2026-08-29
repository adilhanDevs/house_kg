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
    return PaginatedResponse<Listing>.fromJson(
      data,
      (json) => Listing.fromJson(json),
    );
  }
}
