import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:house_kgz/data/api_client.dart';

class _MockHttpServer extends http.BaseClient {
  int callCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    if (request.url.path == '/api/v1/listings/test-slug/') {
      final auth = request.headers['Authorization'];
      if (auth == 'Bearer old_expired_token') {
        // Return 401 Token is expired
        final body = utf8.encode(jsonEncode({
          'error': {
            'code': 'token_not_valid',
            'message': 'Token is expired',
          }
        }));
        return http.StreamedResponse(Stream.value(body), 401, headers: {'content-type': 'application/json'});
      }
      if (auth == 'Bearer new_fresh_token') {
        // Return 200 OK
        final body = utf8.encode(jsonEncode({'slug': 'test-slug', 'price': 100000}));
        return http.StreamedResponse(Stream.value(body), 200, headers: {'content-type': 'application/json'});
      }
    }
    return http.StreamedResponse(Stream.value([]), 404);
  }
}

void main() {
  test('ListingApiClient transparently refreshes expired token on 401 and succeeds', () async {
    final server = _MockHttpServer();
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: server);
    apiClient.setToken('old_expired_token');

    bool refreshCalled = false;
    apiClient.setTokenRefreshCallback(() async {
      refreshCalled = true;
      return 'new_fresh_token';
    });

    final result = await apiClient.getListingDetails('test-slug');

    expect(refreshCalled, true);
    expect(server.callCount, 2); // Initial call (401) + Retry call (200)
    expect(result['slug'], 'test-slug');
    expect(result['price'], 100000);
  });
}
