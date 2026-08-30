// GENERATED from screens/Components.bundle.js — figma node StartScreen37.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Профиль исполнителя — 375.0×1262.0
class Screen38ProProfile extends StatelessWidget {
  const Screen38ProProfile({super.key});

  static const double designWidth = 375.0;
  static const double designHeight = 1262.0;

  /// Where the mockup draws the tab bar on this screen.
  static const Offset tabBarAt = Offset(-3.0, 1178.0);

  /// Which tab the mockup draws highlighted here.
  static const int mockupTab = 4;

  @override
  Widget build(BuildContext context) {
    return FigBox(
      width: 375.0,
      height: 1262.0,
      color: const Color(0xfffefefe),
      radius: 8.0,
      clip: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 25.0, top: 371.0,
            child: FigBox(
              width: 330.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 24.0,
                  children: [
                    FigBox(
                      width: 325.0,
                      height: 64.0,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigBox(
                              width: 325.0,
                              height: 64.0,
                              color: const Color(0xffffffff),
                              radius: 10.0,
                              shadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 4.0, spreadRadius: 0.0), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 4.0), blurRadius: 48.0, spreadRadius: 0.0)],
                              insets: const [FigInset(Color(0xffd9d9d9), 0.5)],
                            )
                          ),
                        ],
                      )
                      ,
                    ),
                    FigBox(
                      width: 330.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8.0,
                          children: [
                            FigText(
                              width: 330.0,
                              span: 
                                TextSpan(text: 'Все объявление', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                              ,
                            ),
                            FigBox(
                              width: 330.0,
                              height: 204.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigBox(
                                      width: 160.0,
                                      height: 204.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(-1.0, -1.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          spacing: 6.0,
                                          children: [
                                            FigBox(
                                              width: 160.0,
                                              height: 160.0,
                                              radius: 10.0,
                                              bgImage: const FigBgImage('assets/figma/92b0d143df96c511.jpg'),
                                              overlays: const [LinearGradient(begin: Alignment(0.018, 1.017), end: Alignment(-0.018, -1.017), colors: [Color(0x26000000), Color(0x00666666)], stops: [0.244, 0.939])],
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 12.0, top: 132.0,
                                                    child: FigBox(
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
                                                                      shapes: const [FigShape(d: _p0, fill: Color(0xffffffff))],
                                                                    )
                                                                  ),
                                                                  Positioned(
                                                                    left: 3.818, top: 0.0,
                                                                    child: FigSvg(
                                                                      width: 1.0, height: 8.0,
                                                                      vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                                      shapes: const [FigShape(d: _p1, fill: Color(0xffffffff))],
                                                                    )
                                                                  ),
                                                                  Positioned(
                                                                    left: 8.182, top: 2.0,
                                                                    child: FigSvg(
                                                                      width: 1.0, height: 8.0,
                                                                      vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                                      shapes: const [FigShape(d: _p1, fill: Color(0xffffffff))],
                                                                    )
                                                                  ),
                                                                ],
                                                              )
                                                              ,
                                                            ),
                                                            FigText(
                                                              noWrap: true,
                                                              span: 
                                                                TextSpan(text: 'Технопарк', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xffffffff)))
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
                                            ),
                                            FigBox(
                                              width: 139.0,
                                              child: FigOverflow(
                                                alignment: const Alignment(-1.0, -1.0),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  spacing: 2.0,
                                                  children: [
                                                    FigText(
                                                      width: 139.0,
                                                      span: 
                                                        TextSpan(text: '102 000\$', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
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
                                      width: 160.0,
                                      height: 204.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(-1.0, -1.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          spacing: 6.0,
                                          children: [
                                            FigBox(
                                              width: 160.0,
                                              height: 160.0,
                                              radius: 10.0,
                                              bgImage: const FigBgImage('assets/figma/2e62acec850fa8b9.jpg'),
                                              overlays: const [LinearGradient(begin: Alignment(0.018, 1.017), end: Alignment(-0.018, -1.017), colors: [Color(0x33000000), Color(0x00666666)], stops: [0.244, 0.939])],
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 10.0, top: 134.0,
                                                    child: FigBox(
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
                                                                      shapes: const [FigShape(d: _p0, fill: Color(0xffffffff))],
                                                                    )
                                                                  ),
                                                                  Positioned(
                                                                    left: 3.818, top: 0.0,
                                                                    child: FigSvg(
                                                                      width: 1.0, height: 8.0,
                                                                      vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                                      shapes: const [FigShape(d: _p1, fill: Color(0xffffffff))],
                                                                    )
                                                                  ),
                                                                  Positioned(
                                                                    left: 8.182, top: 2.0,
                                                                    child: FigSvg(
                                                                      width: 1.0, height: 8.0,
                                                                      vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                                      shapes: const [FigShape(d: _p1, fill: Color(0xffffffff))],
                                                                    )
                                                                  ),
                                                                ],
                                                              )
                                                              ,
                                                            ),
                                                            FigText(
                                                              noWrap: true,
                                                              span: 
                                                                TextSpan(text: 'Асанбай', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xffffffff)))
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
                                            ),
                                            FigBox(
                                              width: 139.0,
                                              child: FigOverflow(
                                                alignment: const Alignment(-1.0, -1.0),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  spacing: 2.0,
                                                  children: [
                                                    FigText(
                                                      width: 139.0,
                                                      span: 
                                                        TextSpan(text: '92 850\$', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
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
                      width: 330.0,
                      child: FigOverflow(
                        alignment: const Alignment(0.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FigBox(
                              width: 343.0,
                              height: 0.5,
                              color: const Color(0xffd7d8d9),
                            ),
                            FigBox(
                              width: 345.0,
                              padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 15.0),
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigBox(
                                      child: FigOverflow(
                                        alignment: const Alignment(-1.0, -1.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            FigText(
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: '16.700 кирпичей', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.333, letterSpacing: -0.42, color: const Color(0xff000000)))
                                              ,
                                            ),
                                            FigText(
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: 'Баланс', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff99a2ad)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      color: const Color(0xffea812e),
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
                                                TextSpan(text: 'Пополнить', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.333, color: const Color(0xffffffff)))
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
                              width: 343.0,
                              height: 0.5,
                              color: const Color(0xffd7d8d9),
                            ),
                          ],
                        )
                        ,
                      )
                      ,
                    ),
                    FigBox(
                      width: 330.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 12.0,
                          children: [
                            FigBox(
                              width: 330.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 5.0,
                                  children: [
                                    FigText(
                                      width: 330.0,
                                      span: 
                                        TextSpan(text: 'Последние уведомления', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                                      ,
                                    ),
                                    FigBox(
                                      width: 330.0,
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(0.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 9.0,
                                          children: [
                                            FigBox(
                                              child: FigOverflow(
                                                freeWidth: true,
                                                alignment: const Alignment(0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  spacing: 8.0,
                                                  children: [
                                                    FigBox(
                                                      width: 48.0,
                                                      height: 48.0,
                                                      radius: 12.0,
                                                      bgImage: const FigBgImage('assets/figma/a7fc1548c3caf430.png'),
                                                    ),
                                                    FigBox(
                                                      child: FigOverflow(
                                                        freeWidth: true,
                                                        alignment: const Alignment(-1.0, 0.0),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          spacing: 46.0,
                                                          children: [
                                                            FigBox(
                                                              width: 183.0,
                                                              child: FigOverflow(
                                                                alignment: const Alignment(-1.0, -1.0),
                                                                child: Column(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    FigText(
                                                                      width: 183.0,
                                                                      span: 
                                                                        TextSpan(text: 'Ташиев Камчыбек', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.15, color: const Color(0xff000000)))
                                                                      ,
                                                                    ),
                                                                    FigText(
                                                                      width: 183.0,
                                                                      span: 
                                                                        TextSpan(text: 'Рассматривает 4 объекта', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff7d7d7d)))
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
                                                    FigText(
                                                      noWrap: true,
                                                      span: 
                                                        TextSpan(text: 'Откликнулся', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.1, color: const Color(0xff4dba17)))
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
                            FigText(
                              align: TextAlign.center,
                              width: 330.0,
                              span: 
                                TextSpan(text: 'Посмотреть все', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff555555)))
                              ,
                            ),
                          ],
                        )
                        ,
                      )
                      ,
                    ),
                    FigBox(
                      width: 330.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8.0,
                          children: [
                            FigText(
                              width: 330.0,
                              span: 
                                TextSpan(text: 'Настройки', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                              ,
                            ),
                            FigBox(
                              width: 330.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 18.0,
                                  children: [
                                    FigBox(
                                      width: 330.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            FigBox(
                                              child: FigOverflow(
                                                freeWidth: true,
                                                alignment: const Alignment(0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  spacing: 4.0,
                                                  children: [
                                                    const FigBox(
                                                      width: 26.0,
                                                      height: 26.0,
                                                      child: Center(
                                                        child: Icon(
                                                          Icons.workspace_premium_outlined,
                                                          size: 22.0,
                                                          color: Color(0xffee9a58),
                                                        ),
                                                      ),
                                                    ),
                                                    FigText(
                                                      align: TextAlign.center,
                                                      noWrap: true,
                                                      span: 
                                                        TextSpan(text: 'Тарифы', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xff000000)))
                                                      ,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            FigBox(
                                              width: 7.0,
                                              height: 12.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 0.0, top: 0.0,
                                                    child: FigSvg(
                                                      width: 7.0, height: 12.0,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 7.0, vbHeight: 12.0,
                                                      shapes: const [FigShape(d: _p3, fill: Color(0xffb8c1cc), evenOdd: true)],
                                                    )
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    FigBox(
                                      width: 330.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            FigBox(
                                              child: FigOverflow(
                                                freeWidth: true,
                                                alignment: const Alignment(0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  spacing: 4.0,
                                                  children: [
                                                    FigBox(
                                                      width: 26.0,
                                                      height: 26.0,
                                                      clip: true,
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Positioned(
                                                            left: 4.0, top: 3.0,
                                                            child: FigBox(
                                                              width: 18.0,
                                                              height: 19.679,
                                                              clip: true,
                                                              child: Stack(
                                                                clipBehavior: Clip.none,
                                                                children: [
                                                                  Positioned(
                                                                    left: 0.0, top: 0.0,
                                                                    child: FigBox(
                                                                      width: 18.0,
                                                                      height: 19.679,
                                                                      clip: true,
                                                                      child: Stack(
                                                                        clipBehavior: Clip.none,
                                                                        children: [
                                                                          Positioned(
                                                                            left: 0.0, top: 0.0,
                                                                            child: FigSvg(
                                                                              width: 18.0, height: 19.679,
                                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 18.0, vbHeight: 19.679,
                                                                              shapes: const [FigShape(d: _p2, fill: Color(0xffee9a58))],
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
                                                    ),
                                                    FigText(
                                                      align: TextAlign.center,
                                                      noWrap: true,
                                                      span: 
                                                        TextSpan(text: 'Уведомление', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xff000000)))
                                                      ,
                                                    ),
                                                  ],
                                                )
                                                ,
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              width: 7.0,
                                              height: 12.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 0.0, top: 0.0,
                                                    child: FigSvg(
                                                      width: 7.0, height: 12.0,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 7.0, vbHeight: 12.0,
                                                      shapes: const [FigShape(d: _p3, fill: Color(0xffb8c1cc), evenOdd: true)],
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
                                    FigBox(
                                      width: 330.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            FigBox(
                                              child: FigOverflow(
                                                freeWidth: true,
                                                alignment: const Alignment(0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  spacing: 4.0,
                                                  children: [
                                                    FigBox(
                                                      width: 26.0,
                                                      height: 26.0,
                                                      clip: true,
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Positioned(
                                                            left: 4.0, top: 3.0,
                                                            child: FigBox(
                                                              width: 18.0,
                                                              height: 19.071,
                                                              clip: true,
                                                              child: Stack(
                                                                clipBehavior: Clip.none,
                                                                children: [
                                                                  Positioned(
                                                                    left: 0.0, top: 0.0,
                                                                    child: FigSvg(
                                                                      width: 18.0, height: 19.071,
                                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 18.0, vbHeight: 19.071,
                                                                      shapes: const [FigShape(d: _p4, fill: Color(0xffee9a58))],
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
                                                    ),
                                                    FigText(
                                                      align: TextAlign.center,
                                                      noWrap: true,
                                                      span: 
                                                        TextSpan(text: 'Аккаунт', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xff000000)))
                                                      ,
                                                    ),
                                                  ],
                                                )
                                                ,
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              width: 7.0,
                                              height: 12.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 0.0, top: 0.0,
                                                    child: FigSvg(
                                                      width: 7.0, height: 12.0,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 7.0, vbHeight: 12.0,
                                                      shapes: const [FigShape(d: _p3, fill: Color(0xffb8c1cc), evenOdd: true)],
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
                                    FigBox(
                                      width: 330.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            FigBox(
                                              child: FigOverflow(
                                                freeWidth: true,
                                                alignment: const Alignment(0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  spacing: 4.0,
                                                  children: [
                                                    FigBox(
                                                      width: 26.0,
                                                      height: 26.0,
                                                      clip: true,
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Positioned(
                                                            left: 4.0, top: 4.0,
                                                            child: FigBox(
                                                              width: 18.0,
                                                              height: 17.799,
                                                              clip: true,
                                                              child: Stack(
                                                                clipBehavior: Clip.none,
                                                                children: [
                                                                  Positioned(
                                                                    left: 0.0, top: 0.0,
                                                                    child: FigBox(
                                                                      width: 18.0,
                                                                      height: 17.799,
                                                                      clip: true,
                                                                      child: Stack(
                                                                        clipBehavior: Clip.none,
                                                                        children: [
                                                                          Positioned(
                                                                            left: 0.0, top: 0.0,
                                                                            child: Opacity(
                                                                              opacity: 0.0,
                                                                              child: FigSvg(
                                                                                width: 18.0, height: 17.799,
                                                                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 18.0, vbHeight: 17.799,
                                                                                shapes: const [FigShape(d: _p5, fill: Color(0xffee9a58))],
                                                                              ),
                                                                            )
                                                                          ),
                                                                          Positioned(
                                                                            left: 0.0, top: 0.042,
                                                                            child: FigSvg(
                                                                              width: 17.756, height: 17.757,
                                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 17.756, vbHeight: 17.757,
                                                                              shapes: const [FigShape(d: _p6, fill: Color(0xffee9a58))],
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
                                                    ),
                                                    FigText(
                                                      align: TextAlign.center,
                                                      noWrap: true,
                                                      span: 
                                                        TextSpan(text: 'Служба поддержки', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xff000000)))
                                                      ,
                                                    ),
                                                  ],
                                                )
                                                ,
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              width: 7.0,
                                              height: 12.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 0.0, top: 0.0,
                                                    child: FigSvg(
                                                      width: 7.0, height: 12.0,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 7.0, vbHeight: 12.0,
                                                      shapes: const [FigShape(d: _p3, fill: Color(0xffb8c1cc), evenOdd: true)],
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
                                    FigBox(
                                      width: 330.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            FigBox(
                                              child: FigOverflow(
                                                freeWidth: true,
                                                alignment: const Alignment(0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  spacing: 4.0,
                                                  children: [
                                                    FigBox(
                                                      width: 26.0,
                                                      height: 26.0,
                                                      clip: true,
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Positioned(
                                                            left: 3.0, top: 3.0,
                                                            child: FigBox(
                                                              width: 20.0,
                                                              height: 20.0,
                                                              clip: true,
                                                              child: Stack(
                                                                clipBehavior: Clip.none,
                                                                children: [
                                                                  Positioned(
                                                                    left: 0.0, top: 0.0,
                                                                    child: FigSvg(
                                                                      width: 20.0, height: 20.0,
                                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 20.0, vbHeight: 20.0,
                                                                      shapes: const [FigShape(d: _p7, fill: Color(0xffee9a58))],
                                                                    )
                                                                  ),
                                                                  Positioned(
                                                                    left: 4.092, top: 2.971,
                                                                    child: FigSvg(
                                                                      width: 6.495, height: 8.038,
                                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 6.495, vbHeight: 8.038,
                                                                      shapes: const [FigShape(d: _p8, fill: Color(0xffee9a58))],
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
                                                    ),
                                                    FigText(
                                                      align: TextAlign.center,
                                                      noWrap: true,
                                                      span: 
                                                        TextSpan(text: 'История пополнения и трат', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xff000000)))
                                                      ,
                                                    ),
                                                  ],
                                                )
                                                ,
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              width: 7.0,
                                              height: 12.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 0.0, top: 0.0,
                                                    child: FigSvg(
                                                      width: 7.0, height: 12.0,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 7.0, vbHeight: 12.0,
                                                      shapes: const [FigShape(d: _p3, fill: Color(0xffb8c1cc), evenOdd: true)],
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
                                    FigBox(
                                      width: 330.0,
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(0.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 82.0,
                                          children: [
                                            FigBox(
                                              child: FigOverflow(
                                                freeWidth: true,
                                                alignment: const Alignment(0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  spacing: 4.0,
                                                  children: [
                                                    FigBox(
                                                      width: 26.0,
                                                      height: 26.0,
                                                      clip: true,
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Positioned(
                                                            left: 4.0, top: 4.0,
                                                            child: FigBox(
                                                              width: 18.0,
                                                              height: 18.0,
                                                              clip: true,
                                                              child: Stack(
                                                                clipBehavior: Clip.none,
                                                                children: [
                                                                  Positioned(
                                                                    left: 0.0, top: 0.0,
                                                                    child: FigSvg(
                                                                      width: 18.0, height: 18.0,
                                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 18.0, vbHeight: 18.0,
                                                                      shapes: const [FigShape(d: _p9, fill: Color(0xffee9a58))],
                                                                    )
                                                                  ),
                                                                  Positioned(
                                                                    left: 5.122, top: 4.312,
                                                                    child: FigSvg(
                                                                      width: 7.748, height: 9.299,
                                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 7.748, vbHeight: 9.299,
                                                                      shapes: const [FigShape(d: _p10, fill: Color(0xffee9a58))],
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
                                                    ),
                                                    FigText(
                                                      align: TextAlign.center,
                                                      noWrap: true,
                                                      span: 
                                                        TextSpan(text: 'Язык', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xff000000)))
                                                      ,
                                                    ),
                                                  ],
                                                )
                                                ,
                                              )
                                              ,
                                            ),
                                            FigBox(
                                              color: const Color(0x4d7d7d7d),
                                              radius: 8.0,
                                              clip: true,
                                              padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 4.0),
                                              child: FigOverflow(
                                                freeWidth: true,
                                                alignment: const Alignment(0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    FigBox(
                                                      color: const Color(0xff7d7d7d),
                                                      radius: 4.0,
                                                      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
                                                      child: FigOverflow(
                                                        freeWidth: true,
                                                        alignment: const Alignment(0.0, 0.0),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            FigText(
                                                              align: TextAlign.center,
                                                              noWrap: true,
                                                              ellipsis: true,
                                                              span: 
                                                                TextSpan(text: 'Русский', style: figStyle(fontSize: 11.0, family: FigFont.display, weight: 500, height: 1.273, letterSpacing: 0.11, color: const Color(0xffffffff)))
                                                              ,
                                                            ),
                                                          ],
                                                        )
                                                        ,
                                                      )
                                                      ,
                                                    ),
                                                    FigBox(
                                                      width: 1.0,
                                                      height: 12.0,
                                                      radius: 0.5,
                                                      opacity: 0.3,
                                                    ),
                                                    FigBox(
                                                      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
                                                      child: FigOverflow(
                                                        freeWidth: true,
                                                        alignment: const Alignment(0.0, 0.0),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          crossAxisAlignment: CrossAxisAlignment.center,
                                                          children: [
                                                            FigText(
                                                              align: TextAlign.center,
                                                              noWrap: true,
                                                              ellipsis: true,
                                                              span: 
                                                                TextSpan(text: 'Кыргызский', style: figStyle(fontSize: 11.0, family: FigFont.display, weight: 500, height: 1.273, letterSpacing: 0.11, color: const Color(0xff7d7d7d)))
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
                                      width: 37.0,
                                      height: 28.0,
                                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                                      child: FigOverflow(
                                        freeWidth: true,
                                        alignment: const Alignment(-1.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 76.0,
                                          children: [
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
            left: 0.0, top: -17.0,
            child: FigBox(
              width: 375.0,
              height: 221.0,
              radius: 23.0,
              bgImage: const FigBgImage('assets/figma/fb9bf9cc77816ef6.jpg'),
              overlays: const [LinearGradient(begin: Alignment(0.0, -1.0), end: Alignment(0.0, 1.0), colors: [Color(0x5e000000), Color(0x5e000000)], stops: [0.0, 1.0])],
            )
          ),
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 25.0, top: 166.0,
            child: FigBox(
              width: 64.0,
              height: 64.0,
              radius: 12.0,
              bgImage: const FigBgImage('assets/figma/b2bc554ea37c013f.png'),
            )
          ),
          Positioned(
            left: 25.0, top: 238.0,
            child: FigBox(
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 46.0,
                  children: [
                    FigBox(
                      width: 183.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FigText(
                              width: 183.0,
                              span: 
                                TextSpan(text: 'Садыр Жапаров', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.21, color: const Color(0xff000000)))
                              ,
                            ),
                            FigText(
                              width: 183.0,
                              span: 
                                TextSpan(text: '8 объектов недвижимости', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff7d7d7d)))
                              ,
                            ),
                            FigText(
                              width: 183.0,
                              span: 
                                TextSpan(text: 'Продано: 12 Объектов', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff7d7d7d)))
                              ,
                            ),
                          ],
                        )
                        ,
                      )
                      ,
                    ),
                    FigBox(
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
                    ),
                  ],
                )
                ,
              )
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 318.0,
            child: FigBox(
              width: 309.0,
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8.0,
                  children: [
                    FigBox(
                      width: 110.0,
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
                              width: 80.0,
                              height: 14.0,
                              span: 
                                TextSpan(text: 'Новостройки', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                              ,
                            )
                          ),
                        ],
                      )
                      ,
                    ),
                    FigBox(
                      width: 82.0,
                      height: 30.0,
                      radius: 8.0,
                      opacity: 0.6,
                      blur: 2.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigText(
                              width: 65.0,
                              height: 14.0,
                              span: 
                                TextSpan(text: 'Квартиры', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                              ,
                            )
                          ),
                        ],
                      )
                      ,
                    ),
                    FigBox(
                      width: 101.0,
                      height: 30.0,
                      radius: 8.0,
                      opacity: 0.6,
                      blur: 2.0,
                      padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigText(
                              width: 71.0,
                              height: 14.0,
                              span: 
                                TextSpan(text: 'Коммерция', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
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
            left: 87.0, top: 385.0,
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
                      width: 30.0,
                      height: 29.459,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigBox(
                              width: 30.0,
                              height: 29.459,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: Opacity(
                                      opacity: 0.0,
                                      child: FigSvg(
                                        width: 30.0, height: 29.459,
                                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 30.0, vbHeight: 29.459,
                                        shapes: const [FigShape(d: _p14, fill: Color(0xffec8d43))],
                                      ),
                                    )
                                  ),
                                  Positioned(
                                    left: 0.0, top: 0.03,
                                    child: FigSvg(
                                      width: 29.444, height: 29.429,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 29.444, vbHeight: 29.429,
                                      shapes: const [FigShape(d: _p15, fill: Color(0xffec8d43))],
                                    )
                                  ),
                                  Positioned(
                                    left: 7.759, top: 7.745,
                                    child: FigSvg(
                                      width: 13.94, height: 13.94,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 13.94, vbHeight: 13.94,
                                      shapes: const [FigShape(d: _p16, fill: Color(0xffec8d43))],
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
                    ),
                    FigBox(
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2.0,
                          children: [
                            FigText(
                              span: 
                                TextSpan(text: 'Добавить объявление', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.15, color: const Color(0xff000000)))
                              ,
                            ),
                            FigText(
                              span: 
                                TextSpan(text: 'Добавьте первый объект', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff7d7d7d)))
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

const String _p0 =
    'M 0 2 L -0.232 1.557 C -0.397 1.643 -0.5 1.814 -0.5 2 L 0 2 Z M 0 10 L -0.5 10 C -0.5 10.175 -0.409 10.337 -0.259 10.428 C -0.109 10.518 0.077 10.524 0.232 10.443 L 0 10 Z M 3.818 8 L 4.027 7.545 C 3.886 7.481 3.723 7.485 3.586 7.557 L 3.818 8 Z M 8.182 10 L 7.973 10.455 C 8.114 10.519 8.277 10.515 8.414 10.443 L 8.182 10 Z M 12 8 L 12.232 8.443 C 12.397 8.357 12.5 8.186 12.5 8 L 12 8 Z M 12 0 L 12.5 0 C 12.5 -0.175 12.409 -0.337 12.259 -0.428 C 12.109 -0.518 11.923 -0.524 11.768 -0.443 L 12 0 Z M 8.182 2 L 7.973 2.455 C 8.114 2.519 8.277 2.515 8.414 2.443 L 8.182 2 Z M 3.818 0 L 4.027 -0.455 C 3.886 -0.519 3.723 -0.515 3.586 -0.443 L 3.818 0 Z M 0 2 L -0.5 2 L -0.5 10 L 0 10 L 0.5 10 L 0.5 2 L 0 2 Z M 0 10 L 0.232 10.443 L 4.05 8.443 L 3.818 8 L 3.586 7.557 L -0.232 9.557 L 0 10 Z M 3.818 8 L 3.61 8.455 L 7.973 10.455 L 8.182 10 L 8.39 9.545 L 4.027 7.545 L 3.818 8 Z M 8.182 10 L 8.414 10.443 L 12.232 8.443 L 12 8 L 11.768 7.557 L 7.95 9.557 L 8.182 10 Z M 12 8 L 12.5 8 L 12.5 0 L 12 0 L 11.5 0 L 11.5 8 L 12 8 Z M 12 0 L 11.768 -0.443 L 7.95 1.557 L 8.182 2 L 8.414 2.443 L 12.232 0.443 L 12 0 Z M 8.182 2 L 8.39 1.545 L 4.027 -0.455 L 3.818 0 L 3.61 0.455 L 7.973 2.455 L 8.182 2 Z M 3.818 0 L 3.586 -0.443 L -0.232 1.557 L 0 2 L 0.232 2.443 L 4.05 0.443 L 3.818 0 Z';
const String _p1 =
    'M 0.5 0 C 0.5 -0.276 0.276 -0.5 0 -0.5 C -0.276 -0.5 -0.5 -0.276 -0.5 0 L 0 0 L 0.5 0 Z M -0.5 8 C -0.5 8.276 -0.276 8.5 0 8.5 C 0.276 8.5 0.5 8.276 0.5 8 L 0 8 L -0.5 8 Z M 0 0 L -0.5 0 L -0.5 8 L 0 8 L 0.5 8 L 0.5 0 L 0 0 Z';
const String _p2 =
    'M 0 15.306 C 0 15.918 0.47 16.328 1.239 16.328 L 5.619 16.328 C 5.687 18.149 7.067 19.679 9 19.679 C 10.933 19.679 12.313 18.157 12.381 16.328 L 16.754 16.328 C 17.53 16.328 18 15.918 18 15.306 C 18 14.343 17.045 13.485 16.231 12.634 C 15.5 11.851 15.388 10.254 15.261 8.888 C 15.134 5.41 14.157 3.082 11.672 2.239 C 11.373 0.963 10.366 0 9 0 C 7.634 0 6.619 0.963 6.328 2.239 C 3.843 3.082 2.866 5.41 2.739 8.888 C 2.612 10.254 2.5 11.851 1.769 12.634 C 0.948 13.485 0 14.343 0 15.306 Z M 1.59 15.082 L 1.59 14.97 C 1.724 14.619 2.343 13.985 2.881 13.396 C 3.687 12.515 3.903 10.978 4.045 9.007 C 4.194 5.201 5.351 3.836 7.015 3.381 C 7.284 3.313 7.433 3.187 7.448 2.933 C 7.507 1.933 8.082 1.216 9 1.216 C 9.918 1.216 10.493 1.933 10.545 2.933 C 10.567 3.187 10.716 3.313 10.985 3.381 C 12.649 3.836 13.806 5.201 13.955 9.007 C 14.097 10.978 14.313 12.515 15.119 13.396 C 15.657 13.985 16.276 14.619 16.41 14.97 L 16.41 15.082 L 1.59 15.082 Z M 6.903 16.328 L 11.097 16.328 C 11.022 17.664 10.179 18.522 9 18.522 C 7.821 18.522 6.978 17.664 6.903 16.328 Z';
const String _p3 =
    'M 0.293 0.293 C -0.098 0.683 -0.098 1.317 0.293 1.707 L 4.586 6 L 0.293 10.293 C -0.098 10.683 -0.098 11.317 0.293 11.707 C 0.683 12.098 1.317 12.098 1.707 11.707 L 6.707 6.707 C 7.098 6.317 7.098 5.683 6.707 5.293 L 1.707 0.293 C 1.317 -0.098 0.683 -0.098 0.293 0.293 Z';
const String _p4 =
    'M 2.36 19.071 L 15.64 19.071 C 17.243 19.071 18 18.572 18 17.493 C 18 14.778 14.577 10.881 8.996 10.881 C 3.423 10.881 0 14.778 0 17.493 C 0 18.572 0.757 19.071 2.36 19.071 Z M 1.965 17.726 C 1.57 17.726 1.426 17.621 1.426 17.332 C 1.426 15.455 4.156 12.234 8.996 12.234 C 13.844 12.234 16.574 15.455 16.574 17.332 C 16.574 17.621 16.43 17.726 16.035 17.726 L 1.965 17.726 Z M 9.012 9.511 C 11.452 9.511 13.417 7.361 13.417 4.695 C 13.417 2.078 11.452 0 9.012 0 C 6.58 0 4.599 2.11 4.599 4.711 C 4.599 7.369 6.572 9.511 9.012 9.511 Z M 9.012 8.166 C 7.377 8.166 6.024 6.652 6.024 4.711 C 6.024 2.827 7.369 1.345 9.012 1.345 C 10.655 1.345 11.992 2.803 11.992 4.695 C 11.992 6.636 10.647 8.166 9.012 8.166 Z';
const String _p5 =
    'M 18 0 L 0 0 L 0 17.799 L 18 17.799 L 18 0 Z';
const String _p6 =
    'M 13.226 17.757 C 14.753 17.757 15.828 17.334 16.767 16.309 C 16.824 16.237 16.882 16.173 16.939 16.108 C 17.498 15.506 17.756 14.897 17.756 14.323 C 17.756 13.699 17.398 13.119 16.652 12.603 L 13.971 10.746 C 13.19 10.201 12.251 10.122 11.462 10.911 L 10.774 11.585 C 10.566 11.793 10.358 11.821 10.122 11.685 C 9.656 11.398 8.638 10.545 7.885 9.793 C 7.075 8.99 6.437 8.259 6.072 7.628 C 5.935 7.391 5.957 7.19 6.165 6.983 L 6.846 6.294 C 7.627 5.499 7.556 4.574 7.011 3.785 L 5.154 1.104 C 4.638 0.352 4.057 0.015 3.434 0.001 C 2.86 -0.014 2.244 0.266 1.649 0.818 C 1.577 0.875 1.513 0.932 1.448 0.99 C 0.43 1.922 0 2.997 0 4.509 C 0 7.119 1.663 10.28 4.573 13.183 C 7.462 16.072 10.616 17.757 13.226 17.757 Z M 13.233 16.531 C 10.875 16.567 7.9 14.768 5.477 12.359 C 3.047 9.936 1.19 6.868 1.226 4.509 C 1.24 3.477 1.599 2.588 2.337 1.915 C 2.387 1.871 2.437 1.836 2.487 1.785 C 2.803 1.499 3.133 1.355 3.419 1.355 C 3.706 1.355 3.95 1.477 4.143 1.764 L 5.935 4.445 C 6.151 4.768 6.186 5.133 5.835 5.477 L 5.054 6.251 C 4.473 6.832 4.502 7.57 4.91 8.151 C 5.391 8.825 6.265 9.836 7.054 10.624 C 7.849 11.42 8.932 12.366 9.606 12.839 C 10.186 13.255 10.925 13.284 11.505 12.703 L 12.28 11.922 C 12.624 11.57 12.989 11.599 13.312 11.814 L 15.993 13.613 C 16.28 13.807 16.401 14.051 16.401 14.337 C 16.401 14.624 16.251 14.954 15.964 15.276 C 15.921 15.327 15.885 15.37 15.842 15.42 C 15.168 16.165 14.265 16.517 13.233 16.531 Z';
const String _p7 =
    'M 9.996 20 C 15.47 20 20 15.47 20 10.004 C 20 4.53 15.463 0 9.988 0 C 4.522 0 0 4.53 0 10.004 C 0 15.47 4.53 20 9.996 20 Z M 9.996 18.572 C 5.251 18.572 1.436 14.749 1.436 10.004 C 1.436 5.251 5.244 1.436 9.988 1.436 C 14.741 1.436 18.564 5.251 18.564 10.004 C 18.564 14.749 14.749 18.572 9.996 18.572 Z';
const String _p8 =
    'M 0.591 8.038 L 5.896 8.038 C 6.234 8.038 6.495 7.777 6.495 7.44 L 6.495 0.591 C 6.495 0.261 6.234 0 5.896 0 C 5.574 0 5.305 0.261 5.305 0.591 L 5.305 6.848 L 0.591 6.848 C 0.253 6.848 0 7.109 0 7.44 C 0 7.777 0.253 8.038 0.591 8.038 Z';
const String _p9 =
    'M 2.978 18 L 15.014 18 C 16.997 18 18 17.004 18 15.051 L 18 2.949 C 18 0.996 16.997 0 15.014 0 L 2.978 0 C 1.003 0 0 0.988 0 2.949 L 0 15.051 C 0 17.012 1.003 18 2.978 18 Z M 3.009 16.644 C 1.937 16.644 1.355 16.077 1.355 14.982 L 1.355 3.018 C 1.355 1.923 1.937 1.356 3.009 1.356 L 14.991 1.356 C 16.04 1.356 16.645 1.923 16.645 3.018 L 16.645 14.982 C 16.645 16.077 16.04 16.644 14.991 16.644 L 3.009 16.644 Z';
const String _p10 =
    'M 0.635 9.299 C 0.942 9.299 1.156 9.161 1.286 8.755 L 2.067 6.534 L 5.681 6.534 L 6.462 8.755 C 6.6 9.153 6.806 9.299 7.128 9.299 C 7.496 9.299 7.748 9.061 7.748 8.717 C 7.748 8.586 7.725 8.464 7.656 8.28 L 4.816 0.659 C 4.647 0.222 4.326 0 3.866 0 C 3.415 0 3.101 0.222 2.932 0.659 L 0.092 8.28 C 0.031 8.464 0 8.586 0 8.717 C 0 9.069 0.245 9.299 0.635 9.299 Z M 2.419 5.492 L 3.828 1.501 L 3.92 1.501 L 5.329 5.492 L 2.419 5.492 Z';
const String _p14 =
    'M 30 0 L 0 0 L 0 29.459 L 30 29.459 L 30 0 Z';
const String _p15 =
    'M 0 8.331 C 0 8.992 0.541 9.534 1.203 9.534 C 1.88 9.534 2.421 8.992 2.421 8.331 L 2.421 5.489 C 2.421 3.579 3.564 2.421 5.489 2.421 L 8.391 2.421 C 9.053 2.421 9.609 1.865 9.609 1.203 C 9.609 0.541 9.053 0 8.391 0 L 5.489 0 C 2.075 0 0 2.09 0 5.489 L 0 8.331 Z M 29.444 8.331 L 29.444 5.489 C 29.444 2.09 27.368 0 23.955 0 L 21.038 0 C 20.376 0 19.835 0.541 19.835 1.203 C 19.835 1.865 20.376 2.421 21.038 2.421 L 23.955 2.421 C 25.88 2.421 27.023 3.579 27.023 5.489 L 27.023 8.331 C 27.023 8.992 27.564 9.534 28.226 9.534 C 28.887 9.534 29.444 8.992 29.444 8.331 Z M 0 21.098 L 0 23.94 C 0 27.338 2.075 29.429 5.489 29.429 L 8.391 29.429 C 9.053 29.429 9.609 28.887 9.609 28.226 C 9.609 27.564 9.053 27.008 8.391 27.008 L 5.489 27.008 C 3.564 27.008 2.421 25.85 2.421 23.94 L 2.421 21.098 C 2.421 20.436 1.88 19.88 1.203 19.88 C 0.541 19.88 0 20.436 0 21.098 Z M 29.444 21.098 C 29.444 20.436 28.887 19.88 28.226 19.88 C 27.564 19.88 27.023 20.436 27.023 21.098 L 27.023 23.94 C 27.023 25.85 25.88 27.008 23.955 27.008 L 21.038 27.008 C 20.376 27.008 19.835 27.564 19.835 28.226 C 19.835 28.887 20.376 29.429 21.038 29.429 L 23.955 29.429 C 27.368 29.429 29.444 27.338 29.444 23.94 L 29.444 21.098 Z';
const String _p16 =
    'M 8.226 12.662 L 8.226 1.293 C 8.226 0.526 7.714 0 6.947 0 C 6.211 0 5.714 0.526 5.714 1.293 L 5.714 12.662 C 5.714 13.413 6.211 13.94 6.947 13.94 C 7.714 13.94 8.226 13.429 8.226 12.662 Z M 1.293 8.226 L 12.662 8.226 C 13.414 8.226 13.94 7.729 13.94 6.992 C 13.94 6.241 13.429 5.714 12.662 5.714 L 1.293 5.714 C 0.511 5.714 0 6.241 0 6.992 C 0 7.729 0.526 8.226 1.293 8.226 Z';
