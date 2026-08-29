import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exceptions.dart';

class AuthInterceptorClient extends http.BaseClient {
  AuthInterceptorClient(this._inner);

  final http.Client _inner;
  String? accessToken;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    return _inner.send(request);
  }
}

class ListingApiClient {
  ListingApiClient({required this.baseUrl, http.Client? client}) {
    _client = AuthInterceptorClient(client ?? http.Client());
  }

  final String baseUrl;
  late final AuthInterceptorClient _client;

  void setToken(String? token) {
    _client.accessToken = token;
  }

  Future<Map<String, dynamic>> getListings({Map<String, dynamic>? filters, String? cursor}) async {
    final queryParameters = <String, String>{};
    
    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          queryParameters[key] = value.toString();
        }
      });
    }

    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final uri = Uri.parse('$baseUrl/api/v1/listings/').replace(
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );

    try {
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
      });
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getFavourites({String? cursor}) async {
    var uri = Uri.parse('$baseUrl/api/v1/favourites/');
    if (cursor != null) uri = uri.replace(queryParameters: {'cursor': cursor});
    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> toggleFavourite(String slug) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$slug/favourite/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getViewHistory({String? cursor}) async {
    var uri = Uri.parse('$baseUrl/api/v1/view-history/');
    if (cursor != null) uri = uri.replace(queryParameters: {'cursor': cursor});
    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getWalletBalance() async {
    final uri = Uri.parse('$baseUrl/api/v1/wallet/');
    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getWalletTransactions({String? kind, String? cursor}) async {
    var uri = Uri.parse('$baseUrl/api/v1/wallet/transactions/');
    final params = <String, String>{};
    if (kind != null) params['kind'] = kind;
    if (cursor != null) params['cursor'] = cursor;
    if (params.isNotEmpty) uri = uri.replace(queryParameters: params);

    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> promoteListing(String slug, int days, String idempotencyKey) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$slug/promote/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({'days': days}),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<void> clearViewHistory() async {
    final uri = Uri.parse('$baseUrl/api/v1/view-history/');
    try {
      final response = await _client.delete(
        uri,
        headers: {'Accept': 'application/json'},
      );
      _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getFilterOptions({String? city}) async {
    var uri = Uri.parse('$baseUrl/api/v1/catalog/filter-options/');
    if (city != null) {
      uri = uri.replace(queryParameters: {'city': city});
    }
    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/');
    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/');
    try {
      final response = await _client.patch(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(data),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<void> logout(String refreshToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/logout/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getListingDetails(String slug) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$slug/');
    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<void> recordListingView(String slug) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$slug/view/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );
      _processResponse(response);
    } catch (e) {
      // Игнорируем ошибку при отправке статистики просмотров
      print('Failed to record listing view: $e');
    }
  }

  Future<Map<String, dynamic>> createDraft(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/draft/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(data),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> updateDraft(String slug, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$slug/');
    try {
      final response = await _client.patch(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(data),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<void> publishListing(String slug) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$slug/publish/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );
      _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> getReelsFeed(String? cursor) async {
    final queryParameters = <String, String>{};
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final uri = Uri.parse('$baseUrl/api/v1/listings/reels/').replace(
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );

    try {
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
      });
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = utf8.decode(response.bodyBytes);
      return jsonDecode(decoded) as Map<String, dynamic>;
    } else {
      throw ApiException(
        response.statusCode,
        'Ошибка загрузки данных: ${response.statusCode}',
      );
    }
  }

  Future<void> updateMediaMetadata(String listingSlug, int mediaId, String? title, String? description) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$listingSlug/media/$mediaId/');
    final body = {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    };

    try {
      final response = await _client.patch(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> uploadMedia(String listingSlug, File file) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$listingSlug/media/');
    
    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..fields['kind'] = 'video'
        ..files.add(await http.MultipartFile.fromPath(
          'files', // Backend expects 'files' array based on MediaUploadSerializer
          file.path,
        ));

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<void> requestOtp(String phone) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/otp/request/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'phone': phone}),
      );
      _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code, {String? name}) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/otp/verify/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'code': code,
          'accepted_terms_version': '1',
          if (name != null) 'name': name,
        }),
      );
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> registerPro(String phone, String name, String password, String iin) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/pro/register/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'name': name,
          'password': password,
          'iin': iin,
        }),
      );
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> loginWithPassword(String phone, String password) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/password/login/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }
}
