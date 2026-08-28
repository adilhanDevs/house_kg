// GENERATED from screens/Components.bundle.js — figma node StartScreen29.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Экран 64:249 — 375.0×795.0
class Screen30Screen64249 extends StatelessWidget {
  const Screen30Screen64249({super.key});

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
                        TextSpan(text: 'Продвижение', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
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
          Positioned(
            left: 25.0, top: 316.0,
            child: FigBox(
              width: 324.0,
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
                        TextSpan(text: 'Использовать точное продвижение', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, letterSpacing: -0.15, color: const Color(0xff85858a)))
                      ,
                    ),
                    FigBox(
                      width: 30.0,
                      height: 16.0,
                      color: const Color(0xffec8d42),
                      radius: 45.161,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 16.0, top: 2.0,
                            child: FigSvg(
                              width: 12.194, height: 12.194,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 12.194, vbHeight: 12.194,
                              shapes: const [FigShape(d: _p3, fill: Color(0xffffffff))],
                              dropShadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 0.452), BoxShadow(color: Color(0x26000000), offset: Offset(0.0, 1.355), blurRadius: 3.613), BoxShadow(color: Color(0x0f000000), offset: Offset(0.0, 1.355), blurRadius: 0.452)],
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
            left: 25.0, top: 234.0,
            child: FigBox(
              width: 326.0,
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 53.0,
                  children: [
                    FigBox(
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 8.0,
                          children: [
                            FigSvg(
                              width: 48.0, height: 48.0,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 48.0, vbHeight: 48.0,
                              shapes: const [FigShape(d: _p4, fill: Color(0xffffffff))],
                            ),
                            FigBox(
                              width: 139.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 3.0,
                                  children: [
                                    FigBox(
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 4.0,
                                          children: [
                                            FigBox(
                                              width: 12.0,
                                              height: 10.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 0.0, top: 0.0,
                                                    child: FigSvg(
                                                      width: 12.0, height: 10.0,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 12.0, vbHeight: 10.0,
                                                      shapes: const [FigShape(d: _p5, fill: Color(0xff484848))],
                                                    )
                                                  ),
                                                  Positioned(
                                                    left: 3.818, top: 0.0,
                                                    child: FigSvg(
                                                      width: 1.0, height: 8.0,
                                                      vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                      shapes: const [FigShape(d: _p6, fill: Color(0xff484848))],
                                                    )
                                                  ),
                                                  Positioned(
                                                    left: 8.182, top: 2.0,
                                                    child: FigSvg(
                                                      width: 1.0, height: 8.0,
                                                      vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                      shapes: const [FigShape(d: _p6, fill: Color(0xff484848))],
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
                                            FigText(
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: 'Технопарк', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff484848)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 139.0,
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
                                                TextSpan(text: '8 эт.', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff555555)))
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
                      width: 77.0,
                      child: FigOverflow(
                        alignment: const Alignment(0.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FigBox(
                              width: 77.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FigBox(
                                      width: 61.0,
                                      height: 16.0,
                                      clip: false,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 1.0, top: 0.0,
                                            child: FigText(
                                              width: 60.0,
                                              height: 16.0,
                                              span: 
                                                TextSpan(text: '107000\$', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff000000)))
                                              ,
                                            )
                                          ),
                                          Positioned(
                                            left: -2.0, top: 0.0,
                                            child: Transform(
                                              transform: Matrix4(0.982, -0.189, 0.0, 0.0, 0.189, 0.982, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 11.5, 0.0, 1.0),
                                              child: FigSvg(
                                                width: 58.052, height: 1.0,
                                                vbLeft: 0.0, vbTop: -0.5, vbWidth: 58.052, vbHeight: 1.0,
                                                shapes: const [FigShape(d: _p7, fill: Color(0xff000000))],
                                              )
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigText(
                                      width: 77.0,
                                      span: 
                                        TextSpan(text: '102 000\$', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff000000)))
                                      ,
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigText(
                              width: 77.0,
                              span: 
                                TextSpan(text: 'Цена снизилась', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.1, color: const Color(0xff4dba17)))
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
            left: 24.0, top: 205.0,
            child: FigText(
              noWrap: true,
              width: 142.0,
              height: 20.0,
              span: 
                TextSpan(text: 'Ваше объявление', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 380.0,
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
                      width: 325.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 13.0,
                          children: [
                            FigText(
                              width: 325.0,
                              span: 
                                TextSpan(text: 'Примерный бюджет', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
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
                    ),
                    FigBox(
                      width: 325.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 10.0,
                          children: [
                            FigText(
                              width: 325.0,
                              span: 
                                TextSpan(text: 'Количество дней', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
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
                                        freeWidth: true,
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 8.0,
                                          children: [
                                            FigBox(
                                              width: 36.0,
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
                                                      width: 6.0,
                                                      height: 14.0,
                                                      span: 
                                                        TextSpan(text: '1', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                                                      ,
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              width: 38.0,
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
                                                      width: 8.0,
                                                      height: 14.0,
                                                      span: 
                                                        TextSpan(text: '2', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                                      ,
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              width: 38.0,
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
                                                      width: 8.0,
                                                      height: 14.0,
                                                      span: 
                                                        TextSpan(text: '3', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                                      ,
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              width: 39.0,
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
                                                      width: 9.0,
                                                      height: 14.0,
                                                      span: 
                                                        TextSpan(text: '4', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                                      ,
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              width: 38.0,
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
                                                      width: 8.0,
                                                      height: 14.0,
                                                      span: 
                                                        TextSpan(text: '5', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                                      ,
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
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
                  ],
                )
                ,
              )
              ,
            )
          ),
          Positioned(
            left: 23.0, top: 543.0,
            child: FigBox(
              width: 335.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 9.0,
                  children: [
                    FigText(
                      width: 335.0,
                      span: 
                        TextSpan(text: '121 - 180 показов в день', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 0.667, letterSpacing: -0.21, color: const Color(0xffec8d42)))
                      ,
                    ),
                    FigText(
                      width: 335.0,
                      span: 
                        TextSpan(text: 'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff7d7d7d)))
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
            left: 26.0, top: 339.0,
            child: FigBox(
              width: 324.0,
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
                        TextSpan(text: 'Использовать клиентскую базу', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, letterSpacing: -0.15, color: const Color(0xff85858a)))
                      ,
                    ),
                    FigBox(
                      width: 30.0,
                      height: 16.0,
                      color: const Color(0x8085858a),
                      radius: 45.161,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 2.0, top: 2.0,
                            child: FigSvg(
                              width: 12.194, height: 12.194,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 12.194, vbHeight: 12.194,
                              shapes: const [FigShape(d: _p3, fill: Color(0xffffffff))],
                              dropShadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 0.452), BoxShadow(color: Color(0x26000000), offset: Offset(0.0, 1.355), blurRadius: 3.613), BoxShadow(color: Color(0x0f000000), offset: Offset(0.0, 1.355), blurRadius: 0.452)],
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
        ],
      )
      ,
    );
  }
}

const String _p3 =
    'M 0 6.097 C 0 2.73 2.73 0 6.097 0 L 6.097 0 C 9.464 0 12.194 2.73 12.194 6.097 L 12.194 6.097 C 12.194 9.464 9.464 12.194 6.097 12.194 L 6.097 12.194 C 2.73 12.194 0 9.464 0 6.097 L 0 6.097 Z';
const String _p4 =
    'M 0 6 C 0 2.686 2.686 0 6 0 L 42 0 C 45.314 0 48 2.686 48 6 L 48 42 C 48 45.314 45.314 48 42 48 L 6 48 C 2.686 48 0 45.314 0 42 L 0 6 Z';
const String _p5 =
    'M 0 2 L -0.232 1.557 C -0.397 1.643 -0.5 1.814 -0.5 2 L 0 2 Z M 0 10 L -0.5 10 C -0.5 10.175 -0.409 10.337 -0.259 10.428 C -0.109 10.518 0.077 10.524 0.232 10.443 L 0 10 Z M 3.818 8 L 4.027 7.545 C 3.886 7.481 3.723 7.485 3.586 7.557 L 3.818 8 Z M 8.182 10 L 7.973 10.455 C 8.114 10.519 8.277 10.515 8.414 10.443 L 8.182 10 Z M 12 8 L 12.232 8.443 C 12.397 8.357 12.5 8.186 12.5 8 L 12 8 Z M 12 0 L 12.5 0 C 12.5 -0.175 12.409 -0.337 12.259 -0.428 C 12.109 -0.518 11.923 -0.524 11.768 -0.443 L 12 0 Z M 8.182 2 L 7.973 2.455 C 8.114 2.519 8.277 2.515 8.414 2.443 L 8.182 2 Z M 3.818 0 L 4.027 -0.455 C 3.886 -0.519 3.723 -0.515 3.586 -0.443 L 3.818 0 Z M 0 2 L -0.5 2 L -0.5 10 L 0 10 L 0.5 10 L 0.5 2 L 0 2 Z M 0 10 L 0.232 10.443 L 4.05 8.443 L 3.818 8 L 3.586 7.557 L -0.232 9.557 L 0 10 Z M 3.818 8 L 3.61 8.455 L 7.973 10.455 L 8.182 10 L 8.39 9.545 L 4.027 7.545 L 3.818 8 Z M 8.182 10 L 8.414 10.443 L 12.232 8.443 L 12 8 L 11.768 7.557 L 7.95 9.557 L 8.182 10 Z M 12 8 L 12.5 8 L 12.5 0 L 12 0 L 11.5 0 L 11.5 8 L 12 8 Z M 12 0 L 11.768 -0.443 L 7.95 1.557 L 8.182 2 L 8.414 2.443 L 12.232 0.443 L 12 0 Z M 8.182 2 L 8.39 1.545 L 4.027 -0.455 L 3.818 0 L 3.61 0.455 L 7.973 2.455 L 8.182 2 Z M 3.818 0 L 3.586 -0.443 L -0.232 1.557 L 0 2 L 0.232 2.443 L 4.05 0.443 L 3.818 0 Z';
const String _p6 =
    'M 0.5 0 C 0.5 -0.276 0.276 -0.5 0 -0.5 C -0.276 -0.5 -0.5 -0.276 -0.5 0 L 0 0 L 0.5 0 Z M -0.5 8 C -0.5 8.276 -0.276 8.5 0 8.5 C 0.276 8.5 0.5 8.276 0.5 8 L 0 8 L -0.5 8 Z M 0 0 L -0.5 0 L -0.5 8 L 0 8 L 0.5 8 L 0.5 0 L 0 0 Z';
const String _p7 =
    'M 0 -0.5 L 0 0 L 58.052 0 L 58.052 -0.5 L 58.052 -1 L 0 -1 L 0 -0.5 Z';
