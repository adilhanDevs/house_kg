// GENERATED from screens/Components.bundle.js — figma node StartScreen8.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Код подтверждения · 2 — 375.0×812.0
class Screen08Code2 extends StatelessWidget {
  const Screen08Code2({super.key});

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
            left: -68.0, top: -346.0,
            child: FigBox(
              width: 1194.0,
              height: 805.0,
              bgImage: const FigBgImage('assets/figma/6c0d66ecdce7df22.jpg', x: 0.5, y: 0.0, wFactor: 1.0, hFactor: 1.06),
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
                      width: 179.0,
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
            left: 26.0, top: 499.0,
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
                      width: 320.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6.0,
                          children: [
                            FigText(
                              width: 320.0,
                              span: 
                                TextSpan(text: 'Код подтверждения', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.333, letterSpacing: -0.21, color: const Color(0xff000000)))
                              ,
                            ),
                            FigText(
                              width: 320.0,
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
                    FigBox(
                      width: 273.0,
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 16.0,
                          children: [
                            FigBox(
                              child: FigOverflow(
                                alignment: const Alignment(0.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 12.0,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: '7', style: figStyle(fontSize: 24.0, family: FigFont.display, weight: 600, height: 1.167, letterSpacing: -0.48, color: const Color(0xff071e68)))
                                      ,
                                    ),
                                    FigSvg(
                                      width: 56.0, height: 1.0,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 56.0, vbHeight: 1.0,
                                      shapes: const [FigShape(d: _p3, fill: Color(0xff071e68))],
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
                              child: FigOverflow(
                                alignment: const Alignment(0.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 12.0,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'X', style: figStyle(fontSize: 24.0, family: FigFont.display, weight: 600, height: 1.167, letterSpacing: -0.48, color: const Color(0xff1c1939)))
                                      ,
                                    ),
                                    FigSvg(
                                      width: 56.0, height: 1.0,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 56.0, vbHeight: 1.0,
                                      shapes: const [FigShape(d: _p3, fill: Color(0xff1c1939))],
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
                              child: FigOverflow(
                                alignment: const Alignment(0.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 12.0,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'X', style: figStyle(fontSize: 24.0, family: FigFont.display, weight: 600, height: 1.167, letterSpacing: -0.48, color: const Color(0xff1c1939)))
                                      ,
                                    ),
                                    FigSvg(
                                      width: 56.0, height: 1.0,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 56.0, vbHeight: 1.0,
                                      shapes: const [FigShape(d: _p3, fill: Color(0xff1c1939))],
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
                              child: FigOverflow(
                                alignment: const Alignment(0.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 12.0,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'X', style: figStyle(fontSize: 24.0, family: FigFont.display, weight: 600, height: 1.167, letterSpacing: -0.48, color: const Color(0xff1c1939)))
                                      ,
                                    ),
                                    FigSvg(
                                      width: 56.0, height: 1.0,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 56.0, vbHeight: 1.0,
                                      shapes: const [FigShape(d: _p3, fill: Color(0xff1c1939))],
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
            )
          ),
          Positioned(
            left: 130.0, top: 732.0,
            child: FigText(
              noWrap: true,
              width: 116.0,
              height: 20.0,
              span: 
                TextSpan(text: 'Вернуться назад', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xffea812e)))
              ,
            )
          ),
        ],
      )
      ,
    );
  }
}

const String _p3 =
    'M 0.384 -0.5 L -0.616 -0.5 L -0.616 1.5 L 0.384 1.5 L 0.384 0.5 L 0.384 -0.5 Z M 55.616 1.5 L 56.616 1.5 L 56.616 -0.5 L 55.616 -0.5 L 55.616 0.5 L 55.616 1.5 Z M 0.384 0.5 L 0.384 1.5 L 55.616 1.5 L 55.616 0.5 L 55.616 -0.5 L 0.384 -0.5 L 0.384 0.5 Z';
