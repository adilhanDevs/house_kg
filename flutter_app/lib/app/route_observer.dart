// Общий наблюдатель за маршрутами.
//
// Нужен страницам, которые обязаны реагировать на то, что поверх них открыли
// другой экран: `deactivate()` в этом случае не вызывается — виджет остаётся
// в дереве, — поэтому видео в рилсах продолжало играть под открытой карточкой
// объявления. С `RouteAware` страница получает `didPushNext` / `didPopNext`.
import 'package:flutter/widgets.dart';

final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
