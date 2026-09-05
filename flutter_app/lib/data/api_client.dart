import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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

  Future<http.StreamedResponse> sendWithoutAuth(http.BaseRequest request) =>
      _inner.send(request);

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
          if (request is! http.MultipartRequest) {
            final retryRequest = _copyRequest(request);
            retryRequest.headers['Authorization'] = 'Bearer $newAccess';
            return await _inner.send(retryRequest);
          }
          // Multipart тела читаются один раз: тот же MultipartRequest нельзя
          // переслать повторно (package:http бросает StateError на второй
          // finalize()). Здесь мы уже обновили accessToken — этого
          // достаточно: ListingApiClient._sendMultipartWithRetry пересобирает
          // запрос из исходных байт и шлёт его снова, и тот второй запрос
          // подхватит уже свежий токен через тот же заголовок Authorization.
        }
      } catch (e) {
        _isRefreshing = false;
        debugPrint('Token refresh failed for ${request.url.path}: $e');
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

/// Сколько байт запроса уже ушло в сокет.
typedef UploadProgress = void Function(int sent, int total);

/// Multipart-запрос, который отсчитывает отданные байты.
///
/// Ролик на 30 МБ уходит около минуты, и всё это время экран показывал
/// безымянный кружок — по нему нельзя отличить работающую загрузку от
/// зависшей. Считаем по мере отдачи тела: `finalize()` возвращает поток,
/// который HTTP-клиент вычитывает по мере готовности сокета.
class _ProgressMultipartRequest extends http.MultipartRequest {
  _ProgressMultipartRequest(super.method, super.url, {this.onProgress});

  final UploadProgress? onProgress;

  @override
  http.ByteStream finalize() {
    final report = onProgress;
    final stream = super.finalize();
    if (report == null) return stream;

    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      stream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (chunk, sink) {
            sent += chunk.length;
            report(sent, total);
            sink.add(chunk);
          },
        ),
      ),
    );
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

  /// Отправляет multipart-запрос, собранный заново на каждый вызов, и
  /// повторяет ровно один раз при 401.
  ///
  /// `AuthInterceptorClient.send` уже обновляет `accessToken` при первом 401
  /// (через `onTokenExpired`), но не пересылает саму multipart-часть: у
  /// `http.MultipartFile` поток тела читается один раз, и повторный
  /// `finalize()` того же объекта бросает `StateError` — значит, чтобы
  /// повторить запрос, файлы нужно пересобрать из исходных байт/пути, а не
  /// переслать те же объекты. [buildRequest] делает эту пересборку —
  /// вызывающий код передаёт замыкание, а не готовый запрос.
  Future<Map<String, dynamic>> _sendMultipartWithRetry(
    Future<http.MultipartRequest> Function() buildRequest,
  ) async {
    try {
      return await _sendMultipartOnce(buildRequest);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      return await _sendMultipartOnce(buildRequest);
    }
  }

  Future<Map<String, dynamic>> _sendMultipartOnce(
    Future<http.MultipartRequest> Function() buildRequest,
  ) async {
    try {
      final request = await buildRequest();
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

  /// Сколько объявлений подходит под фильтр — без выборки самих карточек.
  ///
  /// Отдельный лёгкий эндпоинт: экрану фильтра нужно число для кнопки
  /// «Показать N вариантов», а не страница результатов. Сервер кэширует
  /// ответ на минуту по нормализованным параметрам.
  Future<int> getListingsCount({Map<String, dynamic>? filters}) async {
    final queryParameters = <String, String>{};
    filters?.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        queryParameters[key] = value.toString();
      }
    });

    final uri = Uri.parse('$baseUrl/api/v1/listings/count/').replace(
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );

    try {
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
      });
      final data = _processResponse(response);
      return (data['count'] as num?)?.toInt() ?? 0;
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

  /// Выставляет счёт на пополнение кошелька.
  ///
  /// Ключ идемпотентности обязателен: повторный запрос с тем же ключом в
  /// течение суток вернёт тот же счёт, а не создаст второй.
  Future<Map<String, dynamic>> createTopup({
    required int amountKgs,
    required String idempotencyKey,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/wallet/topup/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({'amount_kgs': amountKgs}),
      );
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  /// Статус счёта. Единственный способ узнать, прошла ли оплата на самом деле:
  /// кирпичи начисляет вебхук провайдера, а не клиент.
  Future<Map<String, dynamic>> getTopupStatus(String paymentId) async {
    final uri = Uri.parse('$baseUrl/api/v1/wallet/topup/$paymentId/');
    try {
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  /// GET /api/v1/promotions/pricing/ — стоимость продвижения и баланс.
  ///
  /// Отдаёт `total_cost`, `balance` и `is_affordable`, поэтому экран может
  /// показать цену и понять, хватает ли кирпичей, ещё до попытки оплаты.
  Future<Map<String, dynamic>> getPromotionPricing({int days = 1, String? package, List<String> options = const []}) async {
    final params = <String, dynamic>{'days': days.toString()};
    if (options.isNotEmpty) params['options'] = options;
    if (package != null && package.isNotEmpty) params['package'] = package;

    final uri = Uri.parse('$baseUrl/api/v1/promotions/pricing/')
        .replace(queryParameters: params);
    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> promoteListing(String slug, int days, List<String> options, String idempotencyKey) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$slug/promote/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode({'days': days, 'options': options}),
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

  /// GET /api/v1/users/me/listings/ — объявления текущего пользователя.
  Future<Map<String, dynamic>> getMyListings({String? status, String? cursor}) async {
    final queryParameters = <String, String>{};
    if (status != null && status.isNotEmpty) queryParameters['status'] = status;
    if (cursor != null && cursor.isNotEmpty) queryParameters['cursor'] = cursor;

    final uri = Uri.parse('$baseUrl/api/v1/users/me/listings/').replace(
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );
    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
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

  /// Загрузка/удаление аватара пользователя (PATCH /api/v1/users/me/).
  Future<Map<String, dynamic>> uploadAvatar({
    List<int>? bytes,
    String? filename,
    String? filePath,
    bool delete = false,
  }) async {
    if (delete) {
      return updateMe({'delete_avatar': true});
    }
    final uri = Uri.parse('$baseUrl/api/v1/users/me/');
    return _sendMultipartWithRetry(() async {
      final request = http.MultipartRequest('PATCH', uri)
        ..headers['Accept'] = 'application/json';

      if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'avatar',
          filePath,
          filename: filename ?? 'avatar.jpg',
        ));
      } else if (bytes != null && bytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: filename ?? 'avatar.jpg',
        ));
      } else {
        throw ArgumentError('Не указаны данные для загрузки аватара');
      }
      return request;
    });
  }

  /// Загрузка/удаление фона/обложки профиля (PATCH /api/v1/users/me/).
  Future<Map<String, dynamic>> uploadProfileCover({
    List<int>? bytes,
    String? filename,
    String? filePath,
    bool delete = false,
  }) async {
    if (delete) {
      return updateMe({'delete_cover': true});
    }
    final uri = Uri.parse('$baseUrl/api/v1/users/me/');
    return _sendMultipartWithRetry(() async {
      final request = http.MultipartRequest('PATCH', uri)
        ..headers['Accept'] = 'application/json';

      if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_cover',
          filePath,
          filename: filename ?? 'cover.jpg',
        ));
      } else if (bytes != null && bytes.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'profile_cover',
          bytes,
          filename: filename ?? 'cover.jpg',
        ));
      } else {
        throw ArgumentError('Не указаны данные для загрузки обложки');
      }
      return request;
    });
  }

  /// Смена пароля авторизованным пользователем (POST /api/v1/auth/password/change/).
  Future<Map<String, dynamic>> changePassword({
    String? currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/password/change/');
    final body = <String, dynamic>{
      'new_password': newPassword,
      'new_password_confirmation': confirmation,
    };
    if (currentPassword != null && currentPassword.isNotEmpty) {
      body['current_password'] = currentPassword;
    }
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  /// Приводит относительный URL медиафайла к абсолютному с учётом baseUrl.
  String absoluteUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$base$cleanPath';
  }

  /// Мягкое удаление профиля (DELETE /api/v1/users/me/).
  Future<void> deleteMe() async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/');
    try {
      final response = await _client.delete(
        uri,
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 204 && response.statusCode != 200) {
        _processResponse(response);
      }
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

  Future<Map<String, dynamic>> publishListing(String slug) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$slug/publish/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      );
      final data = _processResponse(response);
      return data;
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  /// Персонализированная выдача объявлений.
  ///
  /// Принимает те же параметры фильтра, что и каталог: сервер применяет их
  /// строго и только потом ранжирует подходящее. Клиенту не нужно знать,
  /// какой эндпоинт обслуживает запрос — набор параметров один.
  Future<Map<String, dynamic>> getRecommendedListings({
    required String sessionId,
    Map<String, dynamic>? filters,
    String? cursor,
    int limit = 20,
  }) async {
    final queryParameters = <String, String>{
      'session_id': sessionId,
      'limit': limit.toString(),
    };
    filters?.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        queryParameters[key] = value.toString();
      }
    });
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final uri = Uri.parse('$baseUrl/api/v1/recommendations/listings/')
        .replace(queryParameters: queryParameters);

    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  /// Персонализированная лента роликов.
  ///
  /// `session_id` обязателен и не короче восьми символов — сервер иначе
  /// отвечает 400. `feed_session_id` держит защиту от повторов внутри одного
  /// открытия ленты.
  Future<Map<String, dynamic>> getRecommendedReels({
    required String sessionId,
    required String feedSessionId,
    String? cursor,
    int limit = 10,
  }) async {
    final queryParameters = <String, String>{
      'session_id': sessionId,
      'feed_session_id': feedSessionId,
      'limit': limit.toString(),
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParameters['cursor'] = cursor;
    }

    final uri = Uri.parse('$baseUrl/api/v1/recommendations/reels/')
        .replace(queryParameters: queryParameters);

    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  /// Обратная связь для ленты: показы, досмотры, пропуски, переходы.
  ///
  /// Отправка пачкой — событий много, а запрос на каждое сажало бы батарею.
  Future<void> sendRecommendationEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;
    final uri = Uri.parse('$baseUrl/api/v1/recommendations/events/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'events': events}),
      );
      _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
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

  /// Потоково скачивает media через тот же auth-aware HTTP client.
  ///
  /// Так защищённые media URL получают Bearer token и refresh, а
  /// большой ролик не копируется целиком в RAM.
  Future<void> downloadFile(String url, String outputPath) async {
    final rawUri = Uri.parse(url);
    final uri = rawUri.hasScheme ? rawUri : Uri.parse(baseUrl).resolveUri(rawUri);
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'video/*,application/octet-stream';
    final output = File(outputPath);

    try {
      final apiOrigin = Uri.parse(baseUrl).origin;
      final response = uri.origin == apiOrigin
          ? await _client.send(request)
          : await _client.sendWithoutAuth(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _processResponse(await http.Response.fromStream(response));
        throw NetworkException('Не удалось скачать видео');
      }
      await response.stream.pipe(output.openWrite());
    } catch (e) {
      if (await output.exists()) {
        await output.delete();
      }
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
      String errorCode = '';
      Map<String, dynamic> errorDetails = const {};
      try {
        if (response.bodyBytes.isNotEmpty) {
          final decoded = utf8.decode(response.bodyBytes);
          final errorData = jsonDecode(decoded);
          if (errorData is Map) {
            if (errorData['error'] is Map && errorData['error']['message'] != null) {
              final msg = errorData['error']['message'];
              final details = errorData['error']['details'];
              errorCode = (errorData['error']['code'] ?? '').toString();
              if (details is Map) {
                errorDetails = Map<String, dynamic>.from(details);
              }
              // Детали приклеиваем к тексту только у ошибок валидации — там
              // это подсказка по конкретным полям. У остальных (нехватка
              // средств, конфликт) получилось бы «Недостаточно средств
              // (required: 780, available: 100)» вместо человеческой фразы.
                            if (errorCode == 'validation_error' && details is Map && details.isNotEmpty) {
                final messages = <String>[];
                for (final value in details.values) {
                  if (value is List) {
                    messages.addAll(value.map((e) => e.toString()));
                  } else {
                    messages.add(value.toString());
                  }
                }
                errorMessage = messages.join('\\n');
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
        code: errorCode,
        details: errorDetails,
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

  /// Отправляет файл объявления.
  ///
  /// Для видео приложение прикладывает кадр-обложку и метаданные ролика:
  /// сервер их больше не вычисляет сам. Если [filePath] задан, файл уходит
  /// потоком с диска — двухсотмегабайтный ролик не нужно держать в памяти.
  Future<Map<String, dynamic>> uploadMedia(
    String listingSlug, {
    dynamic file,
    List<int>? bytes,
    String? filePath,
    String? filename,
    String kind = 'video',
    List<int>? thumbnailBytes,
    int? durationSeconds,
    int? width,
    int? height,
    UploadProgress? onProgress,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$listingSlug/media/');
    final defaultName = kind == 'photo' ? 'photo.jpg' : 'upload.mp4';

    return _sendMultipartWithRetry(() async {
      final request = _ProgressMultipartRequest('POST', uri, onProgress: onProgress)
        ..headers['Accept'] = 'application/json'
        ..fields['kind'] = kind;

      if (kind == 'video') {
        if (durationSeconds != null && durationSeconds > 0) {
          request.fields['duration_seconds'] = durationSeconds.toString();
        }
        if (width != null && width > 0) request.fields['width'] = width.toString();
        if (height != null && height > 0) request.fields['height'] = height.toString();

        if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
          request.files.add(http.MultipartFile.fromBytes(
            'thumbnail',
            thumbnailBytes,
            filename: 'poster.jpg',
          ));
        }
      }

      // fromPath живёт в dart:io, в браузере он бросает UnsupportedError —
      // там отправляем байты.
      if (!kIsWeb && filePath != null && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'files',
          filePath,
          filename: filename,
        ));
      } else if (bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          bytes,
          filename: filename ?? defaultName,
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
              filename: filename ?? (dynamicFile.name as String?) ?? defaultName,
            ));
          } catch (_) {}
        }
      }

      return request;
    });
  }

  /// Делает фото обложкой объявления.
  ///
  /// Решение принимает сервер и он же держит инвариант «обложка ровно одна»,
  /// поэтому локально её назначать нельзя — только этим запросом.
  Future<Map<String, dynamic>> setCoverMedia(String listingSlug, int mediaId) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$listingSlug/media/$mediaId/set-cover/');
    try {
      final response = await _client.post(
        uri,
        headers: {'Accept': 'application/json'},
      );
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

  Future<void> restoreListing(String listingSlug) async {
    final uri = Uri.parse('$baseUrl/api/v1/listings/$listingSlug/restore/');
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

    // Код тарифа уходит таким, каким его отдал сам бэкенд в GET /tariffs/.
    // Прежний клиентский маппинг (owner->free, top/vip->realtor,
    // premium->agency) ломал покупку: на сервере лежат тарифы с кодами
    // owner/top/vip/premium, псевдонима realtor там нет, и запрос уходил в
    // тариф-заглушку вместо выбранного.

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Idempotency-Key': key,
        },
        body: jsonEncode({
          'tariff_code': tariffCode,
          'months': months,
          'payment_method': paymentMethod,
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

  /// Конфигурация приложения: версии, флаги и ссылки на документы.
  ///
  /// Отсюда экран регистрации берёт актуальную версию соглашения — сервер
  /// сверяет её при создании аккаунта и отклоняет устаревшую.
  Future<Map<String, dynamic>> getAppConfig() async {
    final uri = Uri.parse('$baseUrl/api/v1/app/config/');
    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  /// Запрашивает код. В ответе — `expires_in`, `resend_after`, `is_new_user`.
  ///
  /// `resend_after` нужен экрану кода: собственный отсчёт клиента расходился
  /// с серверными лимитами и показывал второе, неверное время.
  Future<Map<String, dynamic>> requestOtp(String phone, {String? purpose, String? password, String? name}) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/otp/request/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone,
          if (purpose != null) 'purpose': purpose,
          if (password != null && password.isNotEmpty) 'password': password,
          if (name != null && name.isNotEmpty) 'name': name,
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

  /// Подтверждение кода. `password` и `termsVersion` заполняются только на
  /// регистрации: у входа по коду их нет.
  Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String code, {
    String? name,
    String? password,
    String? purpose,
    String? termsVersion,
  }) async {
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
          // Версию соглашения берём из /app/config/, а не зашиваем: подставить
          // её за пользователя — значит принять соглашение вместо него.
          if (termsVersion != null) 'accepted_terms_version': termsVersion,
          if (name != null) 'name': name,
          if (password != null && password.isNotEmpty) 'password': password,
          if (purpose != null) 'purpose': purpose,
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

  /// Новый пароль по коду из SMS. В ответе — сразу пара токенов.
  Future<Map<String, dynamic>> resetPassword(
    String phone,
    String code,
    String password,
  ) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/password/reset/');
    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'phone': phone, 'code': code, 'password': password}),
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

  // -- продавцы (публичный профиль) -------------------------------------------

  /// Публичная карточка продавца.
  Future<Map<String, dynamic>> getSeller(int sellerId) async {
    return _getJson(Uri.parse('$baseUrl/api/v1/sellers/$sellerId/'));
  }

  /// Список активных объявлений продавца с фильтрацией и курсорной пагинацией.
  Future<Map<String, dynamic>> getSellerListings(
    int sellerId, {
    String? cursor,
    String? kind,
    int? pageSize,
  }) async {
    if (cursor != null && cursor.isNotEmpty) {
      return _getJson(Uri.parse(cursor));
    }
    final params = <String, String>{};
    if (kind != null && kind.isNotEmpty) {
      params['kind'] = kind;
    }
    if (pageSize != null && pageSize > 0) {
      params['page_size'] = pageSize.toString();
    }
    final uri = Uri.parse('$baseUrl/api/v1/sellers/$sellerId/listings/').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    return _getJson(uri);
  }

  // -- диалоги и уведомления --------------------------------------------------
  //
  // Контракт задеплоен и не переизобретается: пути, имена полей и курсоры взяты
  // из apps/messaging и apps/notifications как есть.

  /// Список диалогов. Курсорная пагинация: results, next, previous, count.
  Future<Map<String, dynamic>> getConversations({String? cursor}) async {
    final uri = cursor != null && cursor.isNotEmpty
        ? Uri.parse(cursor)
        : Uri.parse('$baseUrl/api/v1/conversations/');
    return _getJson(uri);
  }

  /// Открывает диалог по объявлению. Сервер возвращает существующий, если он
  /// уже есть (201 на новый, 200 на найденный), поэтому дубликатов не будет.
  Future<Map<String, dynamic>> openConversation(String listingSlug) async {
    return _postJson(
      Uri.parse('$baseUrl/api/v1/conversations/'),
      {'listing_slug': listingSlug},
    );
  }

  Future<Map<String, dynamic>> getConversation(String conversationId) async {
    return _getJson(Uri.parse('$baseUrl/api/v1/conversations/$conversationId/'));
  }

  /// История сообщений. Без курсора отдаёт самые свежие; `next` ведёт к старым.
  Future<Map<String, dynamic>> getMessages(String conversationId, {String? cursor}) async {
    final uri = cursor != null && cursor.isNotEmpty
        ? Uri.parse(cursor)
        : Uri.parse('$baseUrl/api/v1/conversations/$conversationId/messages/');
    return _getJson(uri);
  }

  /// Только то, что появилось после известного сообщения.
  Future<Map<String, dynamic>> getMessagesAfter(
    String conversationId,
    String afterMessageId,
  ) async {
    return _getJson(Uri.parse(
      '$baseUrl/api/v1/conversations/$conversationId/messages/?after=$afterMessageId',
    ));
  }

  /// Отправка сообщения. `clientMessageId` обязателен: по нему сервер
  /// защищается от дублей, а повтор возвращает то же самое сообщение.
  Future<Map<String, dynamic>> sendMessage(
    String conversationId,
    String text,
    String clientMessageId,
  ) async {
    return _postJson(
      Uri.parse('$baseUrl/api/v1/conversations/$conversationId/messages/'),
      {'text': text, 'client_message_id': clientMessageId},
    );
  }

  /// Отмечает диалог прочитанным до указанного сообщения.
  Future<Map<String, dynamic>> markConversationRead(
    String conversationId,
    String lastMessageId,
  ) async {
    return _postJson(
      Uri.parse('$baseUrl/api/v1/conversations/$conversationId/read/'),
      {'last_message_id': lastMessageId},
    );
  }

  Future<void> registerPushDevice({required String token, required String deviceId,
      required String locale}) async {
    await _pushDeviceRequest('POST', '/api/v1/notifications/devices/', {
      'token': token, 'platform': 'android', 'device_id': deviceId, 'locale': locale,
    });
  }

  Future<void> deactivatePushDevice(String deviceId) => _pushDeviceRequest(
    'DELETE', '/api/v1/notifications/devices/current/', {'device_id': deviceId});

  Future<void> _pushDeviceRequest(String method, String path, Map<String, dynamic> body) async {
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 10), () => abort.complete());
    final request = http.AbortableRequest(method, Uri.parse('$baseUrl$path'), abortTrigger: abort.future)
      ..headers.addAll({'Content-Type': 'application/json', 'Accept': 'application/json'})
      ..body = jsonEncode(body);
    final access = _client.accessToken;
    if (access != null) request.headers['Authorization'] = 'Bearer $access';
    try {
      // Bind this operation to the current session. A delayed 401 must not
      // refresh credentials after logout and register for a different user.
      // Normal API traffic refreshes auth; push retries on the next resume.
      final response = await http.Response.fromStream(await _client.sendWithoutAuth(request))
          .timeout(const Duration(seconds: 10));
      if (method == 'DELETE' && (response.statusCode == 204 || response.statusCode == 404)) return;
      _processResponse(response);
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<Map<String, dynamic>> getNotifications({String? cursor}) async {
    final uri = cursor != null && cursor.isNotEmpty
        ? Uri.parse(cursor)
        : Uri.parse('$baseUrl/api/v1/notifications/');
    return _getJson(uri);
  }

  Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    return _getJson(Uri.parse('$baseUrl/api/v1/notifications/unread-count/'));
  }

  /// Отмечает уведомления прочитанными: перечисленные или все сразу.
  Future<Map<String, dynamic>> markNotificationsRead({
    List<int>? ids,
    bool all = false,
  }) async {
    return _postJson(
      Uri.parse('$baseUrl/api/v1/notifications/read/'),
      all ? {'all': true} : {'ids': ids ?? const <int>[]},
    );
  }

  Future<Map<String, dynamic>> getNotificationSettings() async {
    return _getJson(Uri.parse('$baseUrl/api/v1/notifications/settings/'));
  }

  Future<Map<String, dynamic>> updateNotificationSettings(Map<String, dynamic> patch) async {
    final uri = Uri.parse('$baseUrl/api/v1/notifications/settings/');
    try {
      final response = await _client.patch(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(patch),
      );
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  Future<Map<String, dynamic>> _postJson(Uri uri, Map<String, dynamic> body) async {
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } on SocketException {
      throw NetworkException('Отсутствует подключение к сети');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw NetworkException(e.toString());
    }
  }
  Future<void> sendSupportTicket({
    required String subject,
    required String message,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/support/tickets/');
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'subject': subject,
        'message': message,
      }),
    );
    _processResponse(response);
  }
}
