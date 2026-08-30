import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/ad_promo_page.dart';

class _TestPublishClient extends http.BaseClient {
  final bool shouldFailWithLimit;
  _TestPublishClient({this.shouldFailWithLimit = false});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.contains('/publish/')) {
      if (shouldFailWithLimit) {
        final body = utf8.encode(jsonEncode({
          'error': {
            'code': 'conflict',
            'message': 'Достигнут лимит активных объявлений',
          }
        }));
        return http.StreamedResponse(Stream.value(body), 409, headers: {'content-type': 'application/json'});
      }
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
    }
    return http.StreamedResponse(Stream.value([]), 200);
  }
}

void main() {
  testWidgets('AdPromoPage with limit conflict shows modal dialog with navigation option', (tester) async {
    final client = _TestPublishClient(shouldFailWithLimit: true);
    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);
    state.draftSlug = 'test-slug-123';

    String? navigatedRoute;
    Object? navigatedArgs;

    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == Routes.adPreview) {
              navigatedRoute = settings.name;
              navigatedArgs = settings.arguments;
              return MaterialPageRoute(builder: (_) => const Scaffold(body: Text('PREVIEW_PAGE')));
            }
            return MaterialPageRoute(builder: (_) => const AdPromoPage());
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap "Далее" button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Далее'));
    await tester.pumpAndSettle();

    // Conflict Dialog should be visible
    expect(find.text('Публикация объявления'), findsOneWidget);
    expect(find.textContaining('Достигнут лимит активных объявлений'), findsOneWidget);
    expect(find.text('К предпросмотру'), findsOneWidget);

    // Tap "К предпросмотру"
    await tester.tap(find.text('К предпросмотру'));
    await tester.pumpAndSettle();

    expect(navigatedRoute, Routes.adPreview);
    expect(navigatedArgs, 'test-slug-123');
    expect(find.text('PREVIEW_PAGE'), findsOneWidget);
  });
}
