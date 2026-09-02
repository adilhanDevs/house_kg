// Карта приложения: какой кадр макета показывает какой экран и куда ведут
// переходы прототипа.
//
// Кадры, которые в макете различаются одним состоянием (вкладка истории,
// «пополнить/списать», шаги «добавить фото» в двух флоу), схлопнуты в один
// экран: страница сама выбирает нужный кадр.
import 'package:flutter/widgets.dart';

import '../prototype.dart';

abstract final class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';
  static const register = '/register';
  static const code = '/code';

  // вкладки
  static const home = '/home';
  static const catalog = '/catalog';
  static const notifications = '/notifications';

  /// «История просмотров» — третья вкладка меню.
  static const viewHistory = '/history/views';
  static const favourites = '/favourites';
  static const profile = '/profile';
  static const account = '/account';
  static const support = '/support';

  static const collection = '/collection';
  static const category = '/category';
  static const filter = '/filter';
  static const savedFilters = '/filters/saved';
  static const listing = '/listing';
  static const listingPhotos = '/listing/photos';
  static const listingVideo = '/listing/video';
  static const listingPhoto = '/listing/photo';
  static const agentListings = '/agent/listings';
  static const agent = '/agent';
  static const agentProfile = '/agent/profile';
  static const flow = '/flow';

  // кошелёк
  static const topup = '/wallet/topup';
  static const history = '/wallet/history';

  // исполнитель
  static const pro = '/profile';
  static const proTasks = '/pro/tasks';
  static const proSignup = '/pro/signup';
  static const proCode = '/pro/code';
  static const proPhoto1 = '/pro/photo/1';
  static const proPhoto2 = '/pro/photo/2';

  // объявление
  static const ad = '/ad';
  static const adPreview = '/ad/preview';
  static const adEdit = '/ad/edit';
  static const adForm = '/ad/form';
  static const adPhotos = '/ad/photos';
  static const adVideo = '/ad/video';
  static const adPromo = '/ad/promo';
  static const subscriptions = '/subscriptions';
  static const tariffs = '/subscriptions/tariffs';
}

/// Пять вкладок нижнего меню — `TAB_TARGETS` прототипа.
const List<String> kTabRoutes = [
  Routes.home,
  Routes.catalog,
  Routes.viewHistory,
  Routes.favourites,
  Routes.profile,
];

/// Куда ведёт кадр макета. Дубли указывают на один и тот же экран.
const Map<int, String> kFrameRoute = {
  0: Routes.splash,
  1: Routes.onboarding, 2: Routes.onboarding, 3: Routes.onboarding,
  4: Routes.welcome,
  // Кадр 07 — не дубль приветствия, а форма регистрации: имя и пароль вместо
  // кнопки «Войти». Пока он вёл на welcome, регистрироваться было негде.
  6: Routes.register,
  5: Routes.code, 7: Routes.code,
  8: Routes.home,
  9: Routes.collection,
  10: Routes.catalog,
  11: Routes.filter,
  12: Routes.agentListings,
  13: Routes.agent,
  14: Routes.profile,
  15: Routes.favourites,
  16: Routes.notifications,
  17: Routes.savedFilters,
  18: Routes.listing,
  19: Routes.listingPhotos,
  20: Routes.listingPhoto,
  21: Routes.flow,
  22: Routes.agentProfile,
  23: Routes.proPhoto1,
  24: Routes.proPhoto2,
  // вторая копия шагов объявления в макете — те же экраны
  25: Routes.adForm, 26: Routes.ad, 27: Routes.adPhotos, 28: Routes.adVideo, 29: Routes.adPromo,
  30: Routes.adPromo, 31: Routes.adPromo,
  32: Routes.subscriptions,
  33: Routes.tariffs,
  34: Routes.adPhotos, 35: Routes.adVideo, 36: Routes.adForm,
  37: Routes.pro,
  38: Routes.proTasks,
  39: Routes.adPreview,
  40: Routes.topup, 41: Routes.history, 42: Routes.history, 43: Routes.history, 44: Routes.history,
  45: Routes.ad,
  46: Routes.adForm, 47: Routes.adPhotos, 48: Routes.adVideo,
  49: Routes.adPromo, 50: Routes.adPromo,
  51: Routes.history, 52: Routes.history, 53: Routes.history, 54: Routes.history,
  55: Routes.proSignup,
  56: Routes.proCode,
};

/// Кадр по номеру из макета («11» — «Каталог»).
FigScreen frame(String number) =>
    figScreens.firstWhere((s) => s.number == number, orElse: () => figScreens.first);

/// Индекс кадра в [figScreens].
int frameIndex(String number) =>
    figScreens.indexWhere((s) => s.number == number);

/// Экран, на который ведёт зона прототипа, или null, если такого экрана в
/// приложении нет (зона осталась в макете, но никуда не ведёт).
String? routeForTarget(int target) => kFrameRoute[target];

/// Первый кадр макета, который показывает этот маршрут, — им подменяются
/// страницы, до которых ещё не дошли руки.
String? frameNumberForRoute(String route) {
  for (final entry in kFrameRoute.entries) {
    if (entry.value == route && entry.key >= 0 && entry.key < figScreens.length) {
      return figScreens[entry.key].number;
    }
  }
  return null;
}

/// Аргумент экрана объявления: правка своего или создание нового.
enum AdMode { edit, create }

/// Аргументы, которые страницы принимают через [Navigator].
@immutable
class ListingArgs {
  const ListingArgs(this.id, {this.initialVideoIndex = 0});
  final String id;
  final int initialVideoIndex;
}
