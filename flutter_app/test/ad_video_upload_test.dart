// Загрузка видеообзора с экрана «Видео» объявления.
//
// Здесь ловится класс ошибок, из-за которого ролик пропадал молча: запрос
// не уходил (или падал), а экран как ни в чём не бывало вёл дальше.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/ad_media.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/ad_video_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UploadClient extends http.BaseClient {
  _UploadClient({this.mediaStatus = 201, this.mediaBody});

  final int mediaStatus;
  final String? mediaBody;

  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final isUpload = request.url.path.endsWith('/media/') && request.method == 'POST';

    if (isUpload) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(mediaBody ?? jsonEncode({'accepted': 1, 'media': [{'id': 5}]}))),
        mediaStatus,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(const <String, dynamic>{}))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

Future<AppState> _openVideoPage(WidgetTester tester, _UploadClient client) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final state = AppState(
    apiClient: ListingApiClient(baseUrl: 'http://test.local', client: client),
  )
    ..draftSlug = 'test-slug'
    ..draftVideoList.add(
      AdMedia(name: 'clip.mp4', bytes: Uint8List.fromList([1, 2, 3]), video: true),
    );

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        home: const AdVideoPage(),
        routes: {Routes.adPromo: (_) => const Scaffold(body: Text('Экран продвижения'))},
      ),
    ),
  );
  await tester.pump();
  return state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ролик уходит на сервер и экран идёт дальше', (tester) async {
    final client = _UploadClient();
    await _openVideoPage(tester, client);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    final uploads = client.requests
        .where((r) => r.method == 'POST' && r.url.path.endsWith('/media/'))
        .toList();
    expect(uploads, hasLength(1), reason: 'запрос на загрузку ролика ушёл');
    expect((uploads.single as http.MultipartRequest).fields['kind'], 'video');
    expect(find.text('Экран продвижения'), findsOneWidget);
  });

  testWidgets('ошибка загрузки видна и дальше не пускает', (tester) async {
    final client = _UploadClient(
      mediaStatus: 400,
      mediaBody: jsonEncode({
        'error': {'code': 'validation_error', 'message': 'Загрузите видео в формате MP4 или MOV.'}
      }),
    );
    await _openVideoPage(tester, client);

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Загрузите видео в формате MP4'), findsOneWidget,
        reason: 'показываем настоящую причину, а не «нет связи с сервером»');
    expect(find.text('Экран продвижения'), findsNothing,
        reason: 'без ролика дальше идти незачем');
  });
}
