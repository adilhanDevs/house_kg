import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exceptions.dart';
export 'api_exceptions.dart';

typedef TokenRefreshCallback = Future<String?> Function();

class AuthInterceptorClient extends http.BaseClient {
  AuthInterceptorClient(this._inner, {this.onTokenExpired});

  final http.Client _inner;
  String? accessToken;
  TokenRefreshCallback? onTokenExpired;
  bool _isRefreshing = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isAuthEndpoint = request.url.path.contains('/auth/refresh') ||
        request.url.path.contains('/auth/otp') ||
        request.url.path.contains('/auth/login') ||
        request.url.path.contains('/auth/register');

    if (accessToken != null && accessToken!.isNotEmpty && !isAuthEndpoint) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    final response = await _inner.send(request);
    
    // Auto-refresh on 401 if it's an authenticated endpoint and we have a refresher
    if (response.statusCode == 401 && onTokenExpired != null && !_isRefreshing && !request.url.path.contains('/auth/')) {
      _isRefreshing = true;
      try {
        final newAccess = await onTokenExpired!();
        _isRefreshing = false;
        if (newAccess != null && newAccess.isNotEmpty) {
          accessToken = newAccess;
          final retryRequest = _copyRequest(request);
          retryRequest.headers['Authorization'] = 'Bearer $newAccess';
          return await _inner.send(retryRequest);
        }
      } catch (_) {
        _isRefreshing = false;
      }
    }
    return response;
  }

  http.BaseRequest _copyRequest(http.BaseRequest request) {
    if (request is http.Request) {
      final req = http.Request(request.method, request.url);
      req.headers.addAll(request.headers);
      req.bodyBytes = request.bodyBytes;
      req.encoding = request.encoding;
      req.followRedirects = request.followRedirects;
      req.maxRedirects = request.maxRedirects;
      req.persistentConnection = request.persistentConnection;
      return req;
    } else if (request is http.MultipartRequest) {
      final req = http.MultipartRequest(request.method, request.url);
      req.headers.addAll(request.headers);
      req.fields.addAll(request.fields);
      req.files.addAll(request.files);
      req.followRedirects = request.followRedirects;
      req.maxRedirects = request.maxRedirects;
      req.persistentConnection = request.persistentConnection;
      return req;
    }
    return request;
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

  void setTokenRefreshCallback(TokenRefreshCallback? callback) {
    _client.onTokenExpired = callback;
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

  Future<void> clearViewHistory({List<String>? slugs, bool? all}) async {
    final uri = Uri.parse('$baseUrl/api/v1/view-history/');
    try {
      final response = await _client.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          if (slugs != null || all != null) 'Content-Type': 'application/json',
        },
        body: (slugs != null || all != null)
            ? jsonEncode({
                if (slugs != null && slugs.isNotEmpty) 'listing_slugs': slugs,
                if (all != null) 'all': all,
              })
            : null,
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

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/refresh/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      final data = _processResponse(response);
      final newAccess = data['access'] as String?;
      if (newAccess != null) {
        setToken(newAccess);
      }
      return data;
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

  Future<Map<String, dynamic>> getDraft() async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/draft/');
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

  Future<Map<String, dynamic>> createDraft([Map<String, dynamic>? data]) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/draft/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Accept': 'application/json'},
      );
      final draftData = _processResponse(response);
      if (data != null && data.isNotEmpty && draftData['slug'] != null) {
        final slug = draftData['slug'] as String;
        return await updateDraft(slug, data);
      }
      return draftData;
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

  Future<Map<String, dynamic>> updateListing(String slug, Map<String, dynamic> data) => updateDraft(slug, data);

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
      if (response.bodyBytes.isEmpty) return {};
      final decoded = utf8.decode(response.bodyBytes);
      return jsonDecode(decoded) as Map<String, dynamic>;
    } else {
      String errorMessage = 'Ошибка: ${response.statusCode}';
      try {
        if (response.bodyBytes.isNotEmpty) {
          final decoded = utf8.decode(response.bodyBytes);
          final errorData = jsonDecode(decoded);
          if (errorData is Map) {
            if (errorData['error'] is Map && errorData['error']['message'] != null) {
              final msg = errorData['error']['message'];
              final details = errorData['error']['details'];
              if (details is Map && details.isNotEmpty) {
                final fieldErrors = details.entries.map((e) => '${e.key}: ${e.value}').join(', ');
                errorMessage = '$msg ($fieldErrors)';
              } else {
                errorMessage = msg.toString();
              }
            } else if (errorData['message'] != null) {
              errorMessage = errorData['message'].toString();
            } else if (errorData['detail'] != null) {
              errorMessage = errorData['detail'].toString();
            } else {
              errorMessage = errorData.entries.map((e) => '${e.key}: ${e.value}').join(', ');
            }
          }
        }
      } catch (_) {}
      throw ApiException(
        response.statusCode,
        errorMessage,
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

  Future<Map<String, dynamic>> uploadMedia(
    String listingSlug, [
    dynamic file,
    List<int>? bytes,
    String? filename,
    String kind = 'video',
  ]) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$listingSlug/media/');
    
    try {
      final request = http.MultipartRequest('POST', uri)
        ..headers['Accept'] = 'application/json'
        ..fields['kind'] = kind;

      if (bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          bytes,
          filename: filename ?? (kind == 'photo' ? 'photo.jpg' : 'upload.mp4'),
        ));
      } else if (file != null) {
        if (file is File) {
          request.files.add(await http.MultipartFile.fromPath('files', file.path));
        } else {
          try {
            final dynamic dynamicFile = file;
            final fileBytes = await dynamicFile.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes(
              'files',
              fileBytes as List<int>,
              filename: filename ?? (dynamicFile.name as String?) ?? (kind == 'photo' ? 'photo.jpg' : 'upload.mp4'),
            ));
          } catch (_) {}
        }
      }

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

  Future<void> deleteMedia(String listingSlug, int mediaId) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$listingSlug/media/$mediaId/');
    try {
      final response = await _client.delete(
        uri,
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        _processResponse(response);
      }
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<void> archiveListing(String listingSlug) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$listingSlug/archive/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Accept': 'application/json'},
      );
      _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> getTariffs() async {
    final uri = Uri.parse('$baseUrl/api/v1/tariffs/');
    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = utf8.decode(response.bodyBytes);
        final list = jsonDecode(decoded);
        if (list is List) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCurrentSubscription() async {
    final uri = Uri.parse('$baseUrl/api/v1/subscriptions/current/');
    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        return jsonDecode(decoded) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> subscribe(String tariffCode, {int months = 1, String paymentMethod = 'som', String? idempotencyKey}) async {
    final uri = Uri.parse('$baseUrl/api/v1/subscriptions/');
    final key = idempotencyKey ?? 'sub_${DateTime.now().millisecondsSinceEpoch}';

    // Map UI tariff codes to backend supported codes:
    // owner -> free
    // top / vip -> realtor (limit 20)
    // premium -> agency (limit 0 / unlimited)
    String backendTariffCode = tariffCode;
    if (tariffCode == 'owner') {
      backendTariffCode = 'free';
    } else if (tariffCode == 'top' || tariffCode == 'vip') {
      backendTariffCode = 'realtor';
    } else if (tariffCode == 'premium') {
      backendTariffCode = 'agency';
    }

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Idempotency-Key': key,
        },
        body: jsonEncode({
          'tariff_code': backendTariffCode,
          'months': months,
        }),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<void> cancelSubscription() async {
    final uri = Uri.parse('$baseUrl/api/v1/subscriptions/cancel/');
    try {
      final response = await _client.post(uri, headers: {'Accept': 'application/json'});
      _processResponse(response);
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
