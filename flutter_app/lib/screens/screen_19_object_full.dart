// GENERATED from screens/Components.bundle.js — figma node StartScreen19.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../fig/fig.dart';

/// Объект · полная — 375.0×1899.0
class Screen19ObjectFull extends StatelessWidget {
  const Screen19ObjectFull({super.key});

  static const double designWidth = 375.0;
  static const double designHeight = 1899.0;

  @override
  Widget build(BuildContext context) {
    return FigBox(
      width: 375.0,
      height: 1899.0,
      color: const Color(0xfffefefe),
      radius: 8.0,
      clip: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0.0, top: 0.0,
            child: FigBox(
              width: 375.0,
              height: 387.0,
              radius: 8.0,
              bgImage: const FigBgImage('assets/figma/92b0d143df96c511.jpg'),
              overlays: const [LinearGradient(begin: Alignment(0.018, 1.016), end: Alignment(-0.018, -1.016), colors: [Color(0x26000000), Color(0x00666666)], stops: [0.244, 0.939])],
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 290.0, top: 346.0,
                    child: FigBox(
                      color: const Color(0x6699a2ad),
                      radius: 34.0,
                      blur: 20.0,
                      padding: const EdgeInsets.fromLTRB(12.0, 6.0, 12.0, 6.0),
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(0.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 6.0,
                          children: [
                            FigSvg(
                              width: 8.0, height: 8.0,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 8.0, vbHeight: 8.0,
                              shapes: const [FigShape(d: _p0, fill: Color(0xffc4c9cf))],
                            ),
                            FigSvg(
                              width: 8.0, height: 8.0,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 8.0, vbHeight: 8.0,
                              shapes: const [FigShape(d: _p0, fill: Color(0xffc4c9cf))],
                            ),
                            FigSvg(
                              width: 8.0, height: 8.0,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 8.0, vbHeight: 8.0,
                              shapes: const [FigShape(d: _p0, fill: Color(0xffea812e))],
                            ),
                          ],
                        )
                        ,
                      )
                      ,
                    )
                  ),
                  Positioned(
                    left: 321.0, top: 43.0,
                    child: FigBox(
                      width: 26.0,
                      height: 26.0,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigBox(
                              width: 26.0,
                              height: 26.0,
                              color: const Color(0xd9ffffff),
                              radius: 13.0,
                            )
                          ),
                          Positioned(
                            left: 6.118, top: 6.882,
                            child: FigBox(
                              width: 13.765,
                              height: 12.235,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: Opacity(
                                      opacity: 0.0,
                                      child: FigSvg(
                                        width: 13.765, height: 12.235,
                                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 13.765, vbHeight: 12.235,
                                        shapes: const [FigShape(d: _p1, fill: Color(0xccea812e))],
                                      ),
                                    )
                                  ),
                                  Positioned(
                                    left: 0.0, top: 0.393,
                                    child: FigSvg(
                                      width: 13.513, height: 11.842,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 13.513, vbHeight: 11.842,
                                      shapes: const [FigShape(d: _p2, fill: Color(0xccea812e))],
                                    )
                                  ),
                                ],
                              )
                              ,
                            )
                          ),
                        ],
                      )
                      ,
                    )
                  ),
                ],
              )
              ,
            )
          ),
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 25.0, top: 445.0,
            child: FigBox(
              width: 335.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12.0,
                  children: [
                    FigBox(
                      width: 335.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FigText(
                              noWrap: true,
                              span: 
                                TextSpan(text: '102 000\$', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.21, color: const Color(0xff000000)))
                              ,
                            ),
                            FigBox(
                              width: 154.0,
                              child: FigOverflow(
                                freeWidth: true,
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 7.0,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: '3-комн.', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff555555)))
                                      ,
                                    ),
                                    FigBox(
                                      width: 4.0,
                                      height: 4.0,
                                      color: const Color(0xffd9d9d9),
                                      radius: 2.0,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff555555)), children: [
                                          TextSpan(text: '92м', style: figStyle(fontSize: 13.0, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 9.36, color: const Color(0xff555555)), 13.0),
                                        ])
                                      ,
                                    ),
                                    FigBox(
                                      width: 4.0,
                                      height: 4.0,
                                      color: const Color(0xffd9d9d9),
                                      radius: 2.0,
                                    ),
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: '8 этаж', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff555555)))
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
            left: 25.0, top: 559.0,
            child: FigSvg(
              width: 325.0, height: 1.0,
              vbLeft: 0.0, vbTop: -0.5, vbWidth: 325.0, vbHeight: 1.0,
              shapes: const [FigShape(d: _p6, fill: Color(0x807d7d7d))],
            )
          ),
          Positioned(
            left: 25.0, top: 578.0,
            child: FigBox(
              width: 406.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12.0,
                  children: [
                    FigBox(
                      width: 325.0,
                      height: 214.0,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigBox(
                              width: 325.0,
                              height: 214.0,
                              radius: 15.0,
                              bgImage: const FigBgImage('assets/figma/f36bc748a320b1d4.jpg'),
                              overlays: const [LinearGradient(begin: Alignment(0.0, -1.0), end: Alignment(0.0, 1.0), colors: [Color(0x0d000000), Color(0x0d000000)], stops: [0.0, 1.0])],
                            )
                          ),
                          Positioned(
                            left: 15.0, top: 163.0,
                            child: FigText(
                              width: 300.0,
                              height: 36.0,
                              span: 
                                TextSpan(text: 'Бишкек, Октябрьский район, \nул.Бакаева 178/4 ', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
                              ,
                            )
                          ),
                          Positioned(
                            left: 160.0, top: 110.0,
                            child: FigBox(
                              width: 14.0,
                              height: 14.0,
                              radius: 7.0,
                              insets: const [FigInset(Color(0xffea812e), 2.0)],
                            )
                          ),
                        ],
                      )
                      ,
                    ),
                    FigBox(
                      width: 406.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 6.0,
                          children: [
                            FigText(
                              width: 406.0,
                              span: 
                                TextSpan(text: 'Ключевые места', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                              ,
                            ),
                            FigBox(
                              width: 325.0,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 12.0,
                                  children: [
                                    FigBox(
                                      width: 89.0,
                                      color: const Color(0x33ea812e),
                                      radius: 8.0,
                                      blur: 2.0,
                                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(0.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 4.0,
                                          children: [
                                            FigText(
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: 'Школа 56', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      color: const Color(0x33ea812e),
                                      radius: 8.0,
                                      blur: 2.0,
                                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(0.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 4.0,
                                          children: [
                                            FigText(
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: 'Магистраль-Бакаева', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      color: const Color(0x33ea812e),
                                      radius: 8.0,
                                      blur: 2.0,
                                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(0.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 4.0,
                                          children: [
                                            FigText(
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: 'Клиника Эскулап', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                  ],
                                ),
                              ),
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
            left: 25.0, top: 888.0,
            child: FigSvg(
              width: 325.0, height: 1.0,
              vbLeft: 0.0, vbTop: -0.5, vbWidth: 325.0, vbHeight: 1.0,
              shapes: const [FigShape(d: _p6, fill: Color(0x807d7d7d))],
            )
          ),
          Positioned(
            left: 25.0, top: 1237.0,
            child: FigSvg(
              width: 325.0, height: 1.0,
              vbLeft: 0.0, vbTop: -0.5, vbWidth: 325.0, vbHeight: 1.0,
              shapes: const [FigShape(d: _p6, fill: Color(0x807d7d7d))],
            )
          ),
          Positioned(
            left: 25.0, top: 1400.0,
            child: FigSvg(
              width: 325.0, height: 1.0,
              vbLeft: 0.0, vbTop: -0.5, vbWidth: 325.0, vbHeight: 1.0,
              shapes: const [FigShape(d: _p6, fill: Color(0x807d7d7d))],
            )
          ),
          Positioned(
            left: 25.0, top: 904.0,
            child: FigBox(
              width: 325.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 7.0,
                  children: [
                    FigText(
                      width: 325.0,
                      span: 
                        TextSpan(text: 'Общая информация', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.176, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 325.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8.0,
                          children: [
                            FigBox(
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Общая квадратура', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)), children: [
                                          TextSpan(text: '92м', style: figStyle(fontSize: 15.0, weight: 600, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 10.8, weight: 600, color: const Color(0xff555555)), 15.0),
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
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Гостинная', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)), children: [
                                          TextSpan(text: '35м', style: figStyle(fontSize: 15.0, weight: 600, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 10.8, weight: 600, color: const Color(0xff555555)), 15.0),
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
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Холл', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)), children: [
                                          TextSpan(text: '23м', style: figStyle(fontSize: 15.0, weight: 600, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 10.8, weight: 600, color: const Color(0xff555555)), 15.0),
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
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Кухня', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)), children: [
                                          TextSpan(text: '17м', style: figStyle(fontSize: 15.0, weight: 600, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 10.8, weight: 600, color: const Color(0xff555555)), 15.0),
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
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Спальная', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)), children: [
                                          TextSpan(text: '25м', style: figStyle(fontSize: 15.0, weight: 600, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 10.8, weight: 600, color: const Color(0xff555555)), 15.0),
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
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Спальная 2', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)), children: [
                                          TextSpan(text: '15м', style: figStyle(fontSize: 15.0, weight: 600, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 10.8, weight: 600, color: const Color(0xff555555)), 15.0),
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
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Балкон', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)), children: [
                                          TextSpan(text: '7м', style: figStyle(fontSize: 15.0, weight: 600, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 10.8, weight: 600, color: const Color(0xff555555)), 15.0),
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
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Сан.узел', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      span: 
                                        TextSpan(style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)), children: [
                                          TextSpan(text: '10м', style: figStyle(fontSize: 15.0, weight: 600, color: const Color(0xff555555))),
                                          figSuper('2', figStyle(fontSize: 10.8, weight: 600, color: const Color(0xff555555)), 15.0),
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
                              width: 325.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Мебель', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Полностью', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.15, color: const Color(0xff555555)))
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
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Этаж', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
                                      ,
                                    ),
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: '8 из 12', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.15, color: const Color(0xff555555)))
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
          Positioned(
            left: 25.0, top: 1255.0,
            child: FigText(
              noWrap: true,
              width: 148.0,
              height: 20.0,
              span: 
                TextSpan(text: 'Варианты покупки', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.176, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 1421.0,
            child: FigText(
              noWrap: true,
              width: 98.0,
              height: 20.0,
              span: 
                TextSpan(text: 'Видеообзор', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.176, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 1723.0,
            child: FigText(
              noWrap: true,
              width: 89.0,
              height: 20.0,
              span: 
                TextSpan(text: 'Фотообзор', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.176, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 1285.0,
            child: FigBox(
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 12.0,
                  children: [
                    FigBox(
                      height: 32.0,
                      color: const Color(0x33ea812e),
                      radius: 8.0,
                      blur: 2.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(0.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 4.0,
                          children: [
                            FigText(
                              noWrap: true,
                              height: 16.0,
                              span: 
                                TextSpan(text: 'Прямая покупка', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xffea812e)))
                              ,
                            ),
                          ],
                        )
                        ,
                      )
                      ,
                    ),
                    FigBox(
                      height: 32.0,
                      radius: 8.0,
                      opacity: 0.8,
                      blur: 2.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      insets: const [FigInset(Color(0xffb5b5b5), 1.0)],
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(0.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 4.0,
                          children: [
                            FigText(
                              noWrap: true,
                              height: 16.0,
                              span: 
                                TextSpan(text: 'Ипотека', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xffb5b5b5)))
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
            left: 25.0, top: 1340.0,
            child: FigBox(
              width: 144.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FigText(
                      width: 144.0,
                      span: 
                        TextSpan(text: '102 000\$', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.21, color: const Color(0xff000000)))
                      ,
                    ),
                    FigText(
                      noWrap: true,
                      span: 
                        TextSpan(text: 'Можно сторговаться', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
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
            left: 0.0,
            right: 0.0,
            top: 1454.0,
            height: 250.0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 15.0,
                children: [
                  _buildVideoCard(context, 'Обзор квартиры'),
                  _buildVideoCard(context, 'Обзор местности'),
                  _buildVideoCard(context, 'Инфраструктура района'),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0.0, top: 402.0,
            child: FigBox(
              width: 375.0,
              height: 32.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 24.0, top: 4.0,
                    child: FigBox(
                      width: 362.0,
                      height: 25.0,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigBox(
                              width: 96.0,
                              height: 25.0,
                              color: const Color(0x33006cfb),
                              radius: 4.0,
                              padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 3.0),
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
                                        TextSpan(text: 'Собственник', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff006cfb)))
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
                            left: 106.0, top: 0.0,
                            child: FigBox(
                              width: 143.0,
                              height: 25.0,
                              color: const Color(0x334dba17),
                              radius: 4.0,
                              padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 3.0),
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
                                        TextSpan(text: 'Цена ниже рыночной', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff4dba17)))
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
                            left: 259.0, top: 0.0,
                            child: FigBox(
                              height: 25.0,
                              color: const Color(0x33ff0404),
                              radius: 4.0,
                              padding: const EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 3.0),
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
                                        TextSpan(text: 'Красная книга', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xffff0404)))
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
                    )
                  ),
                ],
              )
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 1756.0,
            child: FigBox(
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8.0,
                  children: [
                    FigBox(
                      width: 80.0,
                      height: 80.0,
                      radius: 8.0,
                      bgImage: const FigBgImage('assets/figma/2e62acec850fa8b9.jpg'),
                    ),
                    FigBox(
                      width: 80.0,
                      height: 80.0,
                      radius: 8.0,
                      bgImage: const FigBgImage('assets/figma/b76192aa900c610a.jpg'),
                    ),
                    FigBox(
                      width: 80.0,
                      height: 80.0,
                      radius: 8.0,
                      bgImage: const FigBgImage('assets/figma/92b0d143df96c511.jpg'),
                    ),
                    FigBox(
                      width: 80.0,
                      height: 80.0,
                      radius: 8.0,
                      bgImage: const FigBgImage('assets/figma/e267d094d7f9a8fc.jpg'),
                    ),
                    FigBox(
                      width: 80.0,
                      height: 80.0,
                      radius: 8.0,
                      bgImage: const FigBgImage('assets/figma/ccc665cff0c465a4.jpg'),
                    ),
                    FigBox(
                      width: 80.0,
                      height: 80.0,
                      radius: 8.0,
                      bgImage: const FigBgImage('assets/figma/231c034e3954a705.jpg'),
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

  Widget _buildVideoCard(BuildContext context, String title) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pushNamed(Routes.listingVideo),
      child: SizedBox(
        width: 140.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4.0,
          children: [
            FigBox(
              width: 140.0,
              height: 200.0,
              radius: 8.0,
              bgImage: const FigBgImage('assets/figma/92b0d143df96c511.jpg'),
              overlays: const [
                LinearGradient(
                  begin: Alignment(0.018, 1.009),
                  end: Alignment(-0.018, -1.009),
                  colors: [Color(0x26000000), Color(0x00666666)],
                  stops: [0.243, 0.943],
                ),
              ],
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 60.0,
                    top: 90.0,
                    child: FigBox(
                      width: 20.283,
                      height: 19.932,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0,
                            top: 0.0,
                            child: FigSvg(
                              width: 19.922,
                              height: 19.922,
                              vbLeft: 0.0,
                              vbTop: 0.0,
                              vbWidth: 19.922,
                              vbHeight: 19.922,
                              shapes: const [FigShape(d: _p8, fill: Color(0xd9ffffff))],
                            ),
                          ),
                          Positioned(
                            left: 7.158,
                            top: 6.045,
                            child: FigSvg(
                              width: 6.837,
                              height: 7.853,
                              vbLeft: 0.0,
                              vbTop: 0.0,
                              vbWidth: 6.837,
                              vbHeight: 7.853,
                              shapes: const [FigShape(d: _p9, fill: Color(0xd9ffffff))],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FigText(
              width: 140.0,
              span: TextSpan(
                text: title,
                style: figStyle(
                  fontSize: 15.0,
                  family: FigFont.display,
                  weight: 500,
                  height: 1.333,
                  color: const Color(0xff7d7d7d),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const String _p0 =
    'M 0 4 C 0 1.791 1.791 0 4 0 L 4 0 C 6.209 0 8 1.791 8 4 L 8 4 C 8 6.209 6.209 8 4 8 L 4 8 C 1.791 8 0 6.209 0 4 L 0 4 Z';
const String _p1 =
    'M 13.765 0 L 0 0 L 0 12.235 L 13.765 12.235 L 13.765 0 Z';
const String _p2 =
    'M 0 3.896 C 0 6.643 2.429 9.346 6.267 11.668 C 6.409 11.752 6.614 11.842 6.756 11.842 C 6.899 11.842 7.103 11.752 7.253 11.668 C 11.084 9.346 13.513 6.643 13.513 3.896 C 13.513 1.612 11.86 0 9.655 0 C 8.396 0 7.376 0.568 6.756 1.438 C 6.151 0.574 5.117 0 3.858 0 C 1.653 0 0 1.612 0 3.896 Z M 1.095 3.896 C 1.095 2.18 2.266 1.038 3.844 1.038 C 5.123 1.038 5.858 1.793 6.294 2.438 C 6.477 2.696 6.593 2.767 6.756 2.767 C 6.92 2.767 7.022 2.69 7.219 2.438 C 7.689 1.806 8.396 1.038 9.669 1.038 C 11.247 1.038 12.417 2.18 12.417 3.896 C 12.417 6.295 9.743 8.881 6.899 10.674 C 6.831 10.72 6.784 10.752 6.756 10.752 C 6.729 10.752 6.682 10.72 6.62 10.674 C 3.769 8.881 1.095 6.295 1.095 3.896 Z';
const String _p6 =
    'M 0 -0.5 L 0 0 L 325 0 L 325 -0.5 L 325 -1 L 0 -1 L 0 -0.5 Z';
const String _p7 =
    'M 20.283 0 L 0 0 L 0 19.932 L 20.283 19.932 L 20.283 0 Z';
const String _p8 =
    'M 9.961 19.922 C 15.459 19.922 19.922 15.459 19.922 9.961 C 19.922 4.463 15.459 0 9.961 0 C 4.463 0 0 4.463 0 9.961 C 0 15.459 4.463 19.922 9.961 19.922 Z M 9.961 18.262 C 5.371 18.262 1.66 14.551 1.66 9.961 C 1.66 5.371 5.371 1.66 9.961 1.66 C 14.551 1.66 18.262 5.371 18.262 9.961 C 18.262 14.551 14.551 18.262 9.961 18.262 Z';
const String _p9 =
    'M 0.977 7.734 L 6.533 4.443 C 6.943 4.209 6.934 3.643 6.533 3.398 L 0.977 0.107 C 0.557 -0.137 0 0.049 0 0.527 L 0 7.314 C 0 7.783 0.518 8.008 0.977 7.734 Z';
const String _p10 =
    'M 0 8 C 0 3.582 3.582 0 8 0 L 132 0 C 136.418 0 140 3.582 140 8 L 140 192 C 140 196.418 136.418 200 132 200 L 8 200 C 3.582 200 0 196.418 0 192 L 0 8 Z';
