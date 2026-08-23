// GENERATED from screens/Components.bundle.js — figma node Frame48096304.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// История трат · 3 — 375.0×812.0
class Screen54History3 extends StatelessWidget {
  const Screen54History3({super.key});

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
              width: 206.0,
              height: 25.0,
              span: 
                TextSpan(text: 'История пополнения', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 24.0, top: 80.0,
            child: FigText(
              width: 335.0,
              height: 40.0,
              span: 
                TextSpan(text: 'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
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
            left: 24.0, top: 132.0,
            child: FigBox(
              width: 327.0,
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8.0,
                  children: [
                    FigBox(
                      width: 90.0,
                      height: 30.0,
                      color: const Color(0x33ea812e),
                      radius: 8.0,
                      blur: 2.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigText(
                              noWrap: true,
                              width: 60.0,
                              height: 14.0,
                              span: 
                                TextSpan(text: 'Списание', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                              ,
                            )
                          ),
                        ],
                      )
                      ,
                    ),
                    FigBox(
                      width: 114.0,
                      height: 30.0,
                      radius: 8.0,
                      opacity: 0.6,
                      blur: 2.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      insets: const [FigInset(Color(0x807d7d7d), 1.0)],
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigText(
                              noWrap: true,
                              width: 84.0,
                              height: 14.0,
                              span: 
                                TextSpan(text: 'Все операции', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                              ,
                            )
                          ),
                        ],
                      )
                      ,
                    ),
                    FigBox(
                      width: 105.0,
                      height: 30.0,
                      radius: 8.0,
                      opacity: 0.6,
                      blur: 2.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      insets: const [FigInset(Color(0x807d7d7d), 1.0)],
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigText(
                              noWrap: true,
                              width: 75.0,
                              height: 14.0,
                              span: 
                                TextSpan(text: 'Пополнение', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                              ,
                            )
                          ),
                        ],
                      )
                      ,
                    ),
                    FigBox(
                      width: 90.0,
                      height: 30.0,
                      radius: 8.0,
                      opacity: 0.6,
                      blur: 2.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      insets: const [FigInset(Color(0x807d7d7d), 1.0)],
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigText(
                              noWrap: true,
                              width: 60.0,
                              height: 14.0,
                              span: 
                                TextSpan(text: 'Бонусы', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                              ,
                            )
                          ),
                        ],
                      )
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
            left: 24.0, top: 184.0,
            child: FigBox(
              width: 325.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 16.0,
                  children: [
                    FigBox(
                      width: 159.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8.0,
                          children: [
                            FigText(
                              width: 159.0,
                              span: 
                                TextSpan(text: '21 августа', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
                              ,
                            ),
                            FigBox(
                              width: 159.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 4.0,
                                  children: [
                                    FigBox(
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(-1.0, -1.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          spacing: 7.0,
                                          children: [
                                            FigBox(
                                              width: 30.0,
                                              height: 21.0,
                                              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
                                            ),
                                            FigText(
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: '-500 кирпичей', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xffff0404)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                          ],
                        )
                        ,
                      )
                      ,
                    ),
                    FigBox(
                      width: 325.0,
                      height: 1.0,
                      color: const Color(0xffd7d8d9),
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

