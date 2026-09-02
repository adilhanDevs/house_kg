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
  testWidgets('Draft listing displays «Опубликовать» and «Изменить объявление»', (tester) async {
    final client = _TestCaptureClient((request) async {
      if (request.url.path == '/api/v1/listings/my-draft-slug/' && request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 101,
            'slug': 'my-draft-slug',
            'status': 'draft',
            'kind': 'apartment',
            'district': {'id': 1, 'slug': 'asanbay', 'name': 'Асанбай'},
            'rooms': 2,
            'floor': 4,
            'floors': 9,
            'area': 65,
            'price': 80000,
            'currency': 'USD',
            'views_count': 0,
            'media': [
              {'id': 10, 'file': 'https://example.com/p1.jpg', 'kind': 'photo', 'is_cover': true}
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
          home: AdPreviewPage(slug: 'my-draft-slug'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Draft badge is visible
    expect(find.text('Черновик'), findsOneWidget);

    // Primary action «Опубликовать» is visible (both on card and in bottom actions)
    expect(find.text('Опубликовать'), findsNWidgets(2));

    // Secondary action «Изменить объявление» is visible
    expect(find.text('Изменить объявление'), findsOneWidget);

    // Archive button should NOT be shown for a draft
    expect(find.text('Снять с публикации (в архив)'), findsNothing);
  });

  testWidgets('Active listing does NOT display «Опубликовать» button', (tester) async {
    final client = _TestCaptureClient((request) async {
      if (request.url.path == '/api/v1/listings/active-slug/' && request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 102,
            'slug': 'active-slug',
            'status': 'active',
            'kind': 'apartment',
            'district': {'id': 1, 'slug': 'asanbay', 'name': 'Асанбай'},
            'rooms': 2,
            'floor': 4,
            'floors': 9,
            'area': 65,
            'price': 80000,
            'currency': 'USD',
            'views_count': 15,
            'media': [
              {'id': 10, 'file': 'https://example.com/p1.jpg', 'kind': 'photo', 'is_cover': true}
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
          home: AdPreviewPage(slug: 'active-slug'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Active status badge
    expect(find.text('Опубликовано'), findsOneWidget);

    // «Опубликовать» should NOT be present
    expect(find.text('Опубликовать'), findsNothing);

    // «Изменить объявление» is present
    expect(find.text('Изменить объявление'), findsOneWidget);

    // «Снять с публикации (в архив)» is present for active listing
    expect(find.text('Снять с публикации (в архив)'), findsOneWidget);
  });

  testWidgets('Publish success flow: tap publish -> API called once -> success -> updates to active', (tester) async {
    int publishCallCount = 0;
    String currentStatus = 'draft';

    final client = _TestCaptureClient((request) async {
      if (request.url.path == '/api/v1/listings/republish-slug/' && request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 103,
            'slug': 'republish-slug',
            'status': currentStatus,
            'kind': 'apartment',
            'district': {'id': 1, 'slug': 'asanbay', 'name': 'Асанбай'},
            'rooms': 2,
            'floor': 4,
            'floors': 9,
            'area': 65,
            'price': 80000,
            'currency': 'USD',
            'views_count': 0,
            'media': [
              {'id': 10, 'file': 'https://example.com/p1.jpg', 'kind': 'photo', 'is_cover': true}
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/v1/listings/republish-slug/publish/' && request.method == 'POST') {
        publishCallCount++;
        currentStatus = 'active';
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 103,
            'slug': 'republish-slug',
            'status': 'active',
            'price': '80000.00',
            'currency': 'USD',
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response('{}', 200);
    });

    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);
    state.draftSlug = 'republish-slug';

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: AdPreviewPage(slug: 'republish-slug'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Черновик'), findsOneWidget);
    final publishButton = find.text('Опубликовать').first;

    // Tap publish
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    // API was called exactly once
    expect(publishCallCount, 1);

    // Success snackbar shown
    expect(find.text('Объявление успешно опубликовано!'), findsOneWidget);

    // Listing status updated to active
    expect(find.text('Опубликовано'), findsOneWidget);
    expect(find.text('Черновик'), findsNothing);
    expect(find.text('Опубликовать'), findsNothing);

    // Draft slug in state was cleared
    expect(state.draftSlug, isNull);
  });

  testWidgets('Limit error flow: tap publish -> tariff limit 409 -> error dialog with change tariff -> draft intact', (tester) async {
    int publishCallCount = 0;

    final client = _TestCaptureClient((request) async {
      if (request.url.path == '/api/v1/listings/limit-slug/' && request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 104,
            'slug': 'limit-slug',
            'status': 'draft',
            'kind': 'apartment',
            'district': {'id': 1, 'slug': 'asanbay', 'name': 'Асанбай'},
            'rooms': 2,
            'floor': 4,
            'floors': 9,
            'area': 65,
            'price': 80000,
            'currency': 'USD',
            'views_count': 0,
            'media': [
              {'id': 10, 'file': 'https://example.com/p1.jpg', 'kind': 'photo', 'is_cover': true}
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path == '/api/v1/listings/limit-slug/publish/' && request.method == 'POST') {
        publishCallCount++;
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'error': {
              'code': 'conflict',
              'message': 'Достигнут лимит активных объявлений: одновременно можно держать 1. Архивируйте одно из активных или перейдите на другой тариф.',
              'details': {},
            }
          })),
          409,
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
          home: AdPreviewPage(slug: 'limit-slug'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Черновик'), findsOneWidget);
    final publishButton = find.text('Опубликовать').first;

    // Tap publish
    await tester.tap(publishButton);
    await tester.pumpAndSettle();

    // Verify error dialog appears with exact backend message
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Публикация объявления'), findsOneWidget);
    expect(
      find.text('Достигнут лимит активных объявлений: одновременно можно держать 1. Архивируйте одно из активных или перейдите на другой тариф.'),
      findsOneWidget,
    );
    expect(find.text('Сменить тариф'), findsOneWidget);
    expect(find.text('Понятно'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();

    // Verify dialog is closed, listing is STILL draft, and button is still available
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Черновик'), findsOneWidget);
    expect(find.text('Опубликовать'), findsNWidgets(2));
    expect(publishCallCount, 1);
  });
}
