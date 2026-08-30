import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/ad_preview_page.dart';

class _TestCaptureClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  _TestCaptureClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: request,
      headers: response.headers,
    );
  }
}

void main() {
  testWidgets('AdPreviewPage renders listing data and statistics', (tester) async {
    final client = _TestCaptureClient((request) async {
      if (request.url.path == '/api/v1/listings/test-slug/' && request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 1001,
            'slug': 'test-slug',
            'kind': 'apartment',
            'district': {'id': 1, 'slug': 'asanbay', 'name': 'Асанбай'},
            'rooms': 3,
            'floor': 8,
            'floors': 14,
            'area': 118,
            'price': 145000,
            'currency': 'USD',
            'views_count': 42,
            'media': [
              {'id': 1, 'file': 'https://example.com/photo1.jpg', 'kind': 'photo', 'is_cover': true}
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 200);
    });

    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: AdPreviewPage(slug: 'test-slug'),
        ),
      ),
    );

    // Initial loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Settle async fetch
    await tester.pumpAndSettle();

    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      print('RENDERED TEXT: "${text.data}"');
    }

    expect(find.text('Ваше объявление'), findsOneWidget);
    expect(find.text('145 000 \$'), findsOneWidget);
    expect(find.text('Асанбай'), findsOneWidget);
    expect(find.text('3-комн.'), findsOneWidget);
    expect(find.text('118 м²'), findsOneWidget);
    expect(find.text('8/14 эт.'), findsOneWidget);
    expect(find.text('Опубликовано'), findsOneWidget);
    expect(find.text('Продвижение'), findsOneWidget);
    expect(find.text('Просмотр статистики'), findsOneWidget);
    expect(find.text('42'), findsOneWidget); // Views count
    expect(find.text('Просмотров'), findsOneWidget);
    expect(find.text('Изменить объявление'), findsOneWidget);
  });
}
