import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/ad_media.dart';
import 'package:house_kgz/ui/pages/ad_edit_page.dart';
import 'package:house_kgz/ui/pages/ad_preview_page.dart';

class _MockEditClient extends http.BaseClient {
  Map<String, dynamic>? lastPatchBody;
  int deleteMediaCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (request.method == 'GET' && path.contains('/api/v1/listings/test-slug/')) {
      final data = {
        'slug': 'test-slug',
        'address': 'ул. Токомбаева, 21',
        'rooms': 4,
        'area': 2222.0,
        'price': 2222,
        'floor': 2,
        'floors_total': 2,
        'district': {'slug': 'yuzhnye-vorota', 'name': 'Южные ворота'},
        'series': '106',
        'builder': 'Ихлас',
        'description': 'Просторный пентхаус с ремонтом',
        'condition': 'euro',
        'furniture': 'full',
        'heating': 'central',
        'has_gas': true,
        'mortgage_ready': true,
        'exchange_possible': false,
        'media': [
          {'id': 101, 'kind': 'photo', 'url': 'http://test.com/photo1.jpg'},
          {'id': 102, 'kind': 'photo', 'url': 'http://test.com/photo2.jpg'},
          {'id': 201, 'kind': 'video', 'url': 'http://test.com/video.mp4'},
        ],
        'views_count': 15,
        'leads_count': 2,
        'sent_to_clients_count': 5,
        'status': 'active',
      };
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(data))),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (request.method == 'PATCH' && path.contains('/api/v1/listings/test-slug/')) {
      if (request is http.Request) {
        lastPatchBody = jsonDecode(request.body) as Map<String, dynamic>;
      }
      final data = {'slug': 'test-slug', 'status': 'active'};
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(data))),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (request.method == 'DELETE' && path.contains('/media/')) {
      deleteMediaCount++;
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'detail': 'ok'}))),
        204,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'detail': 'not found'}))),
      404,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  testWidgets('AdEditPage loads listing data and saves modifications via PATCH', (tester) async {
    final client = _MockEditClient();
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: AdEditPage(
            slug: 'test-slug',
            media: DeviceMedia(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify fields populated
    expect(find.text('Редактирование объявления'), findsOneWidget);
    expect(find.text('ул. Токомбаева, 21'), findsOneWidget);
    expect(find.text('Южные ворота'), findsOneWidget);
    expect(find.text('2222'), findsNWidgets(2)); // area and price
    expect(find.text('Ихлас'), findsOneWidget);
    expect(find.text('Просторный пентхаус с ремонтом'), findsOneWidget);

    // Verify photos section
    expect(find.text('Главное'), findsOneWidget);

    // Edit price field
    final priceFinder = find.widgetWithText(TextField, '2222').last;
    await tester.enterText(priceFinder, '250000');
    await tester.pump();

    // Tap Save button in AppBar
    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify PATCH was sent
    expect(client.lastPatchBody, isNotNull);
    expect(client.lastPatchBody!['price'], 250000);
    expect(client.lastPatchBody!['district'], 'yuzhnye-vorota');
    expect(client.lastPatchBody!['rooms'], 4);
  });

  testWidgets('AdPreviewPage Edit button navigates to AdEditPage', (tester) async {
    final client = _MockEditClient();
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          routes: {
            Routes.adEdit: (_) => const Scaffold(body: Text('Ad Edit Mock Screen')),
          },
          home: const AdPreviewPage(slug: 'test-slug'),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Изменить объявление'), findsOneWidget);

    await tester.tap(find.text('Изменить объявление'));
    await tester.pumpAndSettle();

    expect(find.text('Ad Edit Mock Screen'), findsOneWidget);
  });

  testWidgets('AdEditPage renders multiple videos and allows deleting a video', (tester) async {
    final client = _MockEditClient();
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);

    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: AdEditPage(
            slug: 'test-slug',
            media: DeviceMedia(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify video from backend is shown
    expect(find.text('Видеоролик 1'), findsOneWidget);
    expect(find.text('Добавить еще видео (+)'), findsOneWidget);

    // Delete the existing video
    final deleteVideoBtn = find.byIcon(Icons.delete_outline).last;
    await tester.tap(deleteVideoBtn);
    await tester.pumpAndSettle();

    expect(client.deleteMediaCount, 1);
    expect(find.text('Добавить видеоролик'), findsOneWidget);
  });
}
