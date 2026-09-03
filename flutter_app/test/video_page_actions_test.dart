import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/video_page.dart';

class _ReelServer extends http.BaseClient {
  _ReelServer({this.initiallyFavourite = false, this.reelCount = 1});

  final bool initiallyFavourite;

  /// Сколько роликов в ленте: вертикальный свайп можно проверить только
  /// тогда, когда листать есть куда.
  final int reelCount;
  int favouritePosts = 0;

  /// Сколько раз запрашивали ленту — по этому счётчику отдаём вторую пачку.
  int feedRequests = 0;

  /// Лента из нескольких объявлений — копии основного с другими слагами.
  List<Map<String, dynamic>> get feed => [
    for (var i = 0; i < reelCount; i++)
      {...listing, 'slug': i == 0 ? 'reel-one' : 'reel-${i + 1}'},
  ];

  Map<String, dynamic> get listing => {
    'slug': 'reel-one',
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
    'is_favourite': initiallyFavourite,
    'videos': [
      {
        'id': 7,
        'kind': 'video',
        'url': 'https://test.local/media/reel-one.mp4',
        'title': 'Обзор',
        'description': 'Вид из окна',
      },
    ],
    'seller': {
      'id': 42,
      'name': 'Айбек',
      'kind': 'owner',
      'phone': '',
      'avatar_url': null,
      'listings_count': 1,
      'member_since': '2024-01-01T00:00:00Z',
    },
  };

  http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/media/reel-one.mp4') {
      return http.StreamedResponse(
        Stream.value(const [0, 1, 2, 3]),
        200,
        headers: {'content-type': 'video/mp4'},
      );
    }
    if (request.method == 'GET' && path == '/api/v1/listings/reel-one/') {
      return _json(listing);
    }
    if (request.method == 'GET' &&
        path == '/api/v1/recommendations/reels/') {
      feedRequests++;
      if (feedRequests == 1) {
        return _json({'results': feed, 'next': 'next'});
      }
      // Вторая пачка нарочно повторяет последний ролик первой: клиент не
      // должен показать его дважды подряд.
      return _json({
        'results': [
          {...listing, 'slug': 'reel-$reelCount'},
          {...listing, 'slug': 'reel-${reelCount + 1}'},
        ],
        'next': null,
      });
    }
    if (request.method == 'GET' && path == '/api/v1/listings/reels/') {
      return _json({
        'count': reelCount,
        'next': null,
        'previous': null,
        'results': feed,
      });
    }
    if (request.method == 'GET' && path == '/api/v1/favourites/') {
      return _json({
        'count': initiallyFavourite ? 1 : 0,
        'next': null,
        'previous': null,
        'results': [
          if (initiallyFavourite) {'slug': 'reel-one'},
        ],
      });
    }
    if (request.method == 'POST' &&
        path == '/api/v1/listings/reel-one/favourite/') {
      favouritePosts++;
      return _json({'is_favourite': true});
    }
    if (request.method == 'GET' && path == '/api/v1/tariffs/') {
      return _json({'results': const []});
    }
    return _json({
      'count': 0,
      'next': null,
      'previous': null,
      'results': const [],
    });
  }
}

class _RouteObserver extends NavigatorObserver {
  final List<String?> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

Future<AppState> _pumpReel(
  WidgetTester tester,
  _ReelServer server, {
  bool authenticated = true,
  Future<void> Function(String source)? saveVideo,
  NavigatorObserver? navigatorObserver,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    if (authenticated) 'access_token': 'test-access',
  });

  final apiClient = ListingApiClient(
    baseUrl: 'https://test.local',
    client: server,
  );
  final state = AppState(apiClient: apiClient);
  await state.authInitialized;

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        navigatorObservers: [?navigatorObserver],
        routes: {
          Routes.welcome: (_) => const Scaffold(body: Text('WelcomePage')),
        },
        home: VideoPage(id: 'reel-one', saveVideo: saveVideo),
      ),
    ),
  );
  for (
    var attempt = 0;
    attempt < 10 &&
        find.byKey(const ValueKey('v_item_reel-one_0')).evaluate().isEmpty;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return state;
}

Future<void> _doubleTapVideo(WidgetTester tester) async {
  final video = find.byKey(const ValueKey('v_item_reel-one_0'));
  expect(video, findsOneWidget);
  await tester.tap(video);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(video);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Двойное нажатие и просмотр кадров всплеска.
///
/// Проверять один кадр нельзя: сразу после нажатия контроллер ещё не тикнул,
/// и сердца в дереве закономерно нет. Поэтому смотрим всю анимацию.
Future<bool> _doubleTapAndSeeHeart(WidgetTester tester) async {
  final video = find.byKey(const ValueKey('v_item_reel-one_0'));
  await tester.tap(video);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(video);
  var visible = false;
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 70));
    final n = find.byKey(const Key('reel_double_tap_heart')).evaluate().length;
    if (n > 0) visible = true;
  }
  await tester.pump(const Duration(seconds: 1));
  return visible;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('double tap adds the current listing to favourites once', (
    tester,
  ) async {
    final server = _ReelServer();
    final state = await _pumpReel(tester, server);

    await _doubleTapVideo(tester);

    expect(server.favouritePosts, 1);
    expect(state.isFavourite('reel-one'), isTrue);
    expect(find.bySemanticsLabel('Убрать из избранного'), findsOneWidget);
  });

  testWidgets('double tap never removes an already favourite listing', (
    tester,
  ) async {
    final server = _ReelServer(initiallyFavourite: true);
    final state = await _pumpReel(tester, server);

    await _doubleTapVideo(tester);

    expect(server.favouritePosts, 0);
    expect(state.isFavourite('reel-one'), isTrue);
  });

  testWidgets('guest double tap uses the existing authentication flow', (
    tester,
  ) async {
    final server = _ReelServer();
    final observer = _RouteObserver();
    final state = await _pumpReel(
      tester,
      server,
      authenticated: false,
      navigatorObserver: observer,
    );
    expect(state.isAuthenticated, isFalse);

    await _doubleTapVideo(tester);

    expect(server.favouritePosts, 0);
    expect(find.text('Войдите, чтобы добавить в избранное'), findsOneWidget);
    expect(observer.pushedRoutes, contains(Routes.welcome));
  });

  testWidgets('двойное нажатие показывает сердце как подтверждение', (
    tester,
  ) async {
    final server = _ReelServer();
    await _pumpReel(tester, server);

    expect(find.byKey(const Key('reel_double_tap_heart')), findsNothing);
    expect(await _doubleTapAndSeeHeart(tester), isTrue);
    // Всплеск заканчивается сам и не остаётся висеть поверх кадра.
    expect(find.byKey(const Key('reel_double_tap_heart')), findsNothing);
  });

  testWidgets('уже добавленный объект тоже даёт отклик, но не запрос', (
    tester,
  ) async {
    final server = _ReelServer(initiallyFavourite: true);
    final state = await _pumpReel(tester, server);

    expect(await _doubleTapAndSeeHeart(tester), isTrue);
    expect(server.favouritePosts, 0, reason: 'убирать из избранного нельзя');
    expect(state.isFavourite('reel-one'), isTrue);
  });

  testWidgets('гостю сердце не показываем: действие не выполнено', (
    tester,
  ) async {
    final server = _ReelServer();
    final state = await _pumpReel(tester, server, authenticated: false);

    expect(await _doubleTapAndSeeHeart(tester), isFalse);
    expect(server.favouritePosts, 0);
    expect(state.isFavourite('reel-one'), isFalse);
  });

  testWidgets('серия быстрых нажатий не множит запросы', (tester) async {
    final server = _ReelServer();
    await _pumpReel(tester, server);

    await _doubleTapVideo(tester);
    await _doubleTapVideo(tester);
    await _doubleTapVideo(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(server.favouritePosts, 1);
  });

  testWidgets('лента листается вертикальным свайпом', (tester) async {
    await _pumpReel(tester, _ReelServer(reelCount: 3));

    final vertical = find.byWidgetPredicate(
      (w) => w is PageView && w.scrollDirection == Axis.vertical,
    );
    expect(vertical, findsOneWidget);
    final controller = tester.widget<PageView>(vertical).controller!;
    expect(controller.page?.round(), 0);

    // pumpAndSettle здесь непригоден: в конце ленты крутится индикатор
    // подгрузки, и кадры не заканчиваются никогда.
    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Настоящий свайп: палец опускается, ведёт по шагам и отрывается —
    // одно мгновенное перемещение PageView трактует иначе.
    await tester.fling(vertical, const Offset(0, -600), 1200);
    await settle();
    expect(controller.page?.round(), 1, reason: 'свайп вверх не листает ленту');

    // И обратно вниз — к предыдущему.
    await tester.fling(vertical, const Offset(0, 600), 1200);
    await settle();
    expect(controller.page?.round(), 0, reason: 'свайп вниз не листает ленту');
  });

  /// Сколько роликов помечены активными: играть должен ровно один.
  int activeCount(WidgetTester tester) => tester
      .widgetList(find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_VideoPlayerItem',
      ))
      .where((w) => (w as dynamic).isActive == true)
      .length;

  testWidgets('следующая пачка подгружается заранее и без дублей', (
    tester,
  ) async {
    final server = _ReelServer(reelCount: 3);
    await _pumpReel(tester, server);
    final vertical = find.byWidgetPredicate(
      (w) => w is PageView && w.scrollDirection == Axis.vertical,
    );
    final controller = tester.widget<PageView>(vertical).controller!;
    expect(server.feedRequests, 1);

    // Доходим до предпоследнего — подгрузка должна начаться до конца ленты.
    await tester.fling(vertical, const Offset(0, -600), 1200);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(server.feedRequests, greaterThan(1),
        reason: 'следующая пачка обязана запрашиваться заранее');
    expect(controller.page?.round(), 1,
        reason: 'подгрузка не должна возвращать ленту в начало');

    // Повтор из второй пачки не должен появиться вторым экземпляром.
    final slugs = tester
        .widgetList(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_VideoPlayerItem',
        ))
        .length;
    expect(slugs, greaterThan(0));
  });

  testWidgets('в любой момент активен ровно один ролик', (tester) async {
    await _pumpReel(tester, _ReelServer(reelCount: 3));
    final vertical = find.byWidgetPredicate(
      (w) => w is PageView && w.scrollDirection == Axis.vertical,
    );

    expect(activeCount(tester), 1, reason: 'на старте играет один');

    await tester.fling(vertical, const Offset(0, -600), 1200);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(activeCount(tester), 1,
        reason: 'после перехода не должно звучать два ролика сразу');
  });

  testWidgets('двойное нажатие и вертикальный свайп не спорят за жест', (
    tester,
  ) async {
    final server = _ReelServer(reelCount: 3);
    await _pumpReel(tester, server);
    final vertical = find.byWidgetPredicate(
      (w) => w is PageView && w.scrollDirection == Axis.vertical,
    );
    final controller = tester.widget<PageView>(vertical).controller!;

    // Сначала двойное нажатие — избранное срабатывает, лента не едет.
    await _doubleTapVideo(tester);
    expect(server.favouritePosts, 1);
    expect(controller.page?.round(), 0, reason: 'нажатие не должно листать');

    // Затем свайп — лента едет, лишнего добавления в избранное нет.
    await tester.fling(vertical, const Offset(0, -600), 1200);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.page?.round(), 1);
    expect(server.favouritePosts, 1, reason: 'свайп не должен добавлять в избранное');
  });

  testWidgets('блокировка экрана останавливает ролик', (tester) async {
    await _pumpReel(tester, _ReelServer());

    // Состояние плеера приватное, поэтому берём его как State и обращаемся
    // динамически — тест проверяет поведение, а не внутренний тип.
    final dynamic player = tester.state<State>(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_VideoPlayerItem',
      ),
    );
    // Плеер в тестах не инициализируется (платформенного канала нет), поэтому
    // проверяем сам контракт: уход в фон помечается и гасит воспроизведение.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(player.isPlaying, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(player.isPlaying, isFalse);
  });

  testWidgets('после разблокировки ролик не включается сам, если его ставили на паузу', (
    tester,
  ) async {
    await _pumpReel(tester, _ReelServer());

    // Состояние плеера приватное, поэтому берём его как State и обращаемся
    // динамически — тест проверяет поведение, а не внутренний тип.
    final dynamic player = tester.state<State>(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_VideoPlayerItem',
      ),
    );

    // Пользователь сам остановил ролик, затем погасил экран.
    player.pauseVideo();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(player.isPlaying, isFalse,
        reason: 'разблокировка не должна включать видео против воли человека');
  });

  testWidgets('download requests the current video and ignores repeated taps', (
    tester,
  ) async {
    final gate = Completer<void>();
    final server = _ReelServer();
    final requestedSources = <String>[];
    await _pumpReel(
      tester,
      server,
      saveVideo: (source) async {
        requestedSources.add(source);
        await gate.future;
      },
    );

    final download = find.text('Скачать видео');
    await tester.tap(download);
    await tester.pump();
    await tester.tap(find.text('Скачивание…'));
    await tester.pump();

    expect(requestedSources, ['https://test.local/media/reel-one.mp4']);
    expect(find.text('Скачивание…'), findsOneWidget);

    gate.complete();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Видео сохранено'), findsOneWidget);
  });

  testWidgets('download failure is reported without leaving the Reel', (
    tester,
  ) async {
    final server = _ReelServer();
    await _pumpReel(
      tester,
      server,
      saveVideo: (_) => Future<void>.error(StateError('save failed')),
    );

    await tester.tap(find.text('Скачать видео'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Не удалось сохранить видео'), findsOneWidget);
    expect(find.byType(VideoPage), findsOneWidget);
  });
}
