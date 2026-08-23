// GENERATED from screens/Components.bundle.js — figma node StartScreen12.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Фильтр — 375.0×812.0
class Screen12Filter extends StatelessWidget {
  const Screen12Filter({super.key});

  static const double designWidth = 375.0;
  static const double designHeight = 812.0;

  /// Where the mockup draws the tab bar on this screen.
  static const Offset tabBarAt = Offset(0.0, 728.0);

  /// Which tab the mockup draws highlighted here.
  static const int mockupTab = 1;

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
          // Статус-бар рисует система — полоса 0..48 остаётся пустой.
          Positioned(
            left: 25.0, top: 58.0,
            child: FigBox(
              width: 335.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4.0,
                  children: [
                    FigText(
                      width: 335.0,
                      span: 
                        TextSpan(text: 'Фильтр', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.21, color: const Color(0xff000000)))
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
            left: 25.0, top: 161.0,
            child: FigBox(
              width: 309.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10.0,
                  children: [
                    FigText(
                      width: 309.0,
                      span: 
                        TextSpan(text: 'Тип недвижимости', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 309.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8.0,
                          children: [
                            FigBox(
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
                                      insets: const [FigInset(Color(0x807d7d7d), 1.0)],
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 0.0, top: 0.0,
                                            child: FigText(
                                              width: 52.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: 'Комната', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
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
                                      insets: const [FigInset(Color(0x807d7d7d), 1.0)],
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
                            ),
                            FigBox(
                              child: FigOverflow(
                                freeWidth: true,
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 8.0,
                                  children: [
                                    FigBox(
                                      width: 87.0,
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
                                              width: 57.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: 'Вторичка', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 91.0,
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
                                              width: 61.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '103 серия', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
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
            )
          ),
          Positioned(
            left: 25.0, top: 281.0,
            child: FigBox(
              width: 309.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10.0,
                  children: [
                    FigText(
                      width: 309.0,
                      span: 
                        TextSpan(text: 'Количество комнат', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 309.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8.0,
                          children: [
                            FigBox(
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
                                      width: 65.0,
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
                                              width: 35.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '1 ком.', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 67.0,
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
                                              width: 37.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '2 ком.', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 67.0,
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
                                              width: 37.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '3 ком.', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 67.0,
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
                                              width: 37.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '4 ком.', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
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
            )
          ),
          Positioned(
            left: 25.0, top: 363.0,
            child: FigBox(
              width: 408.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10.0,
                  children: [
                    FigText(
                      width: 408.0,
                      span: 
                        TextSpan(text: 'Квадратура', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 365.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, -1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8.0,
                          children: [
                            FigBox(
                              width: 365.0,
                              child: FigOverflow(
                                freeWidth: true,
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 8.0,
                                  children: [
                                    FigBox(
                                      width: 68.0,
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
                                              width: 38.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '35-45', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0ea812e)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 68.0,
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
                                              width: 38.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '45-55', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 67.0,
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
                                              width: 37.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '65-75', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 67.0,
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
                                              width: 37.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: '75-85', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                              ,
                                            )
                                          ),
                                        ],
                                      )
                                      ,
                                    ),
                                    FigBox(
                                      width: 186.0,
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
                                              width: 156.0,
                                              height: 14.0,
                                              span: 
                                                TextSpan(text: 'Введите свою квадратуру', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
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
            )
          ),
          Positioned(
            left: 25.0, top: 445.0,
            child: FigBox(
              width: 288.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 13.0,
                  children: [
                    FigText(
                      width: 288.0,
                      span: 
                        TextSpan(text: 'Цена', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 288.0,
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 8.0,
                          children: [
                            FigBox(
                              width: 158.0,
                              height: 36.0,
                              color: const Color(0x1fa1a1aa),
                              radius: 10.0,
                              padding: const EdgeInsets.fromLTRB(12.0, 7.0, 12.0, 7.0),
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: FigText(
                                        noWrap: true,
                                        height: 22.0,
                                        span: 
                                          TextSpan(text: 'Цена от', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 400, height: 1.467, letterSpacing: -0.43, color: const Color(0x993c3c43)))
                                        ,
                                      )
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
                              width: 158.0,
                              height: 36.0,
                              color: const Color(0x1fa1a1aa),
                              radius: 10.0,
                              padding: const EdgeInsets.fromLTRB(12.0, 7.0, 12.0, 7.0),
                              child: FigOverflow(
                                alignment: const Alignment(-1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: FigText(
                                        noWrap: true,
                                        height: 22.0,
                                        span: 
                                          TextSpan(text: 'Цена до', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 400, height: 1.467, letterSpacing: -0.43, color: const Color(0x993c3c43)))
                                        ,
                                      )
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
            left: 25.0, top: 533.581,
            child: FigText(
              width: 288.0,
              height: 20.0,
              span: 
                TextSpan(text: 'Продавец', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 25.0, top: 563.0,
            child: FigBox(
              width: 324.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12.0,
                  children: [
                    FigBox(
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
                                TextSpan(text: 'Только собственник', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, letterSpacing: -0.15, color: const Color(0xff85858a)))
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
                                      shapes: const [FigShape(d: _p7, fill: Color(0xffffffff))],
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
                    ),
                    FigBox(
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
                                TextSpan(text: 'Риелторы', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, letterSpacing: -0.15, color: const Color(0xff85858a)))
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
                                      shapes: const [FigShape(d: _p7, fill: Color(0xffffffff))],
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
                    ),
                    FigBox(
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
                                TextSpan(text: 'Агенство недвижимости', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, letterSpacing: -0.15, color: const Color(0xff85858a)))
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
                                      shapes: const [FigShape(d: _p7, fill: Color(0xffffffff))],
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

const String _p7 =
    'M 0 6.097 C 0 2.73 2.73 0 6.097 0 L 6.097 0 C 9.464 0 12.194 2.73 12.194 6.097 L 12.194 6.097 C 12.194 9.464 9.464 12.194 6.097 12.194 L 6.097 12.194 C 2.73 12.194 0 9.464 0 6.097 L 0 6.097 Z';
