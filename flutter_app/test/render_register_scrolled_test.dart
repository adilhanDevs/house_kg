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
import 'package:house_kgz/l10n/l10n.dart';
import 'package:house_kgz/ui/pages/register_page.dart';

class _MockHttpServer extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'version': '1.0'}))),
      200,
      headers: {'content-type': 'application/json'},
    );
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

  testWidgets('Render RegisterPage scrolled snapshot', (tester) async {
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
      home: RepaintBoundary(
        child: AppScope(
          state: state,
          child: const RegisterPage(),
        ),
      ),
    ));
    await tester.pump();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -250));
    await tester.pump();

    await _saveScreenshot(tester, 'register_page_scrolled_rendered.png');
  });
}
