// Горизонтальные PageController'ы Reels-ленты: сколько их живёт при обычной
// вертикальной прокрутке. Аудит предположил рост без ограничения — здесь
// это измеряется по-настоящему, а не берётся на веру.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/video_page.dart';

class _ReelServer extends http.BaseClient {
  _ReelServer({required this.reelCount});

  final int reelCount;
  int feedRequests = 0;

  List<Map<String, dynamic>> get feed => [
    for (var i = 0; i < reelCount; i++) {...listing, 'slug': 'reel-$i'},
  ];

  Map<String, dynamic> get listing => {
    'slug': 'reel-0',
    'kind': 'apartment',
    'district': {'id': 1, 'name': 'Асанбай', 'slug': 'asanbay'},
    'price': '85000.00',
    'currency': 'USD',
    'rooms': 2,
    'area': 64,
    'floor': 4,
    'floors': 9,
    'cover_url': '',
    'seller_kind': 'owner',
    'owner_id': 42,
    'address': 'Тестовая квартира',
    'description': 'Описание',
    'is_favourite': false,
    'videos': [
      {
        'id': 7,
        'kind': 'video',
        'url': 'https://test.local/media/reel.mp4',
        'title': 'Обзор',
        'description': 'Вид из окна',
      },
    ],
    'seller': {'id': 42, 'name': 'Айбек', 'avatar_url': ''},
  };

  http.StreamedResponse _json(Object body) => http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/media/reel.mp4') {
      return http.StreamedResponse(Stream.value(const [0, 1, 2, 3]), 200,
          headers: {'content-type': 'video/mp4'});
    }
    if (request.method == 'GET' && path == '/api/v1/listings/reel-0/') {
      return _json(listing);
    }
    if (request.method == 'GET' && path == '/api/v1/recommendations/reels/') {
      feedRequests++;
      // Всё разом на первой странице — достаточно роликов, чтобы не упереться
      // в пагинацию при 50 свайпах, и проще прослеживать рост карты.
      return _json({'results': feedRequests == 1 ? feed : [], 'next': null});
    }
    return _json({'count': 0, 'next': null, 'previous': null, 'results': const []});
  }
}

Future<AppState> _pumpReel(WidgetTester tester, _ReelServer server) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'access_token': 'test-access'});

  final apiClient = ListingApiClient(baseUrl: 'https://test.local', client: server);
  final state = AppState(apiClient: apiClient);
  await state.authInitialized;

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(home: VideoPage(id: 'reel-0')),
    ),
  );
  for (
    var attempt = 0;
    attempt < 10 && find.byKey(const ValueKey('v_item_reel-0_0')).evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return state;
}

/// Читает приватный счётчик через динамический вызов публичного
/// `@visibleForTesting`-геттера — тот же приём, что и для другого приватного
/// State в этом наборе тестов.
int _controllerCount(WidgetTester tester) {
  final state = tester.state(find.byType(VideoPage));
  return (state as dynamic).debugHorizontalControllerCount as int;
}

Future<void> _swipeUpOnce(WidgetTester tester) async {
  final vertical = find.byType(PageView).first;
  await tester.fling(vertical, const Offset(0, -800), 2000);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'горизонтальные контроллеры: счёт после 1/10/30/50 вертикальных свайпов',
    (tester) async {
      final server = _ReelServer(reelCount: 60);
      await _pumpReel(tester, server);

      final counts = <int, int>{};
      for (var swipe = 1; swipe <= 50; swipe++) {
        await _swipeUpOnce(tester);
        if (swipe == 1 || swipe == 10 || swipe == 30 || swipe == 50) {
          counts[swipe] = _controllerCount(tester);
        }
      }

      // ignore: avoid_print
      print('горизонтальные контроллеры по свайпам: $counts');

      // Окно вокруг текущей карточки: текущая ± 1 — не больше трёх живых
      // контроллеров, сколько бы ни было пройдено свайпов. До фикса это
      // было {1: 2, 10: 11, 30: 30, 50: 49} — рост один в один со свайпами.
      const maxAllowed = 3;
      for (final swipe in counts.keys) {
        expect(
          counts[swipe]!,
          lessThanOrEqualTo(maxAllowed),
          reason:
              'после $swipe свайпов живо ${counts[swipe]} контроллеров — '
              'карта растёт без ограничения, а не держит окно вокруг '
              'текущей позиции',
        );
      }
    },
  );
}
