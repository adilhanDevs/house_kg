// GENERATED from screens/Components.bundle.js — figma node StartScreen32.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Экран 155:980 — 375.0×795.0
class Screen33Screen155980 extends StatelessWidget {
  const Screen33Screen155980({super.key});

  static const double designWidth = 375.0;
  static const double designHeight = 795.0;

  @override
  Widget build(BuildContext context) {
    return FigBox(
      width: 375.0,
      height: 795.0,
      color: const Color(0xffffffff),
      radius: 8.0,
      clip: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 24.0, top: 48.0,
            child: FigBox(
              width: 327.0,
              height: 8.0,
              color: const Color(0xffe8e9f1),
              radius: 4.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -1.0, top: 0.0,
                    child: FigBox(
                      width: 268.0,
                      height: 8.0,
                      color: const Color(0xffea812e),
                      radius: 8.0,
                    )
                  ),
                ],
              )
              ,
            )
          ),
          Positioned(
            left: 24.0, top: 87.0,
            child: FigBox(
              width: 335.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6.0,
                  children: [
                    FigText(
                      width: 335.0,
                      span: 
                        TextSpan(text: 'Подписки', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
                      ,
                    ),
                    FigText(
                      width: 335.0,
                      span: 
                        TextSpan(text: 'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                      ,
                    ),
                  ],
                )
                ,
              )
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 711.0,
            child: FigBox(
              width: 324.0,
              height: 36.0,
              color: const Color(0xffea812e),
              radius: 10.0,
              padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 15.0),
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(0.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 10.0,
                  children: [
                    FigText(
                      noWrap: true,
                      span: 
                        TextSpan(text: 'Далее', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.294, color: const Color(0xffffffff)))
                      ,
                    ),
                  ],
                )
                ,
              )
              ,
            )
          ),
        ],
      )
      ,
    );
  }
}

