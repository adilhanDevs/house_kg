// Приложение поверх кадров: списки, поиск, фильтр и избранное — живые.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show JSONMethodCodec, MethodCall, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/app/app.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/app/stage.dart';
import 'package:house_kgz/data/listings.dart';
import 'package:house_kgz/fig/tab_bar.dart';
import 'package:house_kgz/ui/app_tab_bar.dart';
import 'package:house_kgz/ui/fig_controls.dart';
import 'package:house_kgz/ui/fig_cta.dart';
import 'package:house_kgz/ui/listing_grid.dart';
import 'package:house_kgz/ui/object_card.dart';
import 'package:house_kgz/ui/pages/catalog_page.dart';
import 'package:house_kgz/ui/pages/favourites_page.dart';
import 'package:house_kgz/ui/pages/filter_page.dart';
import 'package:house_kgz/ui/pages/home_page.dart';
import 'package:house_kgz/ui/pages/listing_page.dart';
import 'package:house_kgz/ui/pages/notifications_page.dart';
import 'package:house_kgz/ui/pages/photos_page.dart';
import 'package:house_kgz/ui/pages/code_page.dart';
import 'package:house_kgz/ui/pages/pro_photo_confirm_page.dart';
import 'package:house_kgz/ui/pages/pro_profile_page.dart';
import 'package:house_kgz/ui/pages/pro_signup_page.dart';
import 'package:house_kgz/ui/pages/profile_page.dart';
import 'package:house_kgz/ui/pages/view_history_page.dart';

/// Сцена срезает верх кадра под системные индикаторы. В тесте индикаторов нет
/// — кадр показан целиком, и точка макета лежит на своей координате.
const double kTrim = 0.0;

/// Куда нажать, чтобы попасть в точку кадра (x, y) его собственных координат.
Offset at(double x, double y) => Offset(x, y - kTrim);

/// Центр ячейки нижнего меню: полоса стоит на своём месте из макета, ячейки
/// в ней — с 11-й по 46-ю точку.
Offset tab(int index) => Offset(
      const [46.5, 116.5, 186.5, 256.5, 326.5][index],
      812 - kTabBarStrip - kTabBarHeight + 28,
    );

/// Кадры макета опираются на CSS `overflow: visible`, а подставной шрифт
/// теста заметно шире SF Pro — строки разъезжаются сильнее, чем на устройстве.
/// Это проверяет render_test.dart; здесь такие сообщения только мешают.
void ignoreFlexOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.exceptionAsString().contains('overflowed by')) {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
}

Future<void> open(WidgetTester tester, {String route = Routes.catalog}) async {
  ignoreFlexOverflow();
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(HouseKgzAppScope(initialRoute: route));
  await tester.pumpAndSettle();
}

/// Открывает «Фильтр» так же, как это делает пользователь, — из каталога,
/// чтобы кнопка «назад» вернула его обратно.
Future<void> openFilterFromCatalog(WidgetTester tester) async {
  await open(tester);
  await tester.tapAt(at(340, 65));
  await tester.pumpAndSettle();
  expect(find.byType(FilterPage), findsOneWidget);
}

Future<void> backToCatalog(WidgetTester tester) async {
  await tester.tapAt(at(330, 62));
  await tester.pumpAndSettle();
  expect(find.byType(CatalogPage), findsOneWidget);
}

/// Что список получил на вход — сам ListView строит только видимые карточки.
List<Listing> shown(WidgetTester tester) =>
    tester.widget<ListingGrid>(find.byType(ListingGrid)).listings;

/// Что показывает «История просмотров», сверху вниз.
List<String> historyIds(WidgetTester tester) => tester
    .widgetList<HistoryTile>(find.byType(HistoryTile))
    .map((t) => t.entry.id)
    .toList();

/// Системная кнопка «назад» — то же сообщение, что шлёт Android и браузер.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Сама кнопка внутри [FigCta] — без пустой полосы до меню.
Finder ctaButton() => find.descendant(
      of: find.byType(FigCta),
      matching: find.byType(DecoratedBox),
    );

/// Тумблер «Продавца» по его подписи.
Finder toggle(String label) =>
    find.byWidgetPredicate((w) => w is FigToggle && w.label == label);

/// Какая фотография показана в «Фотообзоре».
int photo(WidgetTester tester) {
  final view = tester.widget<PageView>(find.byType(PageView));
  return ((view.controller as PageController).page ?? 0).round();
}

/// Открывает «Фотообзор» первого объекта «Главной».
Future<void> openPhotos(WidgetTester tester) async {
  await open(tester, route: Routes.home);
  await tester.tap(find.byType(ObjectCard).first);
  await tester.pumpAndSettle();
  await tester.tapAt(at(187, 200));
  await tester.pumpAndSettle();
  expect(find.byType(PhotosPage), findsOneWidget);
}

void main() {
  group('каталог', () {
    testWidgets('показывает все объекты из данных', (tester) async {
      await open(tester);
      expect(shown(tester), hasLength(kListings.length));
      expect(find.byType(ObjectCard), findsWidgets);
    });

    testWidgets('поиск сужает список', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Асанбай');
      await tester.pumpAndSettle();

      expect(shown(tester), hasLength(1));
      expect(shown(tester).single.district, 'Асанбай');
    });

    testWidgets('недоступный сервер не выдаётся за пустую выдачу',
        (tester) async {
      // Каталог целиком приходит с сервера, а в этом наборе сервера нет.
      // Раньше сорванный запрос показывался как «ничего не нашлось» —
      // пользователь думал, что объявлений нет, хотя их просто не спросили.
      // Пустую выдачу проверяет catalog_filters_test.dart на заглушке.
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Марс');
      await tester.pumpAndSettle();

      expect(find.byType(ObjectCard), findsNothing);
      expect(find.textContaining('Ничего не нашлось'), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);
    });
  });

  group('фильтр', () {
    testWidgets('иконка фильтра открывает «Фильтр»', (tester) async {
      await openFilterFromCatalog(tester);
    });

    testWidgets('чип «Комната» оставляет только комнаты', (tester) async {
      await openFilterFromCatalog(tester);
      await tester.tap(find.widgetWithText(FigChip, 'Комната'));
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.kind == PropertyKind.room), isTrue);
    });

    testWidgets('чип «3 ком.» оставляет трёхкомнатные', (tester) async {
      await openFilterFromCatalog(tester);
      await tester.tap(find.widgetWithText(FigChip, '3 ком.'));
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.rooms == 3), isTrue);
    });

    testWidgets('«Цена до» отсекает дорогие объекты', (tester) async {
      await openFilterFromCatalog(tester);
      await tester.enterText(find.byType(TextField).last, '60000');
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.priceUsd <= 60000), isTrue);
    });

    testWidgets('тумблер «Только собственник» переключается', (tester) async {
      await openFilterFromCatalog(tester);
      expect(tester.widget<FigToggle>(toggle('Только собственник')).value, isFalse);

      await tester.tap(toggle('Только собственник'));
      await tester.pumpAndSettle();
      expect(tester.widget<FigToggle>(toggle('Только собственник')).value, isTrue);

      await backToCatalog(tester);
      expect(shown(tester).every((l) => l.owner), isTrue);
    });

    testWidgets('тумблер «Риелторы» оставляет объекты риелторов', (tester) async {
      await openFilterFromCatalog(tester);
      await tester.tap(toggle('Риелторы'));
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.seller == SellerKind.realtor), isTrue);
    });

    testWidgets('тумблер «Агенство недвижимости» оставляет агентства',
        (tester) async {
      await openFilterFromCatalog(tester);
      await tester.tap(toggle('Агенство недвижимости'));
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.seller == SellerKind.agency), isTrue);
    });

    testWidgets('чип «Вторичка» убирает новостройки', (tester) async {
      await openFilterFromCatalog(tester);
      await tester.tap(find.widgetWithText(FigChip, 'Вторичка'));
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.secondary), isTrue);
    });

    testWidgets('чип «103 серия» оставляет только эту серию', (tester) async {
      await openFilterFromCatalog(tester);
      await tester.tap(find.widgetWithText(FigChip, '103 серия'));
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.series == '103'), isTrue);
    });

    testWidgets('чип квадратуры «35-45» оставляет объекты этой площади',
        (tester) async {
      await openFilterFromCatalog(tester);
      await tester.tap(find.widgetWithText(FigChip, '35-45'));
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.area >= 35 && l.area <= 45), isTrue);
    });

    testWidgets('своя квадратура вводится в поле', (tester) async {
      await openFilterFromCatalog(tester);
      await tester.enterText(find.byType(FigChipInput), '100-200');
      await tester.pumpAndSettle();
      await backToCatalog(tester);

      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.area >= 100 && l.area <= 200), isTrue);
    });
  });

  group('главная', () {
    testWidgets('категория задаёт фильтр и уводит в каталог', (tester) async {
      await open(tester, route: Routes.home);
      // «Участки» — третья категория
      await tester.tapAt(at(224, 340));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogPage), findsOneWidget);
      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.kind == PropertyKind.plot), isTrue);
    });

    testWidgets('вкладка «Новых позиций» меняет список на месте', (tester) async {
      await open(tester, route: Routes.home);
      expect(shown(tester).every((l) => l.kind == PropertyKind.apartment), isTrue);

      await tester.tapAt(at(230, 469)); // «Дома»
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(shown(tester), isNotEmpty);
      expect(shown(tester).every((l) => l.kind == PropertyKind.house), isTrue);
    });

    testWidgets('колокол открывает уведомления', (tester) async {
      await open(tester, route: Routes.home);
      await tester.tapAt(at(335, 59));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('карточка открывает объект', (tester) async {
      await open(tester, route: Routes.home);
      await tester.tap(find.byType(ObjectCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(ListingPage), findsOneWidget);
    });
  });

  group('объект', () {
    testWidgets('сердце переключает избранное', (tester) async {
      await open(tester, route: Routes.home);
      await tester.tap(find.byType(ObjectCard).first);
      await tester.pumpAndSettle();

      final heart = find.bySemanticsLabel('Убрать из избранного');
      expect(heart, findsOneWidget);
      await tester.tap(heart);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('В избранное'), findsOneWidget);
    });

    testWidgets('фотография открывает «Фотообзор»', (tester) async {
      await openPhotos(tester);
    });
  });

  group('фотообзор', () {
    testWidgets('имя продавца открывает его страницу', (tester) async {
      await openPhotos(tester);

      await tester.tap(find.bySemanticsLabel(kListings.first.agent));
      await tester.pumpAndSettle();
      // кадр 13 макета — страница продавца с его объектами
      expect(find.byType(FigCta), findsOneWidget);
      // и с нижним меню на своём месте из макета: под ним остаётся полоса,
      // которую в макете занимает индикатор жеста, а на телефоне — навигация
      final bar = tester.getRect(find.byType(AppTabBar));
      expect(bar.top, 812.0 - kTabBarStrip - kTabBarHeight);
      expect(bar.bottom, 812.0 - kTabBarStrip);
      expect(bar.width, 375.0);
      // подсвечен «Поиск» — вкладка, с которой на страницу приходят
      expect(tester.widget<AppTabBar>(find.byType(AppTabBar)).active, 1);

      // «Связаться с собственником» стоит над меню, а не в кадре
      final cta = tester.getRect(ctaButton());
      expect(cta.bottom, closeTo(bar.top - kCtaGap, 0.5));
      expect(cta.center.dx, closeTo(375 / 2, 0.5));
      // и ложится ровно на ту кнопку, что нарисована в кадре: в окне размером
      // с макет вся раскладка низа совпадает с ним точка в точку
      expect(cta.top, closeTo(frame('13').pinnedCta!.top, 0.5));
      // карточки за кнопкой видно — кадр показан до самой полосы меню
      expect(bar.top, closeTo(frame('13').tabBarAt!.dy, 0.5));
    });

    testWidgets('кнопка продавца держится над меню и на низком окне',
        (tester) async {
      await open(tester, route: Routes.agentListings);
      // окно вдвое ниже кадра — кадр прокручивается, а кнопка стоит на месте
      tester.view.physicalSize = const Size(375, 500);
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byType(AppTabBar));
      final cta = tester.getRect(ctaButton());
      // Полосу меню больше не двигают руками на kTabBarStrip от низа: она
      // стала штатным bottomNavigationBar и стоит на самом низу окна, без
      // пустой ленты под собой.
      expect(bar.bottom, 500.0);
      expect(cta.bottom, lessThanOrEqualTo(bar.top));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      // Кнопка связи закреплена снизу — прокрутка её не уносит.
      expect(tester.getRect(ctaButton()), cta);
    });

    testWidgets('стрелка вперёд листает фотографии', (tester) async {
      await openPhotos(tester);
      expect(photo(tester), 0);

      await tester.tap(find.bySemanticsLabel('Следующее фото'));
      await tester.pumpAndSettle();
      expect(photo(tester), 1);
    });

    testWidgets('стрелка назад возвращает к предыдущей', (tester) async {
      await openPhotos(tester);
      await tester.tap(find.bySemanticsLabel('Следующее фото'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Предыдущее фото'));
      await tester.pumpAndSettle();
      expect(photo(tester), 0);
    });

    testWidgets('лента замкнута: с первой назад — к последней', (tester) async {
      await openPhotos(tester);
      final last = kListings.first.photos.length - 1;

      await tester.tap(find.bySemanticsLabel('Предыдущее фото'));
      await tester.pumpAndSettle();
      expect(photo(tester), last);

      await tester.tap(find.bySemanticsLabel('Следующее фото'));
      await tester.pumpAndSettle();
      expect(photo(tester), 0);
    });

    testWidgets('«Вернуться» уводит обратно на объект', (tester) async {
      await openPhotos(tester);
      // «Вернуться» есть и в кадре под фотографией: наша кнопка идёт поверх,
      // поэтому в дереве она последняя
      await tester.tap(find.bySemanticsLabel('Вернуться').last);
      await tester.pumpAndSettle();
      expect(find.byType(ListingPage), findsOneWidget);
    });
  });

  group('профиль', () {
    testWidgets('вкладка открывает профиль', (tester) async {
      await open(tester);
      await tester.tapAt(tab(4));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('«Вам понравилось» открывает избранное', (tester) async {
      await open(tester, route: Routes.profile);
      await tester.tapAt(at(180, 394));
      await tester.pumpAndSettle();
      expect(find.byType(FavouritesPage), findsOneWidget);
    });

    testWidgets('«Выйти из аккаунта» спрашивает и выходит', (tester) async {
      await open(tester, route: Routes.profile);
      await tester.tap(find.bySemanticsLabel('Выйти из аккаунта'));
      await tester.pumpAndSettle();
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Выйти'));
      await tester.pumpAndSettle();

      // экран входа, вернуться некуда, избранное забыто
      expect(find.byType(ProfilePage), findsNothing);
      expect(find.byType(FramePage), findsOneWidget);
      expect(find.bySemanticsLabel('Назад'), findsNothing);
      final state = AppScope.read(tester.element(find.byType(FramePage)));
      expect(state.favourites, isEmpty);
    });

    testWidgets('«Отмена» оставляет на профиле', (tester) async {
      await open(tester, route: Routes.profile);
      await tester.tap(find.bySemanticsLabel('Выйти из аккаунта'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
    });
  });

  group('избранное', () {
    testWidgets('сердце на карточке добавляет объект в «Понравилось»',
        (tester) async {
      await open(tester);
      final asanbay = find.byWidgetPredicate(
        (w) => w is ObjectCard && w.listing.id == 'asanbay',
      );
      expect(tester.widget<ObjectCard>(asanbay).favourite, isFalse);

      await tester.tap(find.descendant(
        of: asanbay,
        matching: find.bySemanticsLabel('В избранное'),
      ));
      await tester.pumpAndSettle();
      expect(tester.widget<ObjectCard>(asanbay).favourite, isTrue);
    });

    testWidgets('страница показывает то, что отмечено', (tester) async {
      await open(tester, route: Routes.favourites);
      expect(find.byType(FavouritesPage), findsOneWidget);
      expect(shown(tester).map((l) => l.id), ['technopark']);
    });
  });

  group('вкладки', () {
    testWidgets('вкладка без своей страницы показывает кадр и остаётся вкладкой',
        (tester) async {
      await open(tester, route: Routes.notifications);
      expect(find.byType(NotificationsPage), findsOneWidget);
      // с неё можно уйти обратно в каталог
      await tester.tapAt(tab(1));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogPage), findsOneWidget);
    });

    testWidgets('на «Уведомлениях» ни одна вкладка не подсвечена', (tester) async {
      await open(tester, route: Routes.home);
      await tester.tapAt(at(335, 59));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);

      final bar = tester.widget<FigTabBar>(find.byType(FigTabBar));
      expect(bar.active, isNull);
      // и нарисованный в кадре «Поиск» тоже погашен
      expect(bar.mockupTab, -1);
    });

    testWidgets('с «Уведомлений» кнопка «назад» возвращает на «Главную»',
        (tester) async {
      await open(tester, route: Routes.home);
      await tester.tapAt(at(335, 59));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Назад'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('«Избранное» открывает свою страницу', (tester) async {
      await open(tester);
      await tester.tapAt(tab(3));
      await tester.pumpAndSettle();
      expect(find.byType(FavouritesPage), findsOneWidget);
    });

    testWidgets('«Поиск» возвращает в каталог', (tester) async {
      await open(tester, route: Routes.favourites);
      await tester.tapAt(tab(1));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogPage), findsOneWidget);
    });
  });

  group('режим исполнителя в приложении', () {
    testWidgets('«Режим исполнителя» проводит регистрацию до профиля исполнителя',
        (tester) async {
      await open(tester, route: Routes.welcome);
      await tester.tap(find.bySemanticsLabel('Режим исполнителя').last);
      await tester.pumpAndSettle();
      expect(find.byType(ProSignupPage), findsOneWidget);

      // «Далее» есть и в кадре, поэтому нажимаем именно зону
      await tester.tap(find.byWidgetPredicate(
        (w) => w is FigZone && w.label == 'Далее',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CodePage), findsOneWidget);

      // код из четырёх цифр уводит дальше сам — через паузу в 200 мс,
      // поэтому ждём с запасом: pumpAndSettle без интервала её не проматывает
      await tester.enterText(find.byType(EditableText).last, '1234');
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.byType(ProPhotoConfirmPage), findsOneWidget);

      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(ProProfilePage), findsOneWidget);
      final state = AppScope.read(tester.element(find.byType(ProProfilePage)));
      expect(state.pro, isTrue);
    });

    testWidgets('в режиме исполнителя пятая вкладка ведёт в его профиль',
        (tester) async {
      await open(tester, route: Routes.home);
      AppScope.read(tester.element(find.byType(HomePage))).pro = true;
      await tester.pumpAndSettle();

      await tester.tapAt(tab(4));
      await tester.pumpAndSettle();
      expect(find.byType(ProProfilePage), findsOneWidget);
      expect(find.byType(ProfilePage), findsNothing);
    });

    testWidgets('поля регистрации исполнителя принимают ввод', (tester) async {
      await open(tester, route: Routes.proSignup);
      // кнопка «Далее» раньше лежала поверх «Пароля» и «ИИН»
      await tester.enterText(find.byType(TextField).at(2), 'секрет');
      await tester.pumpAndSettle();

      expect(find.byType(ProSignupPage), findsOneWidget);
      expect(find.text('секрет'), findsOneWidget);
    });
  });

  group('история просмотров', () {
    testWidgets('вкладка «История» открывает историю просмотров', (tester) async {
      await open(tester);
      await tester.tapAt(tab(2));
      await tester.pumpAndSettle();
      expect(find.byType(ViewHistoryPage), findsOneWidget);
    });

    testWidgets('открытый объект встаёт в начало истории', (tester) async {
      await open(tester);
      final second = kListings[1];
      await tester.tap(find.byWidgetPredicate(
        (w) => w is ObjectCard && w.listing.id == second.id,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ListingPage), findsOneWidget);

      // у объекта своего меню нет — возвращаемся в каталог и уже оттуда
      await tester.tapAt(at(25, 48));
      await tester.pumpAndSettle();
      await tester.tapAt(tab(2));
      await tester.pumpAndSettle();
      expect(historyIds(tester).first, second.id);
    });

    testWidgets('плитка открывает объект', (tester) async {
      await open(tester, route: Routes.viewHistory);
      await tester.tap(find.byType(HistoryTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(ListingPage), findsOneWidget);
    });

    testWidgets('«Выбрать» убирает отмеченное из истории', (tester) async {
      await open(tester, route: Routes.viewHistory);
      final before = historyIds(tester);
      expect(before, isNotEmpty);

      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(HistoryTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Убрать из истории'));
      await tester.pumpAndSettle();

      expect(historyIds(tester), isNot(contains(before.first)));
      expect(historyIds(tester), hasLength(before.length - 1));
    });

    testWidgets('в режиме выбора плитка не открывает объект', (tester) async {
      await open(tester, route: Routes.viewHistory);
      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(HistoryTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(ListingPage), findsNothing);
      expect(find.byType(ViewHistoryPage), findsOneWidget);
    });

    testWidgets('фильтр по типу оставляет только этот вид', (tester) async {
      await open(tester, route: Routes.viewHistory);
      // подставной шрифт теста шире, чем на устройстве, и третий чип уезжает
      await tester.ensureVisible(find.text('Все типы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Все типы'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Участки').last);
      await tester.pumpAndSettle();

      final shown = tester
          .widgetList<HistoryTile>(find.byType(HistoryTile))
          .map((t) => t.entry.listing.kind);
      expect(shown, isNotEmpty);
      expect(shown.every((k) => k == PropertyKind.plot), isTrue);
    });

    testWidgets('порядок переключается на «Сначала старые»', (tester) async {
      await open(tester, route: Routes.viewHistory);
      final newestFirst = historyIds(tester);

      await tester.tap(find.text('Сначала новые'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сначала старые').last);
      await tester.pumpAndSettle();

      expect(historyIds(tester), newestFirst.reversed.toList());
    });
  });

  group('системная кнопка «назад»', () {
    testWidgets('со вкладки возвращает на предыдущую', (tester) async {
      await open(tester, route: Routes.home);
      await tester.tapAt(tab(1));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogPage), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('после трёх вкладок отматывает их по одной', (tester) async {
      await open(tester, route: Routes.home);
      await tester.tapAt(tab(1));
      await tester.pumpAndSettle();
      await tester.tapAt(tab(3));
      await tester.pumpAndSettle();
      expect(find.byType(FavouritesPage), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(CatalogPage), findsOneWidget);
      await systemBack(tester);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('из каталога по категории возвращает на «Главную»',
        (tester) async {
      await open(tester, route: Routes.home);
      // «Участки» — третья категория
      await tester.tapAt(at(224, 340));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogPage), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('с объекта возвращает в список', (tester) async {
      await open(tester);
      await tester.tap(find.byType(ObjectCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(ListingPage), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(CatalogPage), findsOneWidget);
    });

    testWidgets('из «Фотообзора» возвращает на объект', (tester) async {
      await openPhotos(tester);
      await systemBack(tester);
      expect(find.byType(ListingPage), findsOneWidget);
    });
  });

  group('ассеты', () {
    testWidgets('все фотографии объектов лежат в сборке', (tester) async {
      for (final listing in kListings) {
        for (final photo in listing.photos) {
          final data = await rootBundle.load(photo);
          expect(data.lengthInBytes, greaterThan(0), reason: photo);
        }
      }
    });
  });
}
