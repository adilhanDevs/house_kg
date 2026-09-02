import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/api_exceptions.dart';

void main() {
  group('ListingApiClient', () {
    const baseUrl = 'http://test.com';

    test('requestOtp sends correct POST request', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/otp/request/');
        expect(request.headers['Content-Type'], 'application/json');
        
        final body = jsonDecode(request.body);
        expect(body['phone'], '+996700123456');
        
        return http.Response(jsonEncode({'expires_in': 300}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.requestOtp('+996700123456');
    });

    test('verifyOtp parses response correctly', () async {
      final mockResponse = {
        'access': 'access_token_123',
        'refresh': 'refresh_token_123',
        'is_new_user': false,
      };

      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/otp/verify/');
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.verifyOtp('+996700123456', '1234');
      
      expect(response['access'], 'access_token_123');
      expect(response['is_new_user'], false);
    });

    test('getListings sends GET with query parameters', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/listings/');
        expect(request.url.queryParameters['rooms'], '2');
        expect(request.url.queryParameters['cursor'], 'next_page');
        
        return http.Response(jsonEncode({'results': []}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.getListings(filters: {'rooms': 2}, cursor: 'next_page');
    });

    test('getListingDetails sends correct GET request', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/listings/test-slug/');
        return http.Response(jsonEncode({'slug': 'test-slug'}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.getListingDetails('test-slug');
    });

    test('recordListingView sends correct POST request', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/listings/test-slug/view/');
        return http.Response('', 204);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.recordListingView('test-slug');
    });

    test('createDraft sends POST to draft endpoint', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/listings/draft/') {
          expect(request.method, 'POST');
          return http.Response(jsonEncode({'slug': 'new-draft'}), 200);
        }
        if (request.url.path == '/api/v1/listings/new-draft/') {
          expect(request.method, 'PATCH');
          final body = jsonDecode(request.body);
          expect(body['kind'], 'apartment');
          return http.Response(jsonEncode({'slug': 'new-draft', 'kind': 'apartment'}), 200);
        }
        return http.Response('{}', 404);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final res = await apiClient.createDraft({'kind': 'apartment'});
      expect(res['slug'], 'new-draft');
    });

    test('updateDraft sends PATCH with correct body', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/listings/test-slug/');
        final body = jsonDecode(request.body);
        expect(body['price'], 1000);
        return http.Response(jsonEncode({'slug': 'test-slug'}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.updateDraft('test-slug', {'price': 1000});
    });

    test('publishListing sends POST to publish endpoint', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/listings/test-slug/publish/');
        return http.Response('', 204);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.publishListing('test-slug');
    });

    test('getReelsFeed sends GET with cursor', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/listings/reels/');
        expect(request.url.queryParameters['cursor'], 'reels-cursor');
        return http.Response(jsonEncode({'results': []}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.getReelsFeed('reels-cursor');
    });

    test('updateMediaMetadata sends PATCH with correct data', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/listings/test-slug/media/42/');
        final body = jsonDecode(request.body);
        expect(body['title'], 'My Video');
        expect(body['description'], 'Great description');
        return http.Response('', 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.updateMediaMetadata('test-slug', 42, 'My Video', 'Great description');
    });

    test('registerPro sends POST with correct fields', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/pro/register/');
        final body = jsonDecode(request.body);
        expect(body['phone'], '+996700123456');
        expect(body['iin'], '12345678901234');
        return http.Response(jsonEncode({'status': 'ok'}), 201);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.registerPro('+996700123456', 'Name', 'pwd', '12345678901234');
    });

    test('uploadMedia прикладывает к видео обложку и метаданные', () async {
      http.BaseRequest? capturedRequest;
      final client = _CaptureClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'accepted': 1, 'media': [{'id': 7}]}), 201);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.uploadMedia(
        'test-slug',
        bytes: [1, 2, 3],
        filename: 'clip.mp4',
        kind: 'video',
        thumbnailBytes: [4, 5, 6],
        durationSeconds: 42,
        width: 1920,
        height: 1080,
      );

      final multipart = capturedRequest as http.MultipartRequest;
      expect(multipart.fields['kind'], 'video');
      expect(multipart.fields['duration_seconds'], '42');
      expect(multipart.fields['width'], '1920');
      expect(multipart.fields['height'], '1080');

      final fields = multipart.files.map((f) => f.field).toList();
      expect(fields, containsAll(<String>['files', 'thumbnail']));
    });

    test('uploadMedia не шлёт обложку и длительность для фото', () async {
      http.BaseRequest? capturedRequest;
      final client = _CaptureClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'accepted': 1, 'media': [{'id': 8}]}), 201);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.uploadMedia(
        'test-slug',
        bytes: [1, 2, 3],
        filename: 'photo.jpg',
        kind: 'photo',
        thumbnailBytes: [4, 5, 6],
        durationSeconds: 42,
      );

      final multipart = capturedRequest as http.MultipartRequest;
      expect(multipart.fields.containsKey('duration_seconds'), isFalse);
      expect(multipart.files.map((f) => f.field), ['files']);
    });

    test('uploadMedia sends MultipartRequest with kind field', () async {
      final tempFile = File('test_video.mp4')..writeAsBytesSync([0, 1, 2]);
      
      http.BaseRequest? capturedRequest;
      
      final client = _CaptureClient((request) async {
        capturedRequest = request;
        final mockResponse = {
          'accepted': 1,
          'media': [{'id': 42}]
        };
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.uploadMedia('test-slug', file: tempFile);
      
      expect(capturedRequest, isA<http.MultipartRequest>());
      final multipart = capturedRequest as http.MultipartRequest;
      
      expect(multipart.method, 'POST');
      expect(multipart.url.path, '/api/v1/listings/test-slug/media/');
      expect(multipart.fields['kind'], 'video');
      expect(multipart.files.length, 1);
      expect(multipart.files.first.field, 'files');
      
      expect(response['media'][0]['id'], 42);
      
      tempFile.deleteSync();
    });

    test('throws ApiException on 400 Bad Request', () async {
      final client = MockClient((request) async {
        final errorResponse = {
          'error': {
            'code': 'validation_error',
            'message': 'Error message'
          }
        };
        return http.Response(jsonEncode(errorResponse), 400);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      
      expect(
        () => apiClient.requestOtp('+996700123456'),
        throwsA(isA<ApiException>()),
      );
    });

    test('getMe sends GET request and returns profile', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/users/me/');
        return http.Response(jsonEncode({'name': 'John Doe', 'is_pro': true}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final profile = await apiClient.getMe();
      expect(profile['name'], 'John Doe');
      expect(profile['is_pro'], true);
    });

    test('updateMe sends PATCH request with data', () async {
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/users/me/');
        final body = jsonDecode(request.body);
        expect(body['name'], 'Jane Doe');
        return http.Response(jsonEncode({'name': 'Jane Doe'}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.updateMe({'name': 'Jane Doe'});
      expect(response['name'], 'Jane Doe');
    });

    test('logout sends POST request with refresh token', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/logout/');
        final body = jsonDecode(request.body);
        expect(body['refresh'], 'some-refresh-token');
        return http.Response(jsonEncode({'status': 'ok'}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.logout('some-refresh-token');
    });

    test('getFilterOptions sends GET request and returns options', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/catalog/filter-options/');
        expect(request.url.queryParameters['city'], 'Бишкек');
        return http.Response.bytes(utf8.encode(jsonEncode({
          'districts': [{'value': 'oktyabrskij', 'label': 'Октябрьский'}],
          'rooms': [1, 2, 3],
        })), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final options = await apiClient.getFilterOptions(city: 'Бишкек');
      expect(options['districts'].length, 1);
      expect(options['rooms'].length, 3);
    });

    test('getFavourites sends GET request with cursor', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/favourites/');
        expect(request.url.queryParameters['cursor'], 'cur123');
        return http.Response(jsonEncode({
          'results': [],
          'next': 'cur456',
        }), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.getFavourites(cursor: 'cur123');
      expect(response['next'], 'cur456');
    });

    test('toggleFavourite sends POST request', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/listings/slug123/favourite/');
        return http.Response(jsonEncode({'is_favourited': true}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.toggleFavourite('slug123');
      expect(response['is_favourited'], true);
    });

    test('getViewHistory sends GET request with cursor', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/view-history/');
        expect(request.url.queryParameters['cursor'], 'cur123');
        return http.Response(jsonEncode({
          'results': [],
          'next': 'cur456',
        }), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.getViewHistory(cursor: 'cur123');
      expect(response['next'], 'cur456');
    });

    test('clearViewHistory sends DELETE request', () async {
      final client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/view-history/');
        return http.Response(jsonEncode({}), 204);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await apiClient.clearViewHistory();
    });

    test('getWalletBalance returns balance', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/wallet/');
        return http.Response(jsonEncode({'balance': 12000}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.getWalletBalance();
      expect(response['balance'], 12000);
    });

    test('getWalletTransactions returns transactions with cursor and kind', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/wallet/transactions/');
        expect(request.url.queryParameters['cursor'], 'cur123');
        expect(request.url.queryParameters['kind'], 'topup');
        return http.Response(jsonEncode({
          'results': [{'id': 1}],
          'next': 'cur456',
        }), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.getWalletTransactions(cursor: 'cur123', kind: 'topup');
      expect(response['next'], 'cur456');
      expect(response['results'].length, 1);
    });

    test('promoteListing sends POST request with Idempotency-Key', () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/listings/slug123/promote/');
        expect(request.headers['Idempotency-Key'], 'uuid-v4-key');
        expect(request.body, jsonEncode({'days': 3}));
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.promoteListing('slug123', 3, 'uuid-v4-key');
      expect(response['success'], true);
    });

    test('ListingApiClient getDraft sends GET to draft endpoint', () async {
      final client = _CaptureClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/listings/draft/');
        return http.Response(jsonEncode({'slug': 'draft-123'}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final response = await apiClient.getDraft();
      expect(response['slug'], 'draft-123');
    });

    test('ListingApiClient deleteMedia sends DELETE request', () async {
      final client = _CaptureClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/listings/slug123/media/42/');
        return http.Response('', 204);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await expectLater(apiClient.deleteMedia('slug123', 42), completes);
    });

    test('ListingApiClient archiveListing sends POST request', () async {
      final client = _CaptureClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/listings/slug123/archive/');
        return http.Response(jsonEncode({'status': 'archived'}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      await expectLater(apiClient.archiveListing('slug123'), completes);
    });

    test('ListingApiClient refreshToken sends POST without Authorization header', () async {
      final client = _CaptureClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/refresh/');
        expect(request.headers.containsKey('Authorization'), false);
        return http.Response(jsonEncode({'access': 'new_access', 'refresh': 'new_refresh'}), 200);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      apiClient.setToken('old_expired_token');
      final result = await apiClient.refreshToken('refresh_123');
      expect(result['access'], 'new_access');
      expect(result['refresh'], 'new_refresh');
    });

    test('ListingApiClient getTariffs and subscribe work correctly', () async {
      final client = _CaptureClient((request) async {
        if (request.url.path == '/api/v1/tariffs/') {
          return http.Response(jsonEncode([{'code': 'vip', 'name': 'VIP'}]), 200);
        }
        if (request.url.path == '/api/v1/subscriptions/') {
          return http.Response(jsonEncode({'status': 'active', 'tariff_code': 'vip'}), 201);
        }
        return http.Response('', 404);
      });

      final apiClient = ListingApiClient(baseUrl: baseUrl, client: client);
      final tariffs = await apiClient.getTariffs();
      expect(tariffs.length, 1);
      expect(tariffs[0]['code'], 'vip');

      final sub = await apiClient.subscribe('vip', paymentMethod: 'bricks');
      expect(sub['tariff_code'], 'vip');
    });
  });
}

class _CaptureClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  
  _CaptureClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
