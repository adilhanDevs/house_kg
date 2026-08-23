// GENERATED from screens/Components.bundle.js — figma node StartScreen4.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Онбординг 3 — 375.0×812.0
class Screen04Onboarding3 extends StatelessWidget {
  const Screen04Onboarding3({super.key});

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
            left: 0.0, top: -19.0,
            child: FigBox(
              width: 393.0,
              height: 572.0,
              bgImage: const FigBgImage('assets/figma/fb9bf9cc77816ef6.jpg'),
            )
          ),
          Positioned(
            left: 0.0, top: 0.0,
            child: FigBox(
              width: 377.0,
              height: 813.0,
              color: const Color(0x26000000),
            )
          ),
          Positioned(
            left: 0.0, top: 496.0,
            child: FigBox(
              width: 375.0,
              height: 347.0,
              color: const Color(0xffffffff),
              radius: 22.0,
              shadows: const [BoxShadow(color: Color(0x14000000), offset: Offset(0.0, 0.0), blurRadius: 4.0, spreadRadius: 0.0), BoxShadow(color: Color(0x14000000), offset: Offset(0.0, 4.0), blurRadius: 48.0, spreadRadius: 0.0)],
            )
          ),
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 25.0, top: 528.0,
            child: FigText(
              align: TextAlign.center,
              width: 325.0,
              height: 55.0,
              span: 
                TextSpan(text: 'Сату́рн — шестая планета \nпо удалённости от Солнца', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 22.0, top: 580.0,
            child: FigText(
              align: TextAlign.center,
              width: 332.0,
              height: 60.0,
              span: 
                TextSpan(text: 'Сату́рн — шестая планета по удалённости от Солнца и вторая по размерам планета в Солнечной системе после Юпитера.', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff7d7d7d)))
              ,
            )
          ),
          Positioned(
            left: 31.0, top: 670.0,
            child: FigBox(
              width: 314.0,
              color: const Color(0xffea812e),
              radius: 8.0,
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
            left: 158.0, top: 752.0,
            child: FigBox(
              color: const Color(0x6699a2ad),
              radius: 4.0,
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
                      shapes: const [FigShape(d: _p3, fill: Color(0xffc4c9cf))],
                    ),
                    Opacity(
                      opacity: 0.3,
                      child: FigSvg(
                        width: 8.0, height: 8.0,
                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 8.0, vbHeight: 8.0,
                        shapes: const [FigShape(d: _p3, fill: Color(0xff99a2ad))],
                      ),
                    ),
                    FigSvg(
                      width: 8.0, height: 8.0,
                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 8.0, vbHeight: 8.0,
                      shapes: const [FigShape(d: _p3, fill: Color(0xffea812e))],
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
    'M 0 4 C 0 1.791 1.791 0 4 0 L 4 0 C 6.209 0 8 1.791 8 4 L 8 4 C 8 6.209 6.209 8 4 8 L 4 8 C 1.791 8 0 6.209 0 4 L 0 4 Z';
