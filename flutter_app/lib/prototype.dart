// The screen list, the clickable zones and the tab-bar wiring, copied from the
// prototype's SCREENS / HOTSPOTS / TAB_TARGETS / SCREEN_TAB / NAV_SCREENS
// tables in "House KGZ - Прототип.dc.html".
import 'package:flutter/material.dart';

import 'screens/screen_01_splash.dart';
import 'screens/screen_02_onboarding_1.dart';
import 'screens/screen_03_onboarding_2.dart';
import 'screens/screen_04_onboarding_3.dart';
import 'screens/screen_05_welcome.dart';
import 'screens/screen_06_code.dart';
import 'screens/screen_07_welcome_2.dart';
import 'screens/screen_08_code_2.dart';
import 'screens/screen_09_home.dart';
import 'screens/screen_10_collection.dart';
import 'screens/screen_11_catalog.dart';
import 'screens/screen_12_filter.dart';
import 'screens/screen_13_screen_57_3408.dart';
import 'screens/screen_14_product_card.dart';
import 'screens/screen_15_profile.dart';
import 'screens/screen_16_liked.dart';
import 'screens/screen_17_notifications.dart';
import 'screens/screen_18_your_filters.dart';
import 'screens/screen_19_object_full.dart';
import 'screens/screen_20_photo_review.dart';
import 'screens/screen_21_frame_11133.dart';
import 'screens/screen_22_screen_10_1475.dart';
import 'screens/screen_23_profile_57_506.dart';
import 'screens/screen_24_photo_confirm_1.dart';
import 'screens/screen_25_photo_confirm_2.dart';
import 'screens/screen_26_screen_63_1840.dart';
import 'screens/screen_27_screen_64_1365.dart';
import 'screens/screen_28_screen_63_2044.dart';
import 'screens/screen_29_screen_64_187.dart';
import 'screens/screen_30_screen_64_249.dart';
import 'screens/screen_31_screen_155_823.dart';
import 'screens/screen_32_screen_155_901.dart';
import 'screens/screen_33_screen_155_980.dart';
import 'screens/screen_34_catalog_create.dart';
import 'screens/screen_35_screen_155_1329.dart';
import 'screens/screen_36_screen_155_1379.dart';
import 'screens/screen_37_screen_155_1429.dart';
import 'screens/screen_38_pro_profile.dart';
import 'screens/screen_39_screen_155_2155.dart';
import 'screens/screen_40_screen_155_2313.dart';
import 'screens/screen_41_topup_1.dart';
import 'screens/screen_42_topup_2.dart';
import 'screens/screen_43_topup_3.dart';
import 'screens/screen_44_topup_4.dart';
import 'screens/screen_45_topup_5.dart';
import 'screens/screen_46_ad_1.dart';
import 'screens/screen_47_ad_2.dart';
import 'screens/screen_48_ad_3.dart';
import 'screens/screen_49_ad_4.dart';
import 'screens/screen_50_ad_5.dart';
import 'screens/screen_51_ad_6.dart';
import 'screens/screen_52_history_1.dart';
import 'screens/screen_53_history_2.dart';
import 'screens/screen_54_history_3.dart';
import 'screens/screen_55_history_4.dart';
import 'screens/screen_56_pro_signup.dart';
import 'screens/screen_57_pro_code.dart';

/// Where the five tabs lead (`TAB_TARGETS`). The fifth is the client profile;
/// in contractor mode it goes to [figProProfile] instead.
const List<int> figTabTargets = [8, 10, 16, 15, 14];

/// Профиль в режиме исполнителя (`PRO_PROFILE`), куда приводит регистрация и
/// куда после неё ведёт пятая вкладка.
const int figProProfile = 37;

/// Возврат на сплэш, онбординг или вход — это новый вход, и режим снова
/// клиентский (`go` в прототипе сбрасывает `pro` на экранах 01–08).
bool figResetsPro(int target) => target <= 7;

/// A clickable zone, in the design's 375pt coordinate space.
class FigHotspot {
  const FigHotspot(
    this.left,
    this.top,
    this.width,
    this.height,
    this.target,
    this.label, {
    this.back = false,
    this.pro,
  });

  /// Goes back instead of to a screen — the prototype's «Вернуться».
  const FigHotspot.back(this.left, this.top, this.width, this.height, this.label)
      : target = -1,
        back = true,
        pro = null;

  final double left;
  final double top;
  final double width;
  final double height;

  /// Index into [figScreens]; targets beyond the copied screens are kept as
  /// they are in the original prototype and simply do nothing here.
  final int target;
  final String label;
  final bool back;

  /// Переключает режим: «Режим исполнителя» включает его, «Зарегистрироваться»
  /// возвращает клиентский. null — зона режима не касается.
  final bool? pro;
}

class FigScreen {
  const FigScreen({
    required this.number,
    required this.title,
    required this.node,
    required this.width,
    required this.height,
    required this.builder,
    this.hotspots = const [],
    this.tapAnywhereTo,
    this.autoAdvanceTo,
    this.autoAdvanceAfter,
    this.tabBarAt,
    this.tabBarPinned = false,
    this.activeTab,
    this.mockupTab,
    this.viewportWidth = 375,
    this.viewportHeight = 812,
  });

  final String number;
  final String title;

  /// The Figma node id, as shown in the HTML prototype's header.
  final String node;
  final double width;
  final double height;
  final WidgetBuilder builder;
  final List<FigHotspot> hotspots;

  /// Where a tap that hit nothing else goes — the prototype's fallback at the
  /// end of `_onStageClick`, which walks the photo review, the contractor
  /// registration and the ad flow. It is not a zone: a zone would be covered by
  /// whatever the mockup paints over it (the tab bar on screen 40), while here,
  /// as in the browser, the zones and the tab-bar cells simply get the tap
  /// first.
  final int? tapAnywhereTo;

  final int? autoAdvanceTo;
  final Duration? autoAdvanceAfter;

  /// Where the mockup draws the tab bar, so it scrolls with the content.
  final Offset? tabBarAt;

  /// The mockup has no tab bar here, so the prototype injects one pinned to
  /// the bottom of the viewport (`NAV_SCREENS`).
  final bool tabBarPinned;

  /// Which tab is highlighted (`SCREEN_TAB`); null leaves the mockup's own
  /// colours alone.
  final int? activeTab;

  /// Which tab this screen's own mockup draws highlighted. The bar is one
  /// widget for the whole app, drawn from the catalog screen, so the screens
  /// whose mockup marks another tab say so here — it is what shows wherever
  /// the prototype leaves the mockup alone.
  final int? mockupTab;

  /// The stage the prototype sizes for this screen. Frame 11133 is drawn at
  /// its own 505×820 rather than shrunk into a phone.
  final double viewportWidth;
  final double viewportHeight;

  bool get hasTabBar => tabBarAt != null || tabBarPinned;
}

const List<FigScreen> figScreens = [
  FigScreen(
    number: '01',
    title: 'Сплэш',
    node: '2:47',
    width: Screen01Splash.designWidth,
    height: Screen01Splash.designHeight,
    builder: _splash,
    autoAdvanceTo: 1,
    autoAdvanceAfter: Duration(milliseconds: 1600),
  ),
  FigScreen(
    number: '02',
    title: 'Онбординг 1',
    node: '4:403',
    width: Screen02Onboarding1.designWidth,
    height: Screen02Onboarding1.designHeight,
    builder: _onboarding1,
    hotspots: [FigHotspot(31, 670, 314, 52, 2, 'Далее')],
  ),
  FigScreen(
    number: '03',
    title: 'Онбординг 2',
    node: '4:447',
    width: Screen03Onboarding2.designWidth,
    height: Screen03Onboarding2.designHeight,
    builder: _onboarding2,
    hotspots: [FigHotspot(31, 670, 314, 52, 3, 'Далее')],
  ),
  FigScreen(
    number: '04',
    title: 'Онбординг 3',
    node: '4:501',
    width: Screen04Onboarding3.designWidth,
    height: Screen04Onboarding3.designHeight,
    builder: _onboarding3,
    hotspots: [FigHotspot(31, 670, 314, 52, 4, 'Далее')],
  ),
  FigScreen(
    number: '05',
    title: 'Добро пожаловать',
    node: '57:282',
    width: Screen05Welcome.designWidth,
    height: Screen05Welcome.designHeight,
    builder: _welcome,
    hotspots: [
      FigHotspot(25, 656, 324, 36, 5, 'Войти'),
      FigHotspot(116, 717, 143, 20, 5, 'Зарегистрироваться', pro: false),
      // отсюда начинается регистрация исполнителя
      FigHotspot(118, 753, 140, 20, 55, 'Режим исполнителя', pro: true),
    ],
  ),
  FigScreen(
    number: '06',
    title: 'Код подтверждения',
    node: '63:606',
    width: Screen06Code.designWidth,
    height: Screen06Code.designHeight,
    builder: _code,
    hotspots: [FigHotspot(0, 431, 375, 381, 8, 'Ввести код')],
  ),
  FigScreen(
    number: '07',
    title: 'Добро пожаловать · 2',
    node: '63:557',
    width: Screen07Welcome2.designWidth,
    height: Screen07Welcome2.designHeight,
    builder: _welcome2,
    hotspots: [FigHotspot(25, 656, 324, 36, 7, 'Войти')],
  ),
  FigScreen(
    number: '08',
    title: 'Код подтверждения · 2',
    node: '57:392',
    width: Screen08Code2.designWidth,
    height: Screen08Code2.designHeight,
    builder: _code2,
    hotspots: [FigHotspot(0, 431, 375, 381, 8, 'Ввести код')],
  ),
  FigScreen(
    number: '09',
    title: 'Главная',
    node: '4:541',
    width: Screen09Home.designWidth,
    height: Screen09Home.designHeight,
    builder: _home,
    tabBarPinned: true,
    activeTab: 0,
    hotspots: [
      FigHotspot(320, 44, 30, 30, 16, 'Уведомления'),
      FigHotspot(25, 138, 358, 82, 9, 'Подборка'),
      FigHotspot(25, 236, 325, 50, 10, 'Поиск → каталог'),
      FigHotspot(25, 302, 325, 82, 10, 'Категории → каталог'),
      FigHotspot(23, 456, 222, 26, 10, 'Новые позиции: фильтр → каталог'),
      FigHotspot(25, 512, 325, 422, 9, 'Объект → предложение'),
      FigHotspot(133, 957, 110, 22, 10, 'Посмотреть все'),
    ],
  ),
  FigScreen(
    number: '10',
    title: 'Коллекция',
    node: '10:1286',
    width: Screen10Collection.designWidth,
    height: Screen10Collection.designHeight,
    builder: _collection,
    tabBarPinned: true,
    activeTab: 0,
    hotspots: [FigHotspot(25, 374.3, 95.6, 15, 18, 'Подробнее')],
  ),
  FigScreen(
    number: '11',
    title: 'Каталог',
    node: '57:866',
    width: Screen11Catalog.designWidth,
    height: Screen11Catalog.designHeight,
    builder: _catalog,
    tabBarAt: Screen11Catalog.tabBarAt,
    mockupTab: Screen11Catalog.mockupTab,
    activeTab: 1,
    hotspots: [FigHotspot(326, 50, 30, 30, 11, 'Фильтры')],
  ),
  FigScreen(
    number: '12',
    title: 'Фильтр',
    node: '57:1169',
    width: Screen12Filter.designWidth,
    height: Screen12Filter.designHeight,
    builder: _filter,
    tabBarAt: Screen12Filter.tabBarAt,
    mockupTab: Screen12Filter.mockupTab,
    activeTab: 1,
  ),
  FigScreen(
    number: '13',
    title: 'Экран 57:3408',
    node: '57:3408',
    width: Screen13Screen573408.designWidth,
    height: Screen13Screen573408.designHeight,
    builder: _screen573408,
    tabBarAt: Screen13Screen573408.tabBarAt,
    mockupTab: Screen13Screen573408.mockupTab,
    activeTab: 1,
    hotspots: [FigHotspot(25, 238, 183, 21, 12, 'Садыр Жапаров')],
  ),
  FigScreen(
    number: '14',
    title: 'Карточка товара',
    node: '63:1400',
    width: Screen14ProductCard.designWidth,
    height: Screen14ProductCard.designHeight,
    builder: _productCard,
    tabBarAt: Screen14ProductCard.tabBarAt,
    mockupTab: Screen14ProductCard.mockupTab,
    hotspots: [
      FigHotspot(25, 238, 183, 21, 12, 'Садыр Жапаров'),
      FigHotspot(23, 868, 327, 26, 16, 'Уведомление'),
    ],
  ),
  FigScreen(
    number: '15',
    title: 'Ваш профиль',
    node: '60:118',
    width: Screen15Profile.designWidth,
    height: Screen15Profile.designHeight,
    builder: _profile,
    tabBarAt: Screen15Profile.tabBarAt,
    mockupTab: Screen15Profile.mockupTab,
    activeTab: 4,
    hotspots: [
      FigHotspot(96, 102, 183, 17, 12, 'Садыр Жапаров'),
      FigHotspot(23, 381, 327, 26, 15, 'Вам понравилось'),
      FigHotspot(23, 425, 327, 26, 16, 'Уведомление'),
    ],
  ),
  FigScreen(
    number: '16',
    title: 'Вам понравилось',
    node: '63:227',
    width: Screen16Liked.designWidth,
    height: Screen16Liked.designHeight,
    builder: _liked,
    tabBarAt: Screen16Liked.tabBarAt,
    mockupTab: Screen16Liked.mockupTab,
    activeTab: 3,
  ),
  FigScreen(
    number: '17',
    title: 'Уведомления',
    node: '62:783',
    width: Screen17Notifications.designWidth,
    height: Screen17Notifications.designHeight,
    builder: _notifications,
    tabBarAt: Screen17Notifications.tabBarAt,
    mockupTab: Screen17Notifications.mockupTab,
    activeTab: 2,
    hotspots: [FigHotspot(326, 50, 30, 30, 11, 'Фильтры')],
  ),
  FigScreen(
    number: '18',
    title: 'Ваши фильтры',
    node: '57:1481',
    width: Screen18YourFilters.designWidth,
    height: Screen18YourFilters.designHeight,
    builder: _yourFilters,
    tabBarAt: Screen18YourFilters.tabBarAt,
    mockupTab: Screen18YourFilters.mockupTab,
    activeTab: 1,
    hotspots: [FigHotspot(0, 0, 375, 387, 19, 'Фотообзор')],
  ),
  FigScreen(
    number: '19',
    title: 'Объект · полная',
    node: '9:891',
    width: Screen19ObjectFull.designWidth,
    height: Screen19ObjectFull.designHeight,
    builder: _objectFull,
  ),
  FigScreen(
    number: '20',
    title: 'Фотообзор',
    node: '57:1722',
    width: Screen20PhotoReview.designWidth,
    height: Screen20PhotoReview.designHeight,
    builder: _photoReview,
    tapAnywhereTo: 20,
    hotspots: [FigHotspot.back(136, 725, 107.4, 24, 'Вернуться')],
  ),
  FigScreen(
    number: '21',
    title: 'Frame 11133',
    node: '57:1842',
    width: Screen21Frame11133.designWidth,
    height: Screen21Frame11133.designHeight,
    builder: _frame11133,
    viewportWidth: 505,
    viewportHeight: 820,
    tapAnywhereTo: 21,
  ),
  FigScreen(
    number: '22',
    title: 'Экран 10:1475',
    node: '10:1475',
    width: Screen22Screen101475.designWidth,
    height: Screen22Screen101475.designHeight,
    builder: _screen101475,
    hotspots: [FigHotspot(16, 634, 162.6, 24, 12, 'Садыр Жапаров')],
  ),
  FigScreen(
    number: '23',
    title: 'Профиль 57:506',
    node: '57:506',
    width: Screen23Profile57506.designWidth,
    height: Screen23Profile57506.designHeight,
    builder: _profile57506,
  ),
  FigScreen(
    number: '24',
    title: 'Фото подтверждение · 1',
    node: '63:1001',
    width: Screen24PhotoConfirm1.designWidth,
    height: Screen24PhotoConfirm1.designHeight,
    builder: _photoConfirm1,
    // регистрация исполнителя: клик по экрану — следующий шаг
    tapAnywhereTo: 24,
  ),
  FigScreen(
    number: '25',
    title: 'Фото подтверждение · 2',
    node: '63:1161',
    width: Screen25PhotoConfirm2.designWidth,
    height: Screen25PhotoConfirm2.designHeight,
    builder: _photoConfirm2,
    // последний шаг регистрации — дальше профиль исполнителя
    tapAnywhereTo: 37,
  ),
  FigScreen(
    number: '26',
    title: 'Экран 63:1840',
    node: '63:1840',
    width: Screen26Screen631840.designWidth,
    height: Screen26Screen631840.designHeight,
    builder: _screen631840,
    hotspots: [FigHotspot(25, 1083, 324, 36, 26, 'Далее')],
  ),
  FigScreen(
    number: '27',
    title: 'Экран 64:1365',
    node: '64:1365',
    width: Screen27Screen641365.designWidth,
    height: Screen27Screen641365.designHeight,
    builder: _screen641365,
    hotspots: [FigHotspot(25, 732, 324, 36, 27, 'Далее')],
  ),
  FigScreen(
    number: '28',
    title: 'Экран 63:2044',
    node: '63:2044',
    width: Screen28Screen632044.designWidth,
    height: Screen28Screen632044.designHeight,
    builder: _screen632044,
    hotspots: [FigHotspot(25, 707, 324, 36, 28, 'Далее')],
  ),
  FigScreen(
    number: '29',
    title: 'Экран 64:187',
    node: '64:187',
    width: Screen29Screen64187.designWidth,
    height: Screen29Screen64187.designHeight,
    builder: _screen64187,
    hotspots: [FigHotspot(25, 711, 324, 36, 29, 'Далее')],
  ),
  FigScreen(
    number: '30',
    title: 'Экран 64:249',
    node: '64:249',
    width: Screen30Screen64249.designWidth,
    height: Screen30Screen64249.designHeight,
    builder: _screen64249,
    hotspots: [FigHotspot(25, 711, 324, 36, 30, 'Далее')],
  ),
  // Screens 31…37 and 40 are the prototype's `AD_FLOW`: 40 → 37 → 35 → 36 →
  // 31 → 32 → 33. Inside it a tap anywhere on the screen is the next step, so
  // each one carries a canvas-sized zone under the «Далее» button.
  FigScreen(
    number: '31',
    title: 'Экран 155:823',
    node: '155:823',
    width: Screen31Screen155823.designWidth,
    height: Screen31Screen155823.designHeight,
    builder: _screen155823,
    tapAnywhereTo: 31,
    hotspots: [FigHotspot(25, 709, 324, 36, 31, 'Далее')],
  ),
  FigScreen(
    number: '32',
    title: 'Экран 155:901',
    node: '155:901',
    width: Screen32Screen155901.designWidth,
    height: Screen32Screen155901.designHeight,
    builder: _screen155901,
    tapAnywhereTo: 32,
    hotspots: [FigHotspot(25, 711, 324, 36, 32, 'Далее')],
  ),
  FigScreen(
    number: '33',
    title: 'Экран 155:980',
    node: '155:980',
    width: Screen33Screen155980.designWidth,
    height: Screen33Screen155980.designHeight,
    builder: _screen155980,
    // last step of the flow: only «Далее» leads on, to the next screen
    hotspots: [FigHotspot(25, 711, 324, 36, 33, 'Далее')],
  ),
  FigScreen(
    number: '34',
    title: 'Создание каталога',
    node: '155:1007',
    width: Screen34CatalogCreate.designWidth,
    height: Screen34CatalogCreate.designHeight,
    builder: _catalogCreate,
    hotspots: [FigHotspot(25, 731, 324, 36, 34, 'Далее')],
  ),
  FigScreen(
    number: '35',
    title: 'Экран 155:1329',
    node: '155:1329',
    width: Screen35Screen1551329.designWidth,
    height: Screen35Screen1551329.designHeight,
    builder: _screen1551329,
    tapAnywhereTo: 35,
    hotspots: [FigHotspot(25, 707, 324, 36, 35, 'Далее')],
  ),
  FigScreen(
    number: '36',
    title: 'Экран 155:1379',
    node: '155:1379',
    width: Screen36Screen1551379.designWidth,
    height: Screen36Screen1551379.designHeight,
    builder: _screen1551379,
    tapAnywhereTo: 30,
    hotspots: [FigHotspot(25, 711, 324, 36, 30, 'Далее')],
  ),
  FigScreen(
    number: '37',
    title: 'Экран 155:1429',
    node: '155:1429',
    width: Screen37Screen1551429.designWidth,
    height: Screen37Screen1551429.designHeight,
    builder: _screen1551429,
    tapAnywhereTo: 34,
    hotspots: [FigHotspot(25, 1028, 324, 36, 34, 'Далее')],
  ),
  FigScreen(
    number: '38',
    title: 'Профиль исполнителя',
    node: '155:1944',
    width: Screen38ProProfile.designWidth,
    height: Screen38ProProfile.designHeight,
    builder: _proProfile,
    tabBarAt: Screen38ProProfile.tabBarAt,
    mockupTab: Screen38ProProfile.mockupTab,
    activeTab: 4,
    hotspots: [
      FigHotspot(25, 238, 183, 21, 12, 'Садыр Жапаров'),
      FigHotspot(25, 959, 330, 26, 16, 'Уведомление'),
      // пополнение, создание объявления и история трат — экраны 41+
      FigHotspot(235.9, 733.5, 111.6, 36, 40, 'Пополнить'),
      FigHotspot(129, 385, 161.4, 30, 46, 'Добавить объявление'),
      FigHotspot(25, 1091, 330, 26, 51, 'История пополнения и трат'),
    ],
  ),
  FigScreen(
    number: '39',
    title: 'Экран 155:2155',
    node: '155:2155',
    width: Screen39Screen1552155.designWidth,
    height: Screen39Screen1552155.designHeight,
    builder: _screen1552155,
    tabBarAt: Screen39Screen1552155.tabBarAt,
    mockupTab: Screen39Screen1552155.mockupTab,
    // объявление открывается на экране 46, за пределами перенесённых
    hotspots: [FigHotspot(25, 770, 325, 201.3, 45, 'Объявление')],
  ),
  FigScreen(
    number: '40',
    title: 'Экран 155:2313',
    node: '155:2313',
    width: Screen40Screen1552313.designWidth,
    height: Screen40Screen1552313.designHeight,
    builder: _screen1552313,
    tabBarAt: Screen40Screen1552313.tabBarAt,
    mockupTab: Screen40Screen1552313.mockupTab,
    // начало флоу объявления: клик по экрану ведёт на 37
    tapAnywhereTo: 36,
  ),
  // Пополнение и объявление — кадры двух лент. «Далее» на каждом ведёт на
  // следующий кадр той же ленты, а на последнем — на следующий экран списка
  // (`_nextStep`): 45 → 46, 51 → 52 «История трат», которой ещё нет.
  FigScreen(
    number: '41',
    title: 'Пополнение · 1',
    node: '155:1549',
    width: Screen41Topup1.designWidth,
    height: Screen41Topup1.designHeight,
    builder: _topup1,
    hotspots: [FigHotspot(25, 711, 324, 36, 41, 'Далее')],
  ),
  FigScreen(
    number: '42',
    title: 'Пополнение · 2',
    node: '155:1549',
    width: Screen42Topup2.designWidth,
    height: Screen42Topup2.designHeight,
    builder: _topup2,
    hotspots: [FigHotspot(25, 711, 324, 36, 42, 'Далее')],
  ),
  FigScreen(
    number: '43',
    title: 'Пополнение · 3',
    node: '155:1549',
    width: Screen43Topup3.designWidth,
    height: Screen43Topup3.designHeight,
    builder: _topup3,
    hotspots: [FigHotspot(25, 711, 324, 36, 43, 'Далее')],
  ),
  FigScreen(
    number: '44',
    title: 'Пополнение · 4',
    node: '155:1549',
    width: Screen44Topup4.designWidth,
    height: Screen44Topup4.designHeight,
    builder: _topup4,
    hotspots: [FigHotspot(25, 711, 324, 36, 44, 'Далее')],
  ),
  FigScreen(
    number: '45',
    title: 'Пополнение · 5',
    node: '155:1549',
    width: Screen45Topup5.designWidth,
    height: Screen45Topup5.designHeight,
    builder: _topup5,
    hotspots: [FigHotspot(25, 711, 324, 36, 45, 'Далее')],
  ),
  FigScreen(
    number: '46',
    title: 'Объявление · 1',
    node: '155:380',
    width: Screen46Ad1.designWidth,
    height: Screen46Ad1.designHeight,
    builder: _ad1,
    hotspots: [
      FigHotspot(24, 279, 326, 30, 39, 'Изменить объявление'),
      FigHotspot(25, 732, 324, 36, 46, 'Далее'),
    ],
  ),
  FigScreen(
    number: '47',
    title: 'Объявление · 2',
    node: '155:380',
    width: Screen47Ad2.designWidth,
    height: Screen47Ad2.designHeight,
    builder: _ad2,
    hotspots: [FigHotspot(25, 1083, 324, 36, 47, 'Далее')],
  ),
  FigScreen(
    number: '48',
    title: 'Объявление · 3',
    node: '155:380',
    width: Screen48Ad3.designWidth,
    height: Screen48Ad3.designHeight,
    builder: _ad3,
    hotspots: [FigHotspot(25, 707, 324, 36, 48, 'Далее')],
  ),
  FigScreen(
    number: '49',
    title: 'Объявление · 4',
    node: '155:380',
    width: Screen49Ad4.designWidth,
    height: Screen49Ad4.designHeight,
    builder: _ad4,
    hotspots: [FigHotspot(25, 711, 324, 36, 49, 'Далее')],
  ),
  FigScreen(
    number: '50',
    title: 'Объявление · 5',
    node: '155:380',
    width: Screen50Ad5.designWidth,
    height: Screen50Ad5.designHeight,
    builder: _ad5,
    hotspots: [FigHotspot(25, 709, 324, 36, 50, 'Далее')],
  ),
  FigScreen(
    number: '51',
    title: 'Объявление · 6',
    node: '155:380',
    width: Screen51Ad6.designWidth,
    height: Screen51Ad6.designHeight,
    builder: _ad6,
    // последний кадр ленты: «Далее» ведёт на «Историю трат», экран 52
    hotspots: [FigHotspot(25, 711, 324, 36, 51, 'Далее')],
  ),
  // История трат — третья лента. Её четыре кадра различаются выбранной
  // вкладкой, и вкладки переставлены: активная всегда первая. Прототип ловит их
  // по тексту (`HISTORY_TABS`), поэтому у каждого кадра свои четыре зоны.
  FigScreen(
    number: '52',
    title: 'История трат · 1',
    node: '155:1750',
    width: Screen52History1.designWidth,
    height: Screen52History1.designHeight,
    builder: _history1,
    hotspots: [
      FigHotspot(24, 132, 114, 30, 51, 'Все операции'),
      FigHotspot(146, 132, 105, 30, 52, 'Пополнение'),
      FigHotspot(259, 132, 90, 30, 53, 'Списание'),
      FigHotspot(357, 132, 90, 30, 54, 'Бонусы'),
      FigHotspot(25, 711, 324, 36, 52, 'Далее'),
    ],
  ),
  FigScreen(
    number: '53',
    title: 'История трат · 2',
    node: '155:1750',
    width: Screen53History2.designWidth,
    height: Screen53History2.designHeight,
    builder: _history2,
    hotspots: [
      FigHotspot(24, 132, 105, 30, 52, 'Пополнение'),
      FigHotspot(137, 132, 114, 30, 51, 'Все операции'),
      FigHotspot(259, 132, 90, 30, 53, 'Списание'),
      FigHotspot(357, 132, 90, 30, 54, 'Бонусы'),
      FigHotspot(25, 711, 324, 36, 53, 'Далее'),
    ],
  ),
  FigScreen(
    number: '54',
    title: 'История трат · 3',
    node: '155:1750',
    width: Screen54History3.designWidth,
    height: Screen54History3.designHeight,
    builder: _history3,
    hotspots: [
      FigHotspot(24, 132, 90, 30, 53, 'Списание'),
      FigHotspot(122, 132, 114, 30, 51, 'Все операции'),
      FigHotspot(244, 132, 105, 30, 52, 'Пополнение'),
      FigHotspot(357, 132, 90, 30, 54, 'Бонусы'),
      FigHotspot(25, 711, 324, 36, 54, 'Далее'),
    ],
  ),
  FigScreen(
    number: '55',
    title: 'История трат · 4',
    node: '155:1750',
    width: Screen55History4.designWidth,
    height: Screen55History4.designHeight,
    builder: _history4,
    hotspots: [
      FigHotspot(24, 132, 76, 30, 54, 'Бонусы'),
      FigHotspot(108, 132, 105, 30, 52, 'Пополнение'),
      FigHotspot(221, 132, 90, 30, 53, 'Списание'),
      FigHotspot(319, 132, 114, 30, 51, 'Все операции'),
      // конец ленты: «Далее» ведёт на регистрацию исполнителя
      FigHotspot(25, 711, 324, 36, 55, 'Далее'),
    ],
  ),
  // Регистрация исполнителя (`PRO_FLOW`): 56 → 57 → 24 → 25 → профиль
  // исполнителя. Внутри неё любой клик — следующий шаг.
  FigScreen(
    number: '56',
    title: 'Регистрация исполнителя',
    node: '63:812',
    width: Screen56ProSignup.designWidth,
    height: Screen56ProSignup.designHeight,
    builder: _proSignup,
    tapAnywhereTo: 56,
  ),
  FigScreen(
    number: '57',
    title: 'Код · исполнитель',
    node: '63:855',
    width: Screen57ProCode.designWidth,
    height: Screen57ProCode.designHeight,
    builder: _proCode,
    tapAnywhereTo: 23,
  ),
];

Widget _splash(BuildContext _) => const Screen01Splash();
Widget _onboarding1(BuildContext _) => const Screen02Onboarding1();
Widget _onboarding2(BuildContext _) => const Screen03Onboarding2();
Widget _onboarding3(BuildContext _) => const Screen04Onboarding3();
Widget _welcome(BuildContext _) => const Screen05Welcome();
Widget _code(BuildContext _) => const Screen06Code();
Widget _welcome2(BuildContext _) => const Screen07Welcome2();
Widget _code2(BuildContext _) => const Screen08Code2();
Widget _home(BuildContext _) => const Screen09Home();
Widget _collection(BuildContext _) => const Screen10Collection();
Widget _catalog(BuildContext _) => const Screen11Catalog();
Widget _filter(BuildContext _) => const Screen12Filter();
Widget _screen573408(BuildContext _) => const Screen13Screen573408();
Widget _productCard(BuildContext _) => const Screen14ProductCard();
Widget _profile(BuildContext _) => const Screen15Profile();
Widget _liked(BuildContext _) => const Screen16Liked();
Widget _notifications(BuildContext _) => const Screen17Notifications();
Widget _yourFilters(BuildContext _) => const Screen18YourFilters();
Widget _objectFull(BuildContext _) => const Screen19ObjectFull();
Widget _photoReview(BuildContext _) => const Screen20PhotoReview();
Widget _frame11133(BuildContext _) => const Screen21Frame11133();
Widget _screen101475(BuildContext _) => const Screen22Screen101475();
Widget _profile57506(BuildContext _) => const Screen23Profile57506();
Widget _photoConfirm1(BuildContext _) => const Screen24PhotoConfirm1();
Widget _photoConfirm2(BuildContext _) => const Screen25PhotoConfirm2();
Widget _screen631840(BuildContext _) => const Screen26Screen631840();
Widget _screen641365(BuildContext _) => const Screen27Screen641365();
Widget _screen632044(BuildContext _) => const Screen28Screen632044();
Widget _screen64187(BuildContext _) => const Screen29Screen64187();
Widget _screen64249(BuildContext _) => const Screen30Screen64249();
Widget _screen155823(BuildContext _) => const Screen31Screen155823();
Widget _screen155901(BuildContext _) => const Screen32Screen155901();
Widget _screen155980(BuildContext _) => const Screen33Screen155980();
Widget _catalogCreate(BuildContext _) => const Screen34CatalogCreate();
Widget _screen1551329(BuildContext _) => const Screen35Screen1551329();
Widget _screen1551379(BuildContext _) => const Screen36Screen1551379();
Widget _screen1551429(BuildContext _) => const Screen37Screen1551429();
Widget _proProfile(BuildContext _) => const Screen38ProProfile();
Widget _screen1552155(BuildContext _) => const Screen39Screen1552155();
Widget _screen1552313(BuildContext _) => const Screen40Screen1552313();
Widget _topup1(BuildContext _) => const Screen41Topup1();
Widget _topup2(BuildContext _) => const Screen42Topup2();
Widget _topup3(BuildContext _) => const Screen43Topup3();
Widget _topup4(BuildContext _) => const Screen44Topup4();
Widget _topup5(BuildContext _) => const Screen45Topup5();
Widget _ad1(BuildContext _) => const Screen46Ad1();
Widget _ad2(BuildContext _) => const Screen47Ad2();
Widget _ad3(BuildContext _) => const Screen48Ad3();
Widget _ad4(BuildContext _) => const Screen49Ad4();
Widget _ad5(BuildContext _) => const Screen50Ad5();
Widget _ad6(BuildContext _) => const Screen51Ad6();
Widget _history1(BuildContext _) => const Screen52History1();
Widget _history2(BuildContext _) => const Screen53History2();
Widget _history3(BuildContext _) => const Screen54History3();
Widget _history4(BuildContext _) => const Screen55History4();
Widget _proSignup(BuildContext _) => const Screen56ProSignup();
Widget _proCode(BuildContext _) => const Screen57ProCode();
