// GENERATED from screens/Components.bundle.js — figma node StartScreen21.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Экран 10:1475 — 375.0×812.0
class Screen22Screen101475 extends StatelessWidget {
  const Screen22Screen101475({super.key});

  static const double designWidth = 375.0;
  static const double designHeight = 812.0;

  @override
  Widget build(BuildContext context) {
    return FigBox(
      width: 375.0,
      height: 812.0,
      color: const Color(0xfffefefe),
      radius: 8.0,
      clip: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0.0, top: -8.0,
            child: FigBox(
              width: 375.0,
              height: 820.0,
              radius: 8.0,
              bgImage: const FigBgImage('assets/figma/92b0d143df96c511.jpg'),
              overlays: const [LinearGradient(begin: Alignment(0.018, 1.004), end: Alignment(-0.018, -1.004), colors: [Color(0x26000000), Color(0x00666666)], stops: [0.241, 0.945])],
            )
          ),
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 25.0, top: 48.0,
            child: FigText(
              noWrap: true,
              width: 44.0,
              height: 25.0,
              span: 
                TextSpan(text: 'Flow', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.21, color: const Color(0xffffffff)))
              ,
            )
          ),
          Positioned(
            left: 316.0, top: 44.0,
            child: FigBox(
              width: 34.0,
              height: 34.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0.0, top: 0.0,
                    child: FigBox(
                      width: 34.0,
                      height: 34.0,
                      color: const Color(0xffffffff),
                      radius: 17.0,
                    )
                  ),
                  Positioned(
                    left: 8.0, top: 9.0,
                    child: FigBox(
                      width: 18.0,
                      height: 16.0,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0.0, top: 0.0,
                            child: Opacity(
                              opacity: 0.0,
                              child: FigSvg(
                                width: 18.0, height: 16.0,
                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 18.0, vbHeight: 16.0,
                                shapes: const [FigShape(d: _p3, fill: Color(0xccea812e))],
                              ),
                            )
                          ),
                          Positioned(
                            left: 0.0, top: 0.515,
                            child: FigSvg(
                              width: 17.671, height: 15.486,
                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 17.671, vbHeight: 15.486,
                              shapes: const [FigShape(d: _p4, fill: Color(0xccea812e))],
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
            left: -349.0, top: -89.0,
            child: FigSvg(
              width: 354.0, height: 33.0,
              vbLeft: 0.0, vbTop: 0.0, vbWidth: 354.0, vbHeight: 33.0,
              shapes: const [FigShape(d: _p5, fill: Color(0xffffffff))],
            )
          ),
          Positioned(
            left: 0.0, top: 728.0,
            child: FigBox(
              width: 375.0,
              height: 84.0,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0.0, top: 0.0,
                    child: FigBox(
                      width: 375.0,
                      height: 84.0,
                      color: const Color(0x33000000),
                      radius: 8.0,
                      blur: 32.0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 28.0, top: 11.0,
                            child: FigBox(
                              width: 320.0,
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FigBox(
                                      width: 37.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(0.0, -1.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 3.0,
                                          children: [
                                            FigBox(
                                              width: 24.0,
                                              height: 24.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 1.0, top: 2.0,
                                                    child: FigSvg(
                                                      width: 22.731, height: 20.0,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 22.731, vbHeight: 20.0,
                                                      shapes: const [FigShape(d: _p6, fill: Color(0xffffffff))],
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
                                            FigText(
                                              width: 37.0,
                                              span: 
                                                TextSpan(text: 'Главное', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xffffffff)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 39.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(0.0, -1.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 3.0,
                                          children: [
                                            FigBox(
                                              width: 24.0,
                                              height: 24.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 1.0, top: 2.0,
                                                    child: Opacity(
                                                      opacity: 0.0,
                                                      child: FigSvg(
                                                        width: 21.548, height: 20.0,
                                                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 21.548, vbHeight: 20.0,
                                                        shapes: const [FigShape(d: _p7, fill: Color(0xf2aeaeb2))],
                                                      ),
                                                    )
                                                  ),
                                                  Positioned(
                                                    left: 2.5, top: 2.0,
                                                    child: FigBox(
                                                      width: 19.443,
                                                      height: 19.268,
                                                      clip: true,
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Positioned(
                                                            left: 0.0, top: 0.0,
                                                            child: Opacity(
                                                              opacity: 0.0,
                                                              child: FigSvg(
                                                                width: 19.443, height: 19.268,
                                                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 19.443, vbHeight: 19.268,
                                                                shapes: const [FigShape(d: _p8, fill: Color(0xffacacb0))],
                                                              ),
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 0.0, top: 0.0,
                                                            child: FigSvg(
                                                              width: 19.082, height: 19.268,
                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 19.082, vbHeight: 19.268,
                                                              shapes: const [FigShape(d: _p9, fill: Color(0xffacacb0))],
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
                                              noWrap: true,
                                              span: 
                                                TextSpan(text: 'Поиск', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2aeaeb2)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 39.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(0.0, -1.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 3.0,
                                          children: [
                                            FigBox(
                                              width: 24.0,
                                              height: 24.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 1.0, top: 2.0,
                                                    child: Opacity(
                                                      opacity: 0.0,
                                                      child: FigSvg(
                                                        width: 21.548, height: 20.0,
                                                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 21.548, vbHeight: 20.0,
                                                        shapes: const [FigShape(d: _p7, fill: Color(0xf2aeaeb2))],
                                                      ),
                                                    )
                                                  ),
                                                  Positioned(
                                                    left: 1.0, top: 2.0,
                                                    child: FigSvg(
                                                      width: 21.203, height: 19.991,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 21.203, vbHeight: 19.991,
                                                      shapes: const [FigShape(d: _p10, fill: Color(0xf2aeaeb2))],
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
                                            FigText(
                                              noWrap: true,
                                              width: 39.0,
                                              span: 
                                                TextSpan(text: 'История', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2aeaeb2)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 42.0,
                                      child: FigOverflow(
                                        alignment: const Alignment(0.0, -1.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          spacing: 3.0,
                                          children: [
                                            FigBox(
                                              width: 24.0,
                                              height: 24.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 2.0, top: 2.0,
                                                    child: FigSvg(
                                                      width: 20.0, height: 20.0,
                                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 20.0, vbHeight: 20.0,
                                                      shapes: const [FigShape(d: _p11, fill: Color(0xf2aeaeb2))],
                                                    )
                                                  ),
                                                ],
                                              )
                                              ,
                                            ),
                                            FigText(
                                              width: 42.0,
                                              span: 
                                                TextSpan(text: 'Профиль', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2aeaeb2)))
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
                    )
                  ),
                ],
              )
              ,
            )
          ),
          Positioned(
            left: 16.0, top: 691.0,
            child: FigBox(
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 22.0,
                  children: [
                    FigBox(
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
                                TextSpan(text: '102 000\$', style: figStyle(fontSize: 22.504, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.225, color: const Color(0xffececec)))
                              ,
                            ),
                          ],
                        )
                        ,
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
                          spacing: 9.266,
                          children: [
                            FigText(
                              noWrap: true,
                              span: 
                                TextSpan(text: '3-комн.', style: figStyle(fontSize: 17.209, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.172, color: const Color(0xffececec)))
                              ,
                            ),
                            FigBox(
                              width: 5.295,
                              height: 5.295,
                              color: const Color(0xffd9d9d9),
                              radius: 2.648,
                            ),
                            FigText(
                              span: 
                                TextSpan(style: figStyle(fontSize: 17.209, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.172, color: const Color(0xffececec)), children: [
                                  TextSpan(text: '92м', style: figStyle(fontSize: 17.209, color: const Color(0xffececec))),
                                  figSuper('2', figStyle(fontSize: 12.39, color: const Color(0xffececec)), 17.209),
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
                                      shapes: const [FigShape(d: _p12, fill: Color(0xffececec))],
                                    )
                                  ),
                                  Positioned(
                                    left: 3.818, top: 0.0,
                                    child: FigSvg(
                                      width: 1.0, height: 8.0,
                                      vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                      shapes: const [FigShape(d: _p13, fill: Color(0xffececec))],
                                    )
                                  ),
                                  Positioned(
                                    left: 8.182, top: 2.0,
                                    child: FigSvg(
                                      width: 1.0, height: 8.0,
                                      vbLeft: -0.5, vbTop: 0.0, vbWidth: 1.0, vbHeight: 8.0,
                                      shapes: const [FigShape(d: _p13, fill: Color(0xffececec))],
                                    )
                                  ),
                                ],
                              )
                              ,
                            ),
                            FigText(
                              noWrap: true,
                              span: 
                                TextSpan(text: 'Технопарк', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xffececec)))
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
            left: 16.0, top: 634.0,
            child: FigBox(
              width: 253.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6.0,
                  children: [
                    FigBox(
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 6.0,
                          children: [
                            FigBox(
                              width: 24.0,
                              height: 24.0,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 2.0, top: 2.0,
                                    child: FigSvg(
                                      width: 20.0, height: 20.0,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 20.0, vbHeight: 20.0,
                                      shapes: const [FigShape(d: _p11, fill: Color(0xf2ffffff))],
                                    )
                                  ),
                                ],
                              )
                              ,
                            ),
                            FigText(
                              noWrap: true,
                              span: 
                                TextSpan(text: 'Садыр Жапаров', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2ffffff)))
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
                                      shapes: const [FigShape(d: _p14, fill: Color(0xfff4f3f3), evenOdd: true)],
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
                    FigText(
                      noWrap: true,
                      width: 253.0,
                      span: 
                        TextSpan(text: 'Сату́рн — шестая планета по удал......', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xffd1d1d1)))
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
    'M 18 0 L 0 0 L 0 16 L 18 16 L 18 0 Z';
const String _p4 =
    'M 0 5.094 C 0 8.687 3.176 12.221 8.195 15.258 C 8.382 15.367 8.649 15.486 8.835 15.486 C 9.022 15.486 9.289 15.367 9.485 15.258 C 14.494 12.221 17.671 8.687 17.671 5.094 C 17.671 2.109 15.509 0 12.626 0 C 10.98 0 9.645 0.742 8.835 1.881 C 8.043 0.751 6.691 0 5.045 0 C 2.162 0 0 2.109 0 5.094 Z M 1.433 5.094 C 1.433 2.851 2.963 1.358 5.027 1.358 C 6.7 1.358 7.661 2.345 8.23 3.188 C 8.471 3.526 8.622 3.618 8.835 3.618 C 9.049 3.618 9.182 3.517 9.44 3.188 C 10.054 2.362 10.98 1.358 12.644 1.358 C 14.708 1.358 16.238 2.851 16.238 5.094 C 16.238 8.232 12.741 11.614 9.022 13.959 C 8.933 14.018 8.871 14.06 8.835 14.06 C 8.8 14.06 8.737 14.018 8.657 13.959 C 4.929 11.614 1.433 8.232 1.433 5.094 Z';
const String _p5 =
    'M 0 0 L 354 0 L 354 33 L 0 33 L 0 0 Z';
const String _p6 =
    'M 8.618 19.019 L 14.113 19.019 L 14.113 12.087 C 14.113 11.649 13.827 11.363 13.389 11.363 L 9.351 11.363 C 8.904 11.363 8.618 11.649 8.618 12.087 L 8.618 19.019 Z M 4.895 20 L 17.779 20 C 19.131 20 19.921 19.229 19.921 17.895 L 19.921 7.373 L 18.388 6.325 L 18.388 17.505 C 18.388 18.124 18.055 18.467 17.455 18.467 L 5.218 18.467 C 4.609 18.467 4.276 18.124 4.276 17.505 L 4.276 6.335 L 2.743 7.373 L 2.743 17.895 C 2.743 19.229 3.533 20 4.895 20 Z M 0 9.401 C 0 9.792 0.305 10.163 0.819 10.163 C 1.086 10.163 1.305 10.02 1.505 9.858 L 11.037 1.859 C 11.246 1.669 11.503 1.669 11.713 1.859 L 21.245 9.858 C 21.435 10.02 21.654 10.163 21.921 10.163 C 22.369 10.163 22.731 9.887 22.731 9.43 C 22.731 9.144 22.635 8.954 22.435 8.782 L 12.522 0.45 C 11.818 -0.15 10.942 -0.15 10.227 0.45 L 0.305 8.782 C 0.095 8.954 0 9.182 0 9.401 Z M 17.531 5.107 L 19.921 7.125 L 19.921 2.726 C 19.921 2.307 19.655 2.04 19.236 2.04 L 18.217 2.04 C 17.807 2.04 17.531 2.307 17.531 2.726 L 17.531 5.107 Z';
const String _p7 =
    'M 21.548 0 L 0 0 L 0 20 L 21.548 20 L 21.548 0 Z';
const String _p8 =
    'M 19.443 0 L 0 0 L 0 19.268 L 19.443 19.268 L 19.443 0 Z';
const String _p9 =
    'M 0 7.793 C 0 12.09 3.496 15.586 7.793 15.586 C 9.492 15.586 11.045 15.039 12.324 14.121 L 17.129 18.935 C 17.354 19.16 17.646 19.268 17.959 19.268 C 18.623 19.268 19.082 18.77 19.082 18.115 C 19.082 17.803 18.965 17.52 18.76 17.315 L 13.984 12.51 C 14.99 11.201 15.586 9.57 15.586 7.793 C 15.586 3.496 12.09 0 7.793 0 C 3.496 0 0 3.496 0 7.793 Z M 1.67 7.793 C 1.67 4.414 4.414 1.67 7.793 1.67 C 11.172 1.67 13.916 4.414 13.916 7.793 C 13.916 11.172 11.172 13.916 7.793 13.916 C 4.414 13.916 1.67 11.172 1.67 7.793 Z';
const String _p10 =
    'M 0 17.175 C 0 19.03 0.923 19.991 2.816 19.991 L 18.275 19.991 C 20.233 19.991 21.203 19.03 21.203 17.11 L 21.203 2.89 C 21.203 0.97 20.233 0 18.275 0 L 7.04 0 C 5.091 0 4.112 0.97 4.112 2.89 L 4.112 7.338 L 1.883 7.338 C 0.699 7.338 0 7.981 0 9.091 L 0 17.175 Z M 1.501 17.175 L 1.501 9.38 C 1.501 9.035 1.706 8.839 2.051 8.839 L 4.112 8.839 L 4.112 17.175 C 4.112 17.949 3.543 18.489 2.816 18.489 C 2.079 18.489 1.501 17.921 1.501 17.175 Z M 5.296 18.489 C 5.501 18.089 5.613 17.622 5.613 17.082 L 5.613 2.974 C 5.613 2.005 6.135 1.501 7.068 1.501 L 18.247 1.501 C 19.179 1.501 19.702 2.005 19.702 2.974 L 19.702 17.026 C 19.702 17.995 19.179 18.489 18.247 18.489 L 5.296 18.489 Z M 8.037 5.557 L 17.296 5.557 C 17.622 5.557 17.874 5.296 17.874 4.97 C 17.874 4.653 17.622 4.41 17.296 4.41 L 8.037 4.41 C 7.702 4.41 7.45 4.653 7.45 4.97 C 7.45 5.296 7.702 5.557 8.037 5.557 Z M 8.037 8.839 L 17.296 8.839 C 17.622 8.839 17.874 8.587 17.874 8.27 C 17.874 7.944 17.622 7.692 17.296 7.692 L 8.037 7.692 C 7.702 7.692 7.45 7.944 7.45 8.27 C 7.45 8.587 7.702 8.839 8.037 8.839 Z M 8.587 15.487 L 11.002 15.487 C 11.711 15.487 12.14 15.058 12.14 14.35 L 12.14 12.131 C 12.14 11.413 11.711 10.984 11.002 10.984 L 8.587 10.984 C 7.869 10.984 7.441 11.413 7.441 12.131 L 7.441 14.35 C 7.441 15.058 7.869 15.487 8.587 15.487 Z M 13.818 12.131 L 17.287 12.131 C 17.622 12.131 17.865 11.888 17.865 11.571 C 17.865 11.235 17.622 10.984 17.287 10.984 L 13.818 10.984 C 13.483 10.984 13.24 11.235 13.24 11.571 C 13.24 11.888 13.483 12.131 13.818 12.131 Z M 13.818 15.487 L 17.287 15.487 C 17.622 15.487 17.865 15.245 17.865 14.928 C 17.865 14.601 17.622 14.34 17.287 14.34 L 13.818 14.34 C 13.483 14.34 13.24 14.601 13.24 14.928 C 13.24 15.245 13.483 15.487 13.818 15.487 Z';
const String _p11 =
    'M 2.805 20 L 17.195 20 C 19.096 20 20 19.46 20 18.272 C 20 15.443 16.211 11.35 10.006 11.35 C 3.789 11.35 0 15.443 0 18.272 C 0 19.46 0.904 20 2.805 20 Z M 2.267 18.369 C 1.969 18.369 1.843 18.294 1.843 18.067 C 1.843 16.296 4.751 12.981 10.006 12.981 C 15.249 12.981 18.157 16.296 18.157 18.067 C 18.157 18.294 18.042 18.369 17.745 18.369 L 2.267 18.369 Z M 10.006 10.011 C 12.73 10.011 14.951 7.721 14.951 4.935 C 14.951 2.171 12.742 0 10.006 0 C 7.292 0 5.06 2.214 5.06 4.957 C 5.072 7.732 7.281 10.011 10.006 10.011 Z M 10.006 8.38 C 8.334 8.38 6.903 6.868 6.903 4.957 C 6.903 3.078 8.311 1.631 10.006 1.631 C 11.711 1.631 13.108 3.056 13.108 4.935 C 13.108 6.847 11.689 8.38 10.006 8.38 Z';
const String _p12 =
    'M 0 2 L -0.232 1.557 C -0.397 1.643 -0.5 1.814 -0.5 2 L 0 2 Z M 0 10 L -0.5 10 C -0.5 10.175 -0.409 10.337 -0.259 10.428 C -0.109 10.518 0.077 10.524 0.232 10.443 L 0 10 Z M 3.818 8 L 4.027 7.545 C 3.886 7.481 3.723 7.485 3.586 7.557 L 3.818 8 Z M 8.182 10 L 7.973 10.455 C 8.114 10.519 8.277 10.515 8.414 10.443 L 8.182 10 Z M 12 8 L 12.232 8.443 C 12.397 8.357 12.5 8.186 12.5 8 L 12 8 Z M 12 0 L 12.5 0 C 12.5 -0.175 12.409 -0.337 12.259 -0.428 C 12.109 -0.518 11.923 -0.524 11.768 -0.443 L 12 0 Z M 8.182 2 L 7.973 2.455 C 8.114 2.519 8.277 2.515 8.414 2.443 L 8.182 2 Z M 3.818 0 L 4.027 -0.455 C 3.886 -0.519 3.723 -0.515 3.586 -0.443 L 3.818 0 Z M 0 2 L -0.5 2 L -0.5 10 L 0 10 L 0.5 10 L 0.5 2 L 0 2 Z M 0 10 L 0.232 10.443 L 4.05 8.443 L 3.818 8 L 3.586 7.557 L -0.232 9.557 L 0 10 Z M 3.818 8 L 3.61 8.455 L 7.973 10.455 L 8.182 10 L 8.39 9.545 L 4.027 7.545 L 3.818 8 Z M 8.182 10 L 8.414 10.443 L 12.232 8.443 L 12 8 L 11.768 7.557 L 7.95 9.557 L 8.182 10 Z M 12 8 L 12.5 8 L 12.5 0 L 12 0 L 11.5 0 L 11.5 8 L 12 8 Z M 12 0 L 11.768 -0.443 L 7.95 1.557 L 8.182 2 L 8.414 2.443 L 12.232 0.443 L 12 0 Z M 8.182 2 L 8.39 1.545 L 4.027 -0.455 L 3.818 0 L 3.61 0.455 L 7.973 2.455 L 8.182 2 Z M 3.818 0 L 3.586 -0.443 L -0.232 1.557 L 0 2 L 0.232 2.443 L 4.05 0.443 L 3.818 0 Z';
const String _p13 =
    'M 0.5 0 C 0.5 -0.276 0.276 -0.5 0 -0.5 C -0.276 -0.5 -0.5 -0.276 -0.5 0 L 0 0 L 0.5 0 Z M -0.5 8 C -0.5 8.276 -0.276 8.5 0 8.5 C 0.276 8.5 0.5 8.276 0.5 8 L 0 8 L -0.5 8 Z M 0 0 L -0.5 0 L -0.5 8 L 0 8 L 0.5 8 L 0.5 0 L 0 0 Z';
const String _p14 =
    'M 0.293 0.293 C -0.098 0.683 -0.098 1.317 0.293 1.707 L 4.586 6 L 0.293 10.293 C -0.098 10.683 -0.098 11.317 0.293 11.707 C 0.683 12.098 1.317 12.098 1.707 11.707 L 6.707 6.707 C 7.098 6.317 7.098 5.683 6.707 5.293 L 1.707 0.293 C 1.317 -0.098 0.683 -0.098 0.293 0.293 Z';
