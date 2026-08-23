// GENERATED from screens/Components.bundle.js — figma node Frame48096303.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Пополнение · 1 — 375.0×812.0
class Screen41Topup1 extends StatelessWidget {
  const Screen41Topup1({super.key});

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
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 24.0, top: 55.0,
            child: FigText(
              noWrap: true,
              width: 222.0,
              height: 25.0,
              span: 
                TextSpan(text: 'Пополнение кошелька', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 24.0, top: 80.0,
            child: FigText(
              width: 335.0,
              height: 60.0,
              span: 
                TextSpan(text: 'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
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
          Positioned(
            left: 119.0, top: 438.0,
            child: FigText(
              noWrap: true,
              width: 138.0,
              height: 20.0,
              span: 
                TextSpan(text: '1 сом = 1 кирпичу', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 46.0, top: 326.0,
            child: FigBox(
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 16.0,
                  children: [
                    FigBox(
                      width: 103.0,
                      height: 103.0,
                      bgImage: const FigBgImage('assets/figma/c9723efccfaf2ac1.png'),
                    ),
                    FigText(
                      noWrap: true,
                      span: 
                        TextSpan(text: '=', style: figStyle(fontSize: 57.182, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 111.0,
                      height: 77.0,
                      bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
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

