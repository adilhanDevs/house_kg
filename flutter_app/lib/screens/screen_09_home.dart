// GENERATED from screens/Components.bundle.js — figma node StartScreen9.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Главная — 375.0×1022.0
class Screen09Home extends StatelessWidget {
  const Screen09Home({super.key});

  static const double designWidth = 375.0;
  static const double designHeight = 1022.0;

  @override
  Widget build(BuildContext context) {
    return FigBox(
      width: 375.0,
      height: 1022.0,
      color: const Color(0xfffefefe),
      radius: 8.0,
      clip: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0.0, top: 411.0,
            child: FigBox(
              width: 375.0,
              height: 591.0,
              color: const Color(0xffffffff),
              radius: 22.0,
              shadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 4.0, spreadRadius: 0.0), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 4.0), blurRadius: 48.0, spreadRadius: 0.0)],
            )
          ),
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 26.0, top: 43.0,
            child: FigBox(
              width: 67.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FigText(
                      width: 67.0,
                      span: 
                        TextSpan(text: 'Бишкек', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff000000)))
                      ,
                    ),
                    FigText(
                      width: 67.0,
                      span: 
                        TextSpan(text: 'Кыргызстан', style: figStyle(fontSize: 12.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff000000)))
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
            left: 320.0, top: 44.0,
            child: FigBox(
              width: 30.0,
              height: 30.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0.0, top: 0.0,
                    child: FigBox(
                      width: 30.0,
                      height: 30.0,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigBox(
                              width: 30.0,
                              height: 30.0,
                              radius: 5.769,
                              shadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 3.333, spreadRadius: 0.0), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 3.333), blurRadius: 40.0, spreadRadius: 0.0)],
                              insets: const [FigInset(Color(0xffffac6a), 0.962)],
                            )
                          ),
                        ],
                      )
                      ,
                    )
                  ),
                  Positioned(
                    left: 9.0, top: 8.0,
                    child: FigBox(
                      width: 13.0,
                      height: 14.442,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigBox(
                              width: 13.0,
                              height: 14.442,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: FigSvg(
                                      width: 13.0, height: 10.833,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 13.0, vbHeight: 10.833,
                                      shapes: const [FigShape(d: _p3, fill: Color(0xffffac6a))],
                                    )
                                  ),
                                  Positioned(
                                    left: 5.251, top: 13.722,
                                    child: FigSvg(
                                      width: 2.499, height: 0.72,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 2.499, vbHeight: 0.72,
                                      shapes: const [FigShape(d: _p4, fill: Color(0xffffac6a))],
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
          Positioned(
            left: 25.0, top: 138.0,
            child: FigBox(
              width: 358.0,
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 10.0,
                  children: [
                    FigBox(
                      width: 82.0,
                      height: 82.0,
                      radius: 8.0,
                      insets: const [FigInset(Color(0xffea812e), 1.5)],
                      bgImage: const FigBgImage('assets/figma/ccc665cff0c465a4.jpg'),
                    ),
                    FigBox(
                      width: 82.0,
                      height: 82.0,
                      radius: 8.0,
                      insets: const [FigInset(Color(0xffd3d3d3), 1.5)],
                      bgImage: const FigBgImage('assets/figma/e267d094d7f9a8fc.jpg'),
                    ),
                    FigBox(
                      width: 82.0,
                      height: 82.0,
                      radius: 8.0,
                      insets: const [FigInset(Color(0xffd3d3d3), 1.5)],
                      bgImage: const FigBgImage('assets/figma/b76192aa900c610a.jpg'),
                    ),
                    FigBox(
                      width: 82.0,
                      height: 82.0,
                      radius: 8.0,
                      insets: const [FigInset(Color(0xffd3d3d3), 1.5)],
                      bgImage: const FigBgImage('assets/figma/231c034e3954a705.jpg'),
                    ),
                  ],
                )
                ,
              )
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 236.0,
            child: FigBox(
              width: 325.0,
              color: const Color(0xffffffff),
              radius: 10.0,
              padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 15.0),
              shadows: const [BoxShadow(color: Color(0xffeeeeee), offset: Offset(0.0, 0.0), blurRadius: 0.0, spreadRadius: 0.5), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 4.0, spreadRadius: 0.0), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 4.0), blurRadius: 48.0, spreadRadius: 0.0)],
              insets: const [FigInset(Color(0xffeeeeee), 0.5)],
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8.0,
                  children: [
                    FigBox(
                      width: 14.0,
                      height: 14.0,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigSvg(
                              width: 12.444, height: 12.444,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 12.444, vbHeight: 12.444,
                              shapes: const [FigShape(d: _p5, fill: Color(0xffea812e))],
                            )
                          ),
                          Positioned(
                            left: 10.617, top: 10.617,
                            child: FigSvg(
                              width: 3.383, height: 3.383,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 3.383, vbHeight: 3.383,
                              shapes: const [FigShape(d: _p6, fill: Color(0xffea812e))],
                            )
                          ),
                        ],
                      )
                      ,
                    ),
                    FigText(
                      noWrap: true,
                      ellipsis: true,
                      width: 83.0,
                      span: 
                        TextSpan(text: 'Что ищете?', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, letterSpacing: -0.15, color: const Color(0xff555555)))
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
            left: 25.0, top: 302.0,
            child: FigBox(
              width: 60.0,
              height: 60.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0.0, top: 0.0,
                    child: FigBox(
                      width: 60.0,
                      height: 60.0,
                      color: const Color(0xffffffff),
                      radius: 6.923,
                      shadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 4.0, spreadRadius: 0.0), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 4.0), blurRadius: 48.0, spreadRadius: 0.0)],
                    )
                  ),
                  Positioned(
                    left: 13.0, top: 15.0,
                    child: FigBox(
                      width: 34.0,
                      height: 29.513,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: Opacity(
                              opacity: 0.0,
                              child: FigSvg(
                                width: 34.0, height: 29.513,
                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 34.0, vbHeight: 29.513,
                                shapes: const [FigShape(d: _p7, fill: Color(0xffea812f))],
                              ),
                            )
                          ),
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigSvg(
                              width: 33.481, height: 29.485,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 33.481, vbHeight: 29.485,
                              shapes: const [FigShape(d: _p8, fill: Color(0xffea812f))],
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
            left: 39.5, top: 370.0,
            child: FigText(
              align: TextAlign.center,
              noWrap: true,
              width: 31.0,
              height: 14.0,
              span: 
                TextSpan(text: 'Дома', style: figStyle(fontSize: 12.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 109.667, top: 302.0,
            child: FigBox(
              width: 60.0,
              height: 60.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0.0, top: 0.0,
                    child: FigBox(
                      width: 60.0,
                      height: 60.0,
                      color: const Color(0xffffffff),
                      radius: 6.923,
                      shadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 4.0, spreadRadius: 0.0), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 4.0), blurRadius: 48.0, spreadRadius: 0.0)],
                    )
                  ),
                  Positioned(
                    left: 14.333, top: 14.0,
                    child: FigBox(
                      width: 32.0,
                      height: 31.37,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: Opacity(
                              opacity: 0.0,
                              child: FigSvg(
                                width: 32.0, height: 31.37,
                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 32.0, vbHeight: 31.37,
                                shapes: const [FigShape(d: _p9, fill: Color(0xffea812f))],
                              ),
                            )
                          ),
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigSvg(
                              width: 31.37, height: 31.37,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 31.37, vbHeight: 31.37,
                              shapes: const [FigShape(d: _p10, fill: Color(0xffea812f))],
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
            left: 109.667, top: 370.0,
            child: FigText(
              align: TextAlign.center,
              width: 60.0,
              height: 14.0,
              span: 
                TextSpan(text: 'Квартиры', style: figStyle(fontSize: 12.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 194.333, top: 302.0,
            child: FigBox(
              width: 60.0,
              height: 60.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0.0, top: 0.0,
                    child: FigBox(
                      width: 60.0,
                      height: 60.0,
                      color: const Color(0xffffffff),
                      radius: 6.923,
                      shadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 4.0, spreadRadius: 0.0), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 4.0), blurRadius: 48.0, spreadRadius: 0.0)],
                    )
                  ),
                  Positioned(
                    left: 13.667, top: 16.0,
                    child: FigBox(
                      width: 32.0,
                      height: 28.16,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: Opacity(
                              opacity: 0.0,
                              child: FigSvg(
                                width: 32.0, height: 28.16,
                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 32.0, vbHeight: 28.16,
                                shapes: const [FigShape(d: _p11, fill: Color(0xffea8130))],
                              ),
                            )
                          ),
                          Positioned(
                            left: 0.0, top: 0.038,
                            child: FigSvg(
                              width: 31.508, height: 28.122,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 31.508, vbHeight: 28.122,
                              shapes: const [FigShape(d: _p12, fill: Color(0xffea8130))],
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
            left: 194.333, top: 370.0,
            child: FigText(
              align: TextAlign.center,
              width: 60.0,
              height: 14.0,
              span: 
                TextSpan(text: 'Участки', style: figStyle(fontSize: 12.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 286.0, top: 302.0,
            child: FigBox(
              width: 60.0,
              height: 60.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0.0, top: 0.0,
                    child: FigBox(
                      width: 60.0,
                      height: 60.0,
                      color: const Color(0xffffffff),
                      radius: 6.923,
                      shadows: const [BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 0.0), blurRadius: 4.0, spreadRadius: 0.0), BoxShadow(color: Color(0x0a000000), offset: Offset(0.0, 4.0), blurRadius: 48.0, spreadRadius: 0.0)],
                    )
                  ),
                  Positioned(
                    left: 15.0, top: 12.0,
                    child: FigBox(
                      width: 30.365,
                      height: 35.847,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: Opacity(
                              opacity: 0.0,
                              child: FigSvg(
                                width: 30.365, height: 35.847,
                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 30.365, vbHeight: 35.847,
                                shapes: const [FigShape(d: _p13, fill: Color(0xffea8130))],
                              ),
                            )
                          ),
                          Positioned(
                            left: 19.631, top: 7.35,
                            child: FigSvg(
                              width: 10.168, height: 28.482,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 10.168, vbHeight: 28.482,
                              shapes: const [FigShape(d: _p14, fill: Color(0xffea8130))],
                            )
                          ),
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: FigSvg(
                              width: 22.035, height: 35.832,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 22.035, vbHeight: 35.832,
                              shapes: const [FigShape(d: _p15, fill: Color(0xffea8130))],
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
            left: 279.0, top: 370.0,
            child: FigText(
              align: TextAlign.center,
              width: 74.0,
              height: 14.0,
              span: 
                TextSpan(text: 'Новостройки', style: figStyle(fontSize: 12.0, family: FigFont.display, weight: 500, height: 1.0, letterSpacing: -0.12, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 26.0, top: 93.0,
            child: FigText(
              noWrap: true,
              width: 290.0,
              height: 25.0,
              span: 
                TextSpan(text: 'Здравствуйте, Азамат!', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.21, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 512.0,
            child: FigBox(
              width: 325.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 14.0,
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
                            FigBox(
                              width: 160.0,
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
                                                              shapes: const [FigShape(d: _p16, fill: Color(0xffffffff))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 3.818, top: 0.0,
                                                            child: FigSvg(
                                                              width: 1.0, height: 8.0,
                                                              vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                              shapes: const [FigShape(d: _p17, fill: Color(0xffffffff))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 8.182, top: 2.0,
                                                            child: FigSvg(
                                                              width: 1.0, height: 8.0,
                                                              vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                              shapes: const [FigShape(d: _p17, fill: Color(0xffffffff))],
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
                                          Positioned(
                                            left: 122.0, top: 12.0,
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
                                                                shapes: const [FigShape(d: _p18, fill: Color(0xccea812e))],
                                                              ),
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 0.0, top: 0.393,
                                                            child: FigSvg(
                                                              width: 13.513, height: 11.842,
                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 13.513, vbHeight: 11.842,
                                                              shapes: const [FigShape(d: _p19, fill: Color(0xccea812e))],
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
                                                              shapes: const [FigShape(d: _p16, fill: Color(0xffffffff))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 3.818, top: 0.0,
                                                            child: FigSvg(
                                                              width: 1.0, height: 8.0,
                                                              vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                              shapes: const [FigShape(d: _p17, fill: Color(0xffffffff))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 8.182, top: 2.0,
                                                            child: FigSvg(
                                                              width: 1.0, height: 8.0,
                                                              vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                              shapes: const [FigShape(d: _p17, fill: Color(0xffffffff))],
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
                                          Positioned(
                                            left: 122.0, top: 12.0,
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
                                                                shapes: const [FigShape(d: _p18, fill: Color(0xccea812e))],
                                                              ),
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 0.0, top: 0.393,
                                                            child: FigSvg(
                                                              width: 13.513, height: 11.842,
                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 13.513, vbHeight: 11.842,
                                                              shapes: const [FigShape(d: _p19, fill: Color(0xccea812e))],
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
                                            left: 12.0, top: 15.0,
                                            child: FigBox(
                                              color: const Color(0xff006cfb),
                                              radius: 4.0,
                                              padding: const EdgeInsets.fromLTRB(4.0, 2.0, 4.0, 3.0),
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
                                                        TextSpan(text: 'Собственник', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xffffffff)))
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
                    FigBox(
                      width: 325.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FigBox(
                              width: 160.0,
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
                                                              shapes: const [FigShape(d: _p16, fill: Color(0xffffffff))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 3.818, top: 0.0,
                                                            child: FigSvg(
                                                              width: 1.0, height: 8.0,
                                                              vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                              shapes: const [FigShape(d: _p17, fill: Color(0xffffffff))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 8.182, top: 2.0,
                                                            child: FigSvg(
                                                              width: 1.0, height: 8.0,
                                                              vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                              shapes: const [FigShape(d: _p17, fill: Color(0xffffffff))],
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
                                          Positioned(
                                            left: 122.0, top: 12.0,
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
                                                                shapes: const [FigShape(d: _p18, fill: Color(0xccea812e))],
                                                              ),
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 0.0, top: 0.393,
                                                            child: FigSvg(
                                                              width: 13.513, height: 11.842,
                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 13.513, vbHeight: 11.842,
                                                              shapes: const [FigShape(d: _p19, fill: Color(0xccea812e))],
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
                                                              shapes: const [FigShape(d: _p16, fill: Color(0xffffffff))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 3.818, top: 0.0,
                                                            child: FigSvg(
                                                              width: 1.0, height: 8.0,
                                                              vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                              shapes: const [FigShape(d: _p17, fill: Color(0xffffffff))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 8.182, top: 2.0,
                                                            child: FigSvg(
                                                              width: 1.0, height: 8.0,
                                                              vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                                              shapes: const [FigShape(d: _p17, fill: Color(0xffffffff))],
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
                                          Positioned(
                                            left: 122.0, top: 12.0,
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
                                                                shapes: const [FigShape(d: _p18, fill: Color(0xccea812e))],
                                                              ),
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 0.0, top: 0.393,
                                                            child: FigSvg(
                                                              width: 13.513, height: 11.842,
                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 13.513, vbHeight: 11.842,
                                                              shapes: const [FigShape(d: _p19, fill: Color(0xccea812e))],
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
            )
          ),
          Positioned(
            left: 133.0, top: 957.0,
            child: FigText(
              noWrap: true,
              width: 110.0,
              height: 22.0,
              opacity: 0.8,
              span: 
                TextSpan(text: 'Посмотреть все', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xffea812f)))
              ,
            )
          ),
          Positioned(
            left: 23.0, top: 429.0,
            child: FigBox(
              width: 222.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8.0,
                  children: [
                    FigText(
                      width: 222.0,
                      span: 
                        TextSpan(text: 'Новые позиции', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.21, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 222.0,
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 30.0,
                          children: [
                            FigBox(
                              width: 68.0,
                              height: 22.0,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: FigText(
                                      noWrap: true,
                                      width: 68.0,
                                      height: 22.0,
                                      opacity: 0.8,
                                      span: 
                                        TextSpan(text: 'Квартиры', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xffea812f)))
                                      ,
                                    )
                                  ),
                                  Positioned(
                                    left: 1.0, top: 22.0,
                                    child: FigSvg(
                                      width: 67.0, height: 1.0,
                                      vbLeft: 0.0, vbTop: -0.5, vbWidth: 67.0, vbHeight: 1.0,
                                      shapes: const [FigShape(d: _p20, fill: Color(0xffee9a59))],
                                    )
                                  ),
                                ],
                              )
                              ,
                            ),
                            FigText(
                              noWrap: true,
                              opacity: 0.8,
                              span: 
                                TextSpan(text: 'Участки', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xff7d7d7d)))
                              ,
                            ),
                            FigText(
                              noWrap: true,
                              opacity: 0.8,
                              span: 
                                TextSpan(text: 'Дома', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.467, color: const Color(0xff7d7d7d)))
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
    'M 6.5 0 L 6.5 -0.6 L 6.5 0 Z M 2.167 4.333 L 1.567 4.333 L 2.167 4.333 Z M 0 10.833 L -0.333 10.334 C -0.553 10.481 -0.651 10.754 -0.574 11.007 C -0.498 11.26 -0.264 11.433 0 11.433 L 0 10.833 Z M 13 10.833 L 13 11.433 C 13.264 11.433 13.498 11.26 13.574 11.007 C 13.651 10.754 13.553 10.481 13.333 10.334 L 13 10.833 Z M 10.833 4.333 L 11.433 4.333 C 11.433 3.025 10.914 1.77 9.988 0.845 L 9.564 1.269 L 9.14 1.693 C 9.84 2.394 10.233 3.343 10.233 4.333 L 10.833 4.333 Z M 9.564 1.269 L 9.988 0.845 C 9.063 -0.08 7.808 -0.6 6.5 -0.6 L 6.5 0 L 6.5 0.6 C 7.49 0.6 8.44 0.993 9.14 1.693 L 9.564 1.269 Z M 6.5 0 L 6.5 -0.6 C 5.192 -0.6 3.937 -0.08 3.012 0.845 L 3.436 1.269 L 3.86 1.693 C 4.56 0.993 5.51 0.6 6.5 0.6 L 6.5 0 Z M 3.436 1.269 L 3.012 0.845 C 2.086 1.77 1.567 3.025 1.567 4.333 L 2.167 4.333 L 2.767 4.333 C 2.767 3.343 3.16 2.394 3.86 1.693 L 3.436 1.269 Z M 2.167 4.333 L 1.567 4.333 C 1.567 6.773 1.045 8.297 0.557 9.192 C 0.312 9.641 0.072 9.938 -0.097 10.116 C -0.182 10.205 -0.249 10.265 -0.291 10.3 C -0.312 10.318 -0.327 10.329 -0.334 10.335 C -0.338 10.337 -0.339 10.339 -0.339 10.338 C -0.339 10.338 -0.339 10.338 -0.338 10.337 C -0.337 10.337 -0.336 10.336 -0.336 10.336 C -0.335 10.336 -0.335 10.335 -0.334 10.335 C -0.334 10.335 -0.334 10.335 -0.334 10.335 C -0.333 10.334 -0.333 10.334 0 10.833 C 0.333 11.333 0.333 11.332 0.334 11.332 C 0.334 11.332 0.334 11.332 0.334 11.331 C 0.335 11.331 0.336 11.331 0.336 11.33 C 0.338 11.329 0.339 11.328 0.341 11.327 C 0.344 11.325 0.348 11.323 0.352 11.32 C 0.36 11.314 0.37 11.306 0.383 11.297 C 0.407 11.279 0.439 11.254 0.477 11.222 C 0.554 11.159 0.656 11.066 0.774 10.941 C 1.011 10.691 1.313 10.311 1.61 9.766 C 2.205 8.675 2.767 6.95 2.767 4.333 L 2.167 4.333 Z M 0 10.833 L 0 11.433 L 13 11.433 L 13 10.833 L 13 10.233 L 0 10.233 L 0 10.833 Z M 13 10.833 C 13.333 10.334 13.333 10.334 13.334 10.335 C 13.334 10.335 13.334 10.335 13.334 10.335 C 13.335 10.335 13.335 10.336 13.336 10.336 C 13.336 10.336 13.337 10.337 13.338 10.337 C 13.339 10.338 13.339 10.338 13.339 10.338 C 13.339 10.339 13.338 10.337 13.334 10.335 C 13.327 10.329 13.312 10.318 13.291 10.3 C 13.249 10.265 13.182 10.205 13.097 10.116 C 12.928 9.938 12.688 9.641 12.443 9.192 C 11.955 8.297 11.433 6.773 11.433 4.333 L 10.833 4.333 L 10.233 4.333 C 10.233 6.95 10.795 8.675 11.39 9.766 C 11.687 10.311 11.989 10.691 12.226 10.941 C 12.344 11.066 12.446 11.159 12.523 11.222 C 12.561 11.254 12.593 11.279 12.617 11.297 C 12.63 11.306 12.64 11.314 12.648 11.32 C 12.652 11.323 12.656 11.325 12.659 11.327 C 12.661 11.328 12.662 11.329 12.664 11.33 C 12.664 11.331 12.665 11.331 12.666 11.331 C 12.666 11.332 12.666 11.332 12.666 11.332 C 12.667 11.332 12.667 11.333 13 10.833 Z';
const String _p4 =
    'M 3.018 0.301 C 3.184 0.014 3.087 -0.353 2.8 -0.519 C 2.513 -0.685 2.146 -0.588 1.98 -0.301 L 2.499 0 L 3.018 0.301 Z M 0.519 -0.301 C 0.353 -0.588 -0.014 -0.685 -0.301 -0.519 C -0.588 -0.353 -0.685 0.014 -0.519 0.301 L 0 0 L 0.519 -0.301 Z M 2.499 0 L 1.98 -0.301 C 1.906 -0.173 1.799 -0.067 1.671 0.007 L 1.97 0.527 L 2.27 1.047 C 2.58 0.868 2.838 0.611 3.018 0.301 L 2.499 0 Z M 1.97 0.527 L 1.671 0.007 C 1.543 0.081 1.397 0.12 1.249 0.12 L 1.249 0.72 L 1.249 1.32 C 1.608 1.32 1.959 1.226 2.27 1.047 L 1.97 0.527 Z M 1.249 0.72 L 1.249 0.12 C 1.102 0.12 0.956 0.081 0.828 0.007 L 0.529 0.527 L 0.229 1.047 C 0.539 1.226 0.891 1.32 1.249 1.32 L 1.249 0.72 Z M 0.529 0.527 L 0.828 0.007 C 0.7 -0.067 0.593 -0.173 0.519 -0.301 L 0 0 L -0.519 0.301 C -0.339 0.611 -0.081 0.868 0.229 1.047 L 0.529 0.527 Z';
const String _p5 =
    'M 12.444 6.222 L 11.444 6.222 C 11.444 9.106 9.106 11.444 6.222 11.444 L 6.222 12.444 L 6.222 13.444 C 10.211 13.444 13.444 10.211 13.444 6.222 L 12.444 6.222 Z M 6.222 12.444 L 6.222 11.444 C 3.338 11.444 1 9.106 1 6.222 L 0 6.222 L -1 6.222 C -1 10.211 2.233 13.444 6.222 13.444 L 6.222 12.444 Z M 0 6.222 L 1 6.222 C 1 3.338 3.338 1 6.222 1 L 6.222 0 L 6.222 -1 C 2.233 -1 -1 2.233 -1 6.222 L 0 6.222 Z M 6.222 0 L 6.222 1 C 9.106 1 11.444 3.338 11.444 6.222 L 12.444 6.222 L 13.444 6.222 C 13.444 2.233 10.211 -1 6.222 -1 L 6.222 0 Z';
const String _p6 =
    'M 2.676 4.09 C 3.067 4.481 3.7 4.481 4.09 4.09 C 4.481 3.7 4.481 3.067 4.09 2.676 L 3.383 3.383 L 2.676 4.09 Z M 0.707 -0.707 C 0.317 -1.098 -0.317 -1.098 -0.707 -0.707 C -1.098 -0.317 -1.098 0.317 -0.707 0.707 L 0 0 L 0.707 -0.707 Z M 3.383 3.383 L 4.09 2.676 L 0.707 -0.707 L 0 0 L -0.707 0.707 L 2.676 4.09 L 3.383 3.383 Z';
const String _p7 =
    'M 34 0 L 0 0 L 0 29.513 L 34 29.513 L 34 0 Z';
const String _p8 =
    'M 12.675 28.041 L 20.807 28.041 L 20.807 18.984 C 20.807 18.339 20.386 17.918 19.741 17.918 L 13.754 17.918 C 13.109 17.918 12.675 18.339 12.675 18.984 L 12.675 28.041 Z M 1.206 14.974 C 1.598 14.974 1.921 14.764 2.215 14.525 L 16.25 2.734 C 16.404 2.608 16.586 2.538 16.741 2.538 C 16.909 2.538 17.077 2.608 17.231 2.734 L 31.28 14.525 C 31.56 14.764 31.883 14.974 32.276 14.974 C 33.033 14.974 33.481 14.427 33.481 13.852 C 33.481 13.53 33.355 13.193 33.033 12.941 L 18.423 0.673 C 17.89 0.224 17.315 0 16.741 0 C 16.166 0 15.591 0.224 15.058 0.673 L 0.449 12.941 C 0.14 13.193 0 13.53 0 13.852 C 0 14.427 0.449 14.974 1.206 14.974 Z M 25.868 7.529 L 29.387 10.501 L 29.387 4.178 C 29.387 3.561 28.995 3.169 28.378 3.169 L 26.878 3.169 C 26.275 3.169 25.868 3.561 25.868 4.178 L 25.868 7.529 Z M 7.263 29.485 L 26.233 29.485 C 28.224 29.485 29.387 28.35 29.387 26.387 L 29.387 10.852 L 27.13 9.324 L 27.13 25.826 C 27.13 26.737 26.639 27.228 25.756 27.228 L 7.739 27.228 C 6.842 27.228 6.351 26.737 6.351 25.826 L 6.351 9.338 L 4.094 10.852 L 4.094 26.387 C 4.094 28.364 5.258 29.485 7.263 29.485 Z';
const String _p9 =
    'M 32 0 L 0 0 L 0 31.37 L 32 31.37 L 32 0 Z';
const String _p10 =
    'M 13.751 30.262 L 16.494 30.262 L 16.494 18.488 C 16.494 17.227 17.261 16.511 18.624 16.511 L 30.075 16.511 L 30.075 13.768 L 18.573 13.768 C 15.557 13.768 13.751 15.489 13.751 18.368 L 13.751 30.262 Z M 5.35 31.37 L 26.019 31.37 C 29.598 31.37 31.37 29.615 31.37 26.104 L 31.37 5.282 C 31.37 1.772 29.598 0 26.019 0 L 5.35 0 C 1.789 0 0 1.772 0 5.282 L 0 26.104 C 0 29.615 1.789 31.37 5.35 31.37 Z M 5.384 28.626 C 3.681 28.626 2.743 27.723 2.743 25.951 L 2.743 5.436 C 2.743 3.663 3.681 2.743 5.384 2.743 L 25.985 2.743 C 27.672 2.743 28.626 3.663 28.626 5.436 L 28.626 25.951 C 28.626 27.723 27.672 28.626 25.985 28.626 L 5.384 28.626 Z';
const String _p11 =
    'M 32 0 L 0 0 L 0 28.16 L 32 28.16 L 32 0 Z';
const String _p12 =
    'M 0 19.13 C 0 20.696 1.342 21.983 2.977 21.983 C 4.133 21.983 5.156 21.321 5.635 20.378 L 25.674 25.995 C 25.993 27.217 27.163 28.122 28.545 28.122 C 30.166 28.122 31.508 26.848 31.508 25.282 C 31.508 24.097 30.738 23.078 29.674 22.658 L 29.103 9.82 C 30.246 9.438 31.07 8.393 31.07 7.158 C 31.07 5.591 29.741 4.318 28.12 4.318 C 27.03 4.318 26.086 4.878 25.555 5.693 L 14.485 2.789 C 14.445 1.248 13.13 0 11.535 0 C 9.9 0 8.558 1.286 8.558 2.853 C 8.558 3.694 8.944 4.445 9.555 4.98 L 3.389 16.341 C 3.243 16.302 3.11 16.29 2.977 16.29 C 1.342 16.29 0 17.563 0 19.13 Z M 5.13 17.194 L 11.309 5.655 C 12.346 5.782 13.342 5.311 13.874 4.521 L 25.209 7.502 C 25.302 8.61 26.14 9.565 27.243 9.883 L 27.708 22.543 C 26.831 22.785 26.113 23.409 25.794 24.212 L 5.847 18.595 C 5.767 18.047 5.528 17.602 5.13 17.194 Z';
const String _p13 =
    'M 30.365 0 L 0 0 L 0 35.847 L 30.365 35.847 L 30.365 0 Z';
const String _p14 =
    'M 10.168 2.649 L 10.168 25.848 C 10.168 27.441 9.249 28.482 7.764 28.482 L 0 28.482 C 1.393 28.482 2.288 27.566 2.393 26.139 L 6.998 26.139 C 7.565 26.139 7.84 25.879 7.84 25.312 L 7.84 3.17 C 7.84 2.603 7.565 2.328 6.998 2.328 L 2.404 2.328 L 2.404 0 L 7.764 0 C 9.249 0 10.168 1.026 10.168 2.649 Z M 5.145 18.023 L 5.145 20.305 C 5.145 20.596 4.946 20.78 4.64 20.78 L 2.404 20.78 L 2.404 17.533 L 4.64 17.533 C 4.946 17.533 5.145 17.717 5.145 18.023 Z M 5.145 12.465 L 5.145 14.746 C 5.145 15.037 4.946 15.236 4.64 15.236 L 2.404 15.236 L 2.404 11.975 L 4.64 11.975 C 4.946 11.975 5.145 12.174 5.145 12.465 Z M 5.145 6.906 L 5.145 9.188 C 5.145 9.479 4.946 9.678 4.64 9.678 L 2.404 9.678 L 2.404 6.416 L 4.64 6.416 C 4.946 6.416 5.145 6.615 5.145 6.906 Z';
const String _p15 =
    'M 2.404 35.832 L 19.631 35.832 C 21.116 35.832 22.035 34.791 22.035 33.198 L 22.035 2.634 C 22.035 1.026 21.116 0 19.631 0 L 2.404 0 C 0.919 0 0 1.026 0 2.634 L 0 33.198 C 0 34.791 0.919 35.832 2.404 35.832 Z M 3.17 33.489 C 2.618 33.489 2.328 33.229 2.328 32.662 L 2.328 3.17 C 2.328 2.603 2.618 2.328 3.17 2.328 L 18.865 2.328 C 19.432 2.328 19.708 2.603 19.708 3.17 L 19.708 32.662 C 19.708 33.229 19.432 33.489 18.865 33.489 L 3.17 33.489 Z M 6.248 10.765 L 9.218 10.765 C 9.601 10.765 9.846 10.52 9.846 10.137 L 9.846 7.243 C 9.846 6.875 9.601 6.615 9.218 6.615 L 6.248 6.615 C 5.865 6.615 5.635 6.875 5.635 7.243 L 5.635 10.137 C 5.635 10.52 5.865 10.765 6.248 10.765 Z M 12.801 10.765 L 15.772 10.765 C 16.155 10.765 16.4 10.52 16.4 10.137 L 16.4 7.243 C 16.4 6.875 16.155 6.615 15.772 6.615 L 12.801 6.615 C 12.434 6.615 12.189 6.875 12.189 7.243 L 12.189 10.137 C 12.189 10.52 12.434 10.765 12.801 10.765 Z M 6.248 16.829 L 9.218 16.829 C 9.601 16.829 9.846 16.584 9.846 16.201 L 9.846 13.307 C 9.846 12.939 9.601 12.679 9.218 12.679 L 6.248 12.679 C 5.865 12.679 5.635 12.939 5.635 13.307 L 5.635 16.201 C 5.635 16.584 5.865 16.829 6.248 16.829 Z M 12.801 16.829 L 15.772 16.829 C 16.155 16.829 16.4 16.584 16.4 16.201 L 16.4 13.307 C 16.4 12.939 16.155 12.679 15.772 12.679 L 12.801 12.679 C 12.434 12.679 12.189 12.939 12.189 13.307 L 12.189 16.201 C 12.189 16.584 12.434 16.829 12.801 16.829 Z M 6.248 22.893 L 9.218 22.893 C 9.601 22.893 9.846 22.632 9.846 22.265 L 9.846 19.371 C 9.846 18.988 9.601 18.743 9.218 18.743 L 6.248 18.743 C 5.865 18.743 5.635 18.988 5.635 19.371 L 5.635 22.265 C 5.635 22.632 5.865 22.893 6.248 22.893 Z M 12.801 22.893 L 15.772 22.893 C 16.155 22.893 16.4 22.632 16.4 22.265 L 16.4 19.371 C 16.4 18.988 16.155 18.743 15.772 18.743 L 12.801 18.743 C 12.434 18.743 12.189 18.988 12.189 19.371 L 12.189 22.265 C 12.189 22.632 12.434 22.893 12.801 22.893 Z M 6.523 34.607 L 8.422 34.607 L 8.422 29.722 C 8.422 29.416 8.56 29.263 8.897 29.263 L 13.154 29.263 C 13.475 29.263 13.628 29.416 13.628 29.722 L 13.628 34.607 L 15.527 34.607 L 15.527 29.186 C 15.527 27.946 14.991 27.349 13.782 27.349 L 8.269 27.349 C 7.059 27.349 6.523 27.946 6.523 29.186 L 6.523 34.607 Z';
const String _p16 =
    'M 0 2 L -0.232 1.557 C -0.397 1.643 -0.5 1.814 -0.5 2 L 0 2 Z M 0 10 L -0.5 10 C -0.5 10.175 -0.409 10.337 -0.259 10.428 C -0.109 10.518 0.077 10.524 0.232 10.443 L 0 10 Z M 3.818 8 L 4.027 7.545 C 3.886 7.481 3.723 7.485 3.586 7.557 L 3.818 8 Z M 8.182 10 L 7.973 10.455 C 8.114 10.519 8.277 10.515 8.414 10.443 L 8.182 10 Z M 12 8 L 12.232 8.443 C 12.397 8.357 12.5 8.186 12.5 8 L 12 8 Z M 12 0 L 12.5 0 C 12.5 -0.175 12.409 -0.337 12.259 -0.428 C 12.109 -0.518 11.923 -0.524 11.768 -0.443 L 12 0 Z M 8.182 2 L 7.973 2.455 C 8.114 2.519 8.277 2.515 8.414 2.443 L 8.182 2 Z M 3.818 0 L 4.027 -0.455 C 3.886 -0.519 3.723 -0.515 3.586 -0.443 L 3.818 0 Z M 0 2 L -0.5 2 L -0.5 10 L 0 10 L 0.5 10 L 0.5 2 L 0 2 Z M 0 10 L 0.232 10.443 L 4.05 8.443 L 3.818 8 L 3.586 7.557 L -0.232 9.557 L 0 10 Z M 3.818 8 L 3.61 8.455 L 7.973 10.455 L 8.182 10 L 8.39 9.545 L 4.027 7.545 L 3.818 8 Z M 8.182 10 L 8.414 10.443 L 12.232 8.443 L 12 8 L 11.768 7.557 L 7.95 9.557 L 8.182 10 Z M 12 8 L 12.5 8 L 12.5 0 L 12 0 L 11.5 0 L 11.5 8 L 12 8 Z M 12 0 L 11.768 -0.443 L 7.95 1.557 L 8.182 2 L 8.414 2.443 L 12.232 0.443 L 12 0 Z M 8.182 2 L 8.39 1.545 L 4.027 -0.455 L 3.818 0 L 3.61 0.455 L 7.973 2.455 L 8.182 2 Z M 3.818 0 L 3.586 -0.443 L -0.232 1.557 L 0 2 L 0.232 2.443 L 4.05 0.443 L 3.818 0 Z';
const String _p17 =
    'M 0.5 0 C 0.5 -0.276 0.276 -0.5 0 -0.5 C -0.276 -0.5 -0.5 -0.276 -0.5 0 L 0 0 L 0.5 0 Z M -0.5 8 C -0.5 8.276 -0.276 8.5 0 8.5 C 0.276 8.5 0.5 8.276 0.5 8 L 0 8 L -0.5 8 Z M 0 0 L -0.5 0 L -0.5 8 L 0 8 L 0.5 8 L 0.5 0 L 0 0 Z';
const String _p18 =
    'M 13.765 0 L 0 0 L 0 12.235 L 13.765 12.235 L 13.765 0 Z';
const String _p19 =
    'M 0 3.896 C 0 6.643 2.429 9.346 6.267 11.668 C 6.409 11.752 6.614 11.842 6.756 11.842 C 6.899 11.842 7.103 11.752 7.253 11.668 C 11.084 9.346 13.513 6.643 13.513 3.896 C 13.513 1.612 11.86 0 9.655 0 C 8.396 0 7.376 0.568 6.756 1.438 C 6.151 0.574 5.117 0 3.858 0 C 1.653 0 0 1.612 0 3.896 Z M 1.095 3.896 C 1.095 2.18 2.266 1.038 3.844 1.038 C 5.123 1.038 5.858 1.793 6.294 2.438 C 6.477 2.696 6.593 2.767 6.756 2.767 C 6.92 2.767 7.022 2.69 7.219 2.438 C 7.689 1.806 8.396 1.038 9.669 1.038 C 11.247 1.038 12.417 2.18 12.417 3.896 C 12.417 6.295 9.743 8.881 6.899 10.674 C 6.831 10.72 6.784 10.752 6.756 10.752 C 6.729 10.752 6.682 10.72 6.62 10.674 C 3.769 8.881 1.095 6.295 1.095 3.896 Z';
const String _p20 =
    'M 0 -0.5 L 0 0 L 67 0 L 67 -0.5 L 67 -1 L 0 -1 L 0 -0.5 Z';
