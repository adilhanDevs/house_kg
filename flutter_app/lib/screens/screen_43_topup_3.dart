// GENERATED from screens/Components.bundle.js — figma node Frame48096303.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../fig/fig.dart';

/// Пополнение · 3 — 375.0×812.0
class Screen43Topup3 extends StatelessWidget {
  const Screen43Topup3({super.key});

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
            left: 24.0, top: 55.0,
            child: FigText(
              noWrap: true,
              width: 222.0,
              height: 25.0,
              span: 
                TextSpan(text: context.l10n.topupWalletTitle, style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, color: const Color(0xff000000)))
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
            left: 24.0, top: 629.0,
            child: FigBox(
              width: 325.0,
              child: FigOverflow(
                alignment: const Alignment(-1.0, -1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8.0,
                  children: [
                    FigText(
                      width: 325.0,
                      span: 
                        TextSpan(text: context.l10n.topupYourBudget, style: figStyle(fontSize: 17.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.17, color: const Color(0xff000000)))
                      ,
                    ),
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
                                        TextSpan(text: context.l10n.topupEnterAmount, style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe07d7d7d)))
                                      ,
                                    )
                                  ),
                                ],
                              )
                              ,
                            ),
                            FigBox(
                              width: 55.0,
                              height: 30.0,
                              color: const Color(0xffea812e),
                              radius: 8.0,
                              opacity: 0.6,
                              blur: 2.0,
                              padding: const EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 8.0),
                              insets: const [FigInset(Color(0xffec8d42), 1.0)],
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: FigText(
                                      noWrap: true,
                                      width: 25.0,
                                      height: 14.0,
                                      span: 
                                        TextSpan(text: 'KGS', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.077, letterSpacing: 0.065, color: const Color(0xe0fffefe)))
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
            )
          ),
          Positioned(
            left: 24.0, top: 159.0,
            child: FigText(
              noWrap: true,
              width: 150.0,
              height: 57.0,
              span: 
                TextSpan(text: "", style: figStyle(fontSize: 48.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.48, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 24.0, top: 222.0,
            child: FigText(
              noWrap: true,
              width: 78.0,
              height: 32.0,
              span: 
                TextSpan(text: "", style: figStyle(fontSize: 27.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.27, color: const Color(0xff000000)))
              ,
            )
          ),
          Positioned(
            left: 230.0, top: 227.0,
            child: FigBox(
              width: 27.0,
              height: 19.0,
              bgImage: const FigBgImage('assets/figma/7d929ed14946ddce.png', x: 0.543, y: 0.488, wFactor: 1.622, hFactor: 1.558),
            )
          ),
          Positioned(
            left: 179.0, top: 159.0,
            child: FigText(
              noWrap: true,
              width: 87.0,
              height: 57.0,
              span: 
                TextSpan(text: context.l10n.som, style: figStyle(fontSize: 48.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.48, color: const Color(0xff7d7d7d)))
              ,
            )
          ),
          Positioned(
            left: 106.0, top: 220.0,
            child: FigText(
              noWrap: true,
              width: 120.0,
              height: 32.0,
              span: 
                TextSpan(text: context.l10n.bricksGenitive, style: figStyle(fontSize: 27.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.27, color: const Color(0xff7d7d7d)))
              ,
            )
          ),
          Positioned(
            left: 0.0, top: 0.0,
            child: Transform(
              transform: Matrix4(0.866, -0.5, 0.0, 0.0, 0.866, 0.5, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 164.0, 462.566, 0.0, 1.0),
              child: FigBox(
                width: 257.094,
                height: 166.817,
                radius: 14.13,
                clip: true,
                padding: const EdgeInsets.fromLTRB(1.57, 0.393, 0.393, 1.57),
                shadows: const [BoxShadow(color: Color(0x33000000), offset: Offset(0.0, 7.85), blurRadius: 15.7, spreadRadius: -6.28)],
                border: const Border(top: BorderSide(color: Color(0x99ffffff), width: 0.393), right: BorderSide(color: Color(0x99ffffff), width: 0.393), bottom: BorderSide(color: Color(0x99ffffff), width: 1.57), left: BorderSide(color: Color(0x99ffffff), width: 1.57)),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FigOverflow(
                      alignment: const Alignment(-1.0, -1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8.0,
                        children: [
                        ],
                      )
                      ,
                    ),
                    Positioned(
                      left: 48.0, top: 48.0,
                      child: Transform(
                        transform: Matrix4(0.393, 0.0, 0.0, 0.0, 0.0, 0.393, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0),
                        child: FigBox(
                          width: 554.0,
                          height: 316.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FigBox(
                                width: 136.0,
                                height: 48.0,
                                clip: true,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: 0.0, top: 0.0,
                                      child: FigBox(
                                        width: 77.73,
                                        height: 48.0,
                                        clip: true,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned(
                                              left: 28.36, top: 5.137,
                                              child: FigSvg(
                                                width: 21.016, height: 37.716,
                                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 21.016, vbHeight: 37.716,
                                                shapes: const [FigShape(d: _p3, fill: Color(0xffff5f00))],
                                              )
                                            ),
                                            Positioned(
                                              left: 0.0, top: 0.0,
                                              child: FigSvg(
                                                width: 38.901, height: 48.0,
                                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 38.901, vbHeight: 48.0,
                                                shapes: const [FigShape(d: _p4, fill: Color(0xffeb001b))],
                                              )
                                            ),
                                            Positioned(
                                              left: 38.901, top: 0.0,
                                              child: FigSvg(
                                                width: 38.829, height: 47.983,
                                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 38.829, vbHeight: 47.983,
                                                shapes: const [FigShape(d: _p5, fill: Color(0xfff79e1b))],
                                              )
                                            ),
                                            Positioned(
                                              left: 74.994, top: 37.921,
                                              child: FigSvg(
                                                width: 2.001, height: 0.933,
                                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 2.001, vbHeight: 0.933,
                                                shapes: const [FigShape(d: _p6, fill: Color(0xfff79e1b))],
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
                                width: 554.0,
                                height: 138.0,
                                child: FigOverflow(
                                  alignment: const Alignment(-1.0, -1.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    spacing: 80.0,
                                    children: [
                                      FigText(
                                        noWrap: true,
                                        span: 
                                          TextSpan(text: '5278 0958 0912 6530', style: figStyle(fontSize: 48.0, weight: 700, height: 0.033, color: const Color(0xff262626)))
                                        ,
                                      ),
                                      FigBox(
                                        width: 554.0,
                                        child: FigOverflow(
                                          alignment: const Alignment(-1.0, -1.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              FigText(
                                                noWrap: true,
                                                span: 
                                                  TextSpan(text: 'AZAMAT', style: figStyle(fontSize: 32.0, weight: 500, height: 0.05, color: const Color(0xff262626)))
                                                ,
                                              ),
                                              FigText(
                                                noWrap: true,
                                                span: 
                                                  TextSpan(text: '05/22', style: figStyle(fontSize: 24.0, weight: 500, height: 0.067, color: const Color(0xff262626)))
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
              )
              ,
            )
          ),
          Positioned(
            left: 0.0, top: 0.0,
            child: Transform(
              transform: Matrix4(0.866, -0.5, 0.0, 0.0, 0.866, 0.5, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -130.0, 433.566, 0.0, 1.0),
              child: FigBox(
                width: 256.701,
                height: 166.424,
                radius: 14.13,
                clip: true,
                padding: const EdgeInsets.fromLTRB(1.57, 0.0, 0.0, 1.57),
                shadows: const [BoxShadow(color: Color(0x33000000), offset: Offset(0.0, 7.85), blurRadius: 15.7, spreadRadius: -6.28)],
                border: const Border(top: BorderSide.none, right: BorderSide.none, bottom: BorderSide(color: Color(0x99ffffff), width: 1.57), left: BorderSide(color: Color(0x99ffffff), width: 1.57)),
                bgImage: const FigBgImage('assets/figma/42106bb926250bae.png', x: 0.5, y: 0.4, wFactor: 1.0, hFactor: 1.036),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FigOverflow(
                      alignment: const Alignment(-1.0, -1.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8.0,
                        children: [
                        ],
                      )
                      ,
                    ),
                    Positioned(
                      left: 48.0, top: 48.0,
                      child: Transform(
                        transform: Matrix4(0.393, 0.0, 0.0, 0.0, 0.0, 0.393, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0),
                        child: FigBox(
                          width: 554.0,
                          height: 316.0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FigBox(
                                width: 136.0,
                                height: 48.0,
                                clip: true,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: 0.0, top: 0.0,
                                      child: FigSvg(
                                        width: 96.0, height: 31.04,
                                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 96.0, vbHeight: 31.04,
                                        shapes: const [FigShape(d: _p7, fill: Color(0xff1434cb))],
                                      )
                                    ),
                                  ],
                                )
                                ,
                              ),
                              FigBox(
                                width: 554.0,
                                height: 138.0,
                                child: FigOverflow(
                                  alignment: const Alignment(-1.0, -1.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    spacing: 80.0,
                                    children: [
                                      FigText(
                                        noWrap: true,
                                        span: 
                                          TextSpan(text: '4012 0741 8888 1881', style: figStyle(fontSize: 48.0, weight: 700, height: 0.033, color: const Color(0xff262626)))
                                        ,
                                      ),
                                      FigBox(
                                        width: 554.0,
                                        child: FigOverflow(
                                          alignment: const Alignment(-1.0, -1.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              FigText(
                                                noWrap: true,
                                                span: 
                                                  TextSpan(text: 'ASKAT', style: figStyle(fontSize: 32.0, weight: 500, height: 0.05, color: const Color(0xff262626)))
                                                ,
                                              ),
                                              FigText(
                                                noWrap: true,
                                                span: 
                                                  TextSpan(text: '05/22', style: figStyle(fontSize: 24.0, weight: 500, height: 0.067, color: const Color(0xff262626)))
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
    'M 21.016 0 L 0 0 L 0 37.716 L 21.016 37.716 L 21.016 0 Z';
const String _p4 =
    'M 29.694 23.994 C 29.694 16.665 33.097 9.668 38.834 5.137 C 28.427 -3.06 13.349 -1.261 5.143 9.201 C -3.063 19.596 -1.262 34.656 9.212 42.852 C 17.952 49.716 30.161 49.716 38.901 42.852 C 33.097 38.321 29.694 31.324 29.694 23.994 Z';
const String _p5 =
    'M 38.829 23.994 C 38.829 37.255 28.087 47.983 14.811 47.983 C 9.407 47.983 4.203 46.184 0 42.852 C 10.408 34.656 12.209 19.596 4.003 9.135 C 2.802 7.669 1.468 6.269 0 5.137 C 10.408 -3.06 25.552 -1.261 33.692 9.201 C 37.027 13.399 38.829 18.597 38.829 23.994 Z';
const String _p6 =
    'M 0.467 0.933 L 0.467 0.133 L 0.801 0.133 L 0.801 0 L 0 0 L 0 0.133 L 0.334 0.133 L 0.334 0.933 L 0.467 0.933 Z M 2.001 0.933 L 2.001 0 L 1.735 0 L 1.468 0.666 L 1.201 0 L 0.934 0 L 0.934 0.933 L 1.134 0.933 L 1.134 0.2 L 1.401 0.8 L 1.601 0.8 L 1.868 0.2 L 1.868 0.933 L 2.001 0.933 Z';
const String _p7 =
    'M 62.548 0 C 55.741 0 49.629 3.542 49.629 10.042 C 49.629 17.528 60.425 18.04 60.425 21.765 C 60.425 23.335 58.596 24.759 55.521 24.759 C 51.129 24.759 47.835 22.787 47.835 22.787 L 46.445 29.36 C 46.445 29.36 50.214 31.04 55.265 31.04 C 62.731 31.04 68.587 27.352 68.587 20.706 C 68.587 12.818 57.754 12.306 57.754 8.837 C 57.754 7.596 59.254 6.245 62.329 6.245 C 65.806 6.245 68.66 7.669 68.66 7.669 L 70.051 1.315 C 70.014 1.315 66.904 0 62.548 0 Z M 0.183 0.475 L 0 1.424 C 0 1.424 2.855 1.935 5.453 2.994 C 8.784 4.2 9.003 4.893 9.589 7.048 L 15.701 30.529 L 23.899 30.529 L 36.453 0.475 L 28.291 0.475 L 20.203 20.925 L 16.909 3.579 C 16.616 1.607 15.079 0.475 13.176 0.475 L 0.183 0.475 Z M 39.747 0.475 L 33.342 30.529 L 41.138 30.529 L 47.506 0.475 L 39.747 0.475 Z M 83.154 0.475 C 81.287 0.475 80.299 1.461 79.567 3.214 L 68.148 30.529 L 76.31 30.529 L 77.883 25.964 L 87.838 25.964 L 88.79 30.529 L 96 30.529 L 89.742 0.475 L 83.154 0.475 Z M 84.215 8.618 L 86.631 19.902 L 80.152 19.902 L 84.215 8.618 Z';
