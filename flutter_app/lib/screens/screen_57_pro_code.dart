// GENERATED from screens/Components.bundle.js — figma node PhotoVerify2.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Код · исполнитель — 375.0×812.0
class Screen57ProCode extends StatelessWidget {
  const Screen57ProCode({super.key});

  static const double designWidth = 375.0;
  static const double designHeight = 812.0;

  @override
  Widget build(BuildContext context) {
    return FigBox(
      width: 375.0,
      height: 812.0,
      color: const Color(0xffffffff),
      radius: 8.0,
      clip: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0.0, top: 0.0,
            child: Transform(
              transform: Matrix4(0.866, 0.5, 0.0, 0.0, -0.5, 0.866, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 79.0, 412.0, 0.0, 1.0),
              child: FigBox(
                width: 522.965,
                height: 460.87,
                bgImage: const FigBgImage('assets/figma/0d0941963f5141a8.png', x: 0.138, y: 1.0, wFactor: 1.32, hFactor: 1.059),
              )
              ,
            )
          ),
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
                      width: 143.0,
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
            left: 23.0, top: 87.0,
            child: FigBox(
              width: 273.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 13.0,
                  children: [
                    FigBox(
                      width: 330.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6.0,
                          children: [
                            FigText(
                              width: 330.0,
                              span: 
                                TextSpan(text: 'Код подтверждения', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.333, letterSpacing: -0.21, color: const Color(0xff000000)))
                              ,
                            ),
                            FigText(
                              width: 330.0,
                              opacity: 0.8,
                              span: 
                                TextSpan(style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 500, height: 1.294, color: const Color(0xff7d7d7d)), children: [
                                  TextSpan(text: 'Напишите 4х значный код,'),
                                  TextSpan(text: '\n'),
                                  TextSpan(text: 'который был отправлен'),
                                  TextSpan(text: '\n'),
                                  TextSpan(text: 'на номер '),
                                  TextSpan(text: '+996 997 919 170', style: figStyle(fontSize: 17.0, color: const Color(0xffea812e))),
                                ])
                              ,
                            ),
                          ],
                        )
                        ,
                      )
                      ,
                    ),
                    const SizedBox.shrink(),
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

