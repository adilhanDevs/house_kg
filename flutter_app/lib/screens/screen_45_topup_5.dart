// GENERATED from screens/Components.bundle.js — figma node Frame48096303.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../fig/fig.dart';

/// Пополнение · 5 — 375.0×812.0
class Screen45Topup5 extends StatelessWidget {
  const Screen45Topup5({super.key});

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
                        TextSpan(text: context.l10n.addListingNext, style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.294, color: const Color(0xffffffff)))
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
            left: 20.0, top: 268.0,
            child: FigBox(
              width: 335.0,
              child: FigOverflow(
                alignment: const Alignment(0.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 8.0,
                  children: [
                    FigBox(
                      width: 335.0,
                      child: FigOverflow(
                        alignment: const Alignment(0.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 4.0,
                          children: [
                            FigText(
                              align: TextAlign.center,
                              width: 335.0,
                              span: 
                                TextSpan(text: 'Спасибо за пополнение!', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
                              ,
                            ),
                            FigText(
                              align: TextAlign.center,
                              width: 305.0,
                              span: 
                                TextSpan(text: context.l10n.topupWalletDescription, style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
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
                      color: const Color(0x334dba17),
                      radius: 8.0,
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
                            FigBox(
                              width: 26.0,
                              height: 16.0,
                              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
                            ),
                            FigText(
                              noWrap: true,
                              height: 16.0,
                              span: 
                                TextSpan(text: '+13200 Кирпичей', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.15, color: const Color(0xff4dba17)))
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
            left: 150.0, top: 178.0,
            child: FigBox(
              width: 74.406,
              height: 74.406,
              clip: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0.0, top: 0.0,
                    child: FigSvg(
                      width: 74.406, height: 74.406,
                      vbLeft: -3.5, vbTop: -3.5, vbWidth: 81.406, vbHeight: 81.406,
                      shapes: const [FigShape(d: _p3, fill: Color(0xffea812e), stroke: Color(0xff4dba17), strokeWidth: 5.952, roundJoin: true), FigShape(d: _p4)],
                    )
                  ),
                  Positioned(
                    left: 13.393, top: 13.393,
                    child: FigBox(
                      width: 47.62,
                      height: 47.62,
                      clip: true,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 12.159, top: 14.145,
                            child: FigBox(
                              width: 24.294,
                              height: 19.337,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: FigSvg(
                                      width: 24.294, height: 19.337,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 24.294, vbHeight: 19.337,
                                      shapes: const [FigShape(d: _p5, fill: Color(0xffffffff), evenOdd: true)],
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
        ],
      )
      ,
    );
  }
}

const String _p3 =
    'M 30.369 2.831 C 34.745 1.018 39.661 1.018 44.037 2.831 L 56.676 8.066 C 61.051 9.878 64.528 13.355 66.34 17.73 L 71.575 30.369 C 73.388 34.745 73.388 39.661 71.575 44.037 L 66.34 56.676 C 64.528 61.051 61.051 64.528 56.676 66.34 L 44.037 71.575 C 39.661 73.388 34.745 73.388 30.369 71.575 L 17.73 66.34 C 13.355 64.528 9.878 61.051 8.066 56.676 L 2.831 44.037 C 1.018 39.661 1.018 34.745 2.831 30.369 L 8.066 17.73 C 9.878 13.355 13.355 9.878 17.73 8.066 L 30.369 2.831 Z';
const String _p4 =
    'M 2.831 44.037 L -2.669 46.315 L 2.831 44.037 Z M 17.73 66.34 L 15.452 71.84 L 17.73 66.34 Z M 44.037 71.575 L 41.759 66.076 L 44.037 71.575 Z M 30.369 71.575 L 32.647 66.076 L 30.369 71.575 Z M 66.34 56.676 L 60.841 54.398 L 66.34 56.676 Z M 56.676 66.34 L 54.398 60.841 L 56.676 66.34 Z M 71.575 30.369 L 66.076 32.647 L 71.575 30.369 Z M 71.575 44.037 L 66.076 41.759 L 71.575 44.037 Z M 66.34 17.73 L 71.84 15.452 L 66.34 17.73 Z M 44.037 2.831 L 41.759 8.33 L 54.398 13.565 L 56.676 8.066 L 58.954 2.567 L 46.315 -2.669 L 44.037 2.831 Z M 66.34 17.73 L 60.841 20.008 L 66.076 32.647 L 71.575 30.369 L 77.075 28.091 L 71.84 15.452 L 66.34 17.73 Z M 71.575 44.037 L 66.076 41.759 L 60.841 54.398 L 66.34 56.676 L 71.84 58.954 L 77.075 46.315 L 71.575 44.037 Z M 56.676 66.34 L 54.398 60.841 L 41.759 66.076 L 44.037 71.575 L 46.315 77.075 L 58.954 71.84 L 56.676 66.34 Z M 30.369 71.575 L 32.647 66.076 L 20.008 60.841 L 17.73 66.34 L 15.452 71.84 L 28.091 77.075 L 30.369 71.575 Z M 8.066 56.676 L 13.565 54.398 L 8.33 41.759 L 2.831 44.037 L -2.669 46.315 L 2.567 58.954 L 8.066 56.676 Z M 2.831 30.369 L 8.33 32.647 L 13.565 20.008 L 8.066 17.73 L 2.567 15.452 L -2.669 28.091 L 2.831 30.369 Z M 17.73 8.066 L 20.008 13.565 L 32.647 8.33 L 30.369 2.831 L 28.091 -2.669 L 15.452 2.567 L 17.73 8.066 Z M 8.066 17.73 L 13.565 20.008 C 14.774 17.091 17.091 14.774 20.008 13.565 L 17.73 8.066 L 15.452 2.567 C 9.618 4.983 4.983 9.618 2.567 15.452 L 8.066 17.73 Z M 2.831 44.037 L 8.33 41.759 C 7.122 38.842 7.122 35.564 8.33 32.647 L 2.831 30.369 L -2.669 28.091 C -5.085 33.925 -5.085 40.481 -2.669 46.315 L 2.831 44.037 Z M 17.73 66.34 L 20.008 60.841 C 17.091 59.633 14.774 57.315 13.565 54.398 L 8.066 56.676 L 2.567 58.954 C 4.983 64.788 9.618 69.423 15.452 71.84 L 17.73 66.34 Z M 44.037 71.575 L 41.759 66.076 C 38.842 67.284 35.564 67.284 32.647 66.076 L 30.369 71.575 L 28.091 77.075 C 33.925 79.491 40.481 79.491 46.315 77.075 L 44.037 71.575 Z M 66.34 56.676 L 60.841 54.398 C 59.633 57.315 57.315 59.633 54.398 60.841 L 56.676 66.34 L 58.954 71.84 C 64.788 69.423 69.423 64.788 71.84 58.954 L 66.34 56.676 Z M 71.575 30.369 L 66.076 32.647 C 67.284 35.564 67.284 38.842 66.076 41.759 L 71.575 44.037 L 77.075 46.315 C 79.491 40.481 79.491 33.925 77.075 28.091 L 71.575 30.369 Z M 56.676 8.066 L 54.398 13.565 C 57.315 14.774 59.633 17.091 60.841 20.008 L 66.34 17.73 L 71.84 15.452 C 69.423 9.618 64.788 4.983 58.954 2.567 L 56.676 8.066 Z M 44.037 2.831 L 46.315 -2.669 C 40.481 -5.085 33.925 -5.085 28.091 -2.669 L 30.369 2.831 L 32.647 8.33 C 35.564 7.122 38.842 7.122 41.759 8.33 L 44.037 2.831 Z';
const String _p5 =
    'M 20.491 0.647 C 20.907 0.234 21.469 0.002 22.056 0 C 22.642 -0.002 23.206 0.228 23.625 0.638 C 24.044 1.049 24.284 1.608 24.294 2.194 C 24.304 2.781 24.083 3.347 23.678 3.772 L 11.797 18.623 C 11.593 18.843 11.346 19.02 11.072 19.142 C 10.798 19.265 10.503 19.331 10.202 19.336 C 9.902 19.342 9.604 19.287 9.326 19.175 C 9.048 19.062 8.795 18.895 8.583 18.683 L 0.71 10.808 C 0.491 10.603 0.315 10.357 0.193 10.083 C 0.071 9.809 0.006 9.514 0 9.214 C -0.005 8.914 0.05 8.617 0.162 8.339 C 0.275 8.061 0.442 7.808 0.654 7.596 C 0.866 7.384 1.118 7.217 1.396 7.105 C 1.674 6.993 1.972 6.938 2.272 6.943 C 2.571 6.948 2.867 7.014 3.141 7.136 C 3.414 7.258 3.661 7.434 3.865 7.653 L 10.098 13.882 L 20.434 0.712 C 20.452 0.689 20.472 0.667 20.494 0.647 L 20.491 0.647 Z';
