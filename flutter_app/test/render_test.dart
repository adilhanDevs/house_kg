import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/fig/tab_bar.dart';
import 'package:house_kgz/main.dart';
import 'package:house_kgz/prototype.dart';
import 'package:house_kgz/screens/screen_02_onboarding_1.dart';
import 'package:house_kgz/screens/screen_03_onboarding_2.dart';
import 'package:house_kgz/screens/screen_09_home.dart';
import 'package:house_kgz/screens/screen_06_code.dart';
import 'package:house_kgz/screens/screen_11_catalog.dart';
import 'package:house_kgz/screens/screen_13_screen_57_3408.dart';
import 'package:house_kgz/screens/screen_15_profile.dart';
import 'package:house_kgz/screens/screen_16_liked.dart';
import 'package:house_kgz/screens/screen_17_notifications.dart';
import 'package:house_kgz/screens/screen_19_object_full.dart';
import 'package:house_kgz/screens/screen_31_screen_155_823.dart';
import 'package:house_kgz/screens/screen_32_screen_155_901.dart';
import 'package:house_kgz/screens/screen_33_screen_155_980.dart';
import 'package:house_kgz/screens/screen_34_catalog_create.dart';
import 'package:house_kgz/screens/screen_35_screen_155_1329.dart';
import 'package:house_kgz/screens/screen_36_screen_155_1379.dart';
import 'package:house_kgz/screens/screen_37_screen_155_1429.dart';
import 'package:house_kgz/screens/screen_40_screen_155_2313.dart';
import 'package:house_kgz/screens/screen_38_pro_profile.dart';
import 'package:house_kgz/screens/screen_41_topup_1.dart';
import 'package:house_kgz/screens/screen_42_topup_2.dart';
import 'package:house_kgz/screens/screen_43_topup_3.dart';
import 'package:house_kgz/screens/screen_44_topup_4.dart';
import 'package:house_kgz/screens/screen_45_topup_5.dart';
import 'package:house_kgz/screens/screen_46_ad_1.dart';
import 'package:house_kgz/screens/screen_47_ad_2.dart';
import 'package:house_kgz/screens/screen_48_ad_3.dart';
import 'package:house_kgz/screens/screen_49_ad_4.dart';
import 'package:house_kgz/screens/screen_50_ad_5.dart';
import 'package:house_kgz/screens/screen_51_ad_6.dart';
import 'package:house_kgz/screens/screen_52_history_1.dart';
import 'package:house_kgz/screens/screen_53_history_2.dart';
import 'package:house_kgz/screens/screen_54_history_3.dart';
import 'package:house_kgz/screens/screen_55_history_4.dart';
import 'package:house_kgz/screens/screen_56_pro_signup.dart';
import 'package:house_kgz/screens/screen_57_pro_code.dart';
import 'package:house_kgz/screens/screen_24_photo_confirm_1.dart';
import 'package:house_kgz/screens/screen_25_photo_confirm_2.dart';

/// A screen at its design size, with the tab bar the shell would add.
Widget _host(FigScreen screen) => MaterialApp(
      home: SizedBox(
        width: screen.width,
        height: screen.height,
        child: Stack(
          children: [
            Builder(builder: screen.builder),
            if (screen.hasTabBar)
              Positioned(
                left: screen.tabBarAt?.dx ?? 0,
                top: screen.tabBarAt?.dy,
                bottom: screen.tabBarAt == null ? 0 : null,
                child: FigTabBar(active: screen.activeTab, mockupTab: screen.mockupTab),
              ),
          ],
        ),
      ),
    );

void main() {
  // Every screen must lay out and paint cleanly at its design size.
  //
  // Flex overflow is the one thing excluded here. The design leans on CSS
  // `overflow: visible` — nowrap text runs are allowed to spill out of their
  // fixed-width rows — and the test binding's placeholder font is far wider
  // than the SF Pro the design was measured in, so runs that fit on a device
  // spill here. `no horizontal flex is clamped` below is the font-independent
  // check that Flutter lets them spill instead of squeezing them.
  for (final screen in figScreens) {
    testWidgets('renders ${screen.number} ${screen.title}', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;

      tester.view.physicalSize = Size(screen.width, screen.height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(screen));

      FlutterError.onError = previous;
      final messages = errors.map((e) => e.exceptionAsString()).toList();
      expect(messages.where((e) => !e.contains('overflowed by')), isEmpty);
    });
  }

  // A row that CSS would let overflow must reach Flutter with an unbounded
  // main axis, otherwise Flutter squeezes its children and paints the striped
  // overflow banner over the design. The exceptions are the rows that need a
  // fixed main axis to lay out at all: `space-between`, and rows with a
  // `flex-grow` child (an `Expanded`).
  testWidgets('no horizontal flex is clamped', (tester) async {
    // the space-between rows still overflow under the placeholder font, exactly
    // as css would; that is what this test allows and the check below verifies
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed by')) previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    for (final screen in figScreens) {
      tester.view.physicalSize = Size(screen.width, screen.height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(screen));

      final clamped = tester.allRenderObjects
          .whereType<RenderFlex>()
          .where((flex) => flex.direction == Axis.horizontal)
          .where((flex) => flex.constraints.hasBoundedWidth)
          .where((flex) => flex.mainAxisAlignment != MainAxisAlignment.spaceBetween)
          .where((flex) {
        for (var child = flex.firstChild; child != null;) {
          final data = child.parentData! as FlexParentData;
          if ((data.flex ?? 0) > 0) return false;
          child = data.nextSibling;
        }
        return true;
      });
      expect(clamped, isEmpty, reason: 'screen ${screen.number} ${screen.title}');
    }
  });

  // The tab bar is the prototype's, not the mockup's: it lives outside the
  // screens, is injected onto the two that lack one, and every cell navigates.
  group('tab bar', () {
    // the five cells, laid out space-between across the row at x 29..349
    const cellCentres = [47.5, 116.5, 186.5, 256.5, 328.0];
    const cellY = 757.0;

    Future<void> open(WidgetTester tester, int index) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: PrototypeShell(initialIndex: index)));
      await tester.pump();
    }

    testWidgets('is injected on Главная, which the mockup draws without one',
        (tester) async {
      await open(tester, 8);
      expect(find.byType(FigTabBar), findsOneWidget);
      expect(tester.widget<FigTabBar>(find.byType(FigTabBar)).active, 0);
      // the fourth tab is the prototype's heart, not the mockup's second «История»
      expect(find.text('Избранное'), findsOneWidget);
      expect(find.text('История'), findsOneWidget);
    });

    testWidgets('leaves the mockup colours alone where no tab matches',
        (tester) async {
      await open(tester, 13); // Карточка товара
      final bar = tester.widget<FigTabBar>(find.byType(FigTabBar));
      expect(bar.active, isNull);
      // and there the mockup's own mark is on the profile, not the search the
      // catalog screen the bar was drawn from has
      expect(bar.mockupTab, 4);
    });

    // every screen that draws its own bar says which tab that bar marks
    for (final screen in figScreens.where((s) => s.tabBarAt != null)) {
      test('screen ${screen.number} carries its mockup tab', () {
        expect(screen.mockupTab, isNotNull);
      });
    }

    for (final (cell, target) in [
      (0, Screen09Home),
      (1, Screen11Catalog),
      (2, Screen17Notifications),
      (3, Screen16Liked),
      (4, Screen15Profile),
    ]) {
      testWidgets('cell $cell navigates', (tester) async {
        await open(tester, 8);
        await tester.tapAt(Offset(cellCentres[cell], cellY));
        await tester.pump();
        expect(find.byType(target), findsOneWidget);
      });
    }
  });

  testWidgets('«Подробнее» opens the full listing', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PrototypeShell(initialIndex: 9)));
    await tester.pump();
    await tester.tapAt(const Offset(25 + 47, 374 + 7));
    await tester.pump();
    expect(find.byType(Screen19ObjectFull), findsOneWidget);
  });

  // `AD_FLOW` in the prototype: 40 → 37 → 35 → 36 → 31 → 32 → 33, where a tap
  // anywhere on the screen is the next step, and «Далее» on the last screen of
  // the flow falls through to the next screen in the list.
  group('объявление', () {
    Future<void> open(WidgetTester tester, int index) async {
      // the placeholder font spills the same space-between rows the render
      // tests above allow to spill; that is not what these tests are about
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed by')) previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: PrototypeShell(initialIndex: index)));
      await tester.pump();
    }

    testWidgets('a tap anywhere walks the whole flow', (tester) async {
      await open(tester, 39); // Экран 155:2313
      for (final next in [
        Screen37Screen1551429,
        Screen35Screen1551329,
        Screen36Screen1551379,
        Screen31Screen155823,
        Screen32Screen155901,
        Screen33Screen155980,
      ]) {
        await tester.tapAt(const Offset(187, 300));
        await tester.pump();
        expect(find.byType(next), findsOneWidget, reason: 'на $next');
      }
      // конец флоу: дальше ведёт только «Далее», на следующий экран списка
      await tester.tapAt(const Offset(187, 300));
      await tester.pump();
      expect(find.byType(Screen33Screen155980), findsOneWidget);
      await tester.tapAt(const Offset(25 + 162, 711 + 18));
      await tester.pump();
      expect(find.byType(Screen34CatalogCreate), findsOneWidget);
    });

    testWidgets('the tab bar takes the tap before the tap-anywhere step',
        (tester) async {
      await open(tester, 39); // Экран 155:2313 — бар в макете на y 708
      await tester.tapAt(const Offset(47.5, 708 + 30.5));
      await tester.pump();
      expect(find.byType(Screen09Home), findsOneWidget);
    });

    // а мимо ячейки — как в прототипе: клик доходит до запасного перехода,
    // хотя полоса меню его закрывает
    testWidgets('a tap on the bar itself still walks the flow', (tester) async {
      await open(tester, 39);
      await tester.tapAt(const Offset(10, 750));
      await tester.pump();
      expect(find.byType(Screen37Screen1551429), findsOneWidget);
    });

    testWidgets('«Садыр Жапаров» on the contractor profile opens the listing',
        (tester) async {
      await open(tester, 37); // Профиль исполнителя
      await tester.tapAt(const Offset(25 + 91, 238 + 10));
      await tester.pump();
      expect(find.byType(Screen13Screen573408), findsOneWidget);
    });

    testWidgets('«Уведомление» on the contractor profile opens notifications',
        (tester) async {
      await open(tester, 37);
      expect(find.byType(Screen38ProProfile), findsOneWidget);
      // экран выше окна, до строки настроек нужно доскроллить
      await tester.dragFrom(const Offset(187, 500), const Offset(0, -400));
      await tester.pumpAndSettle();
      final scrolled = tester
          .widget<Scrollable>(find.byType(Scrollable).first)
          .controller!
          .offset;
      expect(scrolled, greaterThan(300));
      await tester.tapAt(Offset(25 + 165, 959 - scrolled + 13));
      await tester.pump();
      expect(find.byType(Screen17Notifications), findsOneWidget);
    });
  });

  // Экраны 41–51 — кадры двух лент, и «Далее» на каждом ведёт на следующий кадр
  // той же ленты (`_nextStep`). Ленты связаны: последний кадр пополнения ведёт
  // на первый кадр объявления.
  group('ленты кадров', () {
    Future<void> open(WidgetTester tester, int index) async {
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed by')) previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: PrototypeShell(initialIndex: index)));
      await tester.pump();
    }

    testWidgets('«Далее» walks the topup strip into the ad strip',
        (tester) async {
      await open(tester, 40); // Пополнение · 1
      for (final next in [
        Screen42Topup2,
        Screen43Topup3,
        Screen44Topup4,
        Screen45Topup5,
        Screen46Ad1,
      ]) {
        await tester.tapAt(const Offset(25 + 162, 711 + 18));
        await tester.pump();
        expect(find.byType(next), findsOneWidget, reason: 'на $next');
      }
    });

    testWidgets('«Далее» walks the ad strip to its last frame', (tester) async {
      await open(tester, 45); // Объявление · 1
      for (final (y, next) in [
        (732.0, Screen47Ad2),
        (1083.0, Screen48Ad3),
        (707.0, Screen49Ad4),
        (711.0, Screen50Ad5),
        (709.0, Screen51Ad6),
      ]) {
        // на 47 кнопка ниже окна — доскроллим до неё
        if (y > 776) {
          await tester.dragFrom(const Offset(187, 500), const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        final offset = tester.widgetList<Scrollable>(find.byType(Scrollable)).isEmpty
            ? 0.0
            : tester.widget<Scrollable>(find.byType(Scrollable).first).controller!.offset;
        await tester.tapAt(Offset(25 + 162, y - offset + 18));
        await tester.pump();
        expect(find.byType(next), findsOneWidget, reason: 'на $next');
      }
    });

    testWidgets('«Пополнить» on the contractor profile opens the topup',
        (tester) async {
      await open(tester, 37); // Профиль исполнителя
      await tester.dragFrom(const Offset(187, 500), const Offset(0, -400));
      await tester.pumpAndSettle();
      final offset =
          tester.widget<Scrollable>(find.byType(Scrollable).first).controller!.offset;
      await tester.tapAt(Offset(235.9 + 55, 733.5 - offset + 18));
      await tester.pump();
      expect(find.byType(Screen41Topup1), findsOneWidget);
    });

    testWidgets('«Изменить объявление» goes back into the edit flow',
        (tester) async {
      await open(tester, 45); // Объявление · 1
      await tester.tapAt(const Offset(24 + 163, 279 + 15));
      await tester.pump();
      expect(find.byType(Screen40Screen1552313), findsOneWidget);
    });

    // На «Заданиях» карточка объявления лежит на 770 — под таб-баром, который
    // макет рисует с 728. Как и в прототипе, клик туда достаётся меню, а не
    // карточке, поэтому её зона (она в коде есть) не срабатывает.
    testWidgets('the ad card on the tasks screen stays under the bar',
        (tester) async {
      await open(tester, 38); // Экран 155:2155
      expect(
        figScreens[38].hotspots.single.label,
        'Объявление',
        reason: 'зона карточки на месте',
      );
      await tester.tapAt(const Offset(186.5, 790));
      await tester.pump();
      // ни объявления, ни перехода по вкладке — клик достался полосе меню
      expect(find.byType(Screen46Ad1), findsNothing);
      expect(find.byType(Screen17Notifications), findsNothing);
    });

    testWidgets('«Добавить объявление» opens the ad form', (tester) async {
      await open(tester, 37); // Профиль исполнителя
      await tester.tapAt(const Offset(129 + 80, 385 + 15));
      await tester.pump();
      expect(find.byType(Screen47Ad2), findsOneWidget);
    });
  });

  // Регистрация исполнителя (`PRO_FLOW`) и то, что она включает: пятая вкладка
  // меню начинает вести в профиль исполнителя, а возврат ко входу это снимает.
  group('режим исполнителя', () {
    Future<void> open(WidgetTester tester, int index) async {
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed by')) previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: PrototypeShell(initialIndex: index)));
      await tester.pump();
    }

    testWidgets('«Режим исполнителя» walks registration to the profile',
        (tester) async {
      await open(tester, 4); // Добро пожаловать
      await tester.tapAt(const Offset(118 + 70, 753 + 10));
      await tester.pump();
      expect(find.byType(Screen56ProSignup), findsOneWidget);

      for (final next in [
        Screen57ProCode,
        Screen24PhotoConfirm1,
        Screen25PhotoConfirm2,
        Screen38ProProfile,
      ]) {
        await tester.tapAt(const Offset(187, 300));
        await tester.pump();
        expect(find.byType(next), findsOneWidget, reason: 'на $next');
      }

      // и с этого момента пятая вкладка ведёт в профиль исполнителя
      await tester.tapAt(const Offset(328.0, 1178 + 30.5));
      await tester.pump();
      expect(find.byType(Screen38ProProfile), findsOneWidget);
    });

    test('returning to the entry screens drops contractor mode', () {
      // `go` в прототипе: экраны 01–08 — это новый вход
      expect(figResetsPro(0), isTrue);
      expect(figResetsPro(7), isTrue);
      expect(figResetsPro(8), isFalse);
      expect(figResetsPro(figProProfile), isFalse);
    });

    testWidgets('and after that the fifth tab is the client profile again',
        (tester) async {
      await open(tester, 4);
      await tester.tapAt(const Offset(118 + 70, 753 + 10)); // режим исполнителя
      await tester.pump();
      expect(find.byType(Screen56ProSignup), findsOneWidget);

      // возвращаемся ко входу через список экранов — там режим сбрасывается,
      // а дальше «Ввести код» ведёт на «Главную», где есть меню
      await tester.longPress(find.byType(Scaffold).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Код подтверждения').last);
      await tester.pumpAndSettle();
      expect(find.byType(Screen06Code), findsOneWidget);

      await tester.tapAt(const Offset(187, 600)); // зона «Ввести код»
      await tester.pump();
      expect(find.byType(Screen09Home), findsOneWidget);

      await tester.tapAt(const Offset(328.0, 757));
      await tester.pump();
      expect(find.byType(Screen15Profile), findsOneWidget);
    });
  });

  // «История трат» — четыре кадра одной ленты, различаются выбранной вкладкой,
  // и вкладки в каждом переставлены: активная первая (`HISTORY_TABS`).
  group('история трат', () {
    Future<void> open(WidgetTester tester, int index) async {
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed by')) previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: PrototypeShell(initialIndex: index)));
      await tester.pump();
    }

    testWidgets('the tabs switch between the four frames', (tester) async {
      await open(tester, 51); // Все операции
      await tester.tapAt(const Offset(146 + 52, 132 + 15)); // Пополнение
      await tester.pump();
      expect(find.byType(Screen53History2), findsOneWidget);

      await tester.tapAt(const Offset(259 + 45, 132 + 15)); // Списание
      await tester.pump();
      expect(find.byType(Screen54History3), findsOneWidget);

      await tester.tapAt(const Offset(365, 132 + 15)); // Бонусы, край экрана
      await tester.pump();
      expect(find.byType(Screen55History4), findsOneWidget);

      await tester.tapAt(const Offset(319 + 25, 132 + 15)); // Все операции
      await tester.pump();
      expect(find.byType(Screen52History1), findsOneWidget);
    });

    testWidgets('«Далее» walks the strip into the registration', (tester) async {
      await open(tester, 51);
      for (final next in [
        Screen53History2,
        Screen54History3,
        Screen55History4,
        Screen56ProSignup,
      ]) {
        await tester.tapAt(const Offset(25 + 162, 711 + 18));
        await tester.pump();
        expect(find.byType(next), findsOneWidget, reason: 'на $next');
      }
    });
  });

  testWidgets('splash auto-advances and hotspots navigate', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HouseKgzApp());
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump();
    expect(find.byType(Screen02Onboarding1), findsOneWidget);

    // "Далее" — the hotspot at 31,670 314×52 in the design's coordinates
    await tester.tapAt(const Offset(31 + 157, 670 + 26));
    await tester.pump();
    expect(find.byType(Screen03Onboarding2), findsOneWidget);
  });
}
