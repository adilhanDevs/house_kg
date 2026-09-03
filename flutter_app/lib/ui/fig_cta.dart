// Кнопка, которую макет рисует поверх списка, — «Связаться с собственником».
//
// В кадре она стоит на своей координате: при другой высоте окна оказывается
// посреди карточек, а при прокрутке уезжает вместе с ними. Здесь она снята с
// кадра и живёт над нижним меню — на том же расстоянии, что и в макете.
import 'package:flutter/material.dart';

import '../app/stage.dart';
import '../fig/fig.dart';

/// Сколько остаётся между кнопкой и меню — как в макете.
const double kCtaGap = 20.0;

class FigCta extends StatelessWidget {
  const FigCta({
    super.key,
    required this.label,
    this.onTap,
    this.bottomGap = kCtaGap,
  });

  final String label;
  final VoidCallback? onTap;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Кнопка нарисована в координатах макета и тянется вместе с кадром.
        final scale = constraints.maxWidth / kDesignWidth;
        return MediaQuery(
          // размер шрифта системы порвал бы вёрстку коробки фиксированной высоты
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomGap * scale),
            // heightFactor, а не обычный Center: в слоте плавающей кнопки
            // ограничения свободные, и Center растягивался на всю высоту
            // экрана. Кнопка при этом уезжала в вертикальный центр этой
            // коробки — то есть на середину профиля, поверх описания.
            child: Align(
              alignment: Alignment.center,
              heightFactor: 1.0,
              child: Semantics(
                button: true,
                label: label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: FigColors.accent,
                        borderRadius: BorderRadius.circular(8.0 * scale),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15.0 * scale,
                          vertical: 8.0 * scale,
                        ),
                        child: FigText(
                          noWrap: true,
                          span: TextSpan(
                            text: label,
                            style: figStyle(
                              fontSize: 13.0 * scale,
                              family: FigFont.display,
                              weight: 500,
                              height: 1.077,
                              letterSpacing: 0.065 * scale,
                              color: const Color(0xffffffff),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
