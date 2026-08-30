import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/ad_media.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/listings.dart';
import 'package:house_kgz/ui/pages/ad_form_page.dart';
import 'package:house_kgz/ui/pages/ad_photos_page.dart';
import 'package:house_kgz/ui/pages/ad_video_page.dart';
import 'package:house_kgz/ui/pages/ad_promo_page.dart';
import 'package:house_kgz/ui/pages/ad_preview_page.dart';

class _MockMediaSource implements MediaSource {
  @override
  Future<List<AdMedia>> photos({required bool camera}) async {
    return [
      const AdMedia.demo('assets/figma/2e62acec850fa8b9.jpg'),
    ];
  }

  @override
  Future<AdMedia?> video({required bool camera}) async {
    return const AdMedia.demo('assets/figma/231c034e3954a705.jpg', video: true);
  }
}

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
  testWidgets('AdFlow: Form -> Photos -> Video -> Promo -> Preview full flow test', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed') ||
          details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final client = _TestCaptureClient((request) async {
      final path = request.url.path;
      if (path == '/api/v1/listings/draft/' && request.method == 'POST') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 1001,
            'slug': 'test-draft-slug',
            'kind': 'apartment',
            'district': 'asanbay',
            'rooms': 3,
            'area': 118.0,
            'price': 145000,
            'currency': 'USD',
            'media': [],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (path == '/api/v1/listings/test-draft-slug/' && request.method == 'PATCH') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'slug': 'test-draft-slug'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (path == '/api/v1/listings/test-draft-slug/publish/' && request.method == 'POST') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 1001,
            'slug': 'test-draft-slug',
            'status': 'active',
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (path == '/api/v1/listings/test-draft-slug/' && request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': 1001,
            'slug': 'test-draft-slug',
            'kind': 'apartment',
            'district': {'id': 1, 'slug': 'asanbay', 'name': 'Асанбай'},
            'rooms': 3,
            'floor': 8,
            'floors': 14,
            'area': 118.0,
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
    final state = AppState(media: _MockMediaSource(), apiClient: apiClient);
    state.draftDistrict = 'asanbay';

    // 1. Render AdFormPage
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          routes: {
            Routes.adPhotos: (context) => const AdPhotosPage(),
            Routes.adVideo: (context) => const AdVideoPage(),
            Routes.adPromo: (context) => const AdPromoPage(),
            Routes.adPreview: (context) => const AdPreviewPage(slug: 'test-draft-slug'),
          },
          home: const AdFormPage(),
        ),
      ),
    );

    expect(find.text('Добавить недвижимость'), findsOneWidget);

    // Enter Area and Price
    final areaFinder = find.widgetWithText(TextField, 'Введите свою квадратуру...');
    expect(areaFinder, findsOneWidget);
    await tester.enterText(areaFinder, '118');

    final priceFinder = find.widgetWithText(TextField, 'Цена');
    expect(priceFinder, findsOneWidget);
    await tester.enterText(priceFinder, '145000');

    // Tap «Далее»
    final nextBtn = find.widgetWithText(ElevatedButton, 'Далее');
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // 2. We should now be on AdPhotosPage
    expect(find.text('Добавить/изменить фотографии'), findsOneWidget);
    expect(state.draftSlug, 'test-draft-slug');

    // Tap «Далее» on photos
    final photosNextBtn = find.widgetWithText(ElevatedButton, 'Далее');
    expect(photosNextBtn, findsOneWidget);
    await tester.tap(photosNextBtn);
    await tester.pumpAndSettle();

    // 3. We should now be on AdVideoPage
    expect(find.text('Добавить видео'), findsOneWidget);

    // Tap «Далее» on video
    final videoNextBtn = find.widgetWithText(ElevatedButton, 'Далее');
    expect(videoNextBtn, findsOneWidget);
    await tester.tap(videoNextBtn);
    await tester.pumpAndSettle();

    // 4. We should now be on AdPromoPage
    expect(find.byType(AdPromoPage), findsOneWidget);

    // Tap «Далее» (publish)
    final promoNextBtn = find.widgetWithText(ElevatedButton, 'Далее');
    expect(promoNextBtn, findsOneWidget);
    await tester.tap(promoNextBtn);
    await tester.pumpAndSettle();

    // 5. We should now be on AdPreviewPage
    expect(find.text('Ваше объявление'), findsOneWidget);
    expect(find.text('145 000 \$'), findsOneWidget);
    expect(find.text('3-комн.'), findsOneWidget);
    expect(find.text('118 м²'), findsOneWidget);
    expect(find.text('8/14 эт.'), findsOneWidget);
    expect(find.text('Продвижение'), findsOneWidget);
    expect(find.text('Просмотр статистики'), findsOneWidget);
    expect(find.text('Изменить объявление'), findsOneWidget);
  });
}
