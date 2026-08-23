// Фотографии и видео объявления: выбор, предел, удаление.
//
// Настоящие галерея и камера здесь недоступны, поэтому на место источника
// файлов встаёт заглушка — проверяем всё, что вокруг него.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/app/app.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/ad_media.dart';
import 'package:house_kgz/ui/media_tile.dart';

/// Однопиксельный PNG — на его месте в жизни лежит выбранный снимок.
final Uint8List kPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Кадры макета шире подставного шрифта теста — строки разъезжаются. К тому,
/// что проверяем, это отношения не имеет.
void ignoreOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// Источник файлов, который отдаёт что велено.
class FakeMedia implements MediaSource {
  FakeMedia({this.photosPerPick = 1, this.hasVideo = true, this.fails = false});

  /// Сколько снимков «выбирает» пользователь за один раз.
  int photosPerPick;

  /// Есть ли что выбрать из роликов.
  bool hasVideo;

  /// Галерея не открылась — отказ в доступе, нет камеры.
  bool fails;

  final List<bool> cameraCalls = [];

  @override
  Future<List<AdMedia>> photos({required bool camera}) async {
    cameraCalls.add(camera);
    if (fails) throw StateError('нет доступа');
    return [
      for (var i = 0; i < photosPerPick; i++)
        AdMedia(name: 'IMG_$i.jpg', bytes: kPixel),
    ];
  }

  @override
  Future<AdMedia?> video({required bool camera}) async {
    cameraCalls.add(camera);
    if (fails) throw StateError('нет доступа');
    return hasVideo ? const AdMedia(name: 'REELS.mp4', video: true) : null;
  }
}

Future<AppState> openAd(
  WidgetTester tester,
  FakeMedia media, {
  required String route,
}) async {
  ignoreOverflow();
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    HouseKgzAppScope(initialRoute: route, media: media),
  );
  await tester.pumpAndSettle();
  return AppScope.read(tester.element(find.byType(Scaffold).first));
}

/// Нажать «Добавить …» и выбрать источник в листе.
Future<void> addFrom(WidgetTester tester, String source) async {
  await tester.tap(find.textContaining('Добавить ').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(source));
  await tester.pumpAndSettle();
}

void main() {
  group('фотографии объявления', () {
    testWidgets('выбор из галереи добавляет снимки в сетку', (tester) async {
      final media = FakeMedia(photosPerPick: 3);
      final state = await openAd(tester, media, route: Routes.adPhotos);
      final before = state.draftPhotos;

      await addFrom(tester, 'Выбрать из галереи');

      expect(state.draftPhotos, before + 3);
      expect(media.cameraCalls, [false]);
      expect(find.byType(AdMediaTile), findsNWidgets(before + 3));
      expect(find.textContaining('Добавлено 3 фотографии'), findsOneWidget);
    });

    testWidgets('снимок с камеры просят у камеры', (tester) async {
      final media = FakeMedia();
      final state = await openAd(tester, media, route: Routes.adPhotos);

      await addFrom(tester, 'Сделать снимок');

      expect(media.cameraCalls, [true]);
      expect(state.draftPhotos, 7);
    });

    testWidgets('крестик убирает снимок', (tester) async {
      final state = await openAd(tester, FakeMedia(), route: Routes.adPhotos);
      final first = state.draftGallery.first;

      await tester.tap(find.byKey(removeKey(first)));
      await tester.pumpAndSettle();

      expect(state.draftGallery, isNot(contains(first)));
      expect(state.draftPhotos, 5);
    });

    testWidgets('сверх предела снимки не берём', (tester) async {
      final media = FakeMedia(photosPerPick: 30);
      final state = await openAd(tester, media, route: Routes.adPhotos);

      await addFrom(tester, 'Выбрать из галереи');
      expect(state.draftPhotos, AppState.draftMediaLimit);

      // предел набран — лист выбора больше не открываем
      await tester.tap(find.textContaining('Добавить ').first);
      await tester.pumpAndSettle();
      expect(find.text('Выбрать из галереи'), findsNothing);
      expect(
        find.text('Больше ${AppState.draftMediaLimit} файлов не добавить'),
        findsOneWidget,
      );
      expect(media.cameraCalls, hasLength(1));
    });

    testWidgets('о закрытом доступе говорим вслух', (tester) async {
      final media = FakeMedia(fails: true);
      final state = await openAd(tester, media, route: Routes.adPhotos);

      await addFrom(tester, 'Выбрать из галереи');

      expect(state.draftPhotos, 6);
      expect(find.text('Не получилось открыть галерею'), findsOneWidget);
    });
  });

  group('видео объявления', () {
    testWidgets('выбранный ролик встаёт в «Было добавлено»', (tester) async {
      final media = FakeMedia();
      final state = await openAd(tester, media, route: Routes.adVideo);
      expect(state.draftVideos, 1);

      await addFrom(tester, 'Выбрать ролик из галереи');

      expect(state.draftVideos, 2);
      expect(state.draftVideoList.last.name, 'REELS.mp4');
      expect(find.byType(AdMediaTile), findsNWidgets(2));
      expect(find.text('Ролик добавлен'), findsOneWidget);
    });

    testWidgets('отменённый выбор ничего не меняет', (tester) async {
      final media = FakeMedia(hasVideo: false);
      final state = await openAd(tester, media, route: Routes.adVideo);

      await addFrom(tester, 'Снять видео');

      expect(media.cameraCalls, [true]);
      expect(state.draftVideos, 1);
      expect(find.text('Ролик добавлен'), findsNothing);
    });

    testWidgets('крестик убирает ролик', (tester) async {
      final state = await openAd(tester, FakeMedia(), route: Routes.adVideo);
      final first = state.draftVideoList.first;

      await tester.tap(find.byKey(removeKey(first)));
      await tester.pumpAndSettle();

      expect(state.draftVideos, 0);
      expect(find.text('Пока ни одного ролика'), findsOneWidget);
    });
  });
}
