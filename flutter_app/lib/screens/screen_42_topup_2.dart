// GENERATED from screens/Components.bundle.js — figma node Frame48096303.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../fig/fig.dart';

/// Пополнение · 2 — 375.0×812.0
class _Pill extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;
  
  const _Pill({required this.text, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.0,
          fontFamily: 'SF Pro Display',
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.1,
        ),
      ),
    );
  }
}

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
            left: 24.0,
            right: 24.0,
            top: 421.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  context.l10n.brickSpendTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17.0, fontFamily: 'SF Pro Display', fontWeight: FontWeight.w600, height: 1.2, color: Color(0xff000000)),
                ),
                const SizedBox(height: 12),
                _Pill(text: context.l10n.brickSpendAds, bgColor: const Color(0x33ea812e), textColor: const Color(0xe0ea812e)),
                const SizedBox(height: 8),
                _Pill(text: context.l10n.brickSpendSubs, bgColor: const Color(0x33ea812e), textColor: const Color(0xe0ea812e)),
                const SizedBox(height: 24),
                Text(
                  context.l10n.brickEarnTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17.0, fontFamily: 'SF Pro Display', fontWeight: FontWeight.w600, height: 1.2, color: Color(0xff000000)),
                ),
                const SizedBox(height: 12),
                _Pill(text: context.l10n.brickEarnTopup, bgColor: const Color(0x334dba17), textColor: const Color(0xff4dba17)),
                const SizedBox(height: 8),
                _Pill(text: context.l10n.brickEarnRef, bgColor: const Color(0x334dba17), textColor: const Color(0xff4dba17)),
                const SizedBox(height: 8),
                _Pill(text: context.l10n.brickEarnQuests, bgColor: const Color(0x334dba17), textColor: const Color(0xff4dba17)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

