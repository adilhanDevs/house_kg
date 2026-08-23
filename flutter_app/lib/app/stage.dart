// Как страница приложения ложится на кадр макета.
//
// Кадры в lib/screens нарисованы в системе координат макета — 375 pt в ширину.
// Сцена масштабирует их под ширину устройства, даёт прокрутку, если кадр выше
// окна, и позволяет положить сверху свои элементы в тех же координатах: зоны
// нажатия, кнопку «назад», подставленные данные.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../prototype.dart';
import 'routes.dart';

/// Ширина, в которой нарисован макет.
const double kDesignWidth = 375.0;

/// Высота, в которой нарисовано большинство кадров.
const double kDesignHeight = 812.0;

/// Пустая полоса вверху кадра, оставленная в макете под статус-бар.
const double kDesignTopBand = 48.0;

/// Сколько остаётся между системными индикаторами и содержимым кадра.
/// Полоса макета шире, поэтому лишнее сцена срезает.
const double kTopGap = 15.0;

/// Видимая высота нижнего меню. В макете оно 84 pt, но нижние 28 — пустая
/// полоса под жест; её сцена не показывает, иначе меню висит над навигацией
/// системы с зазором.
const double kTabBarHeight = 56.0;

/// На сколько сцене разрешено растянуть кадр по высоте, чтобы низ экрана
/// сошёлся с макетом в окне другой пропорции. Больше — уже заметно.
const double kMaxStretch = 1.12;

/// Та самая пустая полоса макета под меню. Её место занимает навигация
/// системы; там, где системной полосы нет — в браузере и на десктопе, — сцена
/// держит её сама, иначе низ экрана съезжает относительно макета на 28 pt.
const double kTabBarStrip = 28.0;

/// Цвета макета, которые нужны и вне сгенерированных экранов.
abstract final class FigColors {
  static const accent = Color(0xFFEA812E);
  static const ink = Color(0xFF000000);
  static const label = Color(0xFF484848);
  static const muted = Color(0xFF7D7D7D);
  static const hairline = Color(0xFFECECEC);
  static const page = Color(0xFFFFFFFF);
  static const shell = Color(0xFF1C1B19);
}

/// Полоса под системной навигацией Android — то, на что нельзя класть
/// содержимое: три кнопки или строка жеста.
///
/// Считаем по двум мерам сразу. `padding` система обнуляет, когда полосу
/// перекрывает что-то ещё, `viewPadding` держит её всегда — берём большее, и
/// отступ не пропадает ни в одном из случаев. Клавиатура ложится поверх
/// навигации: пока она открыта, полосу держать не нужно, иначе между
/// содержимым и клавиатурой встанет пустой провал.
double bottomSafeInset(BuildContext context) {
  final media = MediaQuery.of(context);
  return math.max(
    media.padding.bottom,
    math.max(0.0, media.viewPadding.bottom - media.viewInsets.bottom),
  );
}

/// Элемент, положенный поверх кадра в координатах макета.
class FigOverlayBox extends StatelessWidget {
  const FigOverlayBox({
    super.key,
    required this.left,
    required this.top,
    this.width,
    this.height,
    required this.child,
  });

  final double left;
  final double top;
  final double? width;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Positioned(left: left, top: top, width: width, height: height, child: child);
}

/// Невидимая зона нажатия в координатах макета — то, чем в макете является
/// нарисованная кнопка.
class FigZone extends StatelessWidget {
  const FigZone(
    this.left,
    this.top,
    this.width,
    this.height, {
    super.key,
    required this.onTap,
    this.label,
    this.debug = false,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final VoidCallback onTap;

  /// Подпись для отладки и тестов.
  final String? label;

  /// Подсветить зону — включается флагом `--dart-define=zones=true`.
  final bool debug;

  static const bool showZones = bool.fromEnvironment('zones');

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: showZones || debug ? const Color(0x33EA812E) : null,
              border: showZones || debug
                  ? Border.all(color: const Color(0x99EA812E))
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Кнопка «назад». В макете она есть только на «Фильтре» и «Объекте», поэтому
/// на остальных экранах приложение рисует свою — в той же позиции и тем же
/// цветом, что и родная, чтобы не выбиваться из дизайна.
class FigBackButton extends StatelessWidget {
  const FigBackButton({
    super.key,
    this.left = 25,
    this.top = 40,
    this.onLight = true,
    this.onTap,
  });

  final double left;
  final double top;

  /// Тёмная стрелка на светлом фоне; на фото-шапках — белая с подложкой.
  final bool onLight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onLight ? FigColors.label : Colors.white;
    return Positioned(
      left: left - 8,
      top: top - 8,
      child: Semantics(
        button: true,
        label: 'Назад',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap:
              onTap ??
              () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, Routes.home);
                }
              },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Container(
                width: onLight ? null : 28,
                height: onLight ? null : 28,
                decoration: onLight
                    ? null
                    : const BoxDecoration(
                        color: Color(0x59000000),
                        shape: BoxShape.circle,
                      ),
                child: Icon(Icons.arrow_back_ios_new, size: 15, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Кадр макета как страница приложения.
class FigStage extends StatelessWidget {
  const FigStage({
    super.key,
    required this.frame,
    this.overlays = const [],
    this.bottomBar,
    this.cutBelow,
    this.bottomBarHeight = kTabBarHeight,
    this.background = FigColors.page,
    this.scrollController,
    this.onTapAnywhere,
  });

  /// Какой кадр рисовать. Берётся из [figScreens] — той же таблицы, из которой
  /// собран режим сверки с макетом.
  final FigScreen frame;

  /// Зоны и подставленные элементы — в координатах макета.
  final List<Widget> overlays;

  /// Нижнее меню приложения; рисуется поверх и не прокручивается.
  final Widget? bottomBar;

  /// Черта в координатах макета, ниже которой кадр не показываем: там место
  /// [bottomBar]. Без неё под меню остаются обрезки того, что макет рисует
  /// в его полосе, — начало следующего ряда карточек.
  final double? cutBelow;

  /// Высота [bottomBar] в координатах макета — сколько места оставить под ним
  /// в прокрутке. По умолчанию одно меню.
  final double bottomBarHeight;

  final Color background;
  final ScrollController? scrollController;

  /// Клик мимо всего остального — шаги флоу, где в макете нет кнопки.
  final VoidCallback? onTapAnywhere;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // Место под навигацию системы. Пока открыта клавиатура, навигация лежит
    // поверх неё, и держать под неё полосу — значит показать белый провал
    // между кадром и клавиатурой; поэтому вычитаем. Масштаб кадра от этого не
    // зависит (он считается по ширине), так что экран не дёргается.
    final keyboard = media.viewInsets.bottom;

    // Место под навигацию системы. Под меню его держит сама сцена: внутри всё
    // считается в координатах макета, и полоса меню там ровно та, что в кадре.
    // Где системной полосы нет — в браузере и на десктопе — берём полосу
    // макета, иначе меню поднимается на её высоту и низ экрана не сходится.
    final bottomSafe = bottomBar == null
        ? bottomSafeInset(context)
        : (kIsWeb
            ? bottomSafeInset(context)
            : math.max(
                bottomSafeInset(context),
                kTabBarStrip * media.size.width / kDesignWidth,
              ));

    // Material, а не ColoredBox: без него текст вне сгенерированных кадров
    // получает отладочный стиль Flutter — жёлтое подчёркивание.
    //
    // Сверху поле кадр держит сам — пустая полоса 0..48 под статус-бар
    // системы. Снизу своей полосы не хватает на навбар Android, поэтому
    // отступ берём у системы.
    return Material(
      color: background,
      child: MediaQuery(
        // полосу навигации сцена забирает себе целиком: тем, кто внутри —
        // включая нижнее меню, — её учитывать уже не нужно. Гасим обе меры,
        // и padding, и viewPadding: меню считает отступ по второй.
        data: media.copyWith(
          padding: media.padding.copyWith(bottom: 0),
          viewPadding: media.viewPadding.copyWith(bottom: 0),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomSafe),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Кадр нарисован в 375 pt шириной и тянется по ширине экрана —
              // без полей по бокам. Что не влезло по высоте, прокручивается.
              final designHeight = frame.height;
              // Ниже черты кадр не показываем — там стоит нижняя полоса
              // приложения. По умолчанию черта там, где место меню отмечено
              // в самом кадре.
              final line = cutBelow ?? (bottomBar == null ? null : frame.tabBarAt?.dy);
              final shownHeight = math.min(line ?? designHeight, designHeight);
              final scale = constraints.maxWidth / kDesignWidth;
              final canvasWidth = constraints.maxWidth;

              // Верх кадра сцена срезает до [kTopGap] под индикаторами. Там,
              // где индикаторов нет — в браузере и на десктопе, — резать
              // нечего: кадр держит свою полосу сам, и низ экрана сходится с
              // макетом без зазора.
              final topGap = media.viewPadding.top > 0
                  ? media.viewPadding.top + kTopGap
                  : (kIsWeb ? 12.0 * scale : kDesignTopBand * scale);

              // Сколько pt макета уходит под нож: вся полоса минус то, что должно
              // остаться видимым. Если индикаторы выше полосы, резать нечего —
              // недостающее добавляем отступом.
              final overshoot = kDesignTopBand - topGap / scale;
              final trim = math.max(0.0, overshoot);
              final extraTop = overshoot < 0 ? -overshoot * scale : 0.0;
              final canvasHeight = (shownHeight - trim) * scale;

              Widget canvas = SizedBox(
                width: kDesignWidth,
                height: designHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(child: ColoredBox(color: background)),
                    frame.builder(context),
                    ...overlays,
                  ],
                ),
              );
              if (onTapAnywhere != null) {
                canvas = Stack(
                  children: [
                    canvas,
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: onTapAnywhere,
                      ),
                    ),
                  ],
                );
              }

              // Кадр — картинка в своих координатах: размер шрифта системы
              // растянул бы текст внутри коробок фиксированной высоты и порвал
              // вёрстку. Масштаб экрана задаёт [scale], а не настройки шрифта.
              canvas = MediaQuery(
                data: media.copyWith(textScaler: TextScaler.noScaling),
                child: canvas,
              );

              if (shownHeight < designHeight) {
                canvas = ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    widthFactor: 1,
                    heightFactor: shownHeight / designHeight,
                    child: canvas,
                  ),
                );
              }
              if (trim > 0) {
                canvas = ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    widthFactor: 1,
                    heightFactor: (shownHeight - trim) / shownHeight,
                    child: canvas,
                  ),
                );
              }

              // Окно бывает чуть выше макета — тогда под кадром оставался бы
              // белый провал, а кнопка над меню разъезжалась бы с той, что
              // нарисована в кадре. Небольшой запас кадр добирает высотой:
              // растяжение до [kMaxStretch] на глаз незаметно, а низ экрана
              // сходится с макетом. Что не покрылось — остаётся под страницей.
              final reserve = bottomBar == null ? 0.0 : bottomBarHeight * scale;
              final room = constraints.maxHeight - extraTop - reserve;
              final stretched = math.min(
                canvasHeight * kMaxStretch,
                math.max(canvasHeight, room),
              );

              Widget page = SizedBox(
                width: canvasWidth,
                height: stretched,
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.topLeft,
                  child: canvas,
                ),
              );
              if (extraTop > 0) {
                page = Padding(
                  padding: EdgeInsets.only(top: extraTop),
                  child: page,
                );
              }

              // Сколько внизу осталось незанятого: кадр ниже окна — 0.
              final slack = math.max(
                0.0,
                constraints.maxHeight - extraTop - stretched - reserve,
              );

              final body = SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: scrollController,
                // Место под нижним меню. С клавиатурой меню скрыто, а лишний
                // запас читался бы как белый провал — кадр и так выше экрана,
                // прокрутки хватает, чтобы поднять поле над клавиатурой.
                padding: EdgeInsets.only(
                  bottom: bottomBar == null || keyboard > 0 ? 0 : reserve,
                ),
                child: page,
              );

              return Stack(
                children: [
                  // Клавиатура не накрывает список, а укорачивает его: только
                  // так Flutter доводит поле в фокусе до видимой части.
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: keyboard),
                      child: body,
                    ),
                  ),
                  if (bottomBar != null && keyboard == 0)
                    // Меню стоит там, где кончается кадр: обычно это низ окна,
                    // а если окно выше кадра — сразу под ним, а не отдельно
                    // внизу с провалом посередине.
                    Positioned(left: 0, right: 0, bottom: slack, child: bottomBar!),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
