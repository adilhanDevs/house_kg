// GENERATED from screens/Components.bundle.js — figma node Frame48096303.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../fig/fig.dart';

/// Пополнение · 2 — 375.0×812.0
class Screen42Topup2 extends StatelessWidget {
  const Screen42Topup2({super.key});

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
            left: 143.0, top: 303.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 41.0, top: 279.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 21.0, top: 207.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 6.0, top: 141.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 110.0, top: 145.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 133.0, top: 213.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 233.0, top: 246.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 233.0, top: 158.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 321.0, top: 197.0,
            child: FigBox(
              width: 111.0,
              height: 77.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 24.0, top: 55.0,
            child: FigText(
              noWrap: true,
              width: 185.0,
              height: 25.0,
              span: 
                TextSpan(text: context.l10n.brickSystemTitle, style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 24.0, top: 80.0,
            child: FigText(
              width: 335.0,
              height: 60.0,
              span: 
                TextSpan(text: context.l10n.topupWalletDescription, style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
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
            left: 75.0, top: 421.0,
            child: FigBox(
              width: 225.0,
              child: FigOverflow(
                alignment: const Alignment(0.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 16.0,
                  children: [
                    FigBox(
                      width: 202.0,
                      child: FigOverflow(
                        alignment: const Alignment(0.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 8.0,
                          children: [
                            FigText(
                              align: TextAlign.center,
                              width: 202.0,
                              span: 
                                TextSpan(text: context.l10n.brickSpendTitle, style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
                              ,
                            ),
                            FigBox(
                              width: 142.0,
                              child: FigOverflow(
                                alignment: const Alignment(0.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 8.0,
                                  children: [
                                    FigBox(
                                      width: 82.0,
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
                                              width: 52.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: context.l10n.brickSpendAds, style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 142.0,
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
                                              width: 112.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: context.l10n.brickSpendSubs, style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
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
                      width: 225.0,
                      child: FigOverflow(
                        alignment: const Alignment(0.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 8.0,
                          children: [
                            FigText(
                              align: TextAlign.center,
                              noWrap: true,
                              width: 225.0,
                              span: 
                                TextSpan(text: context.l10n.brickEarnTitle, style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
                              ,
                            ),
                            FigBox(
                              width: 166.0,
                              child: FigOverflow(
                                alignment: const Alignment(0.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 8.0,
                                  children: [
                                    FigBox(
                                      width: 166.0,
                                      height: 30.0,
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
                                            FigText(
                                              noWrap: true,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: context.l10n.brickEarnTopup, style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff4dba17)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 166.0,
                                      height: 30.0,
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
                                            FigText(
                                              noWrap: true,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: context.l10n.brickEarnRef, style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff4dba17)))
                                              ,
                                            ),
                                          ],
                                        )
                                        ,
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      height: 30.0,
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
                                            FigText(
                                              noWrap: true,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: context.l10n.brickEarnQuests, style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.13, color: const Color(0xff4dba17)))
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
        ],
      )
      ,
    );
  }
}

