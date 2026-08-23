// GENERATED from screens/Components.bundle.js — figma node Frame48096303.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Пополнение · 4 — 375.0×812.0
class Screen44Topup4 extends StatelessWidget {
  const Screen44Topup4({super.key});

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
            left: 24.0, top: 629.0,
            child: FigBox(
              width: 325.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8.0,
                  children: [
                    FigText(
                      width: 325.0,
                      span: 
                        TextSpan(text: 'Ваш бюджет для пополнения', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 325.0,
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 8.0,
                          children: [
                            FigBox(
                              width: 140.0,
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
                                      width: 110.0,
                                      height: 14.0,
                                      span: 
                                        TextSpan(text: 'Введите значение', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                      ,
                                    )
                                  ),
                                ],
                              )
                              ,
                            ),
                            FigBox(
                              width: 55.0,
                              height: 30.0,
                              color: const Color(0xffea812e),
                              radius: 8.0,
                              opacity: 0.6,
                              blur: 2.0,
                              padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                              insets: const [FigInset(Color(0xffec8d42), 1.0)],
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: FigText(
                                      noWrap: true,
                                      width: 25.0,
                                      height: 14.0,
                                      span: 
                                        TextSpan(text: 'KGS', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0fffefe)))
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
                    ),
                  ],
                )
                ,
              )
              ,
            )
          ),
          Positioned(
            left: 24.0, top: 159.0,
            child: FigText(
              noWrap: true,
              width: 150.0,
              height: 57.0,
              span: 
                TextSpan(text: '12 000 ', style: figStyle(fontSize: 48.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.48, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 24.0, top: 222.0,
            child: FigText(
              noWrap: true,
              width: 78.0,
              height: 32.0,
              span: 
                TextSpan(text: '+1200 ', style: figStyle(fontSize: 27.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.27, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 230.0, top: 227.0,
            child: FigBox(
              width: 27.0,
              height: 19.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 179.0, top: 159.0,
            child: FigText(
              noWrap: true,
              width: 87.0,
              height: 57.0,
              span: 
                TextSpan(text: 'сом', style: figStyle(fontSize: 48.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.48, color: const Color(0xff7d7d7d)))
              ,
            )
          ),
          Positioned(
            left: 106.0, top: 220.0,
            child: FigText(
              noWrap: true,
              width: 120.0,
              height: 32.0,
              span: 
                TextSpan(text: 'кирпичей', style: figStyle(fontSize: 27.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.27, color: const Color(0xff7d7d7d)))
              ,
            )
          ),
          Positioned(
            left: 0.0, top: 0.0,
            child: FigBox(
              width: 375.0,
              height: 796.0,
              color: const Color(0x70000000),
            )
          ),
          Positioned(
            left: 0.0, top: 149.0,
            child: FigBox(
              width: 375.0,
              height: 658.0,
              color: const Color(0xffececec),
              corners: const [32.0, 32.0, 0.0, 0.0],
            )
          ),
          Positioned(
            left: 14.0, top: 164.0,
            child: FigBox(
              color: const Color(0x00ffffff),
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8.0,
                  children: [
                    FigBox(
                      width: 345.0,
                      height: 40.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FigBox(
                              height: 24.0,
                              child: FigOverflow(
                                freeWidth: true,
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 8.0,
                                  children: [
                                    FigBox(
                                      width: 30.875,
                                      height: 24.0,
                                      clip: true,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 0.0, top: 0.0,
                                            child: FigSvg(
                                              width: 30.875, height: 22.292,
                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 30.875, vbHeight: 22.292,
                                              shapes: const [FigShape(d: _p3, fill: Color(0xd9000000))],
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 16.0,
                                          children: [
                                            FigText(
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: 'Пополнение счета', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
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
                              width: 12.0,
                              height: 12.0,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: Opacity(
                                      opacity: 0.0,
                                      child: FigSvg(
                                        width: 12.0, height: 12.0,
                                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 12.0, vbHeight: 12.0,
                                        shapes: const [FigShape(d: _p4, fill: Color(0xff99a2ad))],
                                      ),
                                    )
                                  ),
                                  Positioned(
                                    left: 0.0, top: 0.018,
                                    child: FigSvg(
                                      width: 11.8, height: 11.982,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 11.8, vbHeight: 11.982,
                                      shapes: const [FigShape(d: _p5, fill: Color(0xff99a2ad))],
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
                    ),
                  ],
                )
                ,
              )
              ,
            )
          ),
          Positioned(
            left: 42.0, top: 207.0,
            child: FigBox(
              width: 292.0,
              height: 564.0,
              bgImage: const FigBgImage('assets/figma/feb14475422c5a62.png', x: 0.0, y: 0.5, wFactor: 1.021, hFactor: 1.0),
            )
          ),
        ],
      )
      ,
    );
  }
}

const String _p3 =
    'M 5.742 17.842 L 8.982 17.842 C 9.762 17.842 10.285 17.319 10.285 16.581 L 10.285 14.12 C 10.285 13.381 9.762 12.858 8.982 12.858 L 5.742 12.858 C 4.963 12.858 4.44 13.381 4.44 14.12 L 4.44 16.581 C 4.44 17.319 4.963 17.842 5.742 17.842 Z M 0.943 7.978 L 29.962 7.978 L 29.962 5.004 L 0.943 5.004 L 0.943 7.978 Z M 3.989 22.292 L 26.875 22.292 C 29.531 22.292 30.875 20.949 30.875 18.334 L 30.875 3.958 C 30.875 1.343 29.531 0 26.875 0 L 3.989 0 C 1.343 0 0 1.333 0 3.958 L 0 18.334 C 0 20.959 1.343 22.292 3.989 22.292 Z M 4.03 20.467 C 2.594 20.467 1.815 19.708 1.815 18.242 L 1.815 4.05 C 1.815 2.574 2.594 1.815 4.03 1.815 L 26.845 1.815 C 28.25 1.815 29.049 2.574 29.049 4.05 L 29.049 18.242 C 29.049 19.708 28.25 20.467 26.845 20.467 L 4.03 20.467 Z';
const String _p4 =
    'M 12 0 L 0 0 L 0 12 L 12 12 L 12 0 Z';
const String _p5 =
    'M 0.164 11.816 C 0.392 12.035 0.753 12.035 0.975 11.816 L 5.898 6.809 L 10.827 11.816 C 11.043 12.035 11.416 12.041 11.632 11.816 C 11.853 11.584 11.853 11.217 11.632 10.998 L 6.709 5.991 L 11.632 0.984 C 11.853 0.765 11.859 0.392 11.632 0.167 C 11.41 -0.053 11.043 -0.053 10.827 0.167 L 5.898 5.173 L 0.975 0.167 C 0.753 -0.053 0.386 -0.059 0.164 0.167 C -0.052 0.398 -0.052 0.765 0.164 0.984 L 5.093 5.991 L 0.164 10.998 C -0.052 11.217 -0.058 11.59 0.164 11.816 Z';
