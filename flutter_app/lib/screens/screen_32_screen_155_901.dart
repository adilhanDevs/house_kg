// GENERATED from screens/Components.bundle.js — figma node StartScreen31.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Экран 155:901 — 375.0×795.0
class Screen32Screen155901 extends StatelessWidget {
  const Screen32Screen155901({super.key});

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
            left: 24.0, top: 503.0,
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
            left: 24.0, top: 607.0,
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
                        TextSpan(text: 'Будет списано: 780 кирпичей', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 0.667, letterSpacing: -0.21, color: const Color(0xffec8d42)))
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
            left: 24.0, top: 335.0,
            child: FigBox(
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
            )
          ),
          Positioned(
            left: 24.0, top: 191.0,
            child: FigBox(
              width: 337.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 9.0,
                  children: [
                    FigText(
                      width: 337.0,
                      span: 
                        TextSpan(text: 'Примерный бюджет', style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                      ,
                    ),
                    FigBox(
                      width: 337.0,
                      child: FigOverflow(
                        freeWidth: true,
                        alignment: const Alignment(-1.0, -1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 7.0,
                          children: [
                            FigBox(
                              width: 164.0,
                              color: const Color(0xffea812e),
                              radius: 8.0,
                              blur: 2.0,
                              padding: const EdgeInsets.fromLTRB(15.0, 9.0, 15.0, 6.0),
                              child: FigOverflow(
                                freeWidth: true,
                                alignment: const Alignment(-1.0, -1.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 4.0,
                                  children: [
                                    FigBox(
                                      width: 26.0,
                                      height: 18.0,
                                      bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
                                    ),
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Списать кирпичи', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xffffffff)))
                                      ,
                                    ),
                                  ],
                                )
                                ,
                              )
                              ,
                            ),
                            FigBox(
                              width: 196.0,
                              radius: 8.0,
                              opacity: 0.6,
                              blur: 2.0,
                              padding: const EdgeInsets.fromLTRB(15.0, 9.0, 15.0, 7.0),
                              insets: const [FigInset(Color(0x807d7d7d), 1.0)],
                              child: FigOverflow(
                                freeWidth: true,
                                alignment: const Alignment(-1.0, -1.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 4.0,
                                  children: [
                                    FigBox(
                                      width: 26.0,
                                      height: 18.0,
                                      bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
                                    ),
                                    FigText(
                                      noWrap: true,
                                      span: 
                                        TextSpan(text: 'Пополнение кошелька', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
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
            left: 24.0, top: 272.0,
            child: Opacity(
              opacity: 0.6,
              child: FigSvg(
                width: 323.0, height: 1.0,
                vbLeft: 0.0, vbTop: -0.5, vbWidth: 323.0, vbHeight: 1.0,
                shapes: const [FigShape(d: _p3, fill: Color(0xff85858a))],
              ),
            )
          ),
          Positioned(
            left: 24.0, top: 290.0,
            child: FigBox(
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
                                TextSpan(text: 'Ваш баланс: 8938 кирпичей', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.15, color: const Color(0xff4dba17)))
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
            left: 24.0, top: 412.0,
            child: FigBox(
              width: 325.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5.0,
                  children: [
                    FigBox(
                      width: 325.0,
                      height: 18.0,
                      child: FigOverflow(
                        alignment: const Alignment(-1.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FigText(
                              noWrap: true,
                              height: 18.0,
                              span: 
                                TextSpan(text: 'Использовать точное продвижение', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, letterSpacing: -0.15, color: const Color(0xff85858a)))
                              ,
                            ),
                            FigBox(
                              width: 30.0,
                              height: 18.0,
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
                                      shapes: const [FigShape(d: _p4, fill: Color(0xffffffff))],
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
                      width: 325.0,
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
                                      shapes: const [FigShape(d: _p4, fill: Color(0xffffffff))],
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
                      width: 325.0,
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
                                TextSpan(text: 'Использовать Whatsapp базу', style: figStyle(fontSize: 15.0, family: FigFont.display, weight: 500, height: 1.0, letterSpacing: -0.15, color: const Color(0xff85858a)))
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
                                      shapes: const [FigShape(d: _p4, fill: Color(0xffffffff))],
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
          Positioned(
            left: 25.0, top: 634.0,
            child: FigBox(
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
                    )
                  ),
                  Positioned(
                    left: 72.0, top: 25.0,
                    child: FigText(
                      noWrap: true,
                      width: 182.0,
                      height: 14.0,
                      span: 
                        TextSpan(text: 'Реклама подписки', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 0.667, letterSpacing: -0.21, color: const Color(0xffec8d42)))
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
    'M 0 -0.5 L 0 0 L 323 0 L 323 -0.5 L 323 -1 L 0 -1 L 0 -0.5 Z';
const String _p4 =
    'M 0 6.097 C 0 2.73 2.73 0 6.097 0 L 6.097 0 C 9.464 0 12.194 2.73 12.194 6.097 L 12.194 6.097 C 12.194 9.464 9.464 12.194 6.097 12.194 L 6.097 12.194 C 2.73 12.194 0 9.464 0 6.097 L 0 6.097 Z';
