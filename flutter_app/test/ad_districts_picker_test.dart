import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/ad_form_page.dart';

class _TestClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  _TestClient(this.handler);

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
  testWidgets('AdFormPage district picker loads and displays districts correctly', (tester) async {
    final client = _TestClient((request) async {
      if (request.url.path == '/api/v1/catalog/filter-options/') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'districts': [
              {'id': 2, 'name': 'Асанбай', 'slug': 'asanbay', 'city': 'bishkek'},
              {'id': 1, 'name': 'Ленин', 'slug': 'lenin', 'city': 'bishkek'},
              {'id': 5, 'name': 'Центр', 'slug': 'center', 'city': 'bishkek'},
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
          home: AdFormPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on district dropdown
    expect(find.text('Выберите район'), findsWidgets);
    await tester.tap(find.text('Выберите район').first);
    await tester.pumpAndSettle();

    // Verify modal title and districts
    expect(find.text('Выберите район Бишкека'), findsOneWidget);
    expect(find.text('Асанбай'), findsOneWidget);
    expect(find.text('Ленин'), findsOneWidget);
    expect(find.text('Центр'), findsOneWidget);

    // Select 'Асанбай'
    await tester.tap(find.text('Асанбай'));
    await tester.pumpAndSettle();

    // District selected
    expect(state.draftDistrict, 'asanbay');
    expect(find.text('Асанбай'), findsWidgets);
  });
}
