import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:house_kgz/data/api_client.dart';

class _DownloadClient extends http.BaseClient {
  http.BaseRequest? request;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    this.request = request;
    return http.StreamedResponse(
      Stream.value(const [1, 2, 3, 4]),
      200,
      headers: {'content-type': 'video/mp4'},
    );
  }
}

void main() {
  test(
    'media download streams bytes through the authenticated API client',
    () async {
      final httpClient = _DownloadClient();
      final apiClient = ListingApiClient(
        baseUrl: 'https://test.local',
        client: httpClient,
      )..setToken('secret-token');
      final tempDirectory = await Directory.systemTemp.createTemp(
        'house_kg_test_',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final output = File('${tempDirectory.path}/reel.mp4');

      await apiClient.downloadFile(
        'https://test.local/private/reel.mp4',
        output.path,
      );

      expect(
        httpClient.request?.url.toString(),
        'https://test.local/private/reel.mp4',
      );
      expect(
        httpClient.request?.headers['Authorization'],
        'Bearer secret-token',
      );
      expect(await output.readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test('media download never leaks the API token to an external CDN', () async {
    final httpClient = _DownloadClient();
    final apiClient = ListingApiClient(
      baseUrl: 'https://api.test.local',
      client: httpClient,
    )..setToken('secret-token');
    final tempDirectory = await Directory.systemTemp.createTemp('house_kg_test_');
    addTearDown(() => tempDirectory.delete(recursive: true));

    await apiClient.downloadFile(
      'https://cdn.test.local/media/reel.mp4',
      '${tempDirectory.path}/reel.mp4',
    );

    expect(httpClient.request?.headers.containsKey('Authorization'), isFalse);
  });
}
