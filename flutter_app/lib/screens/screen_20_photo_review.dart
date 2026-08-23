// GENERATED from screens/Components.bundle.js — figma node StartScreen20.
// Do not edit by hand; regenerate with tool/generate_screens.js.
import 'package:flutter/material.dart';

import '../fig/fig.dart';

/// Фотообзор — 375.0×812.0
class Screen20PhotoReview extends StatelessWidget {
  const Screen20PhotoReview({super.key});

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
            left: -349.0, top: -89.0,
            child: FigSvg(
              width: 354.0, height: 33.0,
              vbLeft: 0.0, vbTop: 0.0, vbWidth: 354.0, vbHeight: 33.0,
              shapes: const [FigShape(d: _p3, fill: Color(0xffffffff))],
            )
          ),
          Positioned(
            left: 136.0, top: 725.0,
            child: FigBox(
              color: const Color(0x4dffffff),
              radius: 20.0,
              blur: 27.0,
              padding: const EdgeInsets.fromLTRB(10.0, 3.0, 10.0, 5.0),
              child: FigOverflow(
                alignment: const Alignment(0.0, 0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 10.0,
                  children: [
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
                              width: 16.0,
                              height: 16.0,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.667, top: 1.333,
                                    child: Opacity(
                                      opacity: 0.0,
                                      child: FigSvg(
                                        width: 14.365, height: 13.333,
                                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 14.365, vbHeight: 13.333,
                                        shapes: const [FigShape(d: _p4, fill: Color(0xf2ffffff))],
                                      ),
                                    )
                                  ),
                                  Positioned(
                                    left: 0.667, top: 1.333,
                                    child: FigSvg(
                                      width: 14.135, height: 13.327,
                                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 14.135, vbHeight: 13.327,
                                      shapes: const [FigShape(d: _p5, fill: Color(0xf2ffffff))],
                                    )
                                  ),
                                ],
                              )
                              ,
                            ),
                            FigText(
                              noWrap: true,
                              span: 
                                TextSpan(text: 'Вернуться', style: figStyle(fontSize: 13.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2ffffff)))
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
            left: 25.0, top: 48.0,
            child: FigBox(
              child: FigOverflow(
                freeWidth: true,
                alignment: const Alignment(-1.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  spacing: 63.0,
                  children: [
                    FigText(
                      noWrap: true,
                      span: 
                        TextSpan(text: 'Фотообзор', style: figStyle(fontSize: 21.0, family: FigFont.display, weight: 600, height: 1.0, letterSpacing: -0.21, color: const Color(0xffffffff)))
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
                              color: const Color(0x4dffffff),
                              radius: 20.0,
                              blur: 27.0,
                              padding: const EdgeInsets.fromLTRB(10.0, 3.0, 10.0, 5.0),
                              child: FigOverflow(
                                alignment: const Alignment(0.0, 0.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 10.0,
                                  children: [
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
                                              width: 16.0,
                                              height: 16.0,
                                              clip: true,
                                              child: Stack(
                                                clipBehavior: Clip.none,
                                                children: [
                                                  Positioned(
                                                    left: 0.667, top: 1.333,
                                                    child: Opacity(
                                                      opacity: 0.0,
                                                      child: FigSvg(
                                                        width: 14.365, height: 13.333,
                                                        vbLeft: 0.0, vbTop: 0.0, vbWidth: 14.365, vbHeight: 13.333,
                                                        shapes: const [FigShape(d: _p4, fill: Color(0xf2ffffff))],
                                                      ),
                                                    )
                                                  ),
                                                  Positioned(
                                                    left: 3.0, top: 1.0,
                                                    child: FigBox(
                                                      width: 10.0,
                                                      height: 14.321,
                                                      clip: true,
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Positioned(
                                                            left: 0.0, top: 0.0,
                                                            child: Opacity(
                                                              opacity: 0.0,
                                                              child: FigSvg(
                                                                width: 10.0, height: 14.321,
                                                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 10.0, vbHeight: 14.321,
                                                                shapes: const [FigShape(d: _p6, fill: Color(0xfffbfafa))],
                                                              ),
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 0.0, top: 3.974,
                                                            child: FigSvg(
                                                              width: 9.796, height: 8.863,
                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 9.796, vbHeight: 8.863,
                                                              shapes: const [FigShape(d: _p7, fill: Color(0xfffbfafa))],
                                                            )
                                                          ),
                                                          Positioned(
                                                            left: 2.627, top: 1.038,
                                                            child: FigSvg(
                                                              width: 4.542, height: 8.079,
                                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 4.542, vbHeight: 8.079,
                                                              shapes: const [FigShape(d: _p8, fill: Color(0xfffbfafa))],
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
                                                TextSpan(text: 'Скачать все фото', style: figStyle(fontSize: 10.0, family: FigFont.display, weight: 500, height: 1.0, color: const Color(0xf2ffffff)))
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
                              width: 24.0,
                              height: 24.0,
                              clip: true,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: 0.0, top: 0.0,
                                    child: FigBox(
                                      width: 24.0,
                                      height: 24.0,
                                      color: const Color(0xffffffff),
                                      radius: 12.0,
                                    )
                                  ),
                                  Positioned(
                                    left: 5.823, top: 6.51,
                                    child: FigBox(
                                      width: 12.353,
                                      height: 10.981,
                                      clip: true,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned(
                                            left: 0.0, top: 0.0,
                                            child: Opacity(
                                              opacity: 0.0,
                                              child: FigSvg(
                                                width: 12.353, height: 10.98,
                                                vbLeft: 0.0, vbTop: 0.0, vbWidth: 12.353, vbHeight: 10.98,
                                                shapes: const [FigShape(d: _p9, fill: Color(0xccea812e))],
                                              ),
                                            )
                                          ),
                                          Positioned(
                                            left: 0.0, top: 0.354,
                                            child: FigSvg(
                                              width: 12.127, height: 10.627,
                                              vbLeft: 0.0, vbTop: 0.0, vbWidth: 12.127, vbHeight: 10.627,
                                              shapes: const [FigShape(d: _p10, fill: Color(0xccea812e))],
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
            left: 340.0, top: 397.0,
            child: FigSvg(
              width: 10.0, height: 18.0,
              vbLeft: 0.0, vbTop: 0.0, vbWidth: 10.0, vbHeight: 18.0,
              shapes: const [FigShape(d: _p11, fill: Color(0xffffffff), evenOdd: true)],
            )
          ),
          Positioned(
            left: 0.0, top: 0.0,
            child: Transform(
              transform: Matrix4(-1.0, 0.0, 0.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 35.0, 415.0, 0.0, 1.0),
              child: FigSvg(
                width: 10.0, height: 18.0,
                vbLeft: 0.0, vbTop: 0.0, vbWidth: 10.0, vbHeight: 18.0,
                shapes: const [FigShape(d: _p11, fill: Color(0xffffffff), evenOdd: true)],
              )
              ,
            )
          ),
          Positioned(
            left: 157.5, top: 758.5,
            child: FigBox(
              color: const Color(0x6699a2ad),
              radius: 34.0,
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
                      shapes: const [FigShape(d: _p12, fill: Color(0xffc4c9cf))],
                    ),
                    FigSvg(
                      width: 8.0, height: 8.0,
                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 8.0, vbHeight: 8.0,
                      shapes: const [FigShape(d: _p12, fill: Color(0xffc4c9cf))],
                    ),
                    FigSvg(
                      width: 8.0, height: 8.0,
                      vbLeft: 0.0, vbTop: 0.0, vbWidth: 8.0, vbHeight: 8.0,
                      shapes: const [FigShape(d: _p12, fill: Color(0xffea812e))],
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
    'M 0 0 L 354 0 L 354 33 L 0 33 L 0 0 Z';
const String _p4 =
    'M 14.365 0 L 0 0 L 0 13.333 L 14.365 13.333 L 14.365 0 Z';
const String _p5 =
    'M 0 11.45 C 0 12.687 0.615 13.327 1.877 13.327 L 12.183 13.327 C 13.489 13.327 14.135 12.687 14.135 11.406 L 14.135 1.927 C 14.135 0.646 13.489 0 12.183 0 L 4.693 0 C 3.394 0 2.741 0.646 2.741 1.927 L 2.741 4.892 L 1.256 4.892 C 0.466 4.892 0 5.321 0 6.061 L 0 11.45 Z M 1.001 11.45 L 1.001 6.253 C 1.001 6.023 1.138 5.893 1.368 5.893 L 2.741 5.893 L 2.741 11.45 C 2.741 11.966 2.362 12.326 1.877 12.326 C 1.386 12.326 1.001 11.947 1.001 11.45 Z M 3.531 12.326 C 3.667 12.059 3.742 11.748 3.742 11.388 L 3.742 1.983 C 3.742 1.336 4.09 1.001 4.712 1.001 L 12.165 1.001 C 12.786 1.001 13.134 1.336 13.134 1.983 L 13.134 11.35 C 13.134 11.997 12.786 12.326 12.165 12.326 L 3.531 12.326 Z M 5.358 3.705 L 11.531 3.705 C 11.748 3.705 11.916 3.531 11.916 3.313 C 11.916 3.102 11.748 2.94 11.531 2.94 L 5.358 2.94 C 5.134 2.94 4.967 3.102 4.967 3.313 C 4.967 3.531 5.134 3.705 5.358 3.705 Z M 5.358 5.893 L 11.531 5.893 C 11.748 5.893 11.916 5.725 11.916 5.514 C 11.916 5.296 11.748 5.128 11.531 5.128 L 5.358 5.128 C 5.134 5.128 4.967 5.296 4.967 5.514 C 4.967 5.725 5.134 5.893 5.358 5.893 Z M 5.725 10.325 L 7.335 10.325 C 7.807 10.325 8.093 10.039 8.093 9.566 L 8.093 8.087 C 8.093 7.608 7.807 7.322 7.335 7.322 L 5.725 7.322 C 5.246 7.322 4.96 7.608 4.96 8.087 L 4.96 9.566 C 4.96 10.039 5.246 10.325 5.725 10.325 Z M 9.212 8.087 L 11.524 8.087 C 11.748 8.087 11.91 7.925 11.91 7.714 C 11.91 7.49 11.748 7.322 11.524 7.322 L 9.212 7.322 C 8.988 7.322 8.827 7.49 8.827 7.714 C 8.827 7.925 8.988 8.087 9.212 8.087 Z M 9.212 10.325 L 11.524 10.325 C 11.748 10.325 11.91 10.163 11.91 9.952 C 11.91 9.734 11.748 9.56 11.524 9.56 L 9.212 9.56 C 8.988 9.56 8.827 9.734 8.827 9.952 C 8.827 10.163 8.988 10.325 9.212 10.325 Z';
const String _p6 =
    'M 10 0 L 0 0 L 0 14.321 L 10 14.321 L 10 0 Z';
const String _p7 =
    'M 9.796 2.307 L 9.796 6.556 C 9.796 8.041 8.968 8.863 7.483 8.863 L 2.307 8.863 C 0.822 8.863 0 8.041 0 6.556 L 0 2.307 C 0 0.828 0.822 0 2.307 0 L 3.422 0 L 3.422 0.889 L 2.307 0.889 C 1.402 0.889 0.889 1.402 0.889 2.307 L 0.889 6.556 C 0.889 7.467 1.402 7.975 2.307 7.975 L 7.483 7.975 C 8.394 7.975 8.907 7.467 8.907 6.556 L 8.907 2.307 C 8.907 1.402 8.394 0.889 7.483 0.889 L 6.374 0.889 L 6.374 0 L 7.483 0 C 8.968 0 9.796 0.828 9.796 2.307 Z';
const String _p8 =
    'M 2.274 0 C 2.036 0 1.832 0.193 1.832 0.425 L 1.832 6.043 L 1.898 7.528 C 1.909 7.732 2.07 7.897 2.274 7.897 C 2.472 7.897 2.632 7.732 2.643 7.528 L 2.71 6.043 L 2.71 0.425 C 2.71 0.193 2.511 0 2.274 0 Z M 0.397 5.497 C 0.166 5.497 0 5.662 0 5.883 C 0 6.004 0.05 6.093 0.132 6.176 L 1.954 7.93 C 2.064 8.041 2.158 8.079 2.274 8.079 C 2.384 8.079 2.478 8.041 2.588 7.93 L 4.41 6.176 C 4.492 6.093 4.542 6.004 4.542 5.883 C 4.542 5.662 4.365 5.497 4.139 5.497 C 4.029 5.497 3.918 5.541 3.841 5.629 L 2.986 6.54 L 2.274 7.301 L 1.556 6.54 L 0.701 5.629 C 0.624 5.541 0.508 5.497 0.397 5.497 Z';
const String _p9 =
    'M 12.353 0 L 0 0 L 0 10.98 L 12.353 10.98 L 12.353 0 Z';
const String _p10 =
    'M 0 3.496 C 0 5.962 2.18 8.387 5.624 10.471 C 5.752 10.546 5.935 10.627 6.064 10.627 C 6.192 10.627 6.375 10.546 6.509 10.471 C 9.947 8.387 12.127 5.962 12.127 3.496 C 12.127 1.447 10.643 0 8.665 0 C 7.535 0 6.619 0.509 6.064 1.291 C 5.52 0.515 4.592 0 3.462 0 C 1.484 0 0 1.447 0 3.496 Z M 0.983 3.496 C 0.983 1.956 2.033 0.932 3.45 0.932 C 4.598 0.932 5.258 1.609 5.648 2.188 C 5.813 2.42 5.917 2.483 6.064 2.483 C 6.21 2.483 6.302 2.414 6.479 2.188 C 6.9 1.621 7.535 0.932 8.677 0.932 C 10.094 0.932 11.144 1.956 11.144 3.496 C 11.144 5.649 8.744 7.971 6.192 9.58 C 6.131 9.62 6.088 9.649 6.064 9.649 C 6.039 9.649 5.996 9.62 5.941 9.58 C 3.383 7.971 0.983 5.649 0.983 3.496 Z';
const String _p11 =
    'M 0.418 0.439 C -0.139 1.025 -0.139 1.975 0.418 2.561 L 6.551 9 L 0.418 15.439 C -0.139 16.025 -0.139 16.975 0.418 17.561 C 0.976 18.146 1.881 18.146 2.439 17.561 L 9.582 10.061 C 10.139 9.475 10.139 8.525 9.582 7.939 L 2.439 0.439 C 1.881 -0.146 0.976 -0.146 0.418 0.439 Z';
const String _p12 =
    'M 0 4 C 0 1.791 1.791 0 4 0 L 4 0 C 6.209 0 8 1.791 8 4 L 8 4 C 8 6.209 6.209 8 4 8 L 4 8 C 1.791 8 0 6.209 0 4 L 0 4 Z';
