// GENERATED from screens/Components.bundle.js — figma node StartScreen.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Сплэш — 375.0×812.0
class Screen01Splash extends StatelessWidget {
  const Screen01Splash({super.key});

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
            left: 25.0, top: 480.0,
            child: FigText(
              align: TextAlign.center,
              width: 325.0,
              height: 48.0,
              span: 
                TextSpan(text: 'Сату́рн — шестая планета\nпо удалённости от Солнца', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.333, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 137.0, top: 350.0,
            child: FigSvg(
              width: 102.222, height: 111.515,
              vbLeft: 0.0, vbTop: 0.0, vbWidth: 102.222, vbHeight: 111.515,
              shapes: const [FigShape(d: _p3, fill: Color(0xffea812e))],
            )
          ),
        ],
      )
      ,
    );
  }
}

const String _p3 =
    'M 7.088 87.482 L 46.934 110.288 C 49.769 111.924 52.453 111.924 55.339 110.288 L 95.134 87.482 C 99.792 84.771 102.222 82.112 102.222 74.8 L 102.222 34.3 C 102.222 28.982 100.298 25.709 96.045 23.203 L 60.199 2.646 C 54.073 -0.882 48.149 -0.882 42.023 2.646 L 6.228 23.203 C 1.924 25.709 0 28.982 0 34.3 L 0 74.8 C 0 82.112 2.481 84.771 7.088 87.482 Z M 11.645 80.731 C 8.708 79.044 7.696 77.356 7.696 74.544 L 7.696 35.936 L 47.137 58.692 L 47.137 101.135 L 11.645 80.731 Z M 90.628 80.731 L 55.086 101.135 L 55.086 58.692 L 94.526 35.936 L 94.526 74.544 C 94.526 77.356 93.514 79.044 90.628 80.731 Z M 51.136 51.533 L 12.05 29.186 L 27.695 20.135 L 66.781 42.584 L 51.136 51.533 Z M 74.933 37.93 L 35.694 15.533 L 45.415 9.959 C 49.314 7.709 52.909 7.658 56.858 9.959 L 90.223 29.186 L 74.933 37.93 Z';
