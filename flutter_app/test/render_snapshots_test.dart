import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/code_flow.dart';
import 'package:house_kgz/data/listings.dart';
import 'package:house_kgz/l10n/l10n.dart';
import 'package:house_kgz/ui/listing_grid.dart';
import 'package:house_kgz/ui/pages/code_page.dart';
import 'package:house_kgz/ui/pages/register_page.dart';

class _MockHttpServer extends http.BaseClient {
  http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.contains('/terms/latest/')) {
      return _json({'version': '1.0', 'url': 'https://example.com/terms'});
    }
    if (path.contains('/auth/otp/request/')) {
      return _json({'status': 'sent', 'resend_after': 60});
    }
    return _json({'detail': 'Not found'}, 404);
  }
}

Future<void> _saveScreenshot(WidgetTester tester, String filename) async {
  await tester.runAsync(() async {
    final boundaryFinder = find.byType(RepaintBoundary).first;
    final element = boundaryFinder.evaluate().first;
    final boundary = element.renderObject! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    
    final dir = Directory('/Users/adminbaike/.gemini/antigravity/brain/c55ca670-d8d2-4f91-9e35-840ba1ff0eab/scratch');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('${dir.path}/$filename').writeAsBytesSync(pngBytes);
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'test_token'});
  });

  testWidgets('Render RegisterPage snapshot', (tester) async {
    final mockHttp = _MockHttpServer();
    final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

    tester.view.physicalSize = const Size(375 * 2.0, 812 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SizedBox(
        width: 375,
        height: 812,
        child: RepaintBoundary(
          child: AppScope(
            state: state,
            child: const RegisterPage(),
          ),
        ),
      ),
    ));
    await tester.pump();

    await _saveScreenshot(tester, 'register_page_rendered.png');
  });

  testWidgets('Render CodePage snapshot', (tester) async {
    final mockHttp = _MockHttpServer();
    final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

    tester.view.physicalSize = const Size(375 * 2.0, 812 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SizedBox(
        width: 375,
        height: 812,
        child: RepaintBoundary(
          child: AppScope(
            state: state,
            child: const CodePage(
              phone: '+996 777 21 27 98',
              flow: CodeFlow(
                kind: CodeFlowKind.register,
                phone: '+996 777 21 27 98',
                name: 'Адилет',
                password: 'password123',
                resendAfter: 60,
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    await _saveScreenshot(tester, 'code_page_rendered.png');
  });

  testWidgets('Render Catalog Grid snapshot', (tester) async {
    final mockHttp = _MockHttpServer();
    final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

    tester.view.physicalSize = const Size(375 * 2.0, 812 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final listings = [
      const Listing(
        id: '1',
        district: 'Технопарк',
        priceUsd: 185000,
        rooms: 4,
        area: 145,
        floor: 12,
        floors: 14,
        kind: PropertyKind.apartment,
        seller: SellerKind.owner,
        status: 'active',
        photo: 'assets/figma/92b0d143df96c511.jpg',
      ),
      const Listing(
        id: '2',
        district: 'Центр',
        priceUsd: 245000,
        rooms: 3,
        area: 115,
        floor: 1,
        floors: 9,
        kind: PropertyKind.apartment,
        seller: SellerKind.owner,
        status: 'active',
        photo: 'assets/figma/2e62acec850fa8b9.jpg',
      ),
      const Listing(
        id: '3',
        district: 'Центр',
        priceUsd: 59000,
        rooms: 1,
        area: 48,
        floor: 5,
        floors: 9,
        kind: PropertyKind.apartment,
        seller: SellerKind.owner,
        status: 'active',
        photo: 'assets/figma/92b0d143df96c511.jpg',
      ),
      const Listing(
        id: '4',
        district: 'Кок-Жар',
        priceUsd: 195000,
        rooms: 5,
        area: 210,
        landArea: 8.0,
        floor: 2,
        floors: 2,
        kind: PropertyKind.house,
        seller: SellerKind.owner,
        status: 'active',
        photo: 'assets/figma/2e62acec850fa8b9.jpg',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RepaintBoundary(
        child: Scaffold(
          backgroundColor: Colors.white,
          body: AppScope(
            state: state,
            child: ListingGrid(
              listings: listings,
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    await _saveScreenshot(tester, 'catalog_grid_rendered.png');
  });
}
