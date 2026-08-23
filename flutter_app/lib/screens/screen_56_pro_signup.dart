// GENERATED from screens/Components.bundle.js — figma node PhotoVerify1.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Регистрация исполнителя — 375.0×812.0
class Screen56ProSignup extends StatelessWidget {
  const Screen56ProSignup({super.key});

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
            left: -78.0, top: 431.0,
            child: FigBox(
              width: 867.0,
              height: 437.0,
              bgImage: const FigBgImage('assets/figma/aab1efb98f0c6da0.png', x: 0.5, y: 0.223, wFactor: 1.001, hFactor: 1.418),
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
                      width: 57.0,
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
            left: 25.0, top: 87.0,
            child: FigBox(
              width: 335.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 11.0,
                  children: [
                    FigBox(
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
                                TextSpan(text: 'Добро пожаловать!', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
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
                    ),
                    FigBox(
                      width: 324.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12.0,
                          children: [
                            FigBox(
                              width: 324.0,
                              height: 36.0,
                              color: const Color(0x1f787880),
                              radius: 10.0,
                              padding: const EdgeInsets.fromLTRB(8.0, 7.0, 8.0, 7.0),
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigBox(
                                      width: 25.0,
                                      height: 22.0,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 0.0, top: 3.0,
                                            child: FigSvg(
                                              width: 16.0, height: 16.0,
                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 16.0, vbHeight: 16.0,
                                              shapes: const [FigShape(cx: 6.6, cy: 6.6, r: 5.1, stroke: Color(0x993c3c43), strokeWidth: 1.7), FigShape(d: _p3, stroke: Color(0x993c3c43), strokeWidth: 1.7, roundCap: true)],
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    Expanded(
                                      child: FigText(
                                        noWrap: true,
                                        height: 22.0,
                                        span: 
                                          TextSpan(text: 'Номер телефона (с WhatsApp)', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 400, height: 1.467, letterSpacing: -0.43, color: const Color(0x993c3c43)))
                                        ,
                                      )
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
                              width: 324.0,
                              height: 36.0,
                              color: const Color(0x1f787880),
                              radius: 10.0,
                              padding: const EdgeInsets.fromLTRB(8.0, 7.0, 8.0, 7.0),
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigBox(
                                      width: 25.0,
                                      height: 22.0,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 0.0, top: 3.0,
                                            child: FigSvg(
                                              width: 16.0, height: 16.0,
                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 16.0, vbHeight: 16.0,
                                              shapes: const [FigShape(cx: 6.6, cy: 6.6, r: 5.1, stroke: Color(0x993c3c43), strokeWidth: 1.7), FigShape(d: _p3, stroke: Color(0x993c3c43), strokeWidth: 1.7, roundCap: true)],
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    Expanded(
                                      child: FigText(
                                        noWrap: true,
                                        height: 22.0,
                                        span: 
                                          TextSpan(text: 'Имя', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 400, height: 1.467, letterSpacing: -0.43, color: const Color(0x993c3c43)))
                                        ,
                                      )
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
                              width: 324.0,
                              height: 36.0,
                              color: const Color(0x1f787880),
                              radius: 10.0,
                              padding: const EdgeInsets.fromLTRB(8.0, 7.0, 8.0, 7.0),
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigBox(
                                      width: 25.0,
                                      height: 22.0,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 0.0, top: 3.0,
                                            child: FigSvg(
                                              width: 16.0, height: 16.0,
                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 16.0, vbHeight: 16.0,
                                              shapes: const [FigShape(cx: 6.6, cy: 6.6, r: 5.1, stroke: Color(0x993c3c43), strokeWidth: 1.7), FigShape(d: _p3, stroke: Color(0x993c3c43), strokeWidth: 1.7, roundCap: true)],
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    Expanded(
                                      child: FigText(
                                        noWrap: true,
                                        height: 22.0,
                                        span: 
                                          TextSpan(text: 'Пароль', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 400, height: 1.467, letterSpacing: -0.43, color: const Color(0x993c3c43)))
                                        ,
                                      )
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
                              width: 324.0,
                              height: 36.0,
                              color: const Color(0x1f787880),
                              radius: 10.0,
                              padding: const EdgeInsets.fromLTRB(8.0, 7.0, 8.0, 7.0),
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigBox(
                                      width: 25.0,
                                      height: 22.0,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 0.0, top: 3.0,
                                            child: FigSvg(
                                              width: 16.0, height: 16.0,
                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 16.0, vbHeight: 16.0,
                                              shapes: const [FigShape(cx: 6.6, cy: 6.6, r: 5.1, stroke: Color(0x993c3c43), strokeWidth: 1.7), FigShape(d: _p3, stroke: Color(0x993c3c43), strokeWidth: 1.7, roundCap: true)],
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    Expanded(
                                      child: FigText(
                                        noWrap: true,
                                        height: 22.0,
                                        span: 
                                          TextSpan(text: 'ИИН', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 400, height: 1.467, letterSpacing: -0.43, color: const Color(0x993c3c43)))
                                        ,
                                      )
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
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
        ],
      )
      ,
    );
  }
}

const String _p3 =
    'M 10.4 10.4 L 14.4 14.4';
